![](docs/banner.png)
# Fedora for Nabu

English | [简体中文](./docs/README.zh.md)

> ### 目录
>
> *   [特性](#特性)
> *   [截图](#截图)
> *   [免责声明](#免责声明)
> *   [安装教程 (支持双系统)](#安装教程-支持双系统)
> *   [支持群组](#支持群组)
> *   [鸣谢](#鸣谢)
> *   [另请参阅](#另请参阅)

本项目提供了一套脚本和 GitHub Actions 工作流，用于为小米平板 5 (nabu) 设备 (aarch64) 构建自定义的 Fedora 42 镜像，并附带了安装教程和相关资源。构建过程会生成一个可启动的根文件系统和 efi 文件。

> [!WARNING]
> **由于本项目使用社区支持的主线内核，部分硬件功能尚未完全支持或存在 bug。**

> [!NOTE]
> 初始用户名为 `user`，密码为 `fedora`。

> [!TIP]
> 大部分预装软件包的更新将发布到 [我的 Copr 仓库](https://copr.fedorainfracloud.org/coprs/jhuang6451/nabu_fedora_packages/)。您可以使用 `dnf upgrade` 命令检查更新！

## 特性

*   **精致的用户界面：** 提供精简的桌面环境 (DE) 和独特的窗口管理器 (WM) niri 供您选择。默认使用 fcitx 输入法，提供开箱即用的良好体验。
*   **统一内核镜像 (UKI)：** 利用 UKI 实现简化的启动流程。
*   **与安卓双系统共存：** 可与您的安卓系统并存安装，在启动时选择进入哪个系统。
*   **最新的内核：** 基于最新的 sm8150 主线内核 (6.16) 构建。

## 截图

![KDE](docs/kde.png)

![niri](docs/niri.png)

![Gnome](docs/gnome.png)

## 免责声明

    ```
    本项目是为小米平板 5 (nabu) 设备提供的非官方 Fedora Linux 移植。本项目“按原样”提供，不附带任何明示或暗示的保证，包括但不限于对适销性、特定用途适用性或非侵权性的暗示保证。

    使用、刷写或与本项目提供的任何文件、镜像或说明进行交互，即表示您承认并同意以下条款：

    1.  风险自负：您对因使用本软件而可能导致的任何设备损坏、数据丢失或任何其他问题负全部责任。本项目的开发者和贡献者对此类损害或损失不承担任何责任。
    2.  无官方支持：本项目未经 Fedora Project、Red Hat、小米或任何其他硬件或软件供应商的官方认可、支持或附属。
    3.  实验性质：这是一个持续开发的项目，软件可能包含错误、不稳定或不完整的功能。其功能可能未完全优化或不可靠。
    4.  数据丢失警告：刷写自定义操作系统本身存在数据丢失的风险。在尝试任何安装之前，**强烈建议**您备份设备中的所有重要数据。
    5.  不保证更新：尽管我们会努力维护和更新项目，但不能保证会持续提供支持、修复错误或发布未来版本。

    请谨慎操作，并自行承担风险。如果您不同意这些条款，请不要使用本项目。
    ```

## 安装教程 (支持双系统)

> [!IMPORTANT]
> 重新分区您的设备将会清除安卓的 userdata 分区，请确保已备份所有重要文件！

> [!NOTE]
> 对于那些已经有 esp 分区并且不想覆盖它的用户，您可以从 release 下载 `efi-files-xx.x.zip`，然后手动将所需的 efi 文件放入 esp 分区。

准备工作：

*   一台电脑。
*   互联网连接。
*   您已**解锁**的小米平板 5。
*   USB 数据线。

步骤：

1.  准备：
    *   确保您的电脑上已安装 `android-tools`，或从[官方网站](https://developer.android.com/tools/releases/platform-tools)下载 `platform-tools`，然后解压并进入该目录。
    *   从 release 下载并解压 esp 镜像和您想要的 rootfs 镜像。
    *   从[此处](https://github.com/ArKT-7/twrp_device_xiaomi_nabu/releases/tag/mod_linux)下载 ArKT-7 为 nabu 修改的 TWRP。
    *   从[此处](https://github.com/rodriguezst/nabu-dualboot-img/releases)下载双系统内核补丁 (如果您不知道什么是 secureboot，请下载 NOSB 版本)。

2.  分区：
    *   将您的平板电脑连接到电脑。
    *   重启您的平板电脑进入 bootloader 模式 (同时按住电源键和音量下键，直到屏幕上出现 `fastboot` 字样)。
    *   启动进入 ArKT-7 修改的 TWRP。

        ```Shell
        fastboot boot path/to/downloaded/twrp/image
        ```

    *   等待平板电脑启动进入 TWRP，然后点击屏幕右上角的 linux 图标。
    *   点击 `Partitioning` -> 输入 linux 分区的大小 -> 点击 `yes` -> 等待分区完成。

3.  通过 adb sideload 安装 DBKP：
    *   在您的平板电脑上，返回 TWRP 主屏幕。
    *   点击 `Advanced` -> 点击 `ADB Sideload` -> 滑动屏幕上的滑块。
    *   在您的电脑上，运行 `adb sideload` 命令：

        ```Shell
        adb sideload path/to/installer_bootmanager.zip
        ```

4.  刷写 esp 镜像：
    *   重启您的平板电脑进入 bootloader 模式。
    *   在您的电脑上，使用 `fastboot` 将 esp 镜像刷入 `esp` 分区：

        ```Shell
        fastboot flash esp path/to/esp-xx.x.img
        ```

5.  刷写 rootfs 镜像：
    *   确保您的平板电脑仍处于 bootloader 模式。
    *   在您的电脑上，使用 `fastboot` 将 rootfs 镜像刷入 `linux` 分区：

        ```Shell
        fastboot flash linux path/to/fedora-xx.x-nabu-variant-rootfs.img
        ```

    *   等待该过程完成，然后重启您的平板电脑：
        ```Shell
        fastboot reboot
        ```

        稍等片刻 (约 1 分钟)，您应该会看到平板电脑重启进入 UEFI 界面。
        *   ***请务必使用 `fastboot reboot` 命令重启，而不是使用电源键强制重启，否则可能会损坏文件系统！！！***

    *   您可以使用音量键选择启动项，并使用电源键确认。

> [!NOTE]
> 请确保 rootfs 镜像已经解压。

## 支持群组

*   [nabulinux](https://t.me/nabulinux) - 小米平板 5 Linux 的 Telegram 群组。

## 鸣谢

*   [@ArKT-7](https://github.com/ArKT-7) 提供了为 nabu 修改的 TWRP。
*   [@rodriguezst](https://github.com/rodriguezst) 提供了双系统内核补丁。
*   [Project-Aloha](https://github.com/Project-Aloha) 进行了 UEFI 开发。
*   [@gmankab](https://github.com/gmankab)、[@Timofey](https://github.com/timoxa0)、[@nik012003](https://github.com/nik012003)、[@panpantepan](https://gitlab.com/panpanpanpan) 以及所有其他为 nabu 构建 linux 发行版的开发者。
*   [@panpantepan](https://gitlab.com/panpanpanpan)、[@map220v](https://github.com/map220v)、[@nik012003](https://github.com/nik012003) 以及所有其他为主线内核做出贡献的开发者。
*   感谢每一位尝试本项目或给我提出建议的朋友。

## 另请参阅

*   [postmarketOS](https://wiki.postmarketos.org/wiki/Xiaomi_Pad_5_%28xiaomi-nabu%29) - 适用于 nabu 的 pmOS。
*   [pocketblue](https://github.com/pocketblue/pocketblue) - 适用于 nabu 的 Fedora Silverblue。
*   [nabu-fedora-builder](https://github.com/nik012003/nabu-fedora-builder) - 另一个适用于 nabu 的最小化 Fedora 。
*   [nabu-alarm](https://github.com/nabu-alarm/) - 适用于 nabu 的 Archlinux Arm (已停止维护)。
*   [Xiaomi-Nabu](https://github.com/TheMojoMan/Xiaomi-Nabu) - 适用于 nabu 的 Ubuntu。