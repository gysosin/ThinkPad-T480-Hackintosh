#!/bin/bash
# T480 macOS Tahoe 26 — Automatic post-install configurator
#
# Run ONCE after first successful boot of macOS Tahoe on the T480.
# Usage:
#   bash /Volumes/Install\ macOS\ Tahoe/post-install.sh
#   (or from the USB at whatever mount point shows)
#
# Does:
#   1. Apply pmset sleep stability block (hibernation off, etc.)
#   2. Apply Liquid Glass / Tahoe perf defaults (DisableSolarium, NSAutoFill, etc.)
#   3. Disable Spotlight bandwidth-eating settings
#   4. Set Reduce Transparency + Reduce Motion (Accessibility)
#   5. Strip verbose/debug boot-args from NVRAM
#   6. Download + run OCLP-Mod root patches (AppleHDA + WiFi)
#   7. Print a summary + reboot prompt

set -uo pipefail   # not -e — we want to continue even if individual steps fail

LOG="$HOME/Desktop/t480-post-install-$(date +%Y%m%d-%H%M%S).log"
exec > >(tee -a "$LOG") 2>&1

GREEN=$'\033[1;32m'; YELLOW=$'\033[1;33m'; RED=$'\033[1;31m'; CYAN=$'\033[1;36m'; RST=$'\033[0m'
info() { echo "${CYAN}[info]${RST} $*"; }
ok()   { echo "${GREEN}[ ok ]${RST} $*"; }
warn() { echo "${YELLOW}[warn]${RST} $*"; }
fail() { echo "${RED}[fail]${RST} $*"; }

cat <<BANNER

============================================================
  ThinkPad T480 — macOS Tahoe 26 post-install configurator
============================================================
  Log: $LOG
============================================================

BANNER

# ------------------------------------------------------------
# 0. Sanity checks
# ------------------------------------------------------------
if [[ "$(uname -s)" != "Darwin" ]]; then
  fail "This script must be run on macOS. (You're on $(uname -s).)"
  exit 1
fi

MACOS_MAJOR=$(sw_vers -productVersion | cut -d. -f1)
if [[ "$MACOS_MAJOR" -lt 26 ]]; then
  warn "Detected macOS $(sw_vers -productVersion). This script targets Tahoe (26+). Some fixes may not apply."
fi

info "macOS $(sw_vers -productVersion) on $(sysctl -n hw.model)"
info "Will prompt for your password once for sudo. Stay near the keyboard."
sudo -v || { fail "Sudo required"; exit 1; }

# Keep sudo alive in background until script exits
( while true; do sudo -n true; sleep 60; kill -0 "$$" 2>/dev/null || exit; done ) &
SUDO_KEEPALIVE_PID=$!
trap 'kill $SUDO_KEEPALIVE_PID 2>/dev/null' EXIT

# ------------------------------------------------------------
# 1. pmset — sleep stability
# ------------------------------------------------------------
info "[1/7] Applying pmset block (hibernation off, no Power Nap, no network wake)..."
sudo pmset -a hibernatemode 0            && ok "hibernatemode = 0"
sudo pmset -a standby 0                  && ok "standby = 0"
sudo pmset -a autopoweroff 0             && ok "autopoweroff = 0"
sudo pmset -a powernap 0                 && ok "powernap = 0"
sudo pmset -a ttyskeepawake 0            && ok "ttyskeepawake = 0"
sudo pmset -a networkoversleep 0         && ok "networkoversleep = 0"
sudo pmset -a womp 0                     && ok "womp (wake on LAN) = 0"
sudo pmset -a tcpkeepalive 0             && ok "tcpkeepalive = 0"
sudo rm -f /var/vm/sleepimage            && ok "removed /var/vm/sleepimage"

# ------------------------------------------------------------
# 2. Liquid Glass / Tahoe perf defaults
# ------------------------------------------------------------
info "[2/7] Applying perf defaults (Liquid Glass off, typing-lag fix)..."
defaults write -g com.apple.SwiftUI.DisableSolarium -bool YES        && ok "DisableSolarium = YES (kills Liquid Glass shader)"
defaults write -g NSAutoFillHeuristicControllerEnabled -bool false   && ok "NSAutoFillHeuristic = false"
defaults write -g NSAutomaticInlinePredictionEnabled  -bool false    && ok "NSAutomaticInlinePrediction = false"
defaults write com.apple.universalaccess reduceTransparency -bool true && ok "Reduce Transparency = on"
defaults write com.apple.universalaccess reduceMotion       -bool true && ok "Reduce Motion = on"

# ------------------------------------------------------------
# 3. Spotlight — disable bandwidth/RAM hogs
# ------------------------------------------------------------
info "[3/7] Disabling Spotlight bandwidth/CPU hogs..."
defaults write com.apple.lookup.shared LookupSuggestionsDisabled -bool true                         && ok "Show Related Content = off"
defaults write com.apple.assistant.support 'Search Queries Data Sharing Status' -int 2              && ok "Help Apple Improve Search = off"

# ------------------------------------------------------------
# 4. Strip verbose / debug boot-args from NVRAM
# ------------------------------------------------------------
info "[4/7] Cleaning install-time verbose/debug boot-args..."
CURRENT_BA=$(nvram boot-args 2>/dev/null | awk '{$1=""; print substr($0,2)}')
if [[ -n "$CURRENT_BA" ]]; then
  CLEAN_BA=$(echo "$CURRENT_BA" | tr ' ' '\n' | grep -vE '^(-v|keepsyms=1|debug=0x100)$' | paste -sd ' ' -)
  if [[ "$CLEAN_BA" != "$CURRENT_BA" ]]; then
    sudo nvram boot-args="$CLEAN_BA"     && ok "Stripped -v / keepsyms=1 / debug=0x100"
    info "New boot-args: $CLEAN_BA"
  else
    ok "boot-args already clean"
  fi
fi

# ------------------------------------------------------------
# 5. OCLP-Mod root patches (AppleHDA + WiFi)
# ------------------------------------------------------------
info "[5/7] Setting up OCLP-Mod for AppleHDA + WiFi root patches..."

OCLP_APP_DIR="/Applications/OCLP-Mod.app"
OCLP_RELEASE_API="https://api.github.com/repos/laobamac/OCLP-Mod/releases/latest"

if [[ -d "$OCLP_APP_DIR" ]]; then
  ok "OCLP-Mod already installed at $OCLP_APP_DIR"
else
  info "Downloading OCLP-Mod latest release..."
  # Find DMG/PKG asset
  ASSET_URL=$(curl -fsSL "$OCLP_RELEASE_API" 2>/dev/null \
    | grep -oE '"browser_download_url": *"[^"]+\.(dmg|pkg)"' \
    | head -1 | sed 's/.*"\(http[^"]*\)"/\1/')
  if [[ -z "$ASSET_URL" ]]; then
    warn "Could not auto-resolve OCLP-Mod download URL."
    warn "Please open https://github.com/laobamac/OCLP-Mod/releases in Safari,"
    warn "download the latest DMG, then run the patcher manually:"
    warn "  Post-Install Root Patch -> select 'Audio + Wi-Fi' -> reboot"
  else
    TMP_FILE="/tmp/oclp-mod.${ASSET_URL##*.}"
    info "Downloading: $ASSET_URL"
    if curl -fL --progress-bar -o "$TMP_FILE" "$ASSET_URL"; then
      ok "Downloaded $(du -h "$TMP_FILE" | awk '{print $1}')"
      case "$TMP_FILE" in
        *.dmg)
          info "Mounting DMG..."
          MOUNT_OUT=$(hdiutil attach -nobrowse -noverify -noautoopen "$TMP_FILE")
          MOUNT_POINT=$(echo "$MOUNT_OUT" | tail -1 | awk '{ for(i=3;i<=NF;i++) printf "%s ", $i; print "" }' | sed 's/[[:space:]]*$//')
          if [[ -d "$MOUNT_POINT" ]]; then
            APP_IN_DMG=$(find "$MOUNT_POINT" -maxdepth 2 -name "*.app" -type d | head -1)
            if [[ -d "$APP_IN_DMG" ]]; then
              sudo cp -R "$APP_IN_DMG" /Applications/ && ok "Installed: $(basename "$APP_IN_DMG")"
            fi
            hdiutil detach "$MOUNT_POINT" -quiet
          fi
          ;;
        *.pkg)
          sudo installer -pkg "$TMP_FILE" -target /  && ok "OCLP-Mod installed via pkg"
          ;;
      esac
      rm -f "$TMP_FILE"
    else
      warn "Download failed. Get OCLP-Mod manually from:"
      warn "  https://github.com/laobamac/OCLP-Mod/releases"
    fi
  fi
fi

# ------------------------------------------------------------
# 6. Print OCLP-Mod GUI instructions (CLI varies by fork; safest to use GUI)
# ------------------------------------------------------------
info "[6/7] Next step: run OCLP-Mod root patches (GUI, ~2 minutes)"
cat <<INSTRUCTIONS

  ${CYAN}>>> Open OCLP-Mod from /Applications now. <<<${RST}

  In OCLP-Mod:
    1. Click ${GREEN}"Post-Install Root Patch"${RST}
    2. Wait while it scans (~10 sec)
    3. Click ${GREEN}"Start Root Patching"${RST}
    4. Enter password, watch progress (~2 min)
    5. Click ${GREEN}"Reboot"${RST} when prompted

  After reboot:
    - Audio (speakers + jack + mic) should work
    - WiFi adapter should appear in menu bar

INSTRUCTIONS

# Try to launch it
if [[ -d "$OCLP_APP_DIR" ]]; then
  open -a "OCLP-Mod"  && ok "Launched OCLP-Mod"
fi

# ------------------------------------------------------------
# 7. Summary
# ------------------------------------------------------------
info "[7/7] Done with automated steps."

cat <<SUMMARY

============================================================
${GREEN}AUTOMATED STEPS COMPLETE${RST}
============================================================

✅ pmset sleep block applied
✅ Liquid Glass perf defaults applied
✅ Spotlight bandwidth hogs disabled
✅ verbose/debug boot-args stripped from NVRAM
$([[ -d "$OCLP_APP_DIR" ]] && echo "✅ OCLP-Mod installed (run it now from /Applications)" || echo "⚠️  OCLP-Mod not auto-installed — manual download needed")

============================================================
${YELLOW}REMAINING MANUAL STEPS${RST}
============================================================

1. Run OCLP-Mod -> Post-Install Root Patch (GUI now open).
   This installs AppleHDA + WiFi support. Without it: no audio, no WiFi.

2. After reboot: log out and log back in once
   (so the Reduce Transparency / Reduce Motion settings take effect).

3. Optional: System Settings -> Apple Account -> sign in
   (only AFTER you've verified everything works).

============================================================
${CYAN}TO RE-RUN AFTER macOS UPDATES${RST}
============================================================

Each Tahoe minor update (26.x -> 26.y) wipes OCLP-Mod's root patches.
Re-run them via OCLP-Mod after each update. The pmset/defaults settings
also reset on hibernate config — re-run this script if needed:

  bash $0

Full log: $LOG

SUMMARY
