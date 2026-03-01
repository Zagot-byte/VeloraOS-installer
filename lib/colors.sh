#!/usr/bin/env bash
# ╔══════════════════════════════════════════════════════════════════╗
# ║    Velora OS — Color palette & print helpers                    ║
# ╚══════════════════════════════════════════════════════════════════╝
# NEWT_COLORS removed — whiptail is no longer used.
# True-color sequences are defined in ui.sh; these are kept as
# thin wrappers for any legacy echo-style prints that remain.

BOLD='\e[1m'
BRED='\e[38;2;229;91;91m'      # #e55b5b active red
BBLUE='\e[34m'
BGREEN='\e[38;2;80;200;90m'   # success green
BYELLOW='\e[93m'
RESET='\e[0m'

# ─── Status print helpers ─────────────────────────────────────────────────────
# These are now thin wrappers; the UI layer's ui_status_* are preferred.
# Kept for compatibility with any stage code that calls them outside of ui_init.
info_print ()  { echo -e "${BOLD}${BRED}  ●  ${RESET}${BOLD}$1${RESET}"; }
input_print () { echo -ne "${BOLD}${BYELLOW}  ▸  ${RESET}${BOLD}$1${RESET}"; }
error_print () { echo -e "${BOLD}${BRED}  ✖  ${RESET}${BOLD}$1${RESET}"; }
