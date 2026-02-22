#!/usr/bin/env bash
# Robrum OS — Stage 1: User Input Collection

keyboard_selector () {
    kblayout=$(whiptail --title "Robrum OS Installer" \
        --inputbox "Enter keyboard layout (leave empty for US):" 10 60 "us" \
        3>&1 1>&2 2>&3) || return 1
    [[ -z "$kblayout" ]] && kblayout="us"
    if ! localectl list-keymaps | grep -Fxq "$kblayout"; then
        whiptail --title "Error" --msgbox "Invalid keyboard layout: $kblayout" 8 40
        return 1
    fi
    loadkeys "$kblayout"
    return 0
}

kernel_selector () {
    kernel=$(whiptail --title "Robrum OS Installer" \
        --menu "Select a kernel:" 15 60 4 \
        "linux"          "Stable — recommended for most users" \
        "linux-hardened" "Hardened — security focused" \
        "linux-lts"      "LTS — long term support" \
        "linux-zen"      "Zen — optimized for desktop" \
        3>&1 1>&2 2>&3) || return 1
    return 0
}

network_selector () {
    network_choice=$(whiptail --title "Robrum OS Installer" \
        --menu "Select a network utility:" 15 70 5 \
        "1" "IWD — WiFi only, Intel (built-in DHCP)" \
        "2" "NetworkManager — WiFi + Ethernet (recommended)" \
        "3" "wpa_supplicant — WiFi with WPA/WPA2 support" \
        "4" "dhcpcd — Basic DHCP, good for VMs" \
        "5" "Skip — I will configure manually" \
        3>&1 1>&2 2>&3) || return 1
    return 0
}

locale_selector () {
    locale=$(whiptail --title "Robrum OS Installer" \
        --inputbox "Enter your locale (e.g. en_US.UTF-8):" 10 60 "en_US.UTF-8" \
        3>&1 1>&2 2>&3) || return 1
    [[ -z "$locale" ]] && locale="en_US.UTF-8"
    if ! grep -q "^#\?$(sed 's/[].*[]/\\&/g' <<< "$locale") " /etc/locale.gen; then
        whiptail --title "Error" --msgbox "Locale '$locale' not found." 8 50
        return 1
    fi
    return 0
}

hostname_selector () {
    hostname=$(whiptail --title "Robrum OS Installer" \
        --inputbox "Enter a hostname for this machine:" 10 60 "robrum" \
        3>&1 1>&2 2>&3) || return 1
    if [[ -z "$hostname" ]]; then
        whiptail --title "Error" --msgbox "Hostname cannot be empty." 8 40
        return 1
    fi
    return 0
}

lukspass_selector () {
    password=$(whiptail --title "Robrum OS Installer" \
        --passwordbox "Enter password for LUKS encryption:" 10 60 \
        3>&1 1>&2 2>&3) || return 1
    if [[ -z "$password" ]]; then
        whiptail --title "Error" --msgbox "Password cannot be empty." 8 40
        return 1
    fi
    password2=$(whiptail --title "Robrum OS Installer" \
        --passwordbox "Confirm LUKS password:" 10 60 \
        3>&1 1>&2 2>&3) || return 1
    if [[ "$password" != "$password2" ]]; then
        whiptail --title "Error" --msgbox "Passwords do not match." 8 40
        return 1
    fi
    return 0
}

userpass_selector () {
    username=$(whiptail --title "Robrum OS Installer" \
        --inputbox "Enter username (leave empty to skip):" 10 60 \
        3>&1 1>&2 2>&3) || return 1
    [[ -z "$username" ]] && return 0
    userpass=$(whiptail --title "Robrum OS Installer" \
        --passwordbox "Enter password for $username:" 10 60 \
        3>&1 1>&2 2>&3) || return 1
    userpass2=$(whiptail --title "Robrum OS Installer" \
        --passwordbox "Confirm password for $username:" 10 60 \
        3>&1 1>&2 2>&3) || return 1
    if [[ "$userpass" != "$userpass2" ]]; then
        whiptail --title "Error" --msgbox "Passwords do not match." 8 40
        return 1
    fi
    return 0
}

rootpass_selector () {
    rootpass=$(whiptail --title "Robrum OS Installer" \
        --passwordbox "Enter root password:" 10 60 \
        3>&1 1>&2 2>&3) || return 1
    rootpass2=$(whiptail --title "Robrum OS Installer" \
        --passwordbox "Confirm root password:" 10 60 \
        3>&1 1>&2 2>&3) || return 1
    if [[ "$rootpass" != "$rootpass2" ]]; then
        whiptail --title "Error" --msgbox "Passwords do not match." 8 40
        return 1
    fi
    return 0
}

disk_selector () {
    mapfile -t DISKS < <(lsblk -dpno NAME,SIZE,MODEL | grep -P "/dev/sd|nvme|vd")
    if [[ ${#DISKS[@]} -eq 0 ]]; then
        whiptail --title "Error" --msgbox "No disks found." 8 40
        return 1
    fi
    local menu_items=()
    for d in "${DISKS[@]}"; do
        name=$(echo "$d" | awk '{print $1}')
        size=$(echo "$d" | awk '{print $2}')
        menu_items+=("$name" "$size")
    done
    DISK=$(whiptail --title "Robrum OS Installer" \
        --menu "Select installation disk:" 15 60 6 \
        "${menu_items[@]}" \
        3>&1 1>&2 2>&3) || return 1
    whiptail --title "WARNING" \
        --yesno "ALL DATA ON $DISK WILL BE ERASED.\n\nAre you sure?" 10 50 || return 1
    return 0
}
