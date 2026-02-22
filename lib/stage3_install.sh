#!/usr/bin/env bash
# Robrum OS — Stage 3: Base System Install

microcode_detector () {
    CPU=$(grep vendor_id /proc/cpuinfo)
    if [[ "$CPU" == *"AuthenticAMD"* ]]; then
        microcode="amd-ucode"
    else
        microcode="intel-ucode"
    fi
}

network_installer () {
    case $network_choice in
        1) pacstrap /mnt iwd >/dev/null
           systemctl enable iwd --root=/mnt &>/dev/null ;;
        2) pacstrap /mnt networkmanager >/dev/null
           systemctl enable NetworkManager --root=/mnt &>/dev/null ;;
        3) pacstrap /mnt wpa_supplicant dhcpcd >/dev/null
           systemctl enable wpa_supplicant --root=/mnt &>/dev/null
           systemctl enable dhcpcd --root=/mnt &>/dev/null ;;
        4) pacstrap /mnt dhcpcd >/dev/null
           systemctl enable dhcpcd --root=/mnt &>/dev/null ;;
    esac
}

virt_check () {
    hypervisor=$(systemd-detect-virt)
    case $hypervisor in
        kvm)       pacstrap /mnt qemu-guest-agent &>/dev/null
                   systemctl enable qemu-guest-agent --root=/mnt &>/dev/null ;;
        vmware)    pacstrap /mnt open-vm-tools >/dev/null
                   systemctl enable vmtoolsd --root=/mnt &>/dev/null
                   systemctl enable vmware-vmblock-fuse --root=/mnt &>/dev/null ;;
        oracle)    pacstrap /mnt virtualbox-guest-utils &>/dev/null
                   systemctl enable vboxservice --root=/mnt &>/dev/null ;;
        microsoft) pacstrap /mnt hyperv &>/dev/null
                   systemctl enable hv_fcopy_daemon --root=/mnt &>/dev/null
                   systemctl enable hv_kvp_daemon --root=/mnt &>/dev/null
                   systemctl enable hv_vss_daemon --root=/mnt &>/dev/null ;;
    esac
}

stage3_install () {
    microcode_detector

    (
    echo "10" ; info_print "Running pacstrap..."
    pacstrap -K /mnt base "$kernel" "$microcode" linux-firmware \
        "$kernel"-headers btrfs-progs grub grub-btrfs rsync \
        efibootmgr snapper reflector snap-pac zram-generator sudo \
        libnewt git curl &>/dev/null

    echo "50" ; info_print "Setting hostname..."
    echo "$hostname" > /mnt/etc/hostname

    echo "60" ; info_print "Generating fstab..."
    genfstab -U /mnt >> /mnt/etc/fstab

    echo "70" ; info_print "Setting locale and keymap..."
    sed -i "/^#$locale/s/^#//" /mnt/etc/locale.gen
    echo "LANG=$locale" > /mnt/etc/locale.conf
    echo "KEYMAP=$kblayout" > /mnt/etc/vconsole.conf

    echo "80" ; info_print "Setting hosts file..."
    cat > /mnt/etc/hosts <<EOF
127.0.0.1   localhost
::1         localhost
127.0.1.1   $hostname.localdomain   $hostname
EOF

    echo "90" ; info_print "Installing network tools..."
    virt_check
    network_installer
    echo "100"
    ) | whiptail --title "Robrum OS Installer" --gauge "Installing base system..." 8 60 0
}
