#!/bin/bash

# ==============================================================================
# 3-create-release.sh
#
# 功能:
#   1. 查找预先打包好的 EFI 文件压缩包和 ESP 镜像。
#   2. 查找所有构建变体的 rootfs 镜像。
#   3. 使用 zstd 对每个 rootfs 镜像进行高效压缩。
#   4. 创建一个包含所有资产的 GitHub Release。
#
# 作者: jhuang6451
# 版本: 2.2
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
BUILD_VERSION="${BUILD_VERSION}"

ARTIFACTS_DIR="artifacts"

ASSETS_TO_UPLOAD=()

# --- 清理函数 ---
cleanup() {
    echo "INFO: Performing cleanup..."
    # 卸载所有可能的挂载点
    grep "$PWD/tmp_mount_" /proc/mounts | awk '{print $2}' | xargs -r sudo umount -l || true
    rm -rf tmp_mount_* tmp_efi_*
    echo "INFO: Cleanup complete."
}
trap cleanup EXIT

# --- 脚本主逻辑 ---

# 1. 查找并准备 EFI 压缩包
echo "INFO: Searching for EFI zip artifact..."
EFI_ZIP_SOURCE=$(find "${ARTIFACTS_DIR}" -type f -name "efi-files.zip")

if [ -z "$EFI_ZIP_SOURCE" ]; then
    echo "ERROR: efi-files.zip not found in artifacts!" >&2
    ls -R "${ARTIFACTS_DIR}"
    exit 1
fi

echo "INFO: Found EFI zip artifact at ${EFI_ZIP_SOURCE}"
EFI_RELEASE_NAME="efi-files-${BUILD_VERSION}.zip"
cp "${EFI_ZIP_SOURCE}" "${EFI_RELEASE_NAME}"
ASSETS_TO_UPLOAD+=("${EFI_RELEASE_NAME}")
echo "INFO: Added '${EFI_RELEASE_NAME}' to upload list."

# 2. 查找并准备 ESP 镜像文件
echo "INFO: Searching for ESP image artifact (esp.img)..."
ESP_IMG_SOURCE=$(find "${ARTIFACTS_DIR}" -type f -name "esp.img")

if [ -n "$ESP_IMG_SOURCE" ]; then
    echo "INFO: Found ESP image artifact at ${ESP_IMG_SOURCE}"
    ESP_RELEASE_NAME="esp-${BUILD_VERSION}.img"
    cp "${ESP_IMG_SOURCE}" "${ESP_RELEASE_NAME}"
    ASSETS_TO_UPLOAD+=("${ESP_RELEASE_NAME}")
    echo "INFO: Added '${ESP_RELEASE_NAME}' to upload list."
else
    echo "WARNING: esp.img not found in artifacts. It will not be included in the release."
fi

# 3. 查找所有下载的 rootfs 镜像文件
echo "INFO: Searching for rootfs image artifacts in '${ARTIFACTS_DIR}'..."
ROOTFS_IMAGES=($(find "${ARTIFACTS_DIR}" -type f -name "*.img"))

if [ ${#ROOTFS_IMAGES[@]} -eq 0 ]; then
    echo "WARNING: No rootfs artifact (*.img) found in '${ARTIFACTS_DIR}'. Release will only contain EFI files."
fi

echo "INFO: Found ${#ROOTFS_IMAGES[@]} rootfs image(s) to process."

# 4. 循环处理每个 rootfs 镜像
for ROOTFS_PATH in "${ROOTFS_IMAGES[@]}"; do
    echo "=================================================================="
    echo "INFO: Processing image: ${ROOTFS_PATH}"

    ROOTFS_COMPRESSED_PATH="${ROOTFS_PATH}.zst"

    # 使用 zstd 进行压缩
    echo "INFO: Compressing '${ROOTFS_PATH}' using zstd..."
    # -T0 使用所有可用线程，-v 显示进度
    zstd -T0 -v "${ROOTFS_PATH}"

    ASSETS_TO_UPLOAD+=("${ROOTFS_COMPRESSED_PATH}")
    echo "INFO: Added '${ROOTFS_COMPRESSED_PATH}' to upload list."

done

# 5. 检查是否有可上传的资产
if [ ${#ASSETS_TO_UPLOAD[@]} -eq 0 ]; then
    echo "ERROR: No assets were generated for upload. Exiting." >&2
    exit 1
fi

# 6. 准备并创建 Release
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
    if [[ "${FILENAME}" == *.img.zst ]]; then
        ASSET_NOTES="${ASSET_NOTES}- \\\`${FILENAME}\\\` - The compressed rootfs image. Decompress with \`unzstd\` or \`zstd -d\`.
"
    elif [[ "${FILENAME}" == *.zip ]]; then
        ASSET_NOTES="${ASSET_NOTES}- \\\`${FILENAME}\\\` - Contains the bootloader and kernel (UKI). Unzip and copy to your ESP partition. This is compatible with all rootfs variants in this release.
"
    elif [[ "${FILENAME}" == esp-*.img ]]; then
        ASSET_NOTES="${ASSET_NOTES}- \\\`${FILENAME}\\\` - A flashable ESP (EFI System Partition) image that already contains the boot loader and kernel. You can flash this image directly to the ESP partition of your device.
"
    fi
done

RELEASE_NOTES=$(cat <<EOF
Automated build of Fedora 42 for Xiaomi Pad 5 (nabu).

## Assets

${ASSET_NOTES}

This build is based on commit: [${GITHUB_SHA:0:7}](${COMMIT_URL})
EOF
)

# 7. 创建 Release 并上传所有资产
echo "INFO: Creating GitHub release '${TAG}' with ${#ASSETS_TO_UPLOAD[@]} assets..."

gh release create "$TAG" \
    --title "$RELEASE_TITLE" \
    --notes "$RELEASE_NOTES" \
    --prerelease \
    "${ASSETS_TO_UPLOAD[@]}"

echo "SUCCESS: Release ${TAG} created successfully with all assets."