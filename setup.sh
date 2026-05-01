#!/bin/bash
set -eu

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BOARDS_DIR="${SCRIPT_DIR}/boards"
USE_GIT_SUBMODULES=false

# ================================
# HELP
# ================================
usage() {
    echo "Usage: $0 -b <board> -p /absolute/path/to/project [-g]"
    echo ""
    echo "Options:"
    echo "  -b <board>   Board to set up (required)"
    echo "  -p <path>    Absolute path for the new Yocto project (required)"
    echo "  -g           Use git submodules instead of git clone"
    echo "  -l           List available boards"
    echo "  -h           Show this help"
    exit 1
}

list_boards() {
    echo "Available boards:"
    echo ""
    for board_dir in "${BOARDS_DIR}"/*/; do
        board="$(basename "$board_dir")"
        if [[ -f "${board_dir}/board.conf" ]]; then
            # shellcheck source=/dev/null
            (source "${board_dir}/board.conf" && echo "  ${board}  —  ${BOARD_NAME} (Yocto ${YOCTO_VERSION})")
        fi
    done
    echo ""
    echo "Usage: $0 -b <board> -p /absolute/path/to/project"
    exit 0
}

# ================================
# PARSE ARGUMENTS
# ================================
BOARD=""
PROJECT_PATH=""

while getopts ":b:p:glh" opt; do
    case "${opt}" in
        b) BOARD="$OPTARG" ;;
        p) PROJECT_PATH="$OPTARG" ;;
        g) USE_GIT_SUBMODULES=true ;;
        l) list_boards ;;
        h) usage ;;
        \?) echo "Unknown option: -${OPTARG}"; usage ;;
        :)  echo "Option -${OPTARG} requires an argument"; usage ;;
    esac
done

if [[ -z "${BOARD}" || -z "${PROJECT_PATH}" ]]; then
    usage
fi

# ================================
# VALIDATE BOARD
# ================================
BOARD_DIR="${BOARDS_DIR}/${BOARD}"

if [[ ! -d "${BOARD_DIR}" || ! -f "${BOARD_DIR}/board.conf" ]]; then
    echo "Error: board '${BOARD}' not found in ${BOARDS_DIR}"
    echo ""
    list_boards
fi

# ================================
# LOAD BOARD CONFIGURATION
# ================================
# shellcheck source=/dev/null
source "${BOARD_DIR}/board.conf"

echo ""
echo "Board:   ${BOARD_NAME}"
echo "Yocto:   ${YOCTO_VERSION}"
echo "Target:  ${PROJECT_PATH}"
echo ""

# ================================
# VALIDATE PATH
# ================================
if [[ "${PROJECT_PATH}" != /* ]]; then
    echo "Error: path must be absolute"
    exit 1
fi

if [[ -d "${PROJECT_PATH}" ]]; then
    echo "Error: directory already exists: ${PROJECT_PATH}"
    exit 1
fi

# ================================
# CREATE PROJECT DIRECTORY
# ================================
echo "Creating project directory..."
mkdir -p "${PROJECT_PATH}"
cd "${PROJECT_PATH}" || { echo "Error: failed to cd into ${PROJECT_PATH}"; exit 1; }

# Clean up on failure so the user can retry without manually removing the directory
cleanup() {
    echo ""
    echo "Error: setup failed. Cleaning up ${PROJECT_PATH}..."
    rm -rf "${PROJECT_PATH}"
    exit 1
}
trap cleanup ERR

# ================================
# CLONE OR ADD SUBMODULES
# ================================
# Copy .gitignore for the generated project
cp "${SCRIPT_DIR}/project.gitignore" "${PROJECT_PATH}/.gitignore"

if [[ "${USE_GIT_SUBMODULES}" == true ]]; then
    echo "Adding git submodules..."

    for repo_entry in "${REPOS[@]}"; do
        read -r name url branch <<< "${repo_entry}"
        echo "  submodule: ${name} (${branch})"
        git submodule add -b "${branch}" "${url}" "${name}"
    done
else
    echo "Cloning repositories..."

    for repo_entry in "${REPOS[@]}"; do
        read -r name url branch <<< "${repo_entry}"
        echo "  clone: ${name} (${branch})"
        git clone -b "${branch}" "${url}" "${name}"
    done
fi

# ================================
# COPY CONFIGURATION FILES
# ================================
echo "Copying board configuration..."

# conf/
if [[ ! -d "${BOARD_DIR}/conf" ]]; then
    echo "Error: ${BOARD_DIR}/conf not found"
    exit 1
fi
cp -r "${BOARD_DIR}/conf" "${PROJECT_PATH}/conf"

# env.sh
if [[ ! -f "${BOARD_DIR}/env.sh" ]]; then
    echo "Error: ${BOARD_DIR}/env.sh not found"
    exit 1
fi
cp "${BOARD_DIR}/env.sh" "${PROJECT_PATH}/env.sh"

# ================================
# COPY SHARED SCRIPTS
# ================================
SHARED_SCRIPTS="${SCRIPT_DIR}/scripts"
if [[ -d "${SHARED_SCRIPTS}" ]]; then
    echo "Copying helper scripts..."
    cp -r "${SHARED_SCRIPTS}" "${PROJECT_PATH}/scripts"
fi

# ================================
# DONE
# ================================
echo ""
echo "Project ready at: ${PROJECT_PATH}"
echo ""
echo "Next steps:"
echo "  cd ${PROJECT_PATH}"
echo "  source env.sh -m ${DEFAULT_MACHINE}"
echo "  bitbake ${DEFAULT_IMAGE}"
echo ""
