#!/bin/bash

# ==============================================================================
# 4_create_release.sh
#
# 功能:
#   1. 从环境变量获取文件名，使其更具灵活性。
#   2. 修正文件路径以匹配 actions/download-artifact@v4 的行为。
#   3. 使用 xz 对 rootfs 镜像进行高效压缩。
#   4. 创建一个带有动态信息的 GitHub Release 并上传资产。
#
# 作者: jhuang6451
# 版本: 1.0
# ==============================================================================

set -e
set -u
set -o pipefail

# --- 配置变量 (从环境变量读取，如果未设置则使用默认值) ---
echo "INFO: Reading configuration from environment variables..."
ROOTFS_FILENAME="${ROOTFS_NAME:-fedora-42-nabu-rootfs.img}"
ESP_FILENAME="${ESP_NAME:-esp.img}"

# --- 路径定义 ---
# 这是下载工件的根目录
ARTIFACTS_DIR="artifacts"

# --- 已修改：在与工件名称匹配的子目录中查找文件 ---
# actions/download-artifact@v4 会为每个工件创建一个子目录。
ROOTFS_PATH="${ARTIFACTS_DIR}/rootfs-artifact/${ROOTFS_FILENAME}"
ESP_PATH="${ARTIFACTS_DIR}/esp-artifact/${ESP_FILENAME}"

# 输出的压缩文件名将是原始文件名加上 .xz 后缀
ROOTFS_COMPRESSED_PATH="${ROOTFS_PATH}.xz"

# --- 脚本主逻辑 ---

# 1. 检查原始文件是否存在
echo "INFO: Verifying presence of artifact files..."
if [ ! -f "$ROOTFS_PATH" ]; then
    echo "ERROR: Rootfs artifact not found at '$ROOTFS_PATH'!"
    # 添加一个 ls 命令来帮助调试，这在 CI 环境中非常有用
    echo "--- Listing contents of ARTIFACTS_DIR ('${ARTIFACTS_DIR}') ---"
    ls -R "${ARTIFACTS_DIR}"
    echo "--------------------------------------------------------"
    exit 1
fi
if [ ! -f "$ESP_PATH" ]; then
    echo "ERROR: ESP artifact not found at '$ESP_PATH'!"
    exit 1
fi
echo "INFO: All artifact files found."

# 2. 将 rootfs img 文件高效压缩为 .xz
echo "INFO: Compressing '${ROOTFS_PATH}' using xz with multi-threading..."
xz -T0 -v "$ROOTFS_PATH"
echo "INFO: Compression successful. Output: '${ROOTFS_COMPRESSED_PATH}'"

# 将 ESP img 文件也进行压缩
echo "INFO: Compressing '${ESP_PATH}' using xz with multi-threading..."
ESP_COMPRESSED_PATH="${ESP_PATH}.xz"
xz -T0 -v "$ESP_PATH"
echo "INFO: Compression successful. Output: '${ESP_COMPRESSED_PATH}'"

# 3. 检查压缩文件是否存在
if [ ! -f "$ROOTFS_COMPRESSED_PATH" ]; then
    echo "ERROR: Compressed rootfs file was not created!"
    exit 1
fi
# --- 新增检查 ---
if [ ! -f "$ESP_COMPRESSED_PATH" ]; then
    echo "ERROR: Compressed ESP file was not created!"
    exit 1
fi


# 4. 准备创建 Release
TAG="test-fedora-nabu-$(date +'%Y%m%d-%H%M')"
RELEASE_TITLE="[Test Release] Fedora 42 for Mi Pad 5 (nabu) - ${TAG}"

# 生成更丰富的发布说明
COMMIT_URL="${GITHUB_SERVER_URL:-https://github.com}/${GITHUB_REPOSITORY:-your/repo}/commit/${GITHUB_SHA:-HEAD}"
RELEASE_NOTES=$(cat <<-EOF
Automated build of Fedora 42 for Xiaomi Pad 5 (nabu).

**THIS IS A TEST BUILD - USE AT YOUR OWN RISK**

**Assets:**
- \`${ROOTFS_FILENAME}.xz\`: The compressed rootfs image. Decompress before use.
- \`${ESP_FILENAME}.xz\`: The compressed ESP image. Decompress before use.

This build is based on commit: [${GITHUB_SHA:0:7}](${COMMIT_URL})
EOF
)

# 5. 创建 Release 并上传资产
echo "INFO: Creating GitHub release '${TAG}'..."
gh release create "$TAG" \
    --title "$RELEASE_TITLE" \
    --notes "$RELEASE_NOTES" \
    "$ROOTFS_COMPRESSED_PATH" \
    "$ESP_COMPRESSED_PATH"

echo "SUCCESS: Release ${TAG} created successfully with assets."