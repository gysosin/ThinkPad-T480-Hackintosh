#!/usr/bin/env bash
# Patch the config.plist on the install USB for INSTALL-ONLY minimal mode.
# Disables the post-install WiFi/IOSkywalk/USBMap stack that breaks the
# minimal macOS recovery boot (prohibited sign / I2C timeout hang).
#
# Run:  sudo bash fix-usb-install-mode.sh
#
# After macOS is installed, run post-install.sh which re-enables WiFi via OCLP.
set -uo pipefail

ESP_DEV="${1:-/dev/sda1}"
MNT=/mnt/usb-esp

G=$'\033[1;32m'; Y=$'\033[1;33m'; R=$'\033[1;31m'; C=$'\033[1;36m'; X=$'\033[0m'
info(){ echo "${C}[info]${X} $*"; }
ok(){ echo "${G}[ ok ]${X} $*"; }
warn(){ echo "${Y}[warn]${X} $*"; }
die(){ echo "${R}[fail]${X} $*"; exit 1; }

[[ $EUID -eq 0 ]] || die "Run with sudo: sudo bash fix-usb-install-mode.sh"

# Auto-detect the OPENCORE ESP if default not present
if [[ ! -b "$ESP_DEV" ]]; then
  ESP_DEV=$(lsblk -ln -o NAME,LABEL | awk '$2=="OPENCORE"{print "/dev/"$1; exit}')
  [[ -n "$ESP_DEV" ]] || die "Cannot find OPENCORE partition. Pass it: sudo bash fix-usb-install-mode.sh /dev/sdX1"
fi
info "ESP device: $ESP_DEV"

mkdir -p "$MNT"
umount "$MNT" 2>/dev/null || true
mount "$ESP_DEV" "$MNT" || die "mount failed"
trap 'umount "$MNT" 2>/dev/null || true' EXIT

CFG="$MNT/EFI/OC/config.plist"
[[ -f "$CFG" ]] || die "config.plist not found at $CFG"

cp "$CFG" "$MNT/EFI/OC/config.plist.fullbackup"
ok "Backed up → config.plist.fullbackup (restore after install for WiFi)"

python3 - "$CFG" <<'PYEOF'
import plistlib, sys
p = sys.argv[1]
with open(p, "rb") as f:
    c = plistlib.load(f)

changes = []

# 1. Disable heavy kexts that break minimal recovery boot
DISABLE = {
    "AirportItlwm.kext",
    "IOSkywalkFamily.kext",
    "IO80211FamilyLegacy.kext",
    "USBToolBox.kext",
    "USBMap.kext",
    "IntelBluetoothFirmware.kext",
    "IntelBTPatcher.kext",
    "BlueToolFixup.kext",
}
for e in c.get("Kernel", {}).get("Add", []):
    bp = e.get("BundlePath", "")
    if bp in DISABLE and e.get("Enabled", False):
        e["Enabled"] = False
        changes.append(f"kext disabled: {bp}")

# 2. Remove IOSkywalkFamily from Kernel.Block (it breaks recovery)
blk = c.get("Kernel", {}).get("Block", [])
newblk = [b for b in blk if b.get("Identifier") != "com.apple.iokit.IOSkywalkFamily"]
if len(newblk) != len(blk):
    c["Kernel"]["Block"] = newblk
    changes.append("removed Kernel.Block IOSkywalkFamily")

# 3. Disable USB ACPI SSDTs causing _UPC errors (not needed for install)
for e in c.get("ACPI", {}).get("Add", []):
    if e.get("Path", "") in ("SSDT-XHC.aml",) and e.get("Enabled", False):
        e["Enabled"] = False
        changes.append("ACPI disabled: SSDT-XHC.aml")

# 4. USBMap disabled → need XhciPortLimit during install
kq = c.setdefault("Kernel", {}).setdefault("Quirks", {})
if not kq.get("XhciPortLimit"):
    kq["XhciPortLimit"] = True
    changes.append("Kernel.Quirks.XhciPortLimit = True")

# 5. Strip the WiFi/OCLP NVRAM bits not needed for plain install boot
nv = c.get("NVRAM", {}).get("Add", {})
ba_guid = "7C436110-AB2A-4BBB-A880-FE41995C9F82"
if ba_guid in nv and "boot-args" in nv[ba_guid]:
    ba = nv[ba_guid]["boot-args"]
    # keep verbose + essentials, drop the WiFi/iGPU-heavy + lilubeta combos
    drop = {"-lilubetaall", "-liluuserbeta", "-amfipassbeta",
            "ipc_control_port_options=0", "-igfxmlr", "-igfxblr",
            "-disable_sidecar_mac"}
    kept = [t for t in ba.split() if t not in drop]
    if "-v" not in kept: kept.insert(0, "-v")
    if "keepsyms=1" not in kept: kept.append("keepsyms=1")
    newba = " ".join(kept)
    if newba != ba:
        nv[ba_guid]["boot-args"] = newba
        changes.append(f"boot-args simplified → {newba}")

with open(p, "wb") as f:
    plistlib.dump(c, f, sort_keys=False)

print(f"Applied {len(changes)} install-mode changes:")
for ch in changes:
    print("  • " + ch)
PYEOF

# XML sanity
if command -v xmllint >/dev/null; then
  xmllint --noout "$CFG" && ok "config.plist XML valid" || die "config.plist XML broken — restoring"
fi

sync
ok "Patched. Eject and boot the T480 from this USB again."
echo ""
echo "After macOS installs and you reach the desktop:"
echo "  1. Re-plug USB into the Linux laptop"
echo "  2. sudo cp $MNT/EFI/OC/config.plist.fullbackup $MNT/EFI/OC/config.plist"
echo "     (restores full WiFi config) — OR just run post-install.sh on macOS"
