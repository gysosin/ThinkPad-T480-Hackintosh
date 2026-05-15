#!/usr/bin/env bash
# Comprehensive recovery-boot fix: strip boot-args to recovery-safe minimal,
# re-pull latest recovery, rebuild HFS+ recovery folder, pre-empt next blockers.
#
# Why: the recovery booted to userspace but dyld shared_region crash-loops
# because our Tahoe daily-driver boot-args (amfi=0x80, -amfipassbeta,
# -lilubetaall, shikigva, igfx*, unfairgva, ipc_control_port_options) break
# AMFI/dyld in the minimal recovery environment. Recovery needs near-stock.
#
# Run:  sudo bash fix-usb-recovery-safe.sh
set -uo pipefail

G=$'\033[1;32m'; Y=$'\033[1;33m'; R=$'\033[1;31m'; C=$'\033[1;36m'; X=$'\033[0m'
info(){ echo "${C}[info]${X} $*"; }
ok(){ echo "${G}[ ok ]${X} $*"; }
warn(){ echo "${Y}[warn]${X} $*"; }
die(){ echo "${R}[fail]${X} $*"; exit 1; }
[[ $EUID -eq 0 ]] || die "Run as root: sudo bash fix-usb-recovery-safe.sh"

# ── locate USB ──────────────────────────────────────────────────────────
ESP=$(lsblk -ln -o NAME,LABEL | awk '$2=="OPENCORE"{print $1; exit}')
[[ -n "$ESP" ]] || die "OPENCORE partition not found — USB plugged in?"
USB_DISK="/dev/$(lsblk -no PKNAME "/dev/$ESP" | head -1)"
REC_PART="${USB_DISK}2"
info "USB: $USB_DISK  ESP: /dev/$ESP  rec: $REC_PART"

# ── 1. Re-pull the LATEST recovery (rule out version mismatch) ──────────
WORK=/root/.cache/macrec-latest
mkdir -p "$WORK"; cd "$WORK"
if [[ ! -f macrecovery.py ]]; then
  curl -fsSL -o macrecovery.py \
    https://raw.githubusercontent.com/acidanthera/OpenCorePkg/master/Utilities/macrecovery/macrecovery.py \
    || die "fetch macrecovery.py failed"
fi
sed -i "s|os.get_terminal_size().columns|__import__('shutil').get_terminal_size(fallback=(80,24)).columns|g" macrecovery.py 2>/dev/null || true

if [[ -s "$WORK/com.apple.recovery.boot/BaseSystem.dmg" ]]; then
  ok "Latest recovery already cached ($(du -h "$WORK/com.apple.recovery.boot/BaseSystem.dmg"|cut -f1))"
else
  info "Downloading LATEST recovery (board Mac-937A206F2EE63C01 = iMac20,1, T2, Tahoe-capable)…"
  # iMac20,1 board pulls the newest recovery Apple serves (Tahoe 26 line)
  if ! python3 macrecovery.py -b Mac-CFF7D910A743CAAF -m 00000000000000000 -os latest download 2>/dev/null; then
    warn "-os latest unsupported by this macrecovery; trying plain latest-board download"
    python3 macrecovery.py -b Mac-CFF7D910A743CAAF -m 00000000000000000 download \
      || die "recovery download failed"
  fi
  [[ -s "$WORK/com.apple.recovery.boot/BaseSystem.dmg" ]] || die "BaseSystem.dmg missing"
  ok "Downloaded latest recovery"
fi
DMG="$WORK/com.apple.recovery.boot/BaseSystem.dmg"
CHK="$WORK/com.apple.recovery.boot/BaseSystem.chunklist"

# ── 2. Rebuild HFS+ recovery partition with the latest dmg ─────────────
info "Reformatting $REC_PART HFS+ and copying recovery…"
umount "${USB_DISK}"* 2>/dev/null || true
wipefs -a "$REC_PART" >/dev/null 2>&1 || true
mkfs.hfsplus -v macOS "$REC_PART" >/dev/null 2>/tmp/mk.err || { cat /tmp/mk.err; die "mkfs.hfsplus failed"; }
MNT=/mnt/usb-rec; mkdir -p "$MNT"
mount "$REC_PART" "$MNT" || die "mount rec failed"
mkdir -p "$MNT/com.apple.recovery.boot"
cp "$DMG" "$MNT/com.apple.recovery.boot/BaseSystem.dmg"
cp "$CHK" "$MNT/com.apple.recovery.boot/BaseSystem.chunklist"
sync; umount "$MNT"
ok "Recovery payload written"

# ── 3. Patch config.plist: RECOVERY-SAFE boot-args + sane SIP ──────────
EMNT=/mnt/usb-esp; mkdir -p "$EMNT"
mount "/dev/$ESP" "$EMNT" || die "mount ESP failed"
CFG="$EMNT/EFI/OC/config.plist"
[[ -f "$CFG" ]] || die "config.plist not found"
cp "$CFG" "$EMNT/EFI/OC/config.plist.bak-presafe"

python3 - "$CFG" <<'PYEOF'
import plistlib, sys
p = sys.argv[1]
c = plistlib.load(open(p, "rb"))
ch = []

NV = "7C436110-AB2A-4BBB-A880-FE41995C9F82"
add = c.setdefault("NVRAM", {}).setdefault("Add", {}).setdefault(NV, {})

# RECOVERY-SAFE boot-args: bare minimum. Everything else breaks recovery dyld/AMFI.
add["boot-args"] = "-v keepsyms=1 debug=0x100"
ch.append("boot-args -> '-v keepsyms=1 debug=0x100' (recovery-safe)")

# SIP fully enabled is SAFEST for recovery boot (00000000).
add["csr-active-config"] = bytes.fromhex("00000000")
ch.append("csr-active-config -> 0x00000000 (full SIP, recovery-safe)")

# Ensure Delete refreshes them each boot
nd = c.setdefault("NVRAM", {}).setdefault("Delete", {}).setdefault(NV, [])
for k in ("boot-args", "csr-active-config"):
    if k not in nd: nd.append(k)

# Drop the OCLP/RestrictEvents NVRAM that's only for installed Tahoe
OCLP = "4D1FDA02-38C7-4A6A-9CC6-4BCCA8B30102"
if OCLP in c.get("NVRAM", {}).get("Add", {}):
    del c["NVRAM"]["Add"][OCLP]
    ch.append("removed OCLP NVRAM block (post-install only)")

# SecureBootModel must be Disabled for the install/recovery
sec = c.setdefault("Misc", {}).setdefault("Security", {})
if sec.get("SecureBootModel") != "Disabled":
    sec["SecureBootModel"] = "Disabled"; ch.append("SecureBootModel=Disabled")
if sec.get("ScanPolicy") != 0:
    sec["ScanPolicy"] = 0; ch.append("ScanPolicy=0")
if sec.get("DmgLoading") != "Any":
    sec["DmgLoading"] = "Any"; ch.append("DmgLoading=Any")
b = c.setdefault("Misc", {}).setdefault("Boot", {})
if b.get("HideAuxiliary") is True:
    b["HideAuxiliary"] = False; ch.append("HideAuxiliary=False")

# Disable AMFIPass kext for recovery (it interferes with recovery dyld/AMFI)
for e in c.get("Kernel", {}).get("Add", []):
    if e.get("BundlePath") == "AMFIPass.kext" and e.get("Enabled"):
        e["Enabled"] = False; ch.append("kext disabled: AMFIPass.kext (recovery)")

# Keep the Booter Skip-Board-ID patch (needed even for recovery on unsupported SMBIOS)
# but make sure the SkipLogo / HW_BID patches stay enabled (harmless, helpful).

# Quirks sane for recovery
kq = c.setdefault("Kernel", {}).setdefault("Quirks", {})
if not kq.get("XhciPortLimit"): kq["XhciPortLimit"] = True; ch.append("XhciPortLimit=True")
kq["DisableLinkeditJettison"] = True

plistlib.dump(c, open(p, "wb"), sort_keys=False)
print(f"{len(ch)} config changes:")
for x in ch: print("  • " + x)
PYEOF

if command -v xmllint >/dev/null; then
  xmllint --noout "$CFG" || die "config.plist XML broke — restore config.plist.bak-presafe"
  ok "config.plist XML valid"
fi
sync; umount "$EMNT"

echo
ok "DONE. Eject and boot:"
echo "  sudo eject $USB_DISK"
echo
echo "Boot T480 → F12 → USB → OpenCore → 'macOS Base System'."
echo "Recovery-safe args + full SIP + minimal kexts should let the recovery"
echo "reach the macOS Utilities / Disk Utility screen."
echo
echo "If it STILL crash-loops on shared_region: the recovery image macOS"
echo "version is fundamentally incompatible with KBL-R via these patches —"
echo "at that point Sonoma/Sequoia is the realistic target, not Tahoe."
