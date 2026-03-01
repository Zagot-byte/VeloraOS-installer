#!/usr/bin/env bash
# ╔══════════════════════════════════════════════════════════════════╗
# ║    Velora OS — Stage 5: Users & Security                        ║
# ╚══════════════════════════════════════════════════════════════════╝

stage5_users () {
    ui_status_info "Stage 5: Setting up users..."

    # Root password
    echo "root:$rootpass" | arch-chroot /mnt chpasswd

    # User account
    if [[ -n "$username" ]]; then
        echo "%wheel ALL=(ALL:ALL) ALL" > /mnt/etc/sudoers.d/wheel
        arch-chroot /mnt useradd -m -G wheel -s /bin/bash "$username"
        echo "$username:$userpass" | arch-chroot /mnt chpasswd
        ui_status_ok "User '${username}' created with sudo access."
    fi

    ui_message "Users Configured" \
"Users have been set up successfully.

  Root password  ✔
$(  [[ -n "$username" ]] && echo "  User: ${username}  ✔ (sudo enabled)" || echo "  No additional user created.")"
}
