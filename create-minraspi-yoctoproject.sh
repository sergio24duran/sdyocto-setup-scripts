#!/bin/bash
set -eu

# ================================
# CONFIGURATION
# ================================
YOCTO_VERSION="kirkstone"
BUILD_DIR="build"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
USE_GIT_SUBMODULES=false

# ================================
# HELP FUNCTION
# ================================
usage() {
    echo "No path used or invalid parameters"
    echo "Correct usage: $0 -p /absolute/path/to/project [-g]"
    echo "  -g : Use git submodules instead of git clone (assumes PROJECT_PATH is already a git repo)"
    exit 1
}

# ================================
# ARGUMENT PARSING
# ================================
while getopts ":p:g" opt; do
  case "${opt}" in
    p ) PROJECT_PATH="$OPTARG" ;;
    g ) USE_GIT_SUBMODULES=true ;;
    \? ) usage ;;
  esac
done

# Check that -p were provided
if [ -z "${PROJECT_PATH:-}" ]; then
    usage
fi

# Validate that the path is absolute
if [[ "${PROJECT_PATH}" != /* ]]; then
    echo "❌ The path must be absolute"
    exit 1
fi

# ================================
# ABORT IF DIRECTORY EXISTS
# ================================
if [ -d "${PROJECT_PATH}" ]; then
    echo "⛔ Directory already exists: ${PROJECT_PATH}. New project can't be created here"
    exit 1
fi

# ================================
# CREATE TARGET DIRECTORY
# ================================
echo "📂 Creating project directory at: ${PROJECT_PATH}"
mkdir -p "${PROJECT_PATH}"
echo "✅ Project directory created successfully"

# ================================
# ENTER PROJECT DIRECTORY
# ================================
echo "📂 Entering project directory..."
cd "${PROJECT_PATH}" || { echo "❌ Failed to change directory to ${PROJECT_PATH}"; exit 1; }

# ================================
# CLONE OR ADD SUBMODULES
# ================================
PARENT_REPO="$(dirname "$PROJECT_PATH")"

if [ "$USE_GIT_SUBMODULES" = true ]; then
    echo "build/" > .gitignore
    echo "🔗 Adding git submodules POKY & META-RASPBERRYPI in $PROJECT_PATH ..."

    # Check if parent dir is a git repo
    if [ ! -d "$PARENT_REPO/.git" ] && [ ! -f "$PARENT_REPO/.git" ]; then
        echo "❌ Parent directory is not a git repository. Please init or clone it first."
        exit 1
    fi

    git submodule add -b $YOCTO_VERSION git://git.yoctoproject.org/poky.git
    git submodule add -b $YOCTO_VERSION https://git.yoctoproject.org/meta-raspberrypi
else
    echo "📥 Cloning POKY & META-RASPBERRYPI directly into $PROJECT_PATH ..."

    git clone -b $YOCTO_VERSION git://git.yoctoproject.org/poky.git
    git clone -b $YOCTO_VERSION https://git.yoctoproject.org/meta-raspberrypi
fi

# ================================
# COPY ENV & CONF TO PROJECT_PATH (EXPLICIT)
# ================================
echo "📂 Copying env script and conf directory to ${PROJECT_PATH}..."

# Copy raspi-env.sh and scripts directory
RASPISCRIPTS_SRC="${SCRIPT_DIR}/raspi-scripts"
if [[ ! -d "${RASPISCRIPTS_SRC}" ]]; then
  echo "❌ Directory not found: ${RASPISCRIPTS_SRC}" >&2
  exit 1
fi

echo "📂 Copying raspi-env.sh and scripts/ to ${PROJECT_PATH}..."

# Copy the main env file
if [[ ! -f "${RASPISCRIPTS_SRC}/raspi-env.sh" ]]; then
  echo "❌ File not found: ${RASPISCRIPTS_SRC}/raspi-env.sh" >&2
  exit 1
fi
cp "${RASPISCRIPTS_SRC}/raspi-env.sh" "${PROJECT_PATH}/" || { echo "❌ Error copying raspi-env.sh" >&2; exit 1; }

# Copy the scripts folder (recursively)
if [[ -d "${RASPISCRIPTS_SRC}/scripts" ]]; then
  cp -r "${RASPISCRIPTS_SRC}/scripts" "${PROJECT_PATH}/" || { echo "❌ Error copying scripts directory" >&2; exit 1; }
else
  echo "⚠️ Warning: scripts/ folder not found under ${RASPISCRIPTS_SRC}"
fi

# Copy conf directory
CONF_SRC="${SCRIPT_DIR}/raspi-conf/conf"
if [[ ! -d "${CONF_SRC}" ]]; then
  echo "❌ Conf directory not found: ${CONF_SRC}" >&2
  exit 1
fi
cp -r "${CONF_SRC}" "${PROJECT_PATH}/conf" || { echo "❌ Error when trying to copy conf directory" >&2; exit 1; }

echo "✅ Enviroment script and conf directory copied successfully"

# ================================
# FINAL INFO
# ================================
echo "⚙️ Project ready:"
echo ""
echo "cd ${PROJECT_PATH}"
echo "source raspi-env.sh -m <machine>"
echo ""
echo "🎉 Your minimal Yocto project is now ready to use!"
