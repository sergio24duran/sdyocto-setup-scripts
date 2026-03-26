#!/bin/bash
set -e

# ---------------------------
# Default parameters
# ---------------------------
IMAGE_NAME=""  # e.g., sdraspi-dev-min-image
MACHINE="${MACHINE:-raspberrypi3}"  # default

# ---------------------------
# Parse arguments
# ---------------------------
while getopts "i:m:" opt; do
    case $opt in
        i) IMAGE_NAME="$OPTARG" ;;
        m) MACHINE="$OPTARG" ;;
        *)
            echo "Usage: $0 -i image_name [-m machine]"
            echo "Example: $0 -i sdraspi-dev-min-image -m raspberrypi4-64"
            exit 1
            ;;
    esac
done

if [[ -z "$IMAGE_NAME" ]]; then
    echo "❌ You must specify the image name with -i"
    exit 1
fi

# ---------------------------
# Relative paths
# ---------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
IMAGES_SRC="${SCRIPT_DIR}/../build/tmp/deploy/images/${MACHINE}/"
IMAGES_DST_ROOT="${SCRIPT_DIR}/../images"

# ---------------------------
# Find the latest .wic.bz2 image
# ---------------------------
LATEST_WIC_BZ2=$(ls -t ${IMAGES_SRC}/${IMAGE_NAME}-${MACHINE}-*.rootfs.wic.bz2 2>/dev/null | head -n1)
if [[ ! -f "$LATEST_WIC_BZ2" ]]; then
    echo "❌ No .wic.bz2 image found in ${IMAGES_SRC} with the name ${IMAGE_NAME}"
    exit 1
fi

# ---------------------------
# Get full timestamp from file name
# ---------------------------
BASENAME=$(basename "$LATEST_WIC_BZ2")
TIMESTAMP=$(echo "$BASENAME" | grep -oE '[0-9]{14}')
if [[ -z "$TIMESTAMP" ]]; then
    echo "❌ Could not extract timestamp from file name."
    exit 1
fi

# ---------------------------
# Create destination folder
# ---------------------------
TARGET_DIR="${IMAGES_DST_ROOT}/${MACHINE}-${TIMESTAMP}"
mkdir -p "$TARGET_DIR"
echo "📁 Preparing new image in: $TARGET_DIR"

# ---------------------------
# Decompress the .wic.bz2 image
# ---------------------------
WIC_DEST="${TARGET_DIR}/${IMAGE_NAME}-${MACHINE}-${TIMESTAMP}.rootfs.wic"
echo "🗜️  Decompressing $LATEST_WIC_BZ2 → $WIC_DEST ..."
bunzip2 -c "$LATEST_WIC_BZ2" > "$WIC_DEST"

# ---------------------------
# Copy corresponding .bmap file
# ---------------------------
BMAP_SRC="${IMAGES_SRC}/${IMAGE_NAME}-${MACHINE}-${TIMESTAMP}.rootfs.wic.bmap"
if [[ ! -f "$BMAP_SRC" ]]; then
    echo "⚠️ Corresponding .bmap file not found. You can flash the image using dd."
else
    cp "$BMAP_SRC" "$TARGET_DIR/"
fi

# ---------------------------
# Display instructions
# ---------------------------
echo ""
echo "✅ Image ready to be flashed."
echo "📍 Location: $TARGET_DIR"
echo ""
if [[ -f "$TARGET_DIR/${IMAGE_NAME}-${MACHINE}-${TIMESTAMP}.rootfs.wic.bmap" ]]; then
    echo "👉 To flash it onto your SD card (e.g., /dev/sdX), run:"
    echo "   sudo bmaptool copy \"$WIC_DEST\" /dev/sdX"
else
    echo "⚠️ No .bmap file found, you can flash using dd:"
    echo "   sudo dd if=\"$WIC_DEST\" of=/dev/sdX bs=4M status=progress conv=fsync"
fi
echo ""
echo "⚠️ Make sure to unmount all SD card partitions before running the command."