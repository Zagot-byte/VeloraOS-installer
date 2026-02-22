#!/usr/bin/env bash
# Robrum OS — Stage 4: System Configuration (chroot)

stage4_config () {
    info_print "Stage 4: Configuring system..."

    # Set up LUKS in grub
    UUID=$(blkid -s UUID -o value "$CRYPTROOT")
    sed -i "\,^GRUB_CMDLINE_LINUX=\"\",s,\",&rd.luks.name=$UUID=cryptroot root=$BTRFS," \
        /mnt/etc/default/grub

    # Also set GRUB bootloader ID to Robrum OS
    sed -i 's/^#\?GRUB_DISTRIBUTOR=.*/GRUB_DISTRIBUTOR="Robrum OS"/' /mnt/etc/default/grub

    (
    echo "15"
    arch-chroot /mnt /bin/bash -e <<EOF
    # Timezone
    ln -sf /usr/share/zoneinfo/\$(curl -s http://ip-api.com/line?fields=timezone) /etc/localtime &>/dev/null
    hwclock --systohc
EOF
    echo "30"
    arch-chroot /mnt /bin/bash -e <<EOF
    # Locales
    locale-gen &>/dev/null
EOF
    echo "45"
    arch-chroot /mnt /bin/bash -e <<EOF
    # Initramfs
    cat > /etc/mkinitcpio.conf <<MKINIT
HOOKS=(systemd autodetect keyboard sd-vconsole modconf block sd-encrypt filesystems)
MKINIT
    mkinitcpio -P &>/dev/null
EOF
    echo "65"
    arch-chroot /mnt /bin/bash -e <<EOF
    # Snapper
    umount /.snapshots
    rm -r /.snapshots
    snapper --no-dbus -c root create-config /
    btrfs subvolume delete /.snapshots &>/dev/null
    mkdir /.snapshots
    mount -a &>/dev/null
    chmod 750 /.snapshots
EOF
    echo "85"
    arch-chroot /mnt /bin/bash -e <<EOF
    # GRUB
    grub-install --target=x86_64-efi --efi-directory=/boot/ --bootloader-id=GRUB &>/dev/null
    grub-mkconfig -o /boot/grub/grub.cfg &>/dev/null
EOF
    echo "100"
    ) | whiptail --title "Robrum OS Installer" --gauge "Configuring system..." 8 60 0
}
