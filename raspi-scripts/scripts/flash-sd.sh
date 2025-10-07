#!/bin/bash
set -e

# ---------------------------
# Parse arguments
# ---------------------------
while getopts "t:d:" opt; do
    case $opt in
        t) TIMESTAMP_PATH="$OPTARG" ;;
        d) SD_DEVICE="$OPTARG" ;;
        *) echo "Usage: $0 -t <timestamp_path> -d <sd_device>"; exit 1 ;;
    esac
done

# Check that both arguments were provided
if [[ -z "$TIMESTAMP_PATH" || -z "$SD_DEVICE" ]]; then
    echo "❌ You must specify both timestamp_path and device"
    echo "Usage: $0 -t <timestamp_path> -d <sd_device>"
    exit 1
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
# Unmount SD partitions
# ---------------------------
echo "🛑 Unmounting partitions from $SD_DEVICE ..."
sudo umount ${SD_DEVICE}?* 2>/dev/null || true

# ---------------------------
# Find the .wic image
# ---------------------------
WIC_IMAGE=$(ls "$TIMESTAMP_PATH"/*.wic | head -n1)
if [[ -z "$WIC_IMAGE" ]]; then
    echo "❌ No .wic file found in $TIMESTAMP_PATH"
    exit 1
fi

# ---------------------------
# Flash using bmaptool
# ---------------------------
echo "⚡ Flashing $WIC_IMAGE → $SD_DEVICE ..."
sudo bmaptool copy "$WIC_IMAGE" "$SD_DEVICE"

echo ""
echo "✅ Image successfully written to $SD_DEVICE"
echo "⚠️ You can now insert the SD card into the Raspberry Pi and boot directly."
