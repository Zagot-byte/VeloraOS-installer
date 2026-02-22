#!/usr/bin/env bash
# Robrum OS — Stage 2: Disk Setup (with manual partitioning support)

stage2_disk () {
    info_print "Stage 2: Setting up disk $DISK"

    # Ask partitioning mode
    PART_MODE=$(whiptail --title "Robrum OS Installer" \
        --menu "Choose partitioning mode:" 12 60 2 \
        "auto"   "Automatic — wipe disk and partition automatically" \
        "manual" "Manual — use cfdisk to partition yourself" \
        3>&1 1>&2 2>&3) || return 1

    if [[ "$PART_MODE" == "manual" ]]; then
        whiptail --title "Manual Partitioning" \
            --msgbox "cfdisk will now open.\n\nYou must create:\n  • An EFI partition (FAT32, ~1GB, type: EFI System)\n  • A root partition (rest of disk, type: Linux filesystem)\n\nWrite and quit when done." \
            14 60
        cfdisk "$DISK"
        partprobe "$DISK"

        # Let user pick which partitions are which
        mapfile -t PARTS < <(lsblk -pno NAME "$DISK" | tail -n +2)
        local part_menu=()
        for p in "${PARTS[@]}"; do
            size=$(lsblk -pno SIZE "$p" | head -1)
            part_menu+=("$p" "$size")
        done

        ESP=$(whiptail --title "Select EFI Partition" \
            --menu "Which partition is your EFI/boot partition?" 15 60 6 \
            "${part_menu[@]}" 3>&1 1>&2 2>&3) || return 1

        CRYPTROOT=$(whiptail --title "Select Root Partition" \
            --menu "Which partition is your root partition?" 15 60 6 \
            "${part_menu[@]}" 3>&1 1>&2 2>&3) || return 1

        whiptail --title "Robrum OS Installer" \
            --yesno "Format $ESP as FAT32?\n(Skip if already formatted)" 8 50
        if [[ $? -eq 0 ]]; then
            mkfs.fat -F 32 "$ESP" &>/dev/null
        fi

    else
        whiptail --title "WARNING" \
            --yesno "ALL DATA ON $DISK WILL BE ERASED.\n\nAre you absolutely sure?" 10 50 || return 1

        (
        echo "10"
        wipefs -af "$DISK" &>/dev/null
        sgdisk -Zo "$DISK" &>/dev/null
        echo "25"
        parted -s "$DISK" \
            mklabel gpt \
            mkpart ESP fat32 1MiB 1025MiB \
            set 1 esp on \
            mkpart CRYPTROOT 1025MiB 100%
        partprobe "$DISK"
        sleep 1
        echo "60"
        ESP="/dev/disk/by-partlabel/ESP"
        CRYPTROOT="/dev/disk/by-partlabel/CRYPTROOT"
        mkfs.fat -F 32 "$ESP" &>/dev/null
        echo "100"
        ) | whiptail --title "Robrum OS Installer" --gauge "Partitioning disk..." 8 60 0

        ESP="/dev/disk/by-partlabel/ESP"
        CRYPTROOT="/dev/disk/by-partlabel/CRYPTROOT"
    fi

    # LUKS + BTRFS — same for both modes
    (
    echo "10"
    echo -n "$password" | cryptsetup luksFormat "$CRYPTROOT" -d - &>/dev/null
    echo "30"
    echo -n "$password" | cryptsetup open "$CRYPTROOT" cryptroot -d -
    BTRFS="/dev/mapper/cryptroot"
    echo "45"
    mkfs.btrfs "$BTRFS" &>/dev/null
    mount "$BTRFS" /mnt
    echo "60"
    subvols=(snapshots var_pkgs var_log home root srv)
    for subvol in '' "${subvols[@]}"; do
        btrfs su cr /mnt/@"$subvol" &>/dev/null
    done
    echo "75"
    umount /mnt
    mountopts="ssd,noatime,compress-force=zstd:3,discard=async"
    mount -o "$mountopts",subvol=@ "$BTRFS" /mnt
    mkdir -p /mnt/{home,root,srv,.snapshots,var/{log,cache/pacman/pkg},boot}
    for subvol in "${subvols[@]:2}"; do
        mount -o "$mountopts",subvol=@"$subvol" "$BTRFS" /mnt/"${subvol//_//}"
    done
    echo "90"
    chmod 750 /mnt/root
    mount -o "$mountopts",subvol=@snapshots "$BTRFS" /mnt/.snapshots
    mount -o "$mountopts",subvol=@var_pkgs "$BTRFS" /mnt/var/cache/pacman/pkg
    chattr +C /mnt/var/log
    mount "$ESP" /mnt/boot/
    echo "100"
    ) | whiptail --title "Robrum OS Installer" --gauge "Setting up LUKS + BTRFS..." 8 60 0

    export ESP
    export CRYPTROOT
    export BTRFS="/dev/mapper/cryptroot"
}
