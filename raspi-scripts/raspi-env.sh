#!/bin/bash
# raspi-env.sh — independent Yocto environment setup

# Ensure this raspi-env.sh has been sourcered
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    echo "Please, execute with: source raspi-env.sh"
    exit 1
fi

# Valid MACHINEs
VALID_MACHINES=("qemux86-64" "raspberrypi3")
MACHINE="qemux86-64"  # default

# Reset OPTIND and parse options on source
OPTIND=1
while getopts "m:" opt; do
    case "$opt" in
        m)
            if [[ ! " ${VALID_MACHINES[*]} " =~ " ${OPTARG} " ]]; then
                echo "Error: MACHINE '${OPTARG}' not valid."
                echo "Valid MACHINEs: ${VALID_MACHINES[*]}"
                return 1
            fi
            MACHINE="$OPTARG"
            ;;
        *)
            echo "Usage: source raspi-env.sh [-m MACHINE]"
            echo "Valid MACHINEs: ${VALID_MACHINES[*]}"
            return 1
            ;;
    esac
done
shift $((OPTIND - 1))

export MACHINE

# Absolute path to the root of this Yocto project
YOCTO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Directory for the build output
export BUILDDIR="${YOCTO_DIR}/build"

# Ensure build/conf exists
mkdir -p "${BUILDDIR}/conf"

# Always create/overwrite symlinks for configuration
if [[ ! -f "${YOCTO_DIR}/conf/local.conf" ]]; then
    echo "Error: ${YOCTO_DIR}/conf/local.conf not found"
    return 1
fi
if [[ ! -f "${YOCTO_DIR}/conf/bblayers.conf" ]]; then
    echo "Error: ${YOCTO_DIR}/conf/bblayers.conf not found"
    return 1
fi

echo "Linking ${YOCTO_DIR}/conf/local.conf and bblayers.conf to ${BUILDDIR}/conf/..."
ln -snf "${YOCTO_DIR}/conf/local.conf" "${BUILDDIR}/conf/local.conf"
ln -snf "${YOCTO_DIR}/conf/bblayers.conf" "${BUILDDIR}/conf/bblayers.conf"

# Add BitBake and Poky helper scripts to PATH
POKY_DIR="${YOCTO_DIR}/poky"
if [[ ! -d "${POKY_DIR}" ]]; then
    echo "Error: poky directory not found in ${YOCTO_DIR}"
    return 1
fi
export PATH="${POKY_DIR}/bitbake/bin:${POKY_DIR}/scripts:$PATH"

# BBPATH must include the build directory and at least one layer with conf/bitbake.conf
export BBPATH="${BUILDDIR}:${POKY_DIR}/meta"

# Basic sanity check: ensure bitbake exists
if ! command -v bitbake >/dev/null 2>&1 || [[ ! -x "$(command -v bitbake)" ]]; then
    echo "Error: bitbake not in PATH or not executable"
    return 1
fi

# Ensure BitBake uses these variables
export BB_ENV_PASSTHROUGH_ADDITIONS="MACHINE"
# export BB_ENV_PASSTHROUGH_ADDITIONS="${BB_ENV_PASSTHROUGH_ADDITIONS} MORE_VARS"

# ================================
# FINAL INFO
# ================================
echo "Yocto environment configured."
echo "BUILDDIR: $BUILDDIR"
echo "BBPATH:   $BBPATH"
echo "MACHINE:  $MACHINE"

# ================================
# USEFUL BITBAKE COMMANDS
# ================================
echo "🧰 Basic bitbake commands (alredy cd in PROJECT_PATH):"

echo "   # Show bitbake help"
echo "   bitbake --help"
echo ""

echo "   # Add a new layer (e.g., meta-mylayer)"
echo "   bitbake-layers add-layer meta-mylayer"
echo ""

echo "   # List all configured layers"
echo "   bitbake-layers show-layers"
echo ""

echo "   # Display available recipes"
echo "   bitbake-layers show-recipes"
echo ""

echo "   # Show recipes from meta-mylayer"
echo "   bitbake-layers show-recipes | grep meta-mylayer"
echo ""

echo "   # Build only one recipe"
echo "   bitbake <recipe>"
echo ""

echo "   # Clean a recipe's work directory"
echo "   bitbake -c clean <recipe>"
echo ""

echo "   # Remove shared-state for a recipe to force full rebuild"
echo "   bitbake -c cleansstate <recipe>"
echo ""

echo "   # Clean everything for a recipe (workdir + sstate + downloads)"
echo "   bitbake -c cleanall <recipe>"
echo ""

echo "   # Generate an SDK installer for target development"
echo "   bitbake <image> -c populate_sdk"
echo ""

echo "   # Generate generic host toolchain (legacy)"
echo "   bitbake meta-toolchain"
