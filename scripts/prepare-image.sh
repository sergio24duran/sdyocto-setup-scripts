#!/bin/bash
set -euo pipefail

# Find the latest built wic image, decompress it, and prepare it for flashing.
# Supports .wic.gz and .wic.bz2 compressed images.

usage() {
    echo "Usage: $0 -i <image-name> [-m <machine>]"
    echo ""
    echo "  -i   Image recipe name (e.g. core-image-minimal, sdradxa-image-minimal)"
    echo "  -m   MACHINE name (default: \$MACHINE from environment)"
    echo ""
    echo "Example:"
    echo "  $0 -i sdradxa-image-minimal -m sdradxa-dragon-q6a"
    exit 1
}

IMAGE_NAME=""
MACHINE="${MACHINE:-}"

while getopts "i:m:h" opt; do
    case $opt in
        i) IMAGE_NAME="$OPTARG" ;;
        m) MACHINE="$OPTARG" ;;
        h) usage ;;
        *) usage ;;
    esac
done

if [[ -z "$IMAGE_NAME" ]]; then
    echo "Error: image name is required (-i)"
    usage
fi

if [[ -z "$MACHINE" ]]; then
    echo "Error: MACHINE not set. Use -m or source env.sh first."
    exit 1
fi

# Locate the deploy directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEPLOY_DIR="${SCRIPT_DIR}/../build/tmp/deploy/images/${MACHINE}"
IMAGES_DIR="${SCRIPT_DIR}/../images"

if [[ ! -d "$DEPLOY_DIR" ]]; then
    echo "Error: deploy directory not found: ${DEPLOY_DIR}"
    exit 1
fi

# Find the latest compressed wic image (.wic.gz or .wic.bz2)
LATEST=""
for ext in wic.gz wic.bz2; do
    candidate=$(ls -t "${DEPLOY_DIR}/${IMAGE_NAME}-${MACHINE}"*.rootfs.${ext} 2>/dev/null | head -n1 || true)
    if [[ -n "$candidate" ]]; then
        LATEST="$candidate"
        break
    fi
done

if [[ -z "$LATEST" ]]; then
    echo "Error: no .wic.gz or .wic.bz2 image found for '${IMAGE_NAME}' in ${DEPLOY_DIR}"
    exit 1
fi

# Extract timestamp from filename (if present) or use current date
BASENAME=$(basename "$LATEST")
TIMESTAMP=$(echo "$BASENAME" | grep -oE '[0-9]{14}' | head -n1 || true)
if [[ -z "$TIMESTAMP" ]]; then
    TIMESTAMP=$(date +%Y%m%d%H%M%S)
fi

# Create output directory
TARGET_DIR="${IMAGES_DIR}/${MACHINE}-${TIMESTAMP}"
mkdir -p "$TARGET_DIR"
echo "Preparing image in: ${TARGET_DIR}"

# Decompress
WIC_NAME="${IMAGE_NAME}-${MACHINE}.rootfs.wic"
WIC_DEST="${TARGET_DIR}/${WIC_NAME}"

case "$LATEST" in
    *.wic.gz)
        echo "Decompressing (gzip): $(basename "$LATEST")..."
        gunzip -c "$LATEST" > "$WIC_DEST"
        ;;
    *.wic.bz2)
        echo "Decompressing (bzip2): $(basename "$LATEST")..."
        bunzip2 -c "$LATEST" > "$WIC_DEST"
        ;;
esac

# Copy bmap file if available
BMAP_SRC=$(ls "${DEPLOY_DIR}/${IMAGE_NAME}-${MACHINE}"*.rootfs.wic.bmap 2>/dev/null | head -n1 || true)
if [[ -n "$BMAP_SRC" ]]; then
    cp "$BMAP_SRC" "${TARGET_DIR}/"
    echo "Copied bmap file."
fi

echo ""
echo "Image ready: ${WIC_DEST}"
echo ""
echo "Flash with:"
echo "  sudo ./scripts/flash-sd.sh -i \"${WIC_DEST}\" -d /dev/sdX"
echo ""
