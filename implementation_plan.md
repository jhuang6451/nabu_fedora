# Nabu Fedora 向 bootc 方案迁移：终极主计划 (Master Plan)

本计划旨在将现有的脚本化构建流程彻底迁移至 Fedora `bootc` 架构。核心目标是实现**原子更新**、**容器化构建**、**Btrfs 空间自适应**以及**便捷的多桌面变体切换**。

---

## 核心设计决策 (Core Design)

> [!IMPORTANT]
> **文件系统策略**：采用 **Btrfs** 作为根文件系统，通过子卷实现 `/` (只读), `/var` (持久) 和 `/home` (用户) 的分离。
> **刷机适配**：继续支持 `fastboot` 刷机。通过流水线从生成的全盘镜像中提取 `esp.img` 和 `rootfs.img`。
> **配置分发**：引入 **“Nabu 随航向导”** (Yad 实现) 解决跨镜像切换时的用户配置同步问题。

---

## 阶段规划 (Phased Timeline)

### 第一阶段：MVP (最小可行性产品) - 基础引导与自动化链路
**目标**：构建并验证可引导的 `base` (Headless) 镜像，打通从 OCI 镜像到磁盘分区的全链路。

1.  **RPM 包优化 (specs)**：
    *   **[MODIFY] [kernel-sm8150.spec](file:///home/jhuang/workspace/nabu_fedora/specs/kernel-sm8150/kernel-sm8150.spec)**: 移除强制写入 `/boot/efi` 的逻辑，改为将 UKI 产物存放在 `/usr/lib/modules` 下，以便被 `bootc` 工具链识别。
    *   **[MODIFY] [nabu-fedora-configs-core.spec](file:///home/jhuang/workspace/nabu_fedora/specs/nabu-fedora-configs-base/nabu-fedora-configs-core.spec)**: 
        *   调整内建脚本以适应 `ostree` 的只读布局。
        *   增加 btrfs-expand.service（一次性服务），在首次启动时执行 btrfs filesystem resize max /。
2.  **构建环境搭建 (CI)**：
    *   **[NEW] [Containerfile.base](file:///home/jhuang/workspace/nabu_fedora/scripts/Containerfile.base)**: 基础硬件驱动镜像。
    *   **[NEW] [config.toml](file:///home/jhuang/workspace/nabu_fedora/scripts/config.toml)**: 配置 `bootc-image-builder` 使用 Btrfs 及特定的分区布局。
3.  **提取脚本开发**：
    *   **[NEW] [extract-and-pack.sh](file:///home/jhuang/workspace/nabu_fedora/scripts/extract-and-pack.sh)**: 运行 bootc-image-builder 生成 raw 镜像。
        *   使用 sfdisk 提取 rootfs.img。
        *   从 OCI 镜像（通过 podman mount）或从 raw 镜像中提取 UKI 等文件。
        *   调用 mkfs.vfat 逻辑，配合 nabu-fedora-dualboot-efi 产出最终的 esp.img。
4.  **验证环节**：
    *   验证 `esp.img` 包含正确的引导项。
    *   验证 `rootfs.img` 在刷入后能通过 Btrfs 自动扩容填满分区。

### 第二阶段：变体扩展与流水线工业化
**目标**：实现 GNOME/KDE/Niri 多变体并行构建，并支持 `bootc switch`。

1.  **变体镜像开发**：
    *   **[NEW] [Containerfile.gnome](file:///home/jhuang/workspace/nabu_fedora/scripts/Containerfile.gnome)**: 继承自 base。
    *   **[NEW] [Containerfile.kde](file:///home/jhuang/workspace/nabu_fedora/scripts/Containerfile.kde)**: 继承自 base。
    *   **[NEW] [Containerfile.niri](file:///home/jhuang/workspace/nabu_fedora/scripts/Containerfile.niri)**: 包含专属配置模板。
2.  **GitHub Actions 集成**：
    *   实现 Matrix Build 系统，同时推送多个 Tag 至 GHCR。
3.  **验证环节**：
    *   测试从 `base` 切换到 `niri` 镜像后，系统组件的增量更新是否正常。

### 第三阶段：首航体验 (OOBE) 与随航向导
**目标**：提供专业级的新机设置引导及针对变体的自动配置。

1.  **初始设置集成**：
    *   在镜像中预装并启用 `fedora-initial-setup`。
2.  **随航向导开发 (Yad)**：
    *   **[NEW] [nabu-wizard.sh](file:///home/jhuang/workspace/nabu_fedora/scripts/nabu-wizard.sh)**: 实现 Yad 交互界面，允许用户获取 `DankMaterialShell` 等配置。
    *   **[NEW] [nabu-user-sync.service](file:///home/jhuang/workspace/nabu_fedora/scripts/nabu-user-sync.service)**: 系统级用户同步服务，检测变体转换并触发向导。
3.  **验证环节**：
    *   模拟用户首次刷机启动，检查是否弹出 Setup 界面。
    *   切换桌面环境后，检查是否弹出“发现新桌面环境，是否应用预设？”的提示。
