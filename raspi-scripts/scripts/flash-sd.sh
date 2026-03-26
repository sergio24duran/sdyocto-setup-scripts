#!/bin/bash
set -euo pipefail

# ============================================================
# Flash Linux image (.wic) to SD card, using bmaptool or dd
# ============================================================

usage() {
    echo "Usage: $0 -t <timestamp_path> -d <sd_device>"
    exit 1
}

# ---------------------------
# Parse arguments
# ---------------------------
while getopts "t:d:" opt; do
    case $opt in
        t) TIMESTAMP_PATH="$OPTARG" ;;
        d) SD_DEVICE="$OPTARG" ;;
        *) usage ;;
    esac
done

if [[ -z "${TIMESTAMP_PATH:-}" || -z "${SD_DEVICE:-}" ]]; then
    echo "❌ You must specify both timestamp_path and device"
    usage
fi

# ---------------------------
# Validations
# ---------------------------
if [[ ! -d "$TIMESTAMP_PATH" ]]; then
    echo "❌ Image folder not found: $TIMESTAMP_PATH"
    exit 1
fi

if [[ ! -b "$SD_DEVICE" ]]; then
    echo "❌ Device not found: $SD_DEVICE"
    exit 1
fi

# ---------------------------
# Find .wic and .bmap files
# ---------------------------
WIC_IMAGE=$(ls "$TIMESTAMP_PATH"/*.wic 2>/dev/null | head -n1 || true)
BMAP_FILE=$(ls "$TIMESTAMP_PATH"/*.wic.bmap 2>/dev/null | head -n1 || true)

if [[ -z "$WIC_IMAGE" ]]; then
    echo "❌ No .wic image found in $TIMESTAMP_PATH"
    exit 1
fi

if [[ -z "$BMAP_FILE" ]]; then
    echo "⚠️ No .bmap file found. Proceeding without it."
fi

# ---------------------------
# Confirm with user
# ---------------------------
echo "⚠️ About to flash:"
echo "   Image:  $WIC_IMAGE"
echo "   Device: $SD_DEVICE"
echo ""
read -rp "❓ Continue? (yes/[no]): " CONFIRM
if [[ "$CONFIRM" != "yes" ]]; then
    echo "❌ Operation cancelled."
    exit 1
fi

# ---------------------------
# Unmount SD partitions
# ---------------------------
echo "🛑 Unmounting partitions from $SD_DEVICE ..."
sudo umount ${SD_DEVICE}?* 2>/dev/null || true

# ---------------------------
# Flash using bmaptool or dd
# ---------------------------
if command -v bmaptool >/dev/null 2>&1; then
    echo "⚡ Using bmaptool to flash image..."
    if [[ -n "$BMAP_FILE" ]]; then
        sudo bmaptool copy "$WIC_IMAGE" "$SD_DEVICE" --bmap "$BMAP_FILE"
    else
        sudo bmaptool copy "$WIC_IMAGE" "$SD_DEVICE"
    fi
else
    echo "⚠️ bmaptool not found, using dd instead..."
    echo "⏳ Writing image to SD card, please wait..."
    sudo dd if="$WIC_IMAGE" of="$SD_DEVICE" bs=4M status=progress conv=fsync
fi

sync
echo ""
echo "✅ Image successfully written to $SD_DEVICE"
echo "💡 You can now remove the SD card and boot your device."
