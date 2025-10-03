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

echo "INFO: Found ${#ROOTFS_IMAGES[@]} rootfs image(s) to process."

# 2. 循环处理每个找到的镜像
for ROOTFS_PATH in "${ROOTFS_IMAGES[@]}"; do
    echo "=================================================================="
    echo "INFO: Processing image: ${ROOTFS_PATH}"

    # 提取变体名称 (e.g., gnome, kde)
    VARIANT_NAME=$(basename "${ROOTFS_PATH}" .img | sed -e 's/.*-//g')
    if [ -z "${VARIANT_NAME}" ]; then
        echo "WARNING: Could not determine variant name from '${ROOTFS_PATH}'. Skipping."
        continue
    fi
    echo "INFO: Detected variant: ${VARIANT_NAME}"

    # 定义此变体相关的文件名
    EFI_ZIP_NAME="efi-files-${VARIANT_NAME}.zip"
    ROOTFS_COMPRESSED_PATH="${ROOTFS_PATH}.xz"

    # 为此变体创建唯一的临时目录
    ROOTFS_MNT_POINT=$(mktemp -d tmp_mount_XXXXXX)
    EFI_EXTRACT_DIR=$(mktemp -d tmp_efi_XXXXXX)

    # 挂载、提取、打包
    echo "INFO: Mounting rootfs image to extract EFI files..."
    mount -o loop,ro "${ROOTFS_PATH}" "${ROOTFS_MNT_POINT}"

    ROOTFS_EFI_CONTENT="${ROOTFS_MNT_POINT}/boot/efi/"
    if [ ! -d "${ROOTFS_EFI_CONTENT}" ] || [ -z "$(ls -A "${ROOTFS_EFI_CONTENT}")" ]; then
        echo "ERROR: EFI content in '${ROOTFS_PATH}' is empty or missing." >&2
        umount "${ROOTFS_MNT_POINT}"
        continue
    fi

    echo "INFO: Copying EFI content to temporary directory..."
    rsync -a "${ROOTFS_EFI_CONTENT}" "${EFI_EXTRACT_DIR}/"
    umount "${ROOTFS_MNT_POINT}"

    echo "INFO: Creating '${EFI_ZIP_NAME}'..."
    (cd "${EFI_EXTRACT_DIR}" && zip -r "$OLDPWD/${EFI_ZIP_NAME}" .)
    ASSETS_TO_UPLOAD+=("${EFI_ZIP_NAME}")
    echo "INFO: Added '${EFI_ZIP_NAME}' to upload list."

    # 压缩镜像
    echo "INFO: Compressing '${ROOTFS_PATH}' using xz..."
    xz -T0 -v "${ROOTFS_PATH}"
    ASSETS_TO_UPLOAD+=("${ROOTFS_COMPRESSED_PATH}")
    echo "INFO: Added '${ROOTFS_COMPRESSED_PATH}' to upload list."

done

# 3. 检查是否有可上传的资产
if [ ${#ASSETS_TO_UPLOAD[@]} -eq 0 ]; then
    echo "ERROR: No assets were generated for upload. Exiting." >&2
    exit 1
fi

# 4. 准备并创建 Release
TAG="test-$(date +'%Y%m%d-%H%M')"
RELEASE_TITLE="Fedora for Nabu Test-$(date +'%Y%m%d-%H%M')"

CHANGELOG="* No changelog provided."
if [ -f "docs/release-notes.md" ]; then
    CHANGELOG=$(cat docs/release-notes.md)
fi

COMMIT_URL="${GITHUB_SERVER_URL:-https://github.com}/${GITHUB_REPOSITORY:-your/repo}/commit/${GITHUB_SHA:-HEAD}"

# 动态生成资产列表
ASSET_NOTES=""
for ASSET in "${ASSETS_TO_UPLOAD[@]}"; do
    FILENAME=$(basename "${ASSET}")
    if [[ "${FILENAME}" == *.img.xz ]]; then
        ASSET_NOTES+="- \`${FILENAME}\` - The compressed rootfs image. Decompress before use.\n"
    elif [[ "${FILENAME}" == *.zip ]]; then
        ASSET_NOTES+="- \`${FILENAME}\` - Contains the bootloader and kernel (UKI). Unzip and copy to your ESP partition.\n"
    fi
done

RELEASE_NOTES=$(cat <<EOF
Automated build of Fedora 42 for Xiaomi Pad 5 (nabu).

## Changelog

${CHANGELOG}

## Assets

${ASSET_NOTES}

This build is based on commit: [${GITHUB_SHA:0:7}](${COMMIT_URL})
EOF
)

# 5. 创建 Release 并上传所有资产
echo "INFO: Creating GitHub release '${TAG}' with ${#ASSETS_TO_UPLOAD[@]} assets..."

gh release create "$TAG" \
    --title "$RELEASE_TITLE" \
    --notes "$RELEASE_NOTES" \
    --latest \
    "${ASSETS_TO_UPLOAD[@]}"

echo "SUCCESS: Release ${TAG} created successfully with all assets."