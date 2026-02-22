#!/usr/bin/env -S bash -e
# shellcheck disable=SC2001
# Robrum OS Installer — Main Entry Point

# Load libraries
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/colors.sh"
source "$SCRIPT_DIR/lib/checkpoints.sh"
source "$SCRIPT_DIR/lib/stage1_input.sh"
source "$SCRIPT_DIR/lib/stage2_disk.sh"
source "$SCRIPT_DIR/lib/stage3_install.sh"
source "$SCRIPT_DIR/lib/stage4_config.sh"
source "$SCRIPT_DIR/lib/stage5_users.sh"
source "$SCRIPT_DIR/lib/stage6_post.sh"

clear

# Welcome screen
echo -ne "${BOLD}${BRED}
▗▄▄▖  ▗▄▖ ▗▄▄▖ ▗▄▄▖ ▗▖ ▗▖▗▖  ▗▖
▐▌ ▐▌▐▌ ▐▌▐▌ ▐▌▐▌ ▐▌▐▌ ▐▌▐▛▚▞▜▌
▐▛▀▚▖▐▌ ▐▌▐▛▀▚▖▐▛▀▚▖▐▌ ▐▌▐▌  ▐▌
▐▌ ▐▌▝▚▄▞▘▐▙▄▞▘▐▌ ▐▌▝▚▄▞▘▐▌  ▐▌
${RESET}"
info_print "Welcome to Robrum OS Installer — Let's get you set up."

# Show current checkpoint progress (useful on resume)
show_progress

# ─── STAGE 1: User Input ────────────────────────────────────────────────────
if ! done_check "stage1_input"; then
    info_print "Stage 1: Collecting installation settings..."
    until keyboard_selector; do : ; done
    until disk_selector; do : ; done
    until lukspass_selector; do : ; done
    until kernel_selector; do : ; done
    until network_selector; do : ; done
    until locale_selector; do : ; done
    until hostname_selector; do : ; done
    until userpass_selector; do : ; done
    until rootpass_selector; do : ; done
    mark_done "stage1_input"
else
    info_print "Stage 1 already complete, skipping..."
fi

# ─── STAGE 2: Disk Setup ────────────────────────────────────────────────────
if ! done_check "stage2_disk"; then
    stage2_disk
    mark_done "stage2_disk"
else
    info_print "Stage 2 already complete, skipping..."
fi

# ─── STAGE 3: Base Install ──────────────────────────────────────────────────
if ! done_check "stage3_install"; then
    stage3_install
    mark_done "stage3_install"
else
    info_print "Stage 3 already complete, skipping..."
fi

# ─── STAGE 4: System Config ─────────────────────────────────────────────────
if ! done_check "stage4_config"; then
    stage4_config
    mark_done "stage4_config"
else
    info_print "Stage 4 already complete, skipping..."
fi

# ─── STAGE 5: Users ─────────────────────────────────────────────────────────
if ! done_check "stage5_users"; then
    stage5_users
    mark_done "stage5_users"
else
    info_print "Stage 5 already complete, skipping..."
fi

# ─── STAGE 6: Post Install ──────────────────────────────────────────────────
if ! done_check "stage6_post"; then
    stage6_post
    mark_done "stage6_post"
else
    info_print "Stage 6 already complete, skipping..."
fi

# ─── DONE ────────────────────────────────────────────────────────────────────
whiptail --title "Robrum OS Installer" \
    --msgbox "Installation complete!\n\nYour easy-install script is waiting at:\n~/easy-install/install.sh\n\nReboot and run it to install your software stack." \
    12 60

info_print "Done. You may now reboot into Robrum OS."
