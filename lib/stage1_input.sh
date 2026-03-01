#!/usr/bin/env bash
# ╔══════════════════════════════════════════════════════════════════╗
# ║    Velora OS — Stage 1: User Input Collection                   ║
# ╚══════════════════════════════════════════════════════════════════╝

keyboard_selector () {
    if ! ui_input "Keyboard Layout" \
        "Enter keyboard layout (leave empty for US):" "us"; then
        return 1
    fi
    kblayout="$REPLY"
    [[ -z "$kblayout" ]] && kblayout="us"

    if ! localectl list-keymaps | grep -Fxq "$kblayout"; then
        ui_error "Invalid Layout" "Keyboard layout '${kblayout}' was not found."
        return 1
    fi
    loadkeys "$kblayout"
    return 0
}

kernel_selector () {
    if ! ui_menu "Select Kernel" \
        "linux|Stable — recommended for most users" \
        "linux-hardened|Hardened — security focused" \
        "linux-lts|LTS — long term support" \
        "linux-zen|Zen — optimized for desktop"; then
        return 1
    fi
    kernel="$REPLY"
    return 0
}

network_selector () {
    if ! ui_menu "Network Manager" \
        "iwd|IWD — WiFi only, Intel (built-in DHCP)" \
        "NetworkManager|NetworkManager — WiFi + Ethernet (recommended)" \
        "wpa_supplicant|wpa_supplicant — WiFi with WPA/WPA2 support" \
        "dhcpcd|dhcpcd — Basic DHCP, good for VMs" \
        "skip|Skip — I will configure manually"; then
        return 1
    fi
    # Map selection to network_choice number (for stage3 compatibility)
    case "$REPLY" in
        iwd)            network_choice=1 ;;
        NetworkManager) network_choice=2 ;;
        wpa_supplicant) network_choice=3 ;;
        dhcpcd)         network_choice=4 ;;
        skip)           network_choice=5 ;;
    esac
    return 0
}

locale_selector () {
    if ! ui_input "Locale" \
        "Enter your locale (e.g. en_US.UTF-8):" "en_US.UTF-8"; then
        return 1
    fi
    locale="$REPLY"
    [[ -z "$locale" ]] && locale="en_US.UTF-8"

    if ! grep -q "^#\?$(sed 's/[].*[]/\\&/g' <<< "$locale") " /etc/locale.gen; then
        ui_error "Invalid Locale" "Locale '${locale}' was not found in /etc/locale.gen."
        return 1
    fi
    return 0
}

hostname_selector () {
    if ! ui_input "Hostname" \
        "Enter a hostname for this machine:" "velora"; then
        return 1
    fi
    hostname="$REPLY"
    if [[ -z "$hostname" ]]; then
        ui_error "Invalid Hostname" "Hostname cannot be empty."
        return 1
    fi
    return 0
}

lukspass_selector () {
    if ! ui_password "LUKS Encryption" "Enter password for LUKS encryption:"; then
        return 1
    fi
    password="$REPLY"
    if [[ -z "$password" ]]; then
        ui_error "Empty Password" "LUKS password cannot be empty."
        return 1
    fi

    if ! ui_password "LUKS Encryption" "Confirm LUKS password:"; then
        return 1
    fi
    local password2="$REPLY"

    if [[ "$password" != "$password2" ]]; then
        ui_error "Mismatch" "Passwords do not match. Please try again."
        return 1
    fi
    return 0
}

userpass_selector () {
    if ! ui_input "User Account" \
        "Enter username (leave empty to skip):"; then
        return 1
    fi
    username="$REPLY"
    [[ -z "$username" ]] && return 0

    if ! ui_password "User Password" "Enter password for ${username}:"; then
        return 1
    fi
    userpass="$REPLY"

    if ! ui_password "User Password" "Confirm password for ${username}:"; then
        return 1
    fi
    local userpass2="$REPLY"

    if [[ "$userpass" != "$userpass2" ]]; then
        ui_error "Mismatch" "Passwords do not match. Please try again."
        return 1
    fi
    return 0
}

rootpass_selector () {
    if ! ui_password "Root Password" "Enter root password:"; then
        return 1
    fi
    rootpass="$REPLY"

    if ! ui_password "Root Password" "Confirm root password:"; then
        return 1
    fi
    local rootpass2="$REPLY"

    if [[ "$rootpass" != "$rootpass2" ]]; then
        ui_error "Mismatch" "Passwords do not match. Please try again."
        return 1
    fi
    return 0
}

disk_selector () {
    mapfile -t DISKS < <(lsblk -dpno NAME,SIZE,MODEL | grep -P "/dev/sd|nvme|vd")
    if [[ ${#DISKS[@]} -eq 0 ]]; then
        ui_error "No Disks Found" "No suitable block devices were detected."
        return 1
    fi

    local menu_args=()
    for d in "${DISKS[@]}"; do
        local name size model
        name=$(echo "$d" | awk '{print $1}')
        size=$(echo "$d" | awk '{print $2}')
        model=$(echo "$d" | awk '{$1=$2=""; print $0}' | xargs)
        [[ -z "$model" ]] && model="—"
        menu_args+=("${name}|${size}  ${model}")
    done

    if ! ui_menu "Select Installation Disk" "${menu_args[@]}"; then
        return 1
    fi
    DISK="$REPLY"

    if ! ui_confirm "⚠  WARNING" \
        "ALL DATA ON ${DISK} WILL BE PERMANENTLY ERASED."; then
        return 1
    fi
    return 0
}
