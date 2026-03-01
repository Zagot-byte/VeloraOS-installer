#!/usr/bin/env bash
# ╔══════════════════════════════════════════════════════════════════╗
# ║    Velora OS — Stage 4: System Configuration (chroot)           ║
# ╚══════════════════════════════════════════════════════════════════╝

stage4_config () {
    ui_status_info "Stage 4: Configuring system..."

    # Embed LUKS UUID into GRUB cmdline
    UUID=$(blkid -s UUID -o value "$CRYPTROOT")
    sed -i "\,^GRUB_CMDLINE_LINUX=\"\",s,\",\&rd.luks.name=$UUID=cryptroot root=$BTRFS," \
        /mnt/etc/default/grub

    # Set GRUB distributor name
    sed -i 's/^#\?GRUB_DISTRIBUTOR=.*/GRUB_DISTRIBUTOR="Velora OS"/' \
        /mnt/etc/default/grub

    ui_gauge_start "Configuring System"

    ui_gauge_update 15 "Setting timezone via ip-api..."
    arch-chroot /mnt /bin/bash -e <<'EOF'
ln -sf /usr/share/zoneinfo/$(curl -s http://ip-api.com/line?fields=timezone) /etc/localtime &>/dev/null
hwclock --systohc
EOF

    ui_gauge_update 30 "Generating locales..."
    arch-chroot /mnt /bin/bash -e <<'EOF'
locale-gen &>/dev/null
EOF

    ui_gauge_update 45 "Building initramfs (mkinitcpio)..."
    arch-chroot /mnt /bin/bash -e <<'EOF'
cat > /etc/mkinitcpio.conf <<MKINIT
HOOKS=(systemd autodetect keyboard sd-vconsole modconf block sd-encrypt filesystems)
MKINIT
mkinitcpio -P &>/dev/null
EOF

    ui_gauge_update 65 "Setting up Snapper (BTRFS snapshots)..."
    arch-chroot /mnt /bin/bash -e <<'EOF'
umount /.snapshots
rm -r /.snapshots
snapper --no-dbus -c root create-config /
btrfs subvolume delete /.snapshots &>/dev/null
mkdir /.snapshots
mount -a &>/dev/null
chmod 750 /.snapshots
EOF

    ui_gauge_update 85 "Installing and configuring GRUB bootloader..."
    arch-chroot /mnt /bin/bash -e <<'EOF'
grub-install --target=x86_64-efi --efi-directory=/boot/ --bootloader-id=GRUB &>/dev/null
grub-mkconfig -o /boot/grub/grub.cfg &>/dev/null
EOF

    ui_gauge_update 100 "System configuration complete."
    ui_gauge_end
}
