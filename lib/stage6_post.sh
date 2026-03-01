#!/usr/bin/env bash
# ╔══════════════════════════════════════════════════════════════════╗
# ║    Velora OS — Stage 6: Post Install                             ║
# ╚══════════════════════════════════════════════════════════════════╝

stage6_post () {
    ui_status_info "Stage 6: Post-install configuration..."

    ui_gauge_start "Finishing Up"

    ui_gauge_update 20 "Installing boot backup pacman hook..."
    mkdir -p /mnt/etc/pacman.d/hooks
    cat > /mnt/etc/pacman.d/hooks/50-bootbackup.hook <<'EOF'
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

    ui_gauge_update 40 "Configuring ZRAM swap..."
    cat > /mnt/etc/systemd/zram-generator.conf <<'EOF'
[zram0]
zram-size = min(ram, 8192)
EOF

    ui_gauge_update 60 "Enabling pacman candy and parallel downloads..."
    sed -Ei 's/^#(Color)$/\1\nILoveCandy/;s/^#(ParallelDownloads).*/\1 = 10/' \
        /mnt/etc/pacman.conf

    ui_gauge_update 75 "Enabling system services..."
    local services=(
        reflector.timer
        snapper-timeline.timer
        snapper-cleanup.timer
        btrfs-scrub@-.timer
        btrfs-scrub@home.timer
        btrfs-scrub@var-log.timer
        "btrfs-scrub@\\x2esnapshots.timer"
        grub-btrfsd.service
        systemd-oomd
    )
    for service in "${services[@]}"; do
        systemctl enable "$service" --root=/mnt &>/dev/null
    done

    ui_gauge_update 90 "Cloning easy-install repo for post-reboot setup..."
    arch-chroot /mnt /bin/bash -e <<EOF
git clone https://github.com/Zagot-byte/easy-install /home/${username}/easy-install &>/dev/null
chown -R ${username}:${username} /home/${username}/easy-install &>/dev/null
EOF

    ui_gauge_update 100 "Post-install complete."
    ui_gauge_end
}
