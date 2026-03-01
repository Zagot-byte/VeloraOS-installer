#!/usr/bin/env bash
# ╔══════════════════════════════════════════════════════════════════╗
# ║    Velora OS — Stage 2: Disk Setup                               ║
# ╚══════════════════════════════════════════════════════════════════╝

stage2_disk () {
    ui_status_info "Stage 2: Setting up disk ${DISK}"

    # ── Partitioning mode ────────────────────────────────────────────────────
    if ! ui_menu "Partitioning Mode" \
        "auto|Automatic — wipe disk and partition automatically" \
        "manual|Manual — use cfdisk to partition yourself"; then
        return 1
    fi
    PART_MODE="$REPLY"

    if [[ "$PART_MODE" == "manual" ]]; then
        # ── Manual partitioning ──────────────────────────────────────────────
        ui_message "Manual Partitioning" \
"cfdisk will open next. You must create:
  •  An EFI partition (FAT32, ~1 GB, type: EFI System)
  •  A root partition (rest of disk, type: Linux filesystem)
Write and quit when done."

        cfdisk "$DISK"
        partprobe "$DISK"

        mapfile -t PARTS < <(lsblk -pno NAME "$DISK" | tail -n +2)
        local part_menu=()
        for p in "${PARTS[@]}"; do
            local size
            size=$(lsblk -pno SIZE "$p" | head -1)
            part_menu+=("${p}|${size}")
        done

        if ! ui_menu "Select EFI Partition" "${part_menu[@]}"; then return 1; fi
        ESP="$REPLY"

        if ! ui_menu "Select Root Partition" "${part_menu[@]}"; then return 1; fi
        CRYPTROOT="$REPLY"

        if ui_confirm "Format EFI?" "Format ${ESP} as FAT32? (Skip if already done)"; then
            mkfs.fat -F 32 "$ESP" &>/dev/null
        fi

    else
        # ── Automatic partitioning ───────────────────────────────────────────
        if ! ui_confirm "⚠  FINAL WARNING" \
            "ALL DATA ON ${DISK} WILL BE PERMANENTLY ERASED. Are you sure?"; then
            return 1
        fi

        ui_gauge_start "Partitioning Disk"
        ui_gauge_update 10 "Wiping existing partition table..."
        wipefs -af "$DISK" &>/dev/null
        sgdisk -Zo "$DISK" &>/dev/null

        ui_gauge_update 30 "Creating GPT partitions..."
        parted -s "$DISK" \
            mklabel gpt \
            mkpart ESP fat32 1MiB 1025MiB \
            set 1 esp on \
            mkpart CRYPTROOT 1025MiB 100%
        partprobe "$DISK"
        sleep 1

        ui_gauge_update 65 "Formatting EFI partition (FAT32)..."
        ESP="/dev/disk/by-partlabel/ESP"
        CRYPTROOT="/dev/disk/by-partlabel/CRYPTROOT"
        mkfs.fat -F 32 "$ESP" &>/dev/null

        ui_gauge_update 100 "Partitioning complete."
        ui_gauge_end

        ESP="/dev/disk/by-partlabel/ESP"
        CRYPTROOT="/dev/disk/by-partlabel/CRYPTROOT"
    fi

    # ── LUKS + BTRFS — same for both modes ──────────────────────────────────
    ui_gauge_start "Setting Up Encryption & Filesystem"

    ui_gauge_update 10 "Formatting LUKS container..."
    echo -n "$password" | cryptsetup luksFormat "$CRYPTROOT" -d - &>/dev/null

    ui_gauge_update 30 "Opening LUKS container..."
    echo -n "$password" | cryptsetup open "$CRYPTROOT" cryptroot -d -
    BTRFS="/dev/mapper/cryptroot"

    ui_gauge_update 45 "Creating BTRFS filesystem..."
    mkfs.btrfs "$BTRFS" &>/dev/null
    mount "$BTRFS" /mnt

    ui_gauge_update 60 "Creating BTRFS subvolumes..."
    local subvols=(snapshots var_pkgs var_log home root srv)
    for subvol in '' "${subvols[@]}"; do
        btrfs su cr /mnt/@"$subvol" &>/dev/null
    done

    ui_gauge_update 75 "Mounting subvolumes..."
    umount /mnt
    local mountopts="ssd,noatime,compress-force=zstd:3,discard=async"
    mount -o "${mountopts}",subvol=@ "$BTRFS" /mnt
    mkdir -p /mnt/{home,root,srv,.snapshots,var/{log,cache/pacman/pkg},boot}
    for subvol in "${subvols[@]:2}"; do
        mount -o "${mountopts}",subvol=@"$subvol" "$BTRFS" /mnt/"${subvol//_//}"
    done

    ui_gauge_update 90 "Finalising mount points..."
    chmod 750 /mnt/root
    mount -o "${mountopts}",subvol=@snapshots "$BTRFS" /mnt/.snapshots
    mount -o "${mountopts}",subvol=@var_pkgs  "$BTRFS" /mnt/var/cache/pacman/pkg
    chattr +C /mnt/var/log
    mount "$ESP" /mnt/boot/

    ui_gauge_update 100 "Disk setup complete."
    ui_gauge_end

    export ESP
    export CRYPTROOT
    export BTRFS="/dev/mapper/cryptroot"
}
