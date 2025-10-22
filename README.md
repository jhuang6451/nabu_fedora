!(docs/950_1x_shots_so.png)
# Fedora for Nabu

English | [Simplified-Chinese](./docs/README.zh.md)

A set of scripts and GitHub Actions workflows to build a custom Fedora 42 image for the Xiaomi Pad 5 (nabu) device (aarch64), along with tutorials and resources for installation. The build process produces a bootable root filesystem and efi files.

> [!NOTE]
> The initial username is `user` and the password is `fedora`.

> [!TIP]
> Most updates will be released to pre-installed packages from [my Copr](https://copr.fedorainfracloud.org/coprs/jhuang6451/nabu_fedora_packages/). Check for them with `dnf upgrade`!

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

* **Polished UIs:** Providing choice between streamlined DEs and an unique WM: niri. Uses fcitx as default input method, providing solid out-of-the-box experience.
* **Unified Kernel Image (UKI):** Utilizes UKI for a streamlined boot process.
* **Dualboot With Android:** Installed alongside your android system, choose system at boot.
* **Latest Kernel:** Built with latest mainline for sm8150 (6.16).

## Todos

* [x] Fix UKI generation.
* [x] Fix efi installation.
* [x] Fix esp image generation.
* [x] Complete installation tutorial docs.
* [x] Dualboot optimization.
* [x] Release config files via Copr.
* [x] KDE variant.
* [x] Niri variant.
* [x] Update kernel to 6.17.

## Bugs
You tell me.

## Installation Tutorial (Dualboot Supportive)

> [!NOTE]
> Re-partitioning your device wipes android's userdata, make sure all important files are backed up!!

> [!NOTE]
> For those who already have an esp partition and don't want it overwritten, you can download `efi-files-xx.x.zip` from release and manually place needed efi files into esp partition.

Requirements:

* A PC.
* Internet connection.
* Your **UNLOCKED** Xiaomi Pad 5 tablet.
* USB Cable.

Steps:

1. Preparation:
    * Make sure `android-tools` is installed on your PC, or download `platform-tools` from [Official Website](https://developer.android.com/tools/releases/platform-tools), then decompress and cd into it.
    * Download and decompress both esp image and desired rootfs image from release.
    * Download ArKT-7's modded TWRP for nabu from [here](https://github.com/ArKT-7/twrp_device_xiaomi_nabu/releases/tag/mod_linux).
    * Download dualboot kernel pacher from [here](https://github.com/rodriguezst/nabu-dualboot-img/releases) (If you don't know what secureboot is, just download the NOSB version).

2. Partitioning:
    * Connect your tablet to your PC.
    * Reboot your tablet into bootloader (press the power bottom and the volume down bottom together, until you see `fastboot` on screen).
    * Boot into ArKT-7's modded TWRP.

        ```Shell
        fastboot boot path/to/downloaded/twrp/image
        ```

    * Wait until your tablet to boot into TWRP, then tap on the linux logo on the top right side of the screen.
    * Tap on `Partitioning` -> Enter the linux partition size -> Tap on `yes` -> Wait for partitioning to be done.

3. Install DBKP via adb sideload:
    * On your tablet, go back to the home screem of TWRP.
    * Tap on `Advanced` -> Tap on `ADB Sideload` -> Swipe the bar on the screen.
    * On your PC, run `adb sideload` command:

        ```Shell
        adb sideload path/to/installer_bootmanager.zip
        ```

4. Flash esp image:
    * Reboot your tablet into bootloader.
    * On your PC, use `fastboot` to flash esp image to `esp` partition:

        ```Shell
        fastboot flash esp path/to/esp-xx.x.img
        ```

5. Flash rootfs image:
    * Make sure your tablet is still in bootloader.
    * On your PC, use `fastboot` to flash rootfs image to `linux` partition:

        ```Shell
        fastboot flash linux path/to/fedora-xx.x-nabu-variant-rootfs.img
        ```

    * Wait for the process to complete, then reboot your tablet:

        ```Shell
        fastboot reboot
        ```

        after a while (About 1 minute), you should see the tablet reboot into UEFI interface.

        * ***Make sure to reboot with `fastboot reboot` rather than force rebooting with power bottom, or it might break the filesystem!!!***
    * You can choose between boot options with volume bottom, and confirm with power bottom.

> [!NOTE]
> Make sure the rootfs is decompressed.

## Support Groups

* [nabulinux](https://t.me/nabulinux) - Telegram group for Xiaomi Pad 5 linux.

## Credits

* [@ArKT-7](https://github.com/ArKT-7) for modded TWRP for nabu.
* [@rodriguezst](https://github.com/rodriguezst) for dualboot kernel pacher.
* [Project-Aloha](https://github.com/Project-Aloha) for UEFI development.
* [@gmankab](https://github.com/gmankab), [@Timofey](https://github.com/timoxa0), [@nik012003](https://github.com/nik012003) and all the other developers for building linux distros for nabu.
* [@panpantepan](https://gitlab.com/panpanpanpan), [@map220v](https://github.com/map220v), [@nik012003](https://github.com/nik012003) and all the other developers who contributed to mainlining.
* Everyone trying this project out or giving me advice.

## See Also

* [pocketblue](https://github.com/pocketblue/pocketblue) - Fedora Silverblue for nabu.
* [nabu-fedora-builder](https://github.com/nik012003/nabu-fedora-builder) - Another minimum Fedora for nabu.
* [nabu-alarm](https://github.com/nabu-alarm/) - Archlinux Arm for nabu (EOL).
* [Xiaomi-Nabu](https://github.com/TheMojoMan/Xiaomi-Nabu) - Ubuntu for nabu.