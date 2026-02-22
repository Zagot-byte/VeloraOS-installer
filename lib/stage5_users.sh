#!/usr/bin/env bash
# Robrum OS — Stage 5: Users & Security

stage5_users () {
    info_print "Stage 5: Setting up users..."

    # Root password
    echo "root:$rootpass" | arch-chroot /mnt chpasswd

    # User account
    if [[ -n "$username" ]]; then
        echo "%wheel ALL=(ALL:ALL) ALL" > /mnt/etc/sudoers.d/wheel
        arch-chroot /mnt useradd -m -G wheel -s /bin/bash "$username"
        echo "$username:$userpass" | arch-chroot /mnt chpasswd
        info_print "User $username created with sudo access."
    fi

    whiptail --title "Robrum OS Installer" \
        --msgbox "Users configured successfully." 8 40
}
