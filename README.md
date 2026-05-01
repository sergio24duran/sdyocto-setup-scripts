# sdyocto-setup-scripts

Bootstrap scripts for creating minimal Yocto projects for different boards.
Clone this repo, run `setup.sh` for your board, and get a ready-to-build Yocto
project with the correct layers, configuration, and helper scripts.

## Supported boards

| Board | ID | Yocto branch | Meta-layer |
|-------|----|-------------|------------|
| Raspberry Pi 3/4 | `raspi` | kirkstone | [meta-raspberrypi](https://git.yoctoproject.org/meta-raspberrypi) |
| Radxa Dragon Q6A | `radxa-dragon-q6a` | scarthgap | [meta-sdradxa](https://github.com/sergio24duran/meta-sdradxa) |

## Quick start

### 1. Clone this repository

```bash
git clone https://github.com/sergio24duran/sdyocto-setup-scripts.git
cd sdyocto-setup-scripts
```

### 2. List available boards

```bash
./setup.sh -l
```

### 3. Create a Yocto project

```bash
./setup.sh -b <board> -p /absolute/path/to/new-project
```

The script creates the project directory, clones all required Yocto layers
(Poky, BSP layers, meta-layers), and copies the board-specific configuration
files and helper scripts.

**Examples:**

```bash
# Raspberry Pi
./setup.sh -b raspi -p /home/user/yocto-raspi

# Radxa Dragon Q6A
./setup.sh -b radxa-dragon-q6a -p /home/user/yocto-radxa
```

**Using git submodules** (useful if the project directory is itself a git repo):

```bash
./setup.sh -b radxa-dragon-q6a -p /home/user/yocto-radxa -g
```

### 4. Build

```bash
cd /home/user/yocto-radxa
source env.sh -m <machine>
bitbake <image>
```

Each board has a default machine and image. After running `setup.sh`, the output
tells you the exact commands.

| Board | Source command | Build command |
|-------|--------------|---------------|
| Raspberry Pi 4 (64-bit) | `source env.sh -m raspberrypi4-64` | `bitbake core-image-minimal` |
| Radxa Dragon Q6A | `source env.sh -m sdradxa-dragon-q6a` | `bitbake sdradxa-image-minimal` |

### 5. Flash to SD card

After the build completes, use the included flash script:

```bash
# Flash directly from the build output (handles .wic.gz and .wic.bz2)
sudo ./scripts/flash-sd.sh \
  -i build/tmp/deploy/images/<machine>/<image>.rootfs.wic.gz \
  -d /dev/sdX
```

Or use the prepare + flash workflow:

```bash
# Decompress the latest image into images/
./scripts/prepare-image.sh -i <image-name> -m <machine>

# Flash the decompressed image
sudo ./scripts/flash-sd.sh -i images/<machine>-<timestamp>/<image>.rootfs.wic -d /dev/sdX
```

> **Important:** Always verify your SD card device with `lsblk` before
> flashing. The script refuses to write to `/dev/sda`, `/dev/nvme0n1`, and
> `/dev/vda` as a safety check, but always double-check.

## Generated project structure

After running `setup.sh`, the generated project looks like this:

```
my-yocto-project/
    poky/                    # Yocto build system
    meta-<bsp>/              # BSP layer(s) for the board
    conf/
        local.conf           # Build configuration
        bblayers.conf        # Layer stack
    scripts/
        flash-sd.sh          # Flash helper
        prepare-image.sh     # Image preparation helper
    env.sh                   # Source this to set up the build environment
```

## Repository structure

```
sdyocto-setup-scripts/
    setup.sh                 # Main entry point
    boards/
        raspi/
            board.conf       # Board metadata (repos, branch, machines)
            conf/            # Yocto configuration files
            env.sh           # Environment setup script (copied to project)
        radxa-dragon-q6a/
            board.conf
            conf/
            env.sh
    scripts/
        flash-sd.sh          # Shared flash script (copied to project)
        prepare-image.sh     # Shared image prep script (copied to project)
```

## Adding a new board

1. Create a directory under `boards/` with your board ID:

```bash
mkdir -p boards/my-board/conf
```

2. Create `boards/my-board/board.conf`:

```bash
BOARD_NAME="My Custom Board"
YOCTO_VERSION="scarthgap"

VALID_MACHINES=("my-board-machine")
DEFAULT_MACHINE="my-board-machine"
DEFAULT_IMAGE="core-image-minimal"

REPOS=(
    "poky git://git.yoctoproject.org/poky.git ${YOCTO_VERSION}"
    "meta-my-bsp https://github.com/example/meta-my-bsp.git ${YOCTO_VERSION}"
)

WIC_COMPRESSION="gz"
```

3. Create `boards/my-board/conf/local.conf` and `bblayers.conf` with the
   appropriate settings for your board.

4. Create `boards/my-board/env.sh` with the valid machines list and default
   machine. Use an existing board's `env.sh` as a template.

5. Run `./setup.sh -l` to verify your board appears, then test with
   `./setup.sh -b my-board -p /tmp/test-project`.

## Board-specific notes

### Raspberry Pi

- **Yocto branch:** kirkstone
- **Machines:** `raspberrypi3`, `raspberrypi3-64`, `raspberrypi4`, `raspberrypi4-64`, `qemux86-64`
- **Kernel:** linux-raspberrypi (from meta-raspberrypi)
- **Image format:** `.wic.bz2`
- UART is enabled by default (`ENABLE_UART = "1"`)
- U-Boot is used as the bootloader (`RPI_USE_U_BOOT = "1"`)
- Recommended meta-layer to add as submodule: [meta-sdraspi](https://github.com/sergio24duran/meta-sdraspi)

### Radxa Dragon Q6A

- **Yocto branch:** scarthgap
- **SoC:** QCS6490 (Snapdragon 7c+ Gen 3)
- **Machine:** `sdradxa-dragon-q6a`
- **Kernel:** linux-linaro-qcomlt 6.6 (Qualcomm Landing Team)
- **Image format:** `.wic.gz`
- **Meta-layer:** [meta-sdradxa](https://github.com/sergio24duran/meta-sdradxa) — provides machine config, kernel config fragment, image recipe, and wic layout
- UEFI boots the kernel directly from SD card (no intermediate bootloader)
- Device tree is provided by UEFI firmware (not compiled into the kernel)
- Serial console on `ttyMSM0` at 115200 baud
- See [meta-sdradxa README](https://github.com/sergio24duran/meta-sdradxa) for full build, flash, and troubleshooting documentation

## Prerequisites

- Linux host (Ubuntu, Debian, Fedora, or similar)
- `git`, `bash`
- Yocto host dependencies ([Yocto Project Quick Build guide](https://docs.yoctoproject.org/brief-yoctoprojectqs/index.html)):

```bash
# Ubuntu / Debian
sudo apt install gawk wget git diffstat unzip texinfo gcc build-essential \
  chrpath socat cpio python3 python3-pip python3-pexpect xz-utils \
  debianutils iputils-ping python3-git python3-jinja2 python3-subunit \
  zstd liblz4-tool file locales libacl1
sudo locale-gen en_US.UTF-8
```

- For flashing: `bmaptool` (recommended) or `dd`

```bash
sudo apt install bmap-tools
```

## License

MIT. See [LICENSE](LICENSE).

## Author

Sergio Duran Martin
