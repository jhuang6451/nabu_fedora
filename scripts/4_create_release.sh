#!/bin/bash

# ==============================================================================
# 4_create_release.sh
#
# 功能: 
#   1. 从 rootfs 中提取 EFI 文件, 安装 systemd-boot, 并打包成zip 压缩包。
#   2. 使用 xz 对 rootfs 镜像进行高效压缩。
#   3. 创建一个带有动态信息的 GitHub Release 并上传所有资产。
#
# 作者: jhuang6451
# 版本: 1.0
# ==============================================================================

set -e
set -u
set -o pipefail

# In containerized GitHub Actions environments, the workspace directory may not be
# owned by the user running the script, causing git to report a "dubious ownership"
# error. We mark the directory as safe to prevent this.
if [ -n "${GITHUB_WORKSPACE}" ]; then
    echo "INFO: Marking '${GITHUB_WORKSPACE}' as a safe git directory..."
    git config --global --add safe.directory "${GITHUB_WORKSPACE}"
fi

# --- 配置变量 ---
echo "INFO: Reading configuration from environment variables..."
ROOTFS_FILENAME="${ROOTFS_NAME:-fedora-42-nabu-rootfs.img}"
EFI_ZIP_NAME="efi-files.zip"

# --- 路径定义 ---
ARTIFACTS_DIR="artifacts"
# actions/download-artifact@v4 会为每个工件创建一个子目录。
# Since we only have one artifact now, its path is predictable.
ROOTFS_PATH="${ARTIFACTS_DIR}/rootfs-artifact/${ROOTFS_FILENAME}"
ROOTFS_COMPRESSED_PATH="${ROOTFS_PATH}.xz"

# --- 临时目录和挂载点 ---
ROOTFS_MNT_POINT=$(mktemp -d)
EFI_BUILD_DIR=$(mktemp -d)
EFI_IMG_PATH="${EFI_BUILD_DIR}/esp.img"
EFI_MNT_POINT="${EFI_BUILD_DIR}/esp"
mkdir -p "$EFI_MNT_POINT"

# --- 清理函数 ---
cleanup() {
    echo "INFO: Performing cleanup..."
    # sync
    # Unmount quietly, ignoring errors if it's not mounted
    umount "$ROOTFS_MNT_POINT" 2>/dev/null || true
    umount "$EFI_MNT_POINT" 2>/dev/null || true
    # Remove temporary directories
    rm -rf "$ROOTFS_MNT_POINT" "$EFI_BUILD_DIR"
    echo "INFO: Cleanup complete."
}
# Register the cleanup function to run on script exit (normal or error)
trap cleanup EXIT

# --- 脚本主逻辑 ---

# 1. 检查 rootfs 文件是否存在
echo "INFO: Verifying presence of rootfs artifact..."
if [ ! -f "$ROOTFS_PATH" ]; then
    echo "ERROR: Rootfs artifact not found at '$ROOTFS_PATH'!"
    echo "--- Listing contents of ARTIFACTS_DIR ('${ARTIFACTS_DIR}') ---"
    ls -R "${ARTIFACTS_DIR}"
    echo "--------------------------------------------------------"
    exit 1
fi
echo "INFO: Rootfs artifact found."

# 2. 创建一个临时的 FAT32 镜像作为 ESP
ESP_SIZE_MB=100
echo "INFO: Creating a temporary ${ESP_SIZE_MB}MB FAT32 image for the ESP..."
fallocate -l "${ESP_SIZE_MB}M" "$EFI_IMG_PATH"
mkfs.vfat -F 32 "$EFI_IMG_PATH"
mount -o loop "$EFI_IMG_PATH" "$EFI_MNT_POINT"
echo "INFO: Temporary ESP image mounted at '${EFI_MNT_POINT}'."

# 3. 挂载 Rootfs 镜像并提取 EFI 文件到 ESP 镜像中
echo "INFO: Mounting rootfs image to extract EFI files..."
mount -o loop,ro "$ROOTFS_PATH" "$ROOTFS_MNT_POINT"

ROOTFS_EFI_CONTENT="${ROOTFS_MNT_POINT}/boot/efi/"
if [ ! -d "$ROOTFS_EFI_CONTENT" ] || [ -z "$(ls -A "$ROOTFS_EFI_CONTENT")" ]; then
    echo "ERROR: The directory '$ROOTFS_EFI_CONTENT' in rootfs is empty or does not exist." >&2
    echo "ERROR: This indicates a problem in the rootfs creation step." >&2
    exit 1
fi

echo "INFO: Copying EFI content from rootfs to temporary ESP..."
rsync -a "$ROOTFS_EFI_CONTENT" "$EFI_MNT_POINT/"

# 提取完成后立即卸载 rootfs
echo "INFO: Unmounting rootfs image..."
umount "$ROOTFS_MNT_POINT"

# 4. 安装 systemd-boot 到 ESP 镜像
echo "INFO: Installing systemd-boot into the ESP image..."
if ! bootctl --esp-path="$EFI_MNT_POINT" install; then
    echo "ERROR: bootctl install failed." >&2
    echo "--- Listing contents of EFI_MNT_POINT ('${EFI_MNT_POINT}') ---"
    ls -R "${EFI_MNT_POINT}"
    echo "--------------------------------------------------------"
    exit 1
fi
echo "INFO: systemd-boot installed successfully."

# 5. 创建 EFI zip 压缩包
echo "INFO: Creating '${EFI_ZIP_NAME}'..."
# Runnin' the zip command in a subshell. This prevents 'cd' from affecting the
# main script's working directory. The zip is created in the original PWD.
ORIGINAL_PWD=$PWD
(cd "$EFI_MNT_POINT" && zip -r "$ORIGINAL_PWD/${EFI_ZIP_NAME}" .)
echo "INFO: EFI zip package created successfully."

# 5. 将 rootfs img 文件高效压缩为 .xz
echo "INFO: Compressing '${ROOTFS_PATH}' using xz with multi-threading..."
xz -T0 -v "$ROOTFS_PATH"
echo "INFO: Compression successful. Output: '${ROOTFS_COMPRESSED_PATH}'"

# 6. 检查压缩文件和 zip 包是否存在
if [ ! -f "$ROOTFS_COMPRESSED_PATH" ]; then
    echo "ERROR: Compressed rootfs file was not created!"
    exit 1
fi
if [ ! -f "$EFI_ZIP_NAME" ]; then
    echo "ERROR: EFI zip file was not created!"
    exit 1
fi

# 7. 准备创建 Release
TAG="release-42.1-$(date +'%Y%m%d-%H%M')"
RELEASE_TITLE="Fedora for Nabu 42.1-$(date +'%Y%m%d-%H%M')"
# 生成新的发布说明
COMMIT_URL="${GITHUB_SERVER_URL:-https://github.com}/${GITHUB_REPOSITORY:-your/repo}/commit/${GITHUB_SHA:-HEAD}"
RELEASE_NOTES=$(cat <<EOF
Automated build of Fedora 42 for Xiaomi Pad 5 (nabu).

**Assets:**

- ${ROOTFS_FILENAME}.xz - The compressed rootfs image. Decompress before use.
- ${EFI_ZIP_NAME} - Contains the bootloader and kernel (UKI) and systemed-boot. Unzip and copy the contents to your existing ESP partition. See the tutorial for details.

This build is based on commit: [${GITHUB_SHA:0:7}](${COMMIT_URL})
EOF
)

# 8. 创建 Release 并上传资产
echo "INFO: Creating GitHub release '${TAG}'..."
gh release create "$TAG" \
    --title "$RELEASE_TITLE" \
    --notes "$RELEASE_NOTES" \
    --latest \
    "$ROOTFS_COMPRESSED_PATH" \
    "$EFI_ZIP_NAME"
# test发布设置为prerelease

echo "SUCCESS: Release ${TAG} created successfully with assets."
