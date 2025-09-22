# Fedora 42 for Nabu

English | [Simplified-Chinese(WIP)](./docs/README.zh.md)

A set of scripts and GitHub Actions workflows to build a custom Fedora 42 image for the Xiaomi Pad 5 (nabu) device (aarch64), along with tutorials and resources for installation. The build process produces a bootable root filesystem and an EFI System Partition (ESP) image.

> [!IMPORTANT]
> **This project is still in early stages.**

> [!NOTE]
> Initial username is `user` and the password is `fedora`.

> [!NOTE]
> The system is designed to work with [UEFI](https://github.com/Project-Aloha/mu_aloha_platforms), [DBKP](https://github.com/rodriguezst/nabu-dualboot-img) is also supported.As of [U-Boot](https://gitlab.com/sm8150-mainline/u-boot), I've yet to test it out.
> The system is designed to work with [UEFI](https://github.com/Project-Aloha/mu_aloha_platforms), [DBKP](https://github.com/rodriguezst/nabu-dualboot-img) is also supported.As of [U-Boot](https://gitlab.com/sm8150-mainline/u-boot), I've yet to test it out.


## Disclaimer

```
This project is an unofficial port of Fedora Linux to the Xiaomi Pad 5 (nabu) device. It is provided "as is" without any warranties of any kind, either express or implied, including, but not limited to, the implied warranties of merchantability, fitness for a particular purpose, or non-infringement.

By using, flashing, or interacting with any files, images, or instructions provided by this project, you acknowledge and agree to the following:

1.  Use at Your Own Risk: You are solely responsible for any damage to your device, loss of data, or any other issues that may arise from using this software. The developers and contributors of this project shall not be held liable for any such damages or losses.
2.  No Official Support: This project is not officially endorsed, supported, or affiliated with Fedora Project, Red Hat, Xiaomi, or any other hardware or software vendor.
3.  Experimental Nature: This is an ongoing development effort, and the software may contain bugs, instabilities, or incomplete features. Functionality may not be fully optimized or reliable.
4.  Data Loss Warning: Flashing custom operating systems inherently carries a risk of data loss. It is **strongly recommended** that you back up all important data from your device before attempting any installation.
5.  No Guarantee of Updates: While efforts will be made to maintain and update the project, there is no guarantee of continuous support, bug fixes, or future releases.

Proceed with caution and at your own discretion. If you are not comfortable with these terms, please do not use this project.
```

## Features

* **Fedora 42 Base Rootfs:** Rootfs image with basic packages, kernel & firmware.
* **Unified Kernel Image (UKI):** Generates a UKI for a secure and streamlined boot process.
* **systemd-boot:** Uses `systemd-boot` as default boot manager.

## Todos

* [x] Fix UKI generation.
* [x] Fix efi installation.
* [x] Complete installation tutorial docs.
* [ ] Builds with other DEs.
* [ ] (Maybe) Write install script.
* [ ] Implement post-install scripts.
* [ ] Kernel update test.

## Installation Tutorial

Requirements:

* A PC.
* Internet connection.
* Your **UNLOCKED** Xiaomi Pad 5 tablet.
* USB Cable.

Steps:

1. Preparation:
    * Make sure `android-tools` is installed on your PC, or download `platform-tools` from [Official Website](https://developer.android.com/tools/releases/platform-tools), then decompress and cd into it.
    * Download and decompress both `efi-files.zip` and `fedora-42-nabu-rootfs.img.xz` from release.
    * Download ArKT-7's modded TWRP (linux) for nabu from [here](https://github.com/ArKT-7/twrp_device_xiaomi_nabu/releases/tag/mod_linux).
    * Download dualboot kernel pacher from [here](https://github.com/rodriguezst/nabu-dualboot-img/releases) (If you don't know what secureboot is, just download the NOSB version).

2. Partitioning:
    * Connect your tablet to your PC.
    * Reboot your tablet into bootloader (press the power bottom and the volume down bottom together, until you see `fastboot` on screen).
    * Boot into ArKT-7's modded TWRP.

        ```Shell
        fastboot boot path/to/downloaded/twrp/image
        ```

    * Wait until your tablet boots into TWRP, then tap on the linux logo on the top right side of the screen.
    * Tap on `Partitioning` -> Enter the linux partition size -> Tap on `yes` -> Wait for partitioning to be done.

3. Transferring efi file to your tablet's esp partition:
    * Make sure your tablet is still in TWRP, and your tablet is still connected to PC.
    * On your PC, run:

        ```Shell
        adb shell 'umount /esp'
        adb shell 'mount /dev/block/sda31 /esp'
        adb push path/to/unzipped/efi-file/* /esp/
        adb shell 'umount /esp'
        ```

4. Install DBKP via adb sideload:
    * On your tablet, go back to the home screem of TWRP.
    * Tap on `Advanced` -> Tap on `ADB Sideload` -> Swipe the bar on the screen.
    * On your PC, run:

        ```Shell
        adb sideload path/to/installer_bootmanager.zip
        ```

5. Install the rootfs:
    * Reboot your tablet into bootloader again.
    * On your PC, run:

        ```Shell
        fastboot flash linux path/to/fedora-42-nabu-rootfs.img
        ```

    * Wait for the process to complete, then reboot your tablet, you should see the UEFI interface.
    * You can choose between boot options with volume bottom, and confirm with power bottom.

> [!NOTE]
> Make sure the rootfs is decompressed, it should end with `.img` rather than `,img.xz`.

## Chats & Support Groups

* [nabulinux](https://t.me/nabulinux) - Telegram group for Xiaomi Pad 5 linux.

## Credits

* [@ArKT-7](https://github.com/ArKT-7) for modded linux TWRP for nabu.
* [@rodriguezst](https://github.com/rodriguezst) for dualboot kernel pacher.
* [Project-Aloha](https://github.com/Project-Aloha) for UEFI development.
* [@gmankab](https://github.com/gmankab), [@Timofey](https://github.com/timoxa0), [@nik012003](https://github.com/nik012003) and all the other developers for building linux distros for nabu.
* [@panpantepan](https://gitlab.com/panpanpanpan), [@map220v](https://github.com/map220v), [@nik012003](https://github.com/nik012003) and all the other developers who contributed to mainlining.
* Everyone trying this project out or giving me advice.

## See Also

* [pocketblue](https://github.com/pocketblue/pocketblue) - Fedora Silverblue for nabu.
* [nabu-fedora-builder](https://github.com/nik012003/nabu-fedora-builder) - Another minimum Fedora for nabu.
* [nabu-alarm](https://github.com/nabu-alarm/) - Archlinux Arm for nabu.
