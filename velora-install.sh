#!/usr/bin/env -S bash -e
# shellcheck disable=SC2001
# ╔══════════════════════════════════════════════════════════════════╗
# ║         Velora OS Installer — Main Entry Point                   ║
# ║         Pure-bash ANSI TUI — no whiptail, no dialog              ║
# ╚══════════════════════════════════════════════════════════════════╝

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/colors.sh"
source "$SCRIPT_DIR/lib/ui.sh"
source "$SCRIPT_DIR/lib/checkpoints.sh"
source "$SCRIPT_DIR/lib/stage1_input.sh"
source "$SCRIPT_DIR/lib/stage2_disk.sh"
source "$SCRIPT_DIR/lib/stage3_install.sh"
source "$SCRIPT_DIR/lib/stage4_config.sh"
source "$SCRIPT_DIR/lib/stage5_users.sh"
source "$SCRIPT_DIR/lib/stage6_post.sh"

# ── Boot the TUI ────────────────────────────────────────────────────────────
ui_init

# Animated header + logo reveal
HEADER_ROW=1
draw_header

# Stage bar baseline (sits below header separator)
_STAGE_BAR_ROW=$HEADER_ROW
CONTENT_ROW=$(( _STAGE_BAR_ROW + 4 ))
_STATUS_LINE=$CONTENT_ROW

# Show resume panel if any checkpoint exists
show_progress

# ─── STAGE 1: User Input ────────────────────────────────────────────────────
draw_stage_bar 1
stage_transition "Stage 1 — Installation Settings"

if ! done_check "stage1_input"; then
    until keyboard_selector; do : ; done
    until disk_selector;     do : ; done
    until lukspass_selector; do : ; done
    until kernel_selector;   do : ; done
    until network_selector;  do : ; done
    until locale_selector;   do : ; done
    until hostname_selector; do : ; done
    until userpass_selector; do : ; done
    until rootpass_selector; do : ; done
    mark_done "stage1_input"
else
    ui_status_info "Stage 1 already complete, skipping..."
fi

# ─── STAGE 2: Disk Setup ────────────────────────────────────────────────────
draw_stage_bar 2
stage_transition "Stage 2 — Disk Setup"
_STATUS_LINE=$CONTENT_ROW

if ! done_check "stage2_disk"; then
    stage2_disk
    mark_done "stage2_disk"
else
    ui_status_info "Stage 2 already complete, skipping..."
fi

# ─── STAGE 3: Base Install ──────────────────────────────────────────────────
draw_stage_bar 3
stage_transition "Stage 3 — Base System Install"
_STATUS_LINE=$CONTENT_ROW

if ! done_check "stage3_install"; then
    stage3_install
    mark_done "stage3_install"
else
    ui_status_info "Stage 3 already complete, skipping..."
fi

# ─── STAGE 4: System Config ─────────────────────────────────────────────────
draw_stage_bar 4
stage_transition "Stage 4 — System Configuration"
_STATUS_LINE=$CONTENT_ROW

if ! done_check "stage4_config"; then
    stage4_config
    mark_done "stage4_config"
else
    ui_status_info "Stage 4 already complete, skipping..."
fi

# ─── STAGE 5: Users ─────────────────────────────────────────────────────────
draw_stage_bar 5
stage_transition "Stage 5 — User Accounts"
_STATUS_LINE=$CONTENT_ROW

if ! done_check "stage5_users"; then
    stage5_users
    mark_done "stage5_users"
else
    ui_status_info "Stage 5 already complete, skipping..."
fi

# ─── STAGE 6: Post Install ──────────────────────────────────────────────────
draw_stage_bar 6
stage_transition "Stage 6 — Post-Install"
_STATUS_LINE=$CONTENT_ROW

if ! done_check "stage6_post"; then
    stage6_post
    mark_done "stage6_post"
else
    ui_status_info "Stage 6 already complete, skipping..."
fi

# ─── DONE ────────────────────────────────────────────────────────────────────
ui_completion_screen
ui_cleanup
