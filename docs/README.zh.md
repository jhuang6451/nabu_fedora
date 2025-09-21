# WIP

# Fedora for Nabu

[English](../README.md) | Simplified-Chinese

该仓库包含一组脚本和 GitHub Actions 工作流，用于为小米 Nabu 设备 (aarch64) 构建自定义的 Fedora 42 镜像。构建过程完全自动化，并生成一个可启动的根文件系统和一个 EFI 系统分区 (ESP) 镜像。

## 特性

*   **Fedora 42:** 基于最新的 Fedora 发行版。
*   **aarch64:** 为 ARM64 架构构建。
*   **图形环境:** 包含标准的图形桌面环境。
*   **systemd-boot:** 使用现代化的 `systemd-boot` 引导加载程序。
*   **统一内核镜像 (UKI):** 生成 UKI 以实现安全、简化的启动过程。

## 工作原理

构建过程分为两个主要阶段，由两个独立的 GitHub Actions 工作流编排：

1.  **构建构建器镜像:** `1-build-builder-image.yml` 工作流构建一个 Docker 容器镜像，作为构建环境。该镜像包含了创建 Fedora 镜像所需的所有工具和依赖。生成的容器被推送到 GitHub Container Registry。

2.  **为 Nabu 构建 Fedora:** `2-build-fedora-nabu.yml` 工作流使用构建器镜像来执行主构建。该工作流包括以下步骤：
    *   **创建根文件系统:** `2_create_rootfs.sh` 脚本引导一个最小化的 Fedora 42 系统，安装图形环境，并为 Nabu 设备进行配置。这包括设置自定义服务、fstab 以及用于生成 UKI 的 dracut。
    *   **创建 ESP:** `3_create_esp.sh` 脚本创建 EFI 系统分区 (ESP) 镜像，安装 `systemd-boot`，并从根文件系统中复制引导加载程序配置和 UKI。
    *   **创建发布:** 最后一个作业会创建一个新的 GitHub Release，并将生成的 `fedora-42-nabu-rootfs.img` 和 `esp.img` 文件作为发布资产上传。