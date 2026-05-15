#!/usr/bin/env bash
#
# create-install-usb.sh — Build a macOS Tahoe 26 install USB on Fedora Linux
# for the Lenovo ThinkPad T480 Hackintosh (OpenCore 1.0.7).
#
# Source EFI : "$REPO_ROOT/EFI - Tahoe/EFI"
# Target USB : GPT, p1 = FAT32 ESP "OPENCORE", p2 = HFS+ "macOS Install"
#

set -euo pipefail

# ─────────────────────────────────────────────────────────────────────────────
# Constants
# ─────────────────────────────────────────────────────────────────────────────
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly REPO_ROOT
readonly EFI_SRC="$REPO_ROOT/EFI - Tahoe/EFI"
LOG_FILE="/tmp/t480-usb-builder-$(date +%s).log"
readonly LOG_FILE
readonly GIBMACOS_DIR="$HOME/.cache/gibMacOS"
readonly BUILD_DIR="/tmp/t480-build"
readonly ESP_MNT="/mnt/t480-usb-esp"
readonly REC_MNT="/mnt/t480-usb-recovery"
readonly BASESYSTEM_RAW="/tmp/BaseSystem.raw"
readonly RECOVERY_BOARD_ID="Mac-7BA5B2D9E42DDD94"   # iMacPro1,1 → latest recovery
readonly RECOVERY_MLB="00000000000000000"
readonly DMG2IMG_URL="https://vu1tur.eu.org/tools/dmg2img-1.6.7.tar.gz"

# ─────────────────────────────────────────────────────────────────────────────
# Mutable state
# ─────────────────────────────────────────────────────────────────────────────
DRY_RUN=0
ASSUME_YES=0
KEEP_CACHE=0
SELECTED_DEV=""
SUDO_KEEPALIVE_PID=""
PKG_MGR=""

# ─────────────────────────────────────────────────────────────────────────────
# Logging helpers
# ─────────────────────────────────────────────────────────────────────────────
if [[ -t 1 ]]; then
    C_CYAN=$'\033[0;36m'
    C_YELLOW=$'\033[0;33m'
    C_RED=$'\033[0;31m'
    C_GREEN=$'\033[0;32m'
    C_BOLD=$'\033[1m'
    C_RESET=$'\033[0m'
else
    C_CYAN=""; C_YELLOW=""; C_RED=""; C_GREEN=""; C_BOLD=""; C_RESET=""
fi

info()  { printf '%s[INFO]%s  %s\n'  "$C_CYAN"   "$C_RESET" "$*"; }
warn()  { printf '%s[WARN]%s  %s\n'  "$C_YELLOW" "$C_RESET" "$*" >&2; }
ok()    { printf '%s[ OK ]%s  %s\n'  "$C_GREEN"  "$C_RESET" "$*"; }
error() { printf '%s[FAIL]%s %s\n'   "$C_RED"    "$C_RESET" "$*" >&2; exit 1; }

# Run a privileged command. In --dry-run mode prints instead of executing.
run_priv() {
    if (( DRY_RUN )); then
        printf '%s[DRY ]%s sudo %s\n' "$C_YELLOW" "$C_RESET" "$*"
        return 0
    fi
    sudo "$@"
}

# Run a privileged command that is always destructive — only printed in dry-run.
run_destructive() { run_priv "$@"; }

# ─────────────────────────────────────────────────────────────────────────────
# Usage
# ─────────────────────────────────────────────────────────────────────────────
usage() {
    cat <<EOF
Usage: ${0##*/} [options]

Builds a macOS Tahoe 26 installer USB for the ThinkPad T480 Hackintosh.

Options:
  --device PATH    Use this block device (e.g. /dev/sdb). Skips TUI picker.
  --yes            Skip the triple-confirmation. Requires --device.
  --dry-run        Print destructive actions instead of executing them.
  --keep-cache     Do not re-download macOS recovery if already cached.
  --help           Show this help and exit.

Output log: $LOG_FILE
EOF
}

# ─────────────────────────────────────────────────────────────────────────────
# Cleanup / traps
# ─────────────────────────────────────────────────────────────────────────────
cleanup() {
    local rc=$?
    set +e
    if [[ -n "$SUDO_KEEPALIVE_PID" ]] && kill -0 "$SUDO_KEEPALIVE_PID" 2>/dev/null; then
        kill "$SUDO_KEEPALIVE_PID" 2>/dev/null || true
    fi
    for mp in "$ESP_MNT" "$REC_MNT"; do
        if mountpoint -q "$mp" 2>/dev/null; then
            sudo umount "$mp" 2>/dev/null || sudo umount -l "$mp" 2>/dev/null || true
        fi
        if [[ -d "$mp" ]]; then
            sudo rmdir "$mp" 2>/dev/null || true
        fi
    done
    [[ -f "$BASESYSTEM_RAW" ]] && sudo rm -f "$BASESYSTEM_RAW" 2>/dev/null
    if (( rc != 0 )); then
        warn "Exited with status $rc — see $LOG_FILE"
    fi
    exit "$rc"
}
trap cleanup EXIT
trap 'error "Interrupted."' INT TERM

# ─────────────────────────────────────────────────────────────────────────────
# Argument parsing
# ─────────────────────────────────────────────────────────────────────────────
parse_args() {
    while (( $# > 0 )); do
        case "$1" in
            --dry-run)    DRY_RUN=1 ;;
            --yes)        ASSUME_YES=1 ;;
            --keep-cache) KEEP_CACHE=1 ;;
            --device)
                [[ $# -ge 2 ]] || error "--device requires a path argument"
                SELECTED_DEV="$2"; shift
                ;;
            --device=*)   SELECTED_DEV="${1#*=}" ;;
            --help|-h)    usage; exit 0 ;;
            *)            error "Unknown argument: $1 (try --help)" ;;
        esac
        shift
    done
    if (( ASSUME_YES )) && [[ -z "$SELECTED_DEV" ]]; then
        error "--yes requires --device PATH (refusing to auto-wipe a guessed disk)"
    fi
}

# ─────────────────────────────────────────────────────────────────────────────
# Preflight
# ─────────────────────────────────────────────────────────────────────────────
detect_pkg_mgr() {
    if command -v dnf >/dev/null 2>&1; then
        PKG_MGR="dnf"
    elif command -v apt-get >/dev/null 2>&1; then
        PKG_MGR="apt"
    else
        error "No supported package manager found (need dnf or apt-get)."
    fi
}

pkg_install() {
    local pkg="$1"
    info "Installing package: $pkg"
    case "$PKG_MGR" in
        dnf) run_priv dnf install -y "$pkg" ;;
        apt) run_priv apt-get update -qq && run_priv apt-get install -y "$pkg" ;;
    esac
}

ensure_sudo() {
    if [[ "$(id -u)" -eq 0 ]]; then
        return 0
    fi
    if sudo -n true 2>/dev/null; then
        : # cached
    else
        info "Privileged operations required — please enter your sudo password:"
        sudo -v || error "Could not obtain sudo credentials."
    fi
    # Background keepalive
    ( while true; do sudo -n true 2>/dev/null || exit; sleep 50; done ) &
    SUDO_KEEPALIVE_PID=$!
    disown "$SUDO_KEEPALIVE_PID" 2>/dev/null || true
}

ensure_dmg2img() {
    if command -v dmg2img >/dev/null 2>&1; then
        ok "dmg2img already installed: $(command -v dmg2img)"
        return 0
    fi
    info "dmg2img not found — attempting package install"
    if [[ "$PKG_MGR" == "dnf" ]]; then
        if sudo dnf install -y dmg2img >/dev/null 2>&1; then
            ok "dmg2img installed via dnf"
            return 0
        fi
    elif [[ "$PKG_MGR" == "apt" ]]; then
        if sudo apt-get install -y dmg2img >/dev/null 2>&1; then
            ok "dmg2img installed via apt"
            return 0
        fi
    fi
    warn "dmg2img not packaged — building from source"
    local build="$BUILD_DIR/dmg2img"
    mkdir -p "$build"
    (
        cd "$build"
        curl -fsSL "$DMG2IMG_URL" -o dmg2img.tar.gz
        tar -xzf dmg2img.tar.gz --strip-components=1
        # dependencies: zlib, openssl, bzip2 development headers
        case "$PKG_MGR" in
            dnf) pkg_install zlib-devel; pkg_install openssl-devel; pkg_install bzip2-devel; pkg_install gcc; pkg_install make ;;
            apt) pkg_install zlib1g-dev; pkg_install libssl-dev; pkg_install libbz2-dev; pkg_install build-essential ;;
        esac
        make
        run_priv install -m 0755 dmg2img /usr/local/bin/dmg2img
    )
    command -v dmg2img >/dev/null 2>&1 || error "Failed to install dmg2img"
    ok "dmg2img built and installed to /usr/local/bin/dmg2img"
}

preflight() {
    info "Phase 1: preflight"

    local kernel arch
    kernel="$(uname -s)"
    arch="$(uname -m)"
    [[ "$kernel" == "Linux" ]]  || error "This script only runs on Linux (got: $kernel)"
    [[ "$arch"   == "x86_64" ]] || error "This script only runs on x86_64 (got: $arch)"
    [[ -f /etc/os-release ]]    || error "/etc/os-release missing — unsupported distro"

    detect_pkg_mgr
    ensure_sudo

    # bin → package map
    declare -A bin_to_pkg=(
        [lsblk]=util-linux
        [blkid]=util-linux
        [parted]=parted
        [sgdisk]=gdisk
        [wipefs]=util-linux
        [mkfs.fat]=dosfstools
        [mkfs.hfsplus]=hfsprogs
        [dd]=coreutils
        [rsync]=rsync
        [curl]=curl
        [python3]=python3
        [unzip]=unzip
        [whiptail]=newt
        [partprobe]=parted
        [fsck.hfsplus]=hfsprogs
        [findmnt]=util-linux
        [mountpoint]=util-linux
        [git]=git
    )

    local missing=()
    local b
    for b in "${!bin_to_pkg[@]}"; do
        command -v "$b" >/dev/null 2>&1 || missing+=("$b")
    done

    if (( ${#missing[@]} > 0 )); then
        info "Missing binaries: ${missing[*]}"
        local pkgs_seen=" "
        for b in "${missing[@]}"; do
            local pkg="${bin_to_pkg[$b]}"
            if [[ "$pkgs_seen" != *" $pkg "* ]]; then
                pkg_install "$pkg"
                pkgs_seen+="$pkg "
            fi
        done
        # Re-check
        local still_missing=()
        for b in "${missing[@]}"; do
            command -v "$b" >/dev/null 2>&1 || still_missing+=("$b")
        done
        if (( ${#still_missing[@]} > 0 )); then
            error "Still missing after install: ${still_missing[*]}"
        fi
    fi

    ensure_dmg2img
    ok "Preflight passed."
}

# ─────────────────────────────────────────────────────────────────────────────
# Validate EFI
# ─────────────────────────────────────────────────────────────────────────────
validate_efi() {
    info "Phase 2: validate EFI source"

    [[ -d "$EFI_SRC" ]] || error "EFI source not found: $EFI_SRC"

    local f
    for f in "$EFI_SRC/BOOT/BOOTx64.efi" "$EFI_SRC/OC/OpenCore.efi" "$EFI_SRC/OC/config.plist"; do
        [[ -f "$f" ]] || error "Missing required file: $f"
        [[ -s "$f" ]] || error "Required file is empty: $f"
    done

    local validator="$BUILD_DIR/oc/Utilities/ocvalidate/ocvalidate.linux"
    if [[ -x "$validator" ]]; then
        if "$validator" "$EFI_SRC/OC/config.plist"; then
            ok "ocvalidate accepted config.plist"
        else
            error "ocvalidate rejected $EFI_SRC/OC/config.plist"
        fi
    else
        warn "ocvalidate not found at $validator — skipping config.plist validation"
    fi
    ok "EFI source looks good."
}

# ─────────────────────────────────────────────────────────────────────────────
# Device selection
# ─────────────────────────────────────────────────────────────────────────────
system_block_devs() {
    # Resolve the parent block device hosting / and /boot (if separate).
    local mp src parent
    for mp in / /boot /boot/efi; do
        src="$(findmnt -n -o SOURCE "$mp" 2>/dev/null || true)"
        [[ -z "$src" ]] && continue
        parent="$(lsblk -no PKNAME "$src" 2>/dev/null || true)"
        [[ -n "$parent" ]] && printf '%s\n' "$parent"
        # If src itself is a whole disk
        parent="$(basename "$src" 2>/dev/null)"
        [[ -n "$parent" ]] && printf '%s\n' "$parent"
    done | sort -u
}

list_candidates() {
    local sys_devs
    sys_devs="$(system_block_devs)"

    # NAME SIZE TRAN RM MODEL  (MODEL last so multi-word names land in $model)
    while read -r name size tran rm model; do
        [[ -z "$name" ]] && continue
        # filter: removable OR usb transport
        if [[ "$rm" != "1" && "$tran" != "usb" ]]; then
            continue
        fi
        # skip zero-size devices (empty card readers etc.)
        if [[ "$size" == "0" ]]; then
            continue
        fi
        # exclude system disks
        if printf '%s\n' "$sys_devs" | grep -qx "$name"; then
            continue
        fi
        printf '%s\t%s\t%s\n' "$name" "$size" "${model:-Unknown}"
    done < <(lsblk -d -b -o NAME,SIZE,TRAN,RM,MODEL -n -e 1,7,11)
}

humanize_size() {
    awk -v b="$1" 'BEGIN {
        split("B KiB MiB GiB TiB PiB", u, " ");
        i=1;
        while (b >= 1024 && i < 6) { b /= 1024; i++ }
        printf("%.1f %s", b, u[i]);
    }'
}

pick_device() {
    info "Phase 3: select USB device"

    local candidates
    candidates="$(list_candidates)"

    if [[ -z "$candidates" ]]; then
        error "No removable USB drives detected — plug one in and re-run."
    fi

    if [[ -n "$SELECTED_DEV" ]]; then
        local dev_name
        dev_name="${SELECTED_DEV#/dev/}"
        if ! printf '%s\n' "$candidates" | awk -F'\t' '{print $1}' | grep -qx "$dev_name"; then
            warn "Requested device $SELECTED_DEV not in detected USB candidate list:"
            printf '%s\n' "$candidates" | sed 's/^/  /'
            error "Refusing to operate on a non-USB / system disk."
        fi
        info "Using --device override: /dev/$dev_name"
        SELECTED_DEV="/dev/$dev_name"
        return 0
    fi

    local menu_args=()
    while IFS=$'\t' read -r name size model; do
        local hr label
        hr="$(humanize_size "$size")"
        label="$hr  $model"
        menu_args+=("/dev/$name" "$label")
    done <<< "$candidates"

    local choice
    if ! choice="$(whiptail \
            --title "Select USB drive (DATA WILL BE WIPED)" \
            --menu "Removable disks detected. Pick one:" \
            20 78 10 \
            "${menu_args[@]}" \
            3>&1 1>&2 2>&3)"; then
        error "Cancelled by user."
    fi
    SELECTED_DEV="$choice"
    info "Selected: $SELECTED_DEV"
}

# ─────────────────────────────────────────────────────────────────────────────
# Triple confirmation
# ─────────────────────────────────────────────────────────────────────────────
confirm_device() {
    info "Phase 4: confirm device"

    local dev="$SELECTED_DEV"
    [[ -b "$dev" ]] || error "Not a block device: $dev"

    info "Current contents of $dev:"
    lsblk -o NAME,SIZE,MODEL,FSTYPE,LABEL,MOUNTPOINTS "$dev" || true

    if (( ASSUME_YES )); then
        warn "--yes given: skipping interactive confirmations for $dev"
        return 0
    fi

    local name size model
    name="${dev#/dev/}"
    size="$(lsblk -dn -o SIZE "$dev")"
    model="$(lsblk -dn -o MODEL "$dev" | sed 's/[[:space:]]*$//')"

    whiptail --defaultno --yesno \
        "WIPE $dev ($size $model)?\n\nALL DATA on this device will be permanently destroyed." \
        12 70 || error "Aborted at first confirmation."

    whiptail --defaultno --yesno \
        "Final check — you'll be asked to type the device name on the next screen.\n\nContinue?" \
        10 70 || error "Aborted at second confirmation."

    local typed
    typed="$(whiptail --inputbox "Type \"$name\" exactly to confirm:" 10 60 "" 3>&1 1>&2 2>&3)" \
        || error "Aborted at typed confirmation."

    if [[ "$typed" != "$name" ]]; then
        error "Confirmation mismatch: expected '$name', got '$typed'."
    fi
    ok "Confirmed: $dev"
}

# ─────────────────────────────────────────────────────────────────────────────
# macOS recovery download
# ─────────────────────────────────────────────────────────────────────────────
download_recovery() {
    info "Phase 5: download macOS recovery"

    local download_dir="$GIBMACOS_DIR/com.apple.recovery.boot"
    mkdir -p "$GIBMACOS_DIR" "$download_dir"

    if (( KEEP_CACHE )) \
       && [[ -s "$download_dir/BaseSystem.dmg" ]] \
       && [[ -s "$download_dir/BaseSystem.chunklist" ]]; then
        ok "Using cached recovery files in $download_dir"
        BASESYSTEM_DMG="$download_dir/BaseSystem.dmg"
        return 0
    fi

    # Prefer macrecovery from the on-disk OpenCore Utilities tree.
    local macrec="$BUILD_DIR/oc/Utilities/macrecovery/macrecovery.py"
    if [[ ! -f "$macrec" ]]; then
        warn "macrecovery.py not found at $macrec — falling back to gibMacOS"
        if [[ -d "$GIBMACOS_DIR/.git" ]]; then
            (( KEEP_CACHE )) || (cd "$GIBMACOS_DIR" && git pull --ff-only) || warn "gibMacOS git pull failed"
        else
            git clone --depth=1 https://github.com/corpnewt/gibMacOS "$GIBMACOS_DIR"
        fi
        (
            cd "$GIBMACOS_DIR"
            python3 gibMacOS.command -r -v -c publicrelease || \
                error "gibMacOS failed to download recovery."
        )
    else
        info "Using macrecovery.py at $macrec"
        # Acidanthera's macrecovery.py calls os.get_terminal_size() which throws
        # ENOTTY when stdout is piped (we tee to a logfile). Patch it idempotently
        # to use shutil.get_terminal_size which has a (80, 24) fallback.
        if grep -q 'os.get_terminal_size().columns' "$macrec"; then
            sed -i "s|os.get_terminal_size().columns|__import__('shutil').get_terminal_size(fallback=(80, 24)).columns|g" "$macrec"
            info "Patched macrecovery.py for non-TTY stdout"
        fi
        # macrecovery default --outdir is "com.apple.recovery.boot" RELATIVE to CWD.
        # cd to GIBMACOS_DIR (parent), so files land in $GIBMACOS_DIR/com.apple.recovery.boot/
        # which is what $download_dir points at.
        (
            cd "$GIBMACOS_DIR"
            python3 "$macrec" \
                -b "$RECOVERY_BOARD_ID" \
                -m "$RECOVERY_MLB" \
                download
        ) || error "macrecovery download failed."
    fi

    [[ -s "$download_dir/BaseSystem.dmg" ]] \
        || error "BaseSystem.dmg missing after download in $download_dir"

    BASESYSTEM_DMG="$download_dir/BaseSystem.dmg"
    ok "Recovery downloaded: $BASESYSTEM_DMG"
}

# ─────────────────────────────────────────────────────────────────────────────
# Partition USB
# ─────────────────────────────────────────────────────────────────────────────
part_path() {
    # part_path /dev/sdb 1  →  /dev/sdb1
    # part_path /dev/nvme0n1 1  →  /dev/nvme0n1p1
    # part_path /dev/mmcblk0 1  →  /dev/mmcblk0p1
    local dev="$1" idx="$2"
    local base="${dev##*/}"
    if [[ "$base" =~ ^(nvme|mmcblk|loop) ]]; then
        printf '%sp%s\n' "$dev" "$idx"
    else
        printf '%s%s\n' "$dev" "$idx"
    fi
}

partition_usb() {
    info "Phase 6: partition $SELECTED_DEV"

    local dev="$SELECTED_DEV"

    # Unmount any existing partitions on this device.
    local part
    while read -r part; do
        [[ -z "$part" ]] && continue
        if mountpoint -q "$part" 2>/dev/null; then
            run_priv umount "$part" || run_priv umount -l "$part" || true
        fi
        run_priv umount "/dev/$(basename "$part")" 2>/dev/null || true
    done < <(lsblk -ln -o MOUNTPOINT "$dev" | awk 'NF')

    # Also umount by partition node directly.
    local p
    for p in $(lsblk -ln -o NAME "$dev" | tail -n +2); do
        run_priv umount "/dev/$p" 2>/dev/null || true
    done

    run_destructive wipefs -af "$dev"
    run_destructive sgdisk --zap-all "$dev"
    run_destructive parted -s "$dev" mklabel gpt
    run_destructive parted -s "$dev" mkpart ESP fat32 1MiB 301MiB
    run_destructive parted -s "$dev" set 1 esp on
    run_destructive parted -s "$dev" mkpart "macOS Install" hfs+ 301MiB 100%

    if (( ! DRY_RUN )); then
        run_priv partprobe "$dev"
        udevadm settle 2>/dev/null || true
    fi

    local esp_part rec_part
    esp_part="$(part_path "$dev" 1)"
    rec_part="$(part_path "$dev" 2)"

    # Poll for partition device nodes to appear (replaces fixed sleep 2)
    if (( ! DRY_RUN )); then
        local i
        for i in $(seq 1 20); do
            [[ -b "$esp_part" && -b "$rec_part" ]] && break
            sleep 0.5
        done
        [[ -b "$esp_part" ]] || error "ESP partition $esp_part never appeared"
        [[ -b "$rec_part" ]] || error "Recovery partition $rec_part never appeared"
    fi

    # Set GPT partition type GUIDs: ESP (EF00) + Apple HFS+ (AF00)
    run_destructive sgdisk -t "1:EF00" -t "2:AF00" "$dev"

    run_destructive mkfs.fat -F 32 -n "OPENCORE" "$esp_part"
    # Recovery partition is overwritten by `dd` later — no need to format,
    # but doing so means partprobe/blkid have something coherent to read.
    run_destructive mkfs.hfsplus -v "Install" "$rec_part"

    ok "Partitioned: $esp_part (ESP FAT32), $rec_part (HFS+)"
}

# ─────────────────────────────────────────────────────────────────────────────
# Write contents
# ─────────────────────────────────────────────────────────────────────────────
write_contents() {
    info "Phase 7: write EFI + BaseSystem"

    local dev="$SELECTED_DEV"
    local esp_part rec_part
    esp_part="$(part_path "$dev" 1)"
    rec_part="$(part_path "$dev" 2)"

    run_priv mkdir -p "$ESP_MNT" "$REC_MNT"

    if (( DRY_RUN )); then
        run_priv mount "$esp_part" "$ESP_MNT" 2>/dev/null || true
    else
        run_priv mount "$esp_part" "$ESP_MNT"
    fi

    info "Copying EFI tree to ESP…"
    run_priv mkdir -p "$ESP_MNT/EFI"
    if (( DRY_RUN )); then
        printf '%s[DRY ]%s rsync -a "%s/" "%s/EFI/"\n' \
            "$C_YELLOW" "$C_RESET" "$EFI_SRC" "$ESP_MNT"
    else
        sudo rsync -a --info=progress2 "$EFI_SRC/" "$ESP_MNT/EFI/"
        # Also copy post-install.sh so the user can run it after install
        local post_install="$REPO_ROOT/post-install.sh"
        if [[ -f "$post_install" ]]; then
            sudo cp "$post_install" "$ESP_MNT/post-install.sh"
            sudo chmod +x "$ESP_MNT/post-install.sh"
            info "Copied post-install.sh to ESP root"
        fi
        sync
    fi

    if mountpoint -q "$ESP_MNT" 2>/dev/null; then
        run_priv umount "$ESP_MNT"
    fi

    info "Converting BaseSystem.dmg → raw image…"
    if (( DRY_RUN )); then
        printf '%s[DRY ]%s dmg2img "%s" "%s"\n' \
            "$C_YELLOW" "$C_RESET" "$BASESYSTEM_DMG" "$BASESYSTEM_RAW"
    else
        sudo dmg2img "$BASESYSTEM_DMG" "$BASESYSTEM_RAW"
    fi

    info "Writing raw image to $rec_part (this takes a while)…"
    if (( DRY_RUN )); then
        printf '%s[DRY ]%s dd if=%s of=%s bs=4M status=progress conv=fsync\n' \
            "$C_YELLOW" "$C_RESET" "$BASESYSTEM_RAW" "$rec_part"
    else
        sudo dd if="$BASESYSTEM_RAW" of="$rec_part" bs=4M status=progress conv=fsync
        sync
        sudo fsck.hfsplus -f "$rec_part" || warn "fsck.hfsplus reported issues — review manually"
    fi

    ok "Contents written."
}

# ─────────────────────────────────────────────────────────────────────────────
# Verify
# ─────────────────────────────────────────────────────────────────────────────
verify_usb() {
    info "Phase 8: verify"

    local dev="$SELECTED_DEV"
    local esp_part rec_part
    esp_part="$(part_path "$dev" 1)"
    rec_part="$(part_path "$dev" 2)"

    if (( DRY_RUN )); then
        warn "Dry-run: skipping read-back verification."
    else
        run_priv mkdir -p "$ESP_MNT"
        sudo mount -o ro "$esp_part" "$ESP_MNT"
        local f
        for f in "EFI/BOOT/BOOTx64.efi" "EFI/OC/OpenCore.efi" "EFI/OC/config.plist"; do
            if [[ ! -s "$ESP_MNT/$f" ]]; then
                sudo umount "$ESP_MNT" || true
                error "Verification failed: missing or empty $f on ESP"
            fi
        done
        sudo umount "$ESP_MNT"
        ok "ESP contents verified."
    fi

    printf '\n%s═══ Summary ═══%s\n' "$C_BOLD" "$C_RESET"
    printf 'Device     : %s\n' "$dev"
    if (( ! DRY_RUN )); then
        lsblk -o NAME,SIZE,FSTYPE,LABEL,UUID "$dev" || true
        printf '\nESP UUID    : %s\n' "$(sudo blkid -s UUID -o value "$esp_part" 2>/dev/null || echo unknown)"
        printf 'Recovery UUID: %s\n' "$(sudo blkid -s UUID -o value "$rec_part" 2>/dev/null || echo unknown)"
    fi

    cat <<EOF

Next steps:
  1. Eject the USB safely (run: sudo eject "$dev").
  2. Plug it into the ThinkPad T480.
  3. Power on and tap F12 to open the boot menu.
  4. Select the UEFI USB entry — OpenCore should appear.
  5. Choose "macOS Base System" to start the Tahoe 26 installer.

Log saved to: $LOG_FILE
EOF
}

# ─────────────────────────────────────────────────────────────────────────────
# main
# ─────────────────────────────────────────────────────────────────────────────
main() {
    parse_args "$@"

    # Tee all output to the log file from this point on.
    exec > >(tee -a "$LOG_FILE") 2>&1

    printf '%s╔════════════════════════════════════════════════════════╗%s\n' "$C_BOLD" "$C_RESET"
    printf '%s║  T480 macOS Tahoe 26 install-USB builder              ║%s\n' "$C_BOLD" "$C_RESET"
    printf '%s╚════════════════════════════════════════════════════════╝%s\n' "$C_BOLD" "$C_RESET"
    printf 'Log file: %s\n' "$LOG_FILE"
    if (( DRY_RUN )); then
        warn "DRY-RUN mode: no disk will be modified."
    fi

    mkdir -p "$BUILD_DIR"

    preflight
    validate_efi
    pick_device
    confirm_device
    download_recovery
    partition_usb
    write_contents
    verify_usb

    ok "Done."
}

main "$@"
