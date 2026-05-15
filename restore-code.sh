#!/usr/bin/env bash
# Auto-clone all gysosin private repos to ~/code/ on macOS.
# Run on macOS after fresh install:
#   brew install gh git
#   gh auth login
#   bash restore-code.sh
set -euo pipefail
DEST="${DEST:-$HOME/code}"
GH_USER="gysosin"
mkdir -p "$DEST"; cd "$DEST"
G=$'\033[1;32m'; Y=$'\033[1;33m'; R=$'\033[1;31m'; X=$'\033[0m'
ok()   { echo "${G}[ ok ]${X} $*"; }
warn() { echo "${Y}[warn]${X} $*"; }
fail() { echo "${R}[fail]${X} $*"; }
clone_one() {
    local folder="$1" slug="$2"
    if [[ -d "$folder/.git" ]]; then
        warn "$folder exists — pull"
        (cd "$folder" && git pull --ff-only) || warn "pull failed: $folder"
    else
        if gh repo clone "$GH_USER/$slug" "$folder"; then ok "$folder"; else fail "$folder"; fi
    fi
}

clone_one adk adk
clone_one Agentic_rag_flow Agentic_rag_flow
clone_one Agentic_studio Agentic_studio
clone_one ai-dashboard ai-dashboard
clone_one Ai_Monitoring Ai_Monitoring
clone_one browser_automation browser_automation
clone_one Chitthi Chitthi
clone_one documet_hunking documet_hunking
clone_one geralt_ai geralt_ai
clone_one github_dashboard github_dashboard
clone_one iers iers
clone_one image_gen image_gen
clone_one Infra Infra
clone_one k8 k8
clone_one meet meet
clone_one mock_apis mock_apis
clone_one NDCG NDCG
clone_one new_chat new_chat
clone_one NexusVault NexusVault
clone_one NexusVault-roadmap NexusVault-roadmap
clone_one ocr-enine ocr-enine
clone_one ocr_gemini ocr_gemini
clone_one ocr_min ocr_min
clone_one openrouter openrouter
clone_one phonepe-vendor-management phonepe-vendor-management
clone_one porfolio porfolio
clone_one portfolio portfolio
clone_one r\&d r-and-d
clone_one SysSentient SysSentient
clone_one videgen videgen

ok "All repos restored to $DEST"
echo
echo "TOAI / Toss / Azure-DevOps repos are NOT in this list — clone manually:"
echo "  git clone https://two8ai@dev.azure.com/two8ai/Toss%20AI/_git/<repo> ~/code/<folder>"
