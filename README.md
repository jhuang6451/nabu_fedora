> [!IMPORTANT]
> **This project is still in early stages. Please stay tuned for formal release!!!**

# Fedora 42 for Nabu

English | [Simplified-Chinese(WIP)](./docs/README.zh.md)

A set of scripts and GitHub Actions workflows to build a custom Fedora 42 image for the Xiaomi Pad 5 (nabu) device (aarch64), along with tutorials and resources for installation. The build process produces a bootable root filesystem and an EFI System Partition (ESP) image.

> [!NOTE]
> Initial username is `user` and the password is `fedora`.

> [!NOTE]
> The system is designed to work with [UEFI](https://github.com/Project-Aloha/mu_aloha_platforms), [DBKP](https://github.com/rodriguezst/nabu-dualboot-img) is also supported.As of [U-Boot](https://gitlab.com/sm8150-mainline/u-boot), I've yet to test it out.


## Disclaimer

```markdown
This project is an unofficial port of Fedora Linux to the Xiaomi Pad 5 (nabu) device. It is provided "as is" without any warranties of any kind, either express or implied, including, but not limited to, the implied warranties of merchantability, fitness for a particular purpose, or non-infringement.

By using, flashing, or interacting with any files, images, or instructions provided by this project, you acknowledge and agree to the following:

1.  **Use at Your Own Risk:** You are solely responsible for any damage to your device, loss of data, or any other issues that may arise from using this software. The developers and contributors of this project shall not be held liable for any such damages or losses.
2.  **No Official Support:** This project is not officially endorsed, supported, or affiliated with Fedora Project, Red Hat, Xiaomi, or any other hardware or software vendor.
3.  **Experimental Nature:** This is an ongoing development effort, and the software may contain bugs, instabilities, or incomplete features. Functionality may not be fully optimized or reliable.
4.  **Data Loss Warning:** Flashing custom operating systems inherently carries a risk of data loss. It is **strongly recommended** that you back up all important data from your device before attempting any installation.
5.  **Warranty Void:** Installing unofficial software may void your device's manufacturer warranty.
6.  **No Guarantee of Updates:** While efforts will be made to maintain and update the project, there is no guarantee of continuous support, bug fixes, or future releases.

**Proceed with caution and at your own discretion. If you are not comfortable with these terms, please do not use this project.**
```

## Features

* **Fedora 42 Base Rootfs:** Rootfs image with basic packages, kernel & firmware.
* **Unified Kernel Image (UKI):** Generates a UKI for a secure and streamlined boot process.
* **systemd-boot:** Uses `systemd-boot` as default boot manager.

## Todos

* [x] Fix UKI generation.
* [x] Fix efi installation.
* [ ] Optimize package selection.
* [ ] Complete installation tutorial docs.
* [ ] (Maybe) write install script.
* [ ] Write scripts for extended rootfs (Includes a standard graphical desktop environment and common utils).
* [ ] Implement post-install scripts.
* [ ] Kernel update test.

## Installation Tutorial

* **WIP**

## Chats & Support Groups

* [nabulinux](https://t.me/nabulinux) - Telegram group for Xiaomi Pad 5 linux.

## Credits

* [@ArKT-7](https://github.com/ArKT-7) for modded linux TWRP for nabu.
* [@rodriguezst](https://github.com/rodriguezst) for UEFI kernel pacher.
* [Project-Aloha](https://github.com/Project-Aloha) for UEFI development.
* [@gmankab](https://github.com/gmankab), [@Timofey](https://github.com/timoxa0), [@nik012003](https://github.com/nik012003) and all the other developers for building linux distros for nabu.
* Everyone who contributed to sm8150-mainline.
* Everyone trying this project out or giving me advice.

## See Also

* [pocketblue](https://github.com/pocketblue/pocketblue) - Fedora Silverblue for nabu.
* [nabu-fedora-builder](https://github.com/nik012003/nabu-fedora-builder) - Another minimum Fedora for nabu.
* [nabu-alarm](https://github.com/nabu-alarm/) - Archlinux Arm for nabu.
