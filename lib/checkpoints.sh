#!/usr/bin/env bash
# ╔══════════════════════════════════════════════════════════════════╗
# ║    Velora OS — Checkpoint system (crash recovery)               ║
# ╚══════════════════════════════════════════════════════════════════╝

CP="/tmp/velora_cp"
mkdir -p "$CP"

# Check if a stage is already done
done_check () { [[ -f "$CP/$1" ]]; }

# Mark a stage as done
mark_done () { touch "$CP/$1"; }

# Show a pretty progress panel at resume time
show_progress () {
    local stages=("stage1_input" "stage2_disk" "stage3_install" "stage4_config" "stage5_users" "stage6_post")
    local names=("User Input" "Disk Setup" "Base Install" "System Config" "Users" "Post Install")

    # Use nameref-compatible call if ui_checkpoint_panel is available
    if declare -f ui_checkpoint_panel &>/dev/null; then
        ui_checkpoint_panel stages names
    else
        # Fallback for sourcing without full UI
        echo ""
        info_print "VeloraOS Install Progress:"
        for i in "${!stages[@]}"; do
            if done_check "${stages[$i]}"; then
                echo -e "  ${BGREEN}✔${RESET} ${names[$i]}"
            else
                echo -e "  ${BRED}○${RESET} ${names[$i]}"
            fi
        done
        echo ""
    fi
}
