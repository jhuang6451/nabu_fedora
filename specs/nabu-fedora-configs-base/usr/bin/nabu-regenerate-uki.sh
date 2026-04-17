#!/bin/bash

# ==============================================================================
#           重新为 nabu 生成 Fedora UKI 
# ==============================================================================
#
# 这个脚本旨在为系统中一个已安装的内核版本，触发一次完整的 UKI 生成流程。
# 它模仿了 kernel-sm8150 RPM 包在安装后（%posttrans 阶段）执行的自动化步骤。
#
# 前提条件：
#   - 对应的内核包已经安装（vmlinuz, 模块, dtb 等文件存在）。
#   - `dracut` 和 `systemd-boot` (提供 ukify) 已经安装。
#   - 相关的配置文件已经就位：
#     - dracut 配置: /etc/dracut.conf 和 /etc/dracut.conf.d/
#     - ukify  配置: /etc/systemd/ukify.conf
#
# ==============================================================================

set -e  # 任何命令失败立即退出
set -u  # 变量未定义时报错
set -o pipefail # 管道中任何一个命令失败，则整个管道失败

# --- 脚本参数 ---
# 如果用户没有在命令行提供内核版本，则自动使用当前正在运行的内核版本。
# 你也可以手动指定，例如：./regenerate-uki.sh 6.16-5.sm8150.aarch64
TARGET_UNAME_R=${1:-$(uname -r)}

echo "--- 准备为内核版本 ${TARGET_UNAME_R} 重新生成 UKI ---"

# --- 检查依赖的命令是否存在 ---
command -v dracut >/dev/null 2>&1 || { echo >&2 "错误: 'dracut' 命令未找到。请先安装它。"; exit 1; }
command -v ukify >/dev/null 2>&1 || { echo >&2 "错误: 'ukify' 命令未找到。它通常由 'systemd-boot' 包提供。"; exit 1; }
command -v depmod >/dev/null 2>&1 || { echo >&2 "错误: 'depmod' 命令未找到。请检查 'kmod' 包是否已安装。"; exit 1; }

# --- 定义和验证路径 ---
KERNEL_PATH="/boot/vmlinuz-${TARGET_UNAME_R}"
INITRD_PATH="/boot/initramfs-${TARGET_UNAME_R}.img" # 这是一个临时文件
DTB_PATH="/usr/lib/modules/${TARGET_UNAME_R}/dtb/qcom/sm8150-xiaomi-nabu.dtb" # 从 spec 文件中硬编码
UKI_DIR="/boot/efi/EFI/fedora"

# 检查所需文件是否存在
if [ ! -f "${KERNEL_PATH}" ]; then
    echo "错误: 内核镜像未找到: ${KERNEL_PATH}" >&2
    exit 1
fi

if [ ! -d "/usr/lib/modules/${TARGET_UNAME_R}" ]; then
    echo "错误: 内核模块目录未找到: /usr/lib/modules/${TARGET_UNAME_R}" >&2
    exit 1
fi

if [ ! -f "${DTB_PATH}" ]; then
    echo "错误: 设备树文件 (DTB) 未找到: ${DTB_PATH}" >&2
    exit 1
fi

# --- 确定最终输出的 EFI 文件名 ---
UKI_PATH="${UKI_DIR}/fedora-${TARGET_UNAME_R}.efi"

# 确保输出目录存在
mkdir -p "$UKI_DIR"

# ==============================================================================
#                           UKI 生成流程开始
# ==============================================================================

# --- 步骤 1: 重新生成模块依赖 ---
echo "INFO: 正在为 ${TARGET_UNAME_R} 运行 depmod..."
depmod -a "${TARGET_UNAME_R}"
echo "SUCCESS: 模块依赖已更新。"

# --- 步骤 2: 使用 dracut 生成临时的 initramfs ---
echo "INFO: 正在使用 dracut 生成 initramfs..."
# 使用 --force 选项确保覆盖任何已存在的同名文件
dracut --kver "${TARGET_UNAME_R}" --force "${INITRD_PATH}"
if [ ! -f "${INITRD_PATH}" ]; then
    echo "CRITICAL: dracut 未能成功创建 initramfs 文件: ${INITRD_PATH}" >&2
    exit 1
fi
echo "SUCCESS: 临时的 initramfs 已生成于 ${INITRD_PATH}"

# --- 步骤 3: 使用 systemd-ukify 将所有组件打包成 UKI ---
echo "INFO: 正在使用 systemd-ukify 生成最终的 UKI..."

# 构建 ukify 命令参数
ukify_args=(
    build
    --linux="${KERNEL_PATH}"
    --initrd="${INITRD_PATH}"
    --output="${UKI_PATH}"
    --devicetree="${DTB_PATH}"
)

# 执行 ukify
ukify "${ukify_args[@]}"

if [ ! -f "${UKI_PATH}" ]; then
    echo "CRITICAL: ukify 未能成功创建 UKI 文件: ${UKI_PATH}" >&2
    # 清理失败后留下的临时文件
    rm -f "${INITRD_PATH}"
    exit 1
fi
echo "SUCCESS: UKI 已成功生成于: ${UKI_PATH}"

# --- 步骤 4: 清理临时的 initramfs ---
echo "INFO: 正在清理临时的 initramfs 文件..."
rm -f "${INITRD_PATH}"
echo "SUCCESS: 清理完成。"

# ==============================================================================
echo "--- 所有操作已成功完成！ ---"
# ==============================================================================