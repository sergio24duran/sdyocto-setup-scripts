# sdyocto-setup-scripts

Minimal Yocto Linux image bootstrap and SD flashing helper for Raspberry Pi (Kirkstone).

This repository provides a minimal workflow to:
- bootstrap a Yocto project with Poky and meta-raspberrypi,
- provide a reusable environment script for building,
- prepare built .wic images for flashing,
- flash images to SD cards using bmaptool (or dd fallback).

Quick links to key files:
- Main project bootstrap script: [`create-minraspi-yoctoproject.sh`](create-minraspi-yoctoproject.sh)  
- Yocto environment helper: [`raspi-scripts/raspi-env.sh`](raspi-scripts/raspi-env.sh)  
- Prepare image script: [`raspi-scripts/scripts/prepare-image.sh`](raspi-scripts/scripts/prepare-image.sh)  
- Flash SD script: [`raspi-scripts/scripts/flash-sd.sh`](raspi-scripts/scripts/flash-sd.sh)  
- Preconfigured Yocto confs: [`raspi-conf/conf/local.conf`](raspi-conf/conf/local.conf), [`raspi-conf/conf/bblayers.conf`](raspi-conf/conf/bblayers.conf)  
- CI mirror job: [`.gitlab-ci.yml`](.gitlab-ci.yml)
- Recommended meta-layer to add:
    - Github: [meta-sdraspi](https://github.com/sergio24duran/meta-sdraspi)
    - Gitlab: [meta-sdraspi](https://gitlab.com/sdyocto/meta-sdraspi.git)

Requirements
- Linux host (Ubuntu/Debian/Fedora tested)
- git, bash, bunzip2
- bmaptool (recommended) or dd
- Yocto build prerequisites (see Yocto Project Quick Start)

Repository layout
- raspi-scripts/
  - raspi-env.sh — environment helper to source before building ([open file](raspi-scripts/raspi-env.sh))
  - scripts/
    - prepare-image.sh — find latest .wic.bz2, decompress to images/<timestamp> ([open file](raspi-scripts/scripts/prepare-image.sh))
    - flash-sd.sh — flash decompressed .wic to an SD device ([open file](raspi-scripts/scripts/flash-sd.sh))
- raspi-conf/conf/
  - local.conf — base local.conf tailored for Raspberry Pi and qemu ([open file](raspi-conf/conf/local.conf))
  - bblayers.conf — minimal bblayers list pointing to poky & meta-raspberrypi ([open file](raspi-conf/conf/bblayers.conf))
- create-minraspi-yoctoproject.sh — bootstrap script to create a new project and copy env/conf & scripts files ([open file](create-minraspi-yoctoproject.sh))
- .gitlab-ci.yml — CI job to mirror develop branch to GitHub ([open file](.gitlab-ci.yml)). Only used to maintain gihub repo mirror from gitlab original repo.

Usage

1) Create a new Yocto project
- Preferred usage (absolute path required), sudo or normal user depending on your environment:
    ```bash
    ./create-minraspi-yoctoproject.sh -p /absolute/path/to/yocto-project
    ```
- Optional: add -g to use git submodules instead of cloning:
    ```bash
    ./create-minraspi-yoctoproject.sh -p /absolute/path/to/yocto-project -g
    ```

What the script does:
- creates the project dir
- clones (or adds submodules) Poky and meta-raspberrypi (Kirkstone branch)
- copies `raspi-env.sh` and `scripts/`
- copies `conf/` (local.conf & bblayers.conf)

2) Configure the build environment
    ```bash
    cd /absolute/path/to/yocto-project
    source raspi-env.sh -m <machine>
    ```
    Default machine is `qemux86-64`, example:
    ```bash
    source raspi-env.sh -m raspberrypi3
    ```

Notes:
- The environment script is designed to be sourced (using `source`or `.`): see [`raspi-scripts/raspi-env.sh`](raspi-scripts/raspi-env.sh)
- Valid MACHINE values: `raspberrypi3`, `qemux86-64`
- The script links your project conf files into the build directory and sets PATH/BBPATH for BitBake

3) Build an image
- Example:
    ```bash
    bitbake core-image-minimal
    ```
    or
    ```bash
    bitbake sdraspi-min-image
    ```

- Useful BitBake commands are printed by `raspi-env.sh` and include build/clean/sdk commands.

4) Prepare the latest image for flashing
- From your project (after build), run:
    ```bash
    ./scripts/prepare-image.sh -i <image-name>
    ```
- Example:
    ```bash
    ./scripts/prepare-image.sh -i core-image-minimal
    ```

What it does:
- looks for the latest file matching `${IMAGE_NAME}-raspberrypi3-*.rootfs.wic.bz2` in the build deploy folder
- extracts the timestamp from the filename and creates .../yocto-project/images/timestamp
- decompresses the .wic.bz2 to the new folder
- copies the .bmap if available and prints flashing instructions  
(see [`raspi-scripts/scripts/prepare-image.sh`](raspi-scripts/scripts/prepare-image.sh))

5) Flash the SD card
- Example:
    ```bash
    sudo ./scripts/flash-sd.sh -t .../path/to/images/timestamp -d /dev/sdX
    ```

What it does:
- unmounts any mounted partitions on device
- uses `bmaptool copy <image.wic> /dev/sdX` (recommended)
- falls back to `dd` if no .bmap is available (prepare-image prints both options)  
(see [`raspi-scripts/scripts/flash-sd.sh`](raspi-scripts/scripts/flash-sd.sh))

Safety & tips
- Always unmount partitions on the SD device before flashing and make a back-up of the data if you don't want to lose it (remember to umount them after back-up).
- Double-check the device path (e.g., /dev/sdX) to avoid overwriting your host disk.
- Keep DL_DIR and SSTATE_DIR persistent across builds to speed up subsequent builds (configured in `local.conf` if you choose).

Customization
- Adjust `raspi-conf/conf/local.conf` and `bblayers.conf` to add layers, change MACHINE defaults, or tweak output directories. ([open local.conf](raspi-conf/conf/local.conf)) ([open bblayers.conf](raspi-conf/conf/bblayers.conf))

License
- MIT (as stated in repository)

Ower/Maintainer
- Sergio Durán Martín — GitHub
