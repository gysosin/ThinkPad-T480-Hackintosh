#!/usr/bin/env bash
# Rebuild the USB recovery partition the CORRECT way for OpenCore.
#
# The first build dd'd an APFS BaseSystem image onto an HFS+ partition →
# kernel boots but can't mount root ("boot-uuid-media" + prohibited sign).
#
# Correct method: put com.apple.recovery.boot/{BaseSystem.dmg,chunklist}
# on a FAT32 partition. OpenCore detects it and boots the dmg as a
# recovery ramdisk — no raw dd, no filesystem-type mismatch.
#
# Run:  sudo bash fix-usb-recovery.sh
set -uo pipefail

G=$'\033[1;32m'; Y=$'\033[1;33m'; R=$'\033[1;31m'; C=$'\033[1;36m'; X=$'\033[0m'
info(){ echo "${C}[info]${X} $*"; }
ok(){ echo "${G}[ ok ]${X} $*"; }
warn(){ echo "${Y}[warn]${X} $*"; }
die(){ echo "${R}[fail]${X} $*"; exit 1; }

[[ $EUID -eq 0 ]] || die "Run as root:  sudo bash fix-usb-recovery.sh"

# ── 1. Find the USB by its OPENCORE label, then its partition 2 ──────────
ESP=$(lsblk -ln -o NAME,LABEL | awk '$2=="OPENCORE"{print $1; exit}')
[[ -n "$ESP" ]] || die "Can't find OPENCORE partition — is the USB plugged in?"
USB_DISK="/dev/$(lsblk -no PKNAME "/dev/$ESP" | head -1)"
REC_PART="${USB_DISK}2"
[[ -b "$REC_PART" ]] || die "Recovery partition $REC_PART not found"
info "USB disk: $USB_DISK   ESP: /dev/$ESP   recovery: $REC_PART"

# ── 2. Locate cached BaseSystem; else re-download via macrecovery ────────
CACHE="/root/.cache/gibMacOS/com.apple.recovery.boot"
DMG="" CHK=""
if [[ -s "$CACHE/BaseSystem.dmg" && -s "$CACHE/BaseSystem.chunklist" ]]; then
  DMG="$CACHE/BaseSystem.dmg"; CHK="$CACHE/BaseSystem.chunklist"
  ok "Using cached BaseSystem ($(du -h "$DMG"|cut -f1))"
else
  warn "BaseSystem not cached — re-downloading (~700 MB)…"
  WORK=/root/.cache/macrec; mkdir -p "$WORK"; cd "$WORK"
  if [[ ! -f macrecovery.py ]]; then
    curl -fsSL -o macrecovery.py \
      https://raw.githubusercontent.com/acidanthera/OpenCorePkg/master/Utilities/macrecovery/macrecovery.py \
      || die "Could not fetch macrecovery.py"
  fi
  sed -i "s|os.get_terminal_size().columns|__import__('shutil').get_terminal_size(fallback=(80,24)).columns|g" macrecovery.py 2>/dev/null || true
  python3 macrecovery.py -b Mac-7BA5B2D9E42DDD94 -m 00000000000000000 download \
    || die "macrecovery download failed"
  DMG="$WORK/com.apple.recovery.boot/BaseSystem.dmg"
  CHK="$WORK/com.apple.recovery.boot/BaseSystem.chunklist"
  [[ -s "$DMG" ]] || die "BaseSystem.dmg missing after download"
  ok "Downloaded BaseSystem"
fi

# ── 3. Reformat recovery partition as HFS+ (OpenCore reads via HfsPlus.efi)
# mkfs.vfat can't FAT32-format a 114 GB partition; HFS+ has no such limit
# and mkfs.hfsplus is proven to work on this exact partition.
info "Reformatting $REC_PART as HFS+…"
umount "${REC_PART}" 2>/dev/null || true
umount "${USB_DISK}"* 2>/dev/null || true
wipefs -a "$REC_PART" >/dev/null 2>&1 || true
if ! mkfs.hfsplus -v macOS "$REC_PART" 2>/tmp/mkfs.err; then
  cat /tmp/mkfs.err
  die "mkfs.hfsplus failed on $REC_PART"
fi
ok "Formatted HFS+ (label macOS)"

# ── 4. Copy com.apple.recovery.boot/{BaseSystem.dmg,chunklist} ──────────
MNT=/mnt/usb-rec
mkdir -p "$MNT"
mount "$REC_PART" "$MNT" || die "mount $REC_PART failed"
trap 'sync; umount "$MNT" 2>/dev/null || true' EXIT
mkdir -p "$MNT/com.apple.recovery.boot"
info "Copying BaseSystem.dmg ($(du -h "$DMG"|cut -f1))…"
cp "$DMG" "$MNT/com.apple.recovery.boot/BaseSystem.dmg"
cp "$CHK" "$MNT/com.apple.recovery.boot/BaseSystem.chunklist"
sync
ok "Copied recovery payload"

# ── 5. Verify ───────────────────────────────────────────────────────────
ls -la "$MNT/com.apple.recovery.boot/"
d=$(stat -c%s "$MNT/com.apple.recovery.boot/BaseSystem.dmg")
[[ "$d" -gt 100000000 ]] || die "BaseSystem.dmg too small ($d bytes) — copy failed"
ok "BaseSystem.dmg = $((d/1024/1024)) MB on recovery partition"

# ── 6. Make sure OpenCore will scan & boot it ───────────────────────────
CFG="/mnt/usb-esp"
mkdir -p "$CFG"
mount "/dev/$ESP" "$CFG" 2>/dev/null || true
if [[ -f "$CFG/EFI/OC/config.plist" ]]; then
  python3 - "$CFG/EFI/OC/config.plist" <<'PYEOF'
import plistlib,sys
p=sys.argv[1]
c=plistlib.load(open(p,'rb'))
ch=[]
sec=c.setdefault("Misc",{}).setdefault("Security",{})
if sec.get("ScanPolicy")!=0: sec["ScanPolicy"]=0; ch.append("ScanPolicy=0")
b=c.setdefault("Misc",{}).setdefault("Boot",{})
if b.get("HideAuxiliary") is True: b["HideAuxiliary"]=False; ch.append("HideAuxiliary=False")
if sec.get("DmgLoading")!="Any": sec["DmgLoading"]="Any"; ch.append("DmgLoading=Any")
plistlib.dump(c,open(p,'wb'),sort_keys=False)
print("config tweaks:", ", ".join(ch) if ch else "none needed")
PYEOF
  ok "OpenCore config set to scan + load recovery dmg"
else
  warn "config.plist not found on ESP — skipping (recovery should still show)"
fi
umount "$CFG" 2>/dev/null || true

echo
ok "DONE. Eject and boot the T480 from this USB."
echo "  sudo eject $USB_DISK"
echo
echo "At the OpenCore picker you should now see 'macOS Base System'."
echo "Select it → it loads the recovery → Disk Utility → erase NVMe as APFS"
echo "→ Reinstall macOS."
