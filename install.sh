#!/usr/bin/env bash
#
# install.sh — Install shared-llm-tools into global ~/.cursor
#
# This script symlinks commands and skills from this repo into
# ~/.cursor/commands/ and ~/.cursor/skills/ so they are available
# as global Cursor slash-commands and skills across all projects.
#
# Usage:
#   ./install.sh           # install (symlink) everything
#   ./install.sh --uninstall  # remove all installed symlinks
#
# Because we use symlinks, any git pull in this repo will
# automatically update the tools in Cursor — no re-install needed.

set -euo pipefail

# ── Resolve paths ──────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CURSOR_DIR="${HOME}/.cursor"
CURSOR_COMMANDS_DIR="${CURSOR_DIR}/commands"
CURSOR_SKILLS_DIR="${CURSOR_DIR}/skills"

SRC_COMMANDS_DIR="${SCRIPT_DIR}/commands"
SRC_SKILLS_DIR="${SCRIPT_DIR}/skills"

# ── Colors ─────────────────────────────────────────────────────
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

info()    { echo -e "${CYAN}ℹ${NC}  $*"; }
success() { echo -e "${GREEN}✔${NC}  $*"; }
warn()    { echo -e "${YELLOW}⚠${NC}  $*"; }
error()   { echo -e "${RED}✖${NC}  $*"; }

# ── Uninstall ──────────────────────────────────────────────────
uninstall() {
    echo
    echo -e "${BOLD}🗑  Uninstalling shared-llm-tools from Cursor...${NC}"
    echo

    local removed=0

    # Remove command symlinks
    if [[ -d "$SRC_COMMANDS_DIR" ]]; then
        for file in "$SRC_COMMANDS_DIR"/*; do
            [[ -f "$file" ]] || continue
            local name
            name="$(basename "$file")"
            local target="${CURSOR_COMMANDS_DIR}/${name}"
            if [[ -L "$target" ]]; then
                rm "$target"
                success "Removed command: ${name}"
                ((removed++))
            fi
        done
    fi

    # Remove skill symlinks
    if [[ -d "$SRC_SKILLS_DIR" ]]; then
        for dir in "$SRC_SKILLS_DIR"/*/; do
            [[ -d "$dir" ]] || continue
            local name
            name="$(basename "$dir")"
            local target="${CURSOR_SKILLS_DIR}/${name}"
            if [[ -L "$target" ]]; then
                rm "$target"
                success "Removed skill:   ${name}"
                ((removed++))
            fi
        done
    fi

    if [[ $removed -eq 0 ]]; then
        info "Nothing to remove — no symlinks found."
    else
        echo
        success "Uninstalled ${removed} item(s). Done!"
    fi
}

# ── Install ────────────────────────────────────────────────────
install() {
    echo
    echo -e "${BOLD}🚀  Installing shared-llm-tools into Cursor...${NC}"
    echo -e "   Source: ${CYAN}${SCRIPT_DIR}${NC}"
    echo -e "   Target: ${CYAN}${CURSOR_DIR}${NC}"
    echo

    # Ensure target directories exist
    mkdir -p "$CURSOR_COMMANDS_DIR"
    mkdir -p "$CURSOR_SKILLS_DIR"

    local installed=0
    local skipped=0

    # ── Symlink commands ───────────────────────────────────────
    if [[ -d "$SRC_COMMANDS_DIR" ]]; then
        info "Installing commands..."
        for file in "$SRC_COMMANDS_DIR"/*; do
            [[ -f "$file" ]] || continue
            local name
            name="$(basename "$file")"
            local target="${CURSOR_COMMANDS_DIR}/${name}"

            if [[ -L "$target" ]]; then
                local existing_src
                existing_src="$(readlink "$target")"
                if [[ "$existing_src" == "$file" ]]; then
                    warn "Already linked: ${name} (skipped)"
                    ((skipped++))
                    continue
                else
                    warn "Replacing existing symlink: ${name}"
                    rm "$target"
                fi
            elif [[ -e "$target" ]]; then
                warn "File already exists (not a symlink): ${name} — skipping"
                warn "  Remove it manually if you want to replace: ${target}"
                ((skipped++))
                continue
            fi

            ln -s "$file" "$target"
            success "Linked command:  ${name}"
            ((installed++))
        done
    else
        warn "No commands/ directory found — skipping commands."
    fi

    echo

    # ── Symlink skills ─────────────────────────────────────────
    if [[ -d "$SRC_SKILLS_DIR" ]]; then
        info "Installing skills..."
        for dir in "$SRC_SKILLS_DIR"/*/; do
            [[ -d "$dir" ]] || continue
            local name
            name="$(basename "$dir")"
            local target="${CURSOR_SKILLS_DIR}/${name}"

            if [[ -L "$target" ]]; then
                local existing_src
                existing_src="$(readlink "$target")"
                if [[ "$existing_src" == "${dir%/}" ]]; then
                    warn "Already linked: ${name} (skipped)"
                    ((skipped++))
                    continue
                else
                    warn "Replacing existing symlink: ${name}"
                    rm "$target"
                fi
            elif [[ -e "$target" ]]; then
                warn "Directory already exists (not a symlink): ${name} — skipping"
                warn "  Remove it manually if you want to replace: ${target}"
                ((skipped++))
                continue
            fi

            ln -s "${dir%/}" "$target"
            success "Linked skill:    ${name}"
            ((installed++))
        done
    else
        warn "No skills/ directory found — skipping skills."
    fi

    # ── Summary ────────────────────────────────────────────────
    echo
    echo -e "${BOLD}────────────────────────────────────────${NC}"
    success "Installed: ${installed}  |  Skipped: ${skipped}"
    echo
    info "Commands → ${CYAN}${CURSOR_COMMANDS_DIR}${NC}"
    info "Skills   → ${CYAN}${CURSOR_SKILLS_DIR}${NC}"
    echo
    info "Symlinks point back to this repo — ${GREEN}git pull${NC} to update."
    echo -e "${BOLD}────────────────────────────────────────${NC}"
    echo
}

# ── Main ───────────────────────────────────────────────────────
case "${1:-}" in
    --uninstall | -u | uninstall)
        uninstall
        ;;
    --help | -h)
        echo "Usage: $0 [--uninstall]"
        echo
        echo "  (no args)     Install (symlink) commands & skills into ~/.cursor"
        echo "  --uninstall   Remove symlinks created by this script"
        echo "  --help        Show this help"
        ;;
    "")
        install
        ;;
    *)
        error "Unknown option: $1"
        echo "Run '$0 --help' for usage."
        exit 1
        ;;
esac
