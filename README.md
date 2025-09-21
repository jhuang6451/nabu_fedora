# Fedora 42 for Nabu

English | [Simplified-Chinese(WIP)](./docs/README.zh.md)

A set of scripts and GitHub Actions workflows to build a custom Fedora 42 image for the Xiaomi Pad 5 (nabu) device (aarch64), along with tutorials and resources for installation. The build process produces a bootable root filesystem and an EFI System Partition (ESP) image.

## Disclaimer

This project is still in early stages. Use it at your own risk.

## Features

* **Fedora 42 Base Rootfs:** Rootfs image with basic packages, kernel & firmware.
* **Unified Kernel Image (UKI):** Generates a UKI for a secure and streamlined boot process.
* **systemd-boot:** Uses `systemd-boot` as default boot manager.

## Todos

* [x] Fix UKI boot.
* [ ] Some package update test.
* [ ] Improve esp generate logic.
* [ ] Complete the docs.
* [ ] Write scripts for extended rootfs (Includes a standard graphical desktop environment and common utils).
* [ ] Implement post-install scripts.

## Installation Tutorial

* **WIP**

## Chats & Support Groups

* [nabulinux](https://t.me/nabulinux) - Telegram group for Xiaomi Pad 5 linux.

## See Also

* [pocketblue](https://github.com/pocketblue/pocketblue) - Fedora Silverblue for nabu.
* [nabu-fedora-builder](https://github.com/nik012003/nabu-fedora-builder) - Another minimum Fedora for nabu.
* [nabu-alarm](https://github.com/nabu-alarm/) - Archlinux Arm for nabu.
