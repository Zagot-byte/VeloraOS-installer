#!/usr/bin/env bash
# Robrum OS — Stage 6: Post Install

stage6_post () {
    info_print "Stage 6: Post install configuration..."

    (
    echo "20" ; info_print "Setting up boot backup hook..."
    mkdir -p /mnt/etc/pacman.d/hooks
    cat > /mnt/etc/pacman.d/hooks/50-bootbackup.hook <<EOF
[Trigger]
Operation = Upgrade
Operation = Install
Operation = Remove
Type = Path
Target = usr/lib/modules/*/vmlinuz

[Action]
Depends = rsync
Description = Backing up /boot...
When = PostTransaction
Exec = /usr/bin/rsync -a --delete /boot /.bootbackup
EOF

    echo "40" ; info_print "Configuring ZRAM..."
    cat > /mnt/etc/systemd/zram-generator.conf <<EOF
[zram0]
zram-size = min(ram, 8192)
EOF

    echo "60" ; info_print "Enabling pacman candy and parallel downloads..."
    sed -Ei 's/^#(Color)$/\1\nILoveCandy/;s/^#(ParallelDownloads).*/\1 = 10/' \
        /mnt/etc/pacman.conf

    echo "75" ; info_print "Enabling services..."
    services=(
        reflector.timer
        snapper-timeline.timer
        snapper-cleanup.timer
        btrfs-scrub@-.timer
        btrfs-scrub@home.timer
        btrfs-scrub@var-log.timer
        btrfs-scrub@\\x2esnapshots.timer
        grub-btrfsd.service
        systemd-oomd
    )
    for service in "${services[@]}"; do
        systemctl enable "$service" --root=/mnt &>/dev/null
    done

    echo "90" ; info_print "Pulling easy-install for post-reboot setup..."
    arch-chroot /mnt /bin/bash -e <<EOF
    git clone https://github.com/Zagot-byte/easy-install /home/${username}/easy-install &>/dev/null
    chown -R ${username}:${username} /home/${username}/easy-install &>/dev/null
EOF

    echo "100"
    ) | whiptail --title "Robrum OS Installer" --gauge "Finishing up..." 8 60 0
}
