#!/bin/bash
set -euo pipefail

# Flash a .wic image (or compressed .wic.gz / .wic.bz2) to an SD card.
# Uses bmaptool when available, falls back to dd.

usage() {
    echo "Usage: $0 -i <image> -d <device>"
    echo ""
    echo "  -i   Path to .wic, .wic.gz, or .wic.bz2 image"
    echo "  -d   Target block device (e.g. /dev/sdc)"
    echo ""
    echo "Examples:"
    echo "  $0 -i build/tmp/deploy/images/*/my-image.rootfs.wic.gz -d /dev/sdc"
    echo "  $0 -i images/my-image.rootfs.wic -d /dev/sdc"
    exit 1
}

while getopts "i:d:h" opt; do
    case $opt in
        i) IMAGE="$OPTARG" ;;
        d) SD_DEVICE="$OPTARG" ;;
        h) usage ;;
        *) usage ;;
    esac
done

if [[ -z "${IMAGE:-}" || -z "${SD_DEVICE:-}" ]]; then
    usage
fi

if [[ ! -f "$IMAGE" ]]; then
    echo "Error: image not found: $IMAGE"
    exit 1
fi

if [[ ! -b "$SD_DEVICE" ]]; then
    echo "Error: block device not found: $SD_DEVICE"
    exit 1
fi

# Safety: refuse to write to anything that looks like a system disk
case "$SD_DEVICE" in
    /dev/sda|/dev/nvme0n1|/dev/vda)
        echo "Error: refusing to write to $SD_DEVICE (looks like a system disk)"
        exit 1
        ;;
esac

echo ""
echo "Image:  $IMAGE"
echo "Device: $SD_DEVICE"
echo ""
read -rp "This will ERASE all data on ${SD_DEVICE}. Continue? (yes/no): " CONFIRM
if [[ "$CONFIRM" != "yes" ]]; then
    echo "Cancelled."
    exit 1
fi

# Unmount any mounted partitions
echo "Unmounting partitions on ${SD_DEVICE}..."
sudo umount ${SD_DEVICE}?* 2>/dev/null || true
sudo umount ${SD_DEVICE}p* 2>/dev/null || true

# Flash
if command -v bmaptool >/dev/null 2>&1; then
    echo "Flashing with bmaptool..."
    BMAP_FILE="${IMAGE%.gz}"
    BMAP_FILE="${BMAP_FILE%.bz2}"
    BMAP_FILE="${BMAP_FILE}.bmap"
    if [[ -f "$BMAP_FILE" ]]; then
        sudo bmaptool copy "$IMAGE" "$SD_DEVICE" --bmap "$BMAP_FILE"
    else
        sudo bmaptool copy "$IMAGE" "$SD_DEVICE"
    fi
else
    echo "bmaptool not found, using dd..."
    case "$IMAGE" in
        *.wic.gz)
            gunzip -c "$IMAGE" | sudo dd of="$SD_DEVICE" bs=4M status=progress iflag=fullblock conv=fsync
            ;;
        *.wic.bz2)
            bunzip2 -c "$IMAGE" | sudo dd of="$SD_DEVICE" bs=4M status=progress iflag=fullblock conv=fsync
            ;;
        *.wic)
            sudo dd if="$IMAGE" of="$SD_DEVICE" bs=4M status=progress conv=fsync
            ;;
        *)
            echo "Error: unsupported image format. Expected .wic, .wic.gz, or .wic.bz2"
            exit 1
            ;;
    esac
fi

sync

echo ""
echo "Flash complete: $SD_DEVICE"
echo ""

# Offer to expand rootfs
ROOTFS_PART=""
if [[ -b "${SD_DEVICE}2" ]]; then
    ROOTFS_PART="${SD_DEVICE}2"
elif [[ -b "${SD_DEVICE}p2" ]]; then
    ROOTFS_PART="${SD_DEVICE}p2"
fi

if [[ -n "$ROOTFS_PART" ]]; then
    read -rp "Expand rootfs partition to fill the SD card? (yes/no): " EXPAND
    if [[ "$EXPAND" == "yes" ]]; then
        echo "Expanding ${ROOTFS_PART}..."
        sudo e2fsck -f -y "$ROOTFS_PART"
        sudo resize2fs "$ROOTFS_PART"
        sudo e2fsck -f "$ROOTFS_PART"
        sync
        echo "Rootfs expanded."
    fi
fi

echo ""
echo "Done. You can remove the SD card and boot your board."
