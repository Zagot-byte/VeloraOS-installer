#!/usr/bin/env bash
# Robrum OS — Checkpoint system
# Saves progress so crashes don't restart everything

CP="/tmp/robrum_cp"
mkdir -p "$CP"

# Check if a stage is already done
done_check () { [[ -f "$CP/$1" ]]; }

# Mark a stage as done
mark_done () { touch "$CP/$1"; }

# Show checkpoint status on start
show_progress () {
    local stages=("stage1_input" "stage2_disk" "stage3_install" "stage4_config" "stage5_users" "stage6_post")
    local names=("User Input" "Disk Setup" "Base Install" "System Config" "Users" "Post Install")
    echo ""
    info_print "Robrum OS Install Progress:"
    for i in "${!stages[@]}"; do
        if done_check "${stages[$i]}"; then
            echo -e "  ${BGREEN}✓${RESET} ${names[$i]}"
        else
            echo -e "  ${BRED}○${RESET} ${names[$i]}"
        fi
    done
    echo ""
}
