# Fedora 42 for Nabu

English | [Simplified-Chinese](./docs/README.zh.md)

A set of scripts and GitHub Actions workflows to build a custom Fedora 42 image for the Xiaomi Pad 5 (nabu) device (aarch64), along with tutorials and resources for installation. The build process produces a bootable root filesystem and an EFI System Partition (ESP) image.

## Features

* **Fedora 42 Base Rootfs:** Rootfs image with basic packages, kernel & firmware.
* **Extended Rootfs:** (#TODO) Includes a standard graphical desktop environment and common utils.
* **systemd-boot:** Uses `systemd-boot` boot manager.
* **Unified Kernel Image (UKI):** Generates a UKI for a secure and streamlined boot process.

## Todos

* **Improve esp generate logic.**
* **Complete the docs.**
* **Write scripts for extended rootfs**
* **Implement post-install scripts**

## Install Tutorial

## How it Works

The build process is divided into two main stages, orchestrated by two separate GitHub Actions workflows:

1.**Build Builder Image:** The `1-build-builder-image.yml` workflow builds a Docker container image that serves as the build environment. This image contains all the necessary tools and dependencies to create the Fedora image. The resulting container is pushed to the GitHub Container Registry.

2.**Build Fedora for Nabu:** The `2-build-fedora-nabu.yml` workflow uses the builder image to perform the main build. This workflow consists of the following steps:
    * **Create Rootfs:** The `2_create_rootfs.sh` script bootstraps a minimal Fedora 42 system, installs a graphical environment, and configures it for the Nabu device. This includes setting up custom services, fstab, and dracut for UKI generation.
    * **Create ESP:** The `3_create_esp.sh` script creates the EFI System Partition (ESP) image, installs `systemd-boot`, and copies the bootloader configuration and UKIs from the rootfs.
    * **Create Release:** A final job creates a new GitHub Release and uploads the generated `fedora-42-nabu-rootfs.img` and `esp.img` files as release assets.