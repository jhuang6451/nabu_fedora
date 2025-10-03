#!/bin/bash

# ==============================================================================
# 2_create_release.sh
#
# 功能:
#   1. 自动查找所有构建变体的 rootfs 镜像。
#   2. 为每个镜像提取 EFI 文件并打包成 zip。
#   3. 使用 xz 对每个镜像进行高效压缩。
#   4. 创建一个包含所有资产的 GitHub Release。
#
# 作者: jhuang6451
# 版本: 2.0
# ==============================================================================

set -e
set -u
set -o pipefail

# 在容器化的 GitHub Actions 环境中，将工作区标记为安全的 git 目录
if [ -n "${GITHUB_WORKSPACE}" ]; then
    echo "INFO: Marking '${GITHUB_WORKSPACE}' as a safe git directory..."
    git config --global --add safe.directory "${GITHUB_WORKSPACE}"
fi

# --- 配置变量 ---
echo "INFO: Reading configuration from environment variables..."
BUILD_VERSION="${BUILD_VERSION:-42.2}"

# --- 路径定义 ---
ARTIFACTS_DIR="artifacts"

# --- 存储最终要上传的资产 ---
ASSETS_TO_UPLOAD=()

# --- 清理函数 ---
cleanup() {
    echo "INFO: Performing cleanup..."
    # 卸载所有可能的挂载点
    grep "$PWD/tmp_mount_" /proc/mounts | awk '{print $2}' | xargs -r sudo umount -l
    rm -rf tmp_mount_* tmp_efi_*
    echo "INFO: Cleanup complete."
}
trap cleanup EXIT

# --- 脚本主逻辑 ---

# 1. 查找所有下载的 rootfs 镜像文件
echo "INFO: Searching for rootfs image artifacts in '${ARTIFACTS_DIR}'..."
ROOTFS_IMAGES=($(find "${ARTIFACTS_DIR}" -type f -name "*.img"))

if [ ${#ROOTFS_IMAGES[@]} -eq 0 ]; then
    echo "ERROR: No rootfs artifact (*.img) found in '${ARTIFACTS_DIR}'!" >&2
    echo "--- Listing contents of ARTIFACTS_DIR --- "
    ls -R "${ARTIFACTS_DIR}"
    echo "---------------------------------------"
    exit 1
fi

echo "INFO: Found ${#ROOTFS_IMAGES[@]} rootfs image(s) to