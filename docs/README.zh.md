# Fedora for Nabu

[English](../README.md) | 简体中文

这是一套脚本和 GitHub Actions 工作流，用于为小米平板 5 (nabu) 设备 (aarch64) 构建自定义的 Fedora 42 镜像，并附有安装教程和相关资源。构建过程会生成一个可启动的根文件系统和 efi 文件。

> [!NOTE]
> 初始用户名是 `user`，密码是 `fedora`。


## 免责声明

```
本项目是为小米平板 5 (nabu) 设备提供的非官方 Fedora Linux 移植。它以“原样”提供，不附带任何形式的明示或暗示的保证，包括但不限于对适销性、特定用途适用性或非侵权性的暗示保证。

通过使用、刷入或与本项目提供的任何文件、镜像或说明进行交互，您承认并同意以下条款：

1.  风险自负：您将对因使用本软件而可能导致的任何设备损坏、数据丢失或其他问题承担全部责任。本项目的开发者和贡献者对此类损害或损失不承担任何责任。
2.  无官方支持：本项目未经 Fedora Project、Red Hat、小米或任何其他硬件或软件供应商的官方认可、支持或与其存在任何关联。
3.  实验性质：这是一个持续开发的项目，软件可能包含错误、不稳定或不完整的功能。其功能可能未得到充分优化或不完全可靠。
4.  数据丢失警告：刷入自定义操作系统本身就存在数据丢失的风险。在尝试任何安装操作前，我们**强烈建议**您备份设备上的所有重要数据。
5.  不保证更新：尽管我们会努力维护和更新项目，但不能保证会持续提供支持、修复错误或发布未来版本。

请谨慎操作，并自行承担风险。如果您对这些条款感到不安，请不要使用本项目。
```

## 功能特性

*   **流畅的 Gnome 体验：** 内置精简的 Gnome 桌面环境和 fcitx 作为默认输入法，提供开箱即用的坚实体验。
*   **统一内核镜像 (UKI)：** 利用 UKI 技术简化启动流程。
*   **与安卓双系统共存：** 可与您的安卓系统并存安装，在开机时选择进入哪个系统。
*   **最新的内核：** 基于最新的 sm8150 主线内核 (6.16) 构建。

## Bug
等你来发现。

## 安装教程 (支持双系统)

> [!NOTE]
> 对设备重新分区会清除安卓系统的 userdata 分区，请务必备份所有重要文件！

准备工作：

*   一台电脑。
*   网络连接。
*   您的**已解锁**的小米平板 5。
*   USB 数据线。

步骤：

1.  准备：
    *   确保您的电脑上已安装 `android-tools`，或从[官方网站](https://developer.android.com/tools/releases/platform-tools)下载 `platform-tools`，然后解压并进入其目录。
    *   从 release 页面下载并解压 `efi-files.zip` 和 `fedora-42-nabu-rootfs.img.xz` 这两个文件。
    *   从[这里](https://github.com/ArKT-7/twrp_device_xiaomi_nabu/releases/tag/mod_linux)下载 ArKT-7 为 nabu 修改的 TWRP。
    *   从[这里](https://github.com/rodriguezst/nabu-dualboot-img/releases)下载双系统内核补丁 (DBKP) (如果您不了解什么是安全启动 (secureboot)，下载 NOSB 版本即可)。

2.  分区：
    *   将平板连接到电脑。
    *   重启平板进入 bootloader 模式 (同时按住电源键和音量下键，直到屏幕上出现 `fastboot` 字样)。
    *   启动进入 ArKT-7 修改版的 TWRP。

        ```Shell
        fastboot boot path/to/downloaded/twrp/image
        ```

    *   等待平板启动进入 TWRP，然后点击屏幕右上角的 Linux 图标。
    *   依次点击 `Partitioning` -> 输入 Linux 分区大小 -> 点击 `yes` -> 等待分区完成。

3.  将 efi 文件传输到平板的 esp 分区：
    *   确保您的平板仍处于 TWRP 模式，并与电脑保持连接。
    *   在您的电脑上运行：

        ```Shell
        adb shell 'umount /esp'
        adb shell 'mount /dev/block/sda31 /esp'
        adb push path/to/unzipped/efi-file/* /esp/
        adb shell 'umount /esp'
        ```

4.  通过 adb sideload 安装 DBKP：
    *   在平板上，返回 TWRP 主屏幕。
    *   依次点击 `Advanced` -> `ADB Sideload` -> 滑动屏幕上的滑块。
    *   在您的电脑上运行：

        ```Shell
        adb sideload path/to/installer_bootmanager.zip
        ```

5.  安装根文件系统 (rootfs)：
    *   再次重启平板进入 bootloader 模式。
    *   在您的电脑上运行：

        ```Shell
        fastboot flash linux path/to/fedora-42-nabu-rootfs.img
        ```

    *   等待该过程完成，然后重启您的平板，您应该会看到 UEFI 界面。
    *   您可以使用音量键选择启动项，并用电源键确认。

> [!NOTE]
> 请确保根文件系统是解压后的文件，其后缀应为 `.img` 而非 `.img.xz`。

## 交流群组

*   [nabulinux](https://t.me/nabulinux) - 小米平板 5 Linux Telegram 交流群。

## 鸣谢

*   [@ArKT-7](https://github.com/ArKT-7) 提供了用于 nabu 的修改版 TWRP。
*   [@rodriguezst](https://github.com/rodriguezst) 提供了双系统内核补丁。
*   [Project-Aloha](https://github.com/Project-Aloha) 进行了 UEFI 开发工作。
*   [@gmankab](https://github.com/gmankab), [@Timofey](https://github.com/timoxa0), [@nik012003](https://github.com/nik012003) 以及所有其他为 nabu 构建 Linux 发行版的开发者们。
*   [@panpantepan](https://gitlab.com/panpanpanpan), [@map220v](https://github.com/map220v), [@nik012003](https://github.com/nik012003) 以及所有其他为内核主线化做出贡献的开发者们。
*   每一位尝试本项目或给我提出建议的朋友。

## 相关项目

*   [pocketblue](https://github.com/pocketblue/pocketblue) - 用于 nabu 的 Fedora Silverblue。
*   [nabu-fedora-builder](https://github.com/nik012003/nabu-fedora-builder) - 另一个用于 nabu 的最小化 Fedora。
*   [nabu-alarm](https://github.com/nabu-alarm/) - 用于 nabu 的 Archlinux Arm (已停止维护)。
*   [Xiaomi-Nabu](https://github.com/TheMojoMan/Xiaomi-Nabu) - 用于 nabu 的 Ubuntu。
