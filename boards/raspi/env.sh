#!/bin/bash
# env.sh — Yocto build environment setup for Raspberry Pi

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    echo "This script must be sourced: source env.sh [-m MACHINE]"
    exit 1
fi

VALID_MACHINES=("qemux86-64" "raspberrypi3" "raspberrypi3-64" "raspberrypi4" "raspberrypi4-64")
MACHINE="raspberrypi4-64"

OPTIND=1
while getopts "m:" opt; do
    case "$opt" in
        m)
            if [[ ! " ${VALID_MACHINES[*]} " =~ " ${OPTARG} " ]]; then
                echo "Error: invalid MACHINE '${OPTARG}'"
                echo "Valid: ${VALID_MACHINES[*]}"
                return 1
            fi
            MACHINE="$OPTARG"
            ;;
        *)
            echo "Usage: source env.sh [-m MACHINE]"
            echo "Valid: ${VALID_MACHINES[*]}"
            return 1
            ;;
    esac
done
shift $((OPTIND - 1))

export MACHINE
YOCTO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export BUILDDIR="${YOCTO_DIR}/build"

mkdir -p "${BUILDDIR}/conf"

for f in local.conf bblayers.conf; do
    if [[ ! -f "${YOCTO_DIR}/conf/${f}" ]]; then
        echo "Error: ${YOCTO_DIR}/conf/${f} not found"
        return 1
    fi
    ln -snf "${YOCTO_DIR}/conf/${f}" "${BUILDDIR}/conf/${f}"
done

POKY_DIR="${YOCTO_DIR}/poky"
if [[ ! -d "${POKY_DIR}" ]]; then
    echo "Error: poky directory not found in ${YOCTO_DIR}"
    return 1
fi

export PATH="${POKY_DIR}/bitbake/bin:${POKY_DIR}/scripts:$PATH"
export BBPATH="${BUILDDIR}:${POKY_DIR}/meta"
export BB_ENV_PASSTHROUGH_ADDITIONS="MACHINE"

# Remove miniconda from PATH if present (causes conflicts with bitbake)
export PATH="${PATH//'/tools/miniconda/bin:'/}"

if ! command -v bitbake >/dev/null 2>&1; then
    echo "Error: bitbake not found in PATH"
    return 1
fi

echo ""
echo "Environment ready."
echo "  MACHINE:  $MACHINE"
echo "  BUILDDIR: $BUILDDIR"
echo ""
echo "Quick start:"
echo "  bitbake core-image-minimal"
echo ""
