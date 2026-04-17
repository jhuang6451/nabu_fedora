#!/bin/bash

# ==============================================================================
# extract-and-pack.sh
#
# 功能:
#   1. 使用 bootc-image-builder 从 OCI 镜像生成 raw 磁盘镜像。
#   2. 通过 sfdisk 解析分区表，用 dd 提取 rootfs 分区。
#   3. 从 OCI 镜像中提取 UKI 和 dualboot EFI 文件，合成 esp.img。
#   4. 压缩输出文件。
#
# 用法:
#   ./extract-and-pack.sh <OCI_IMAGE_REF> [BUILD_VERSION]
#
# 示例:
#   ./extract-and-pack.sh localhost/nabu-fedora:base 43.1
#
# 作者: jhuang6451
# ==============================================================================

set -euo pipefail

# --- 参数解析 ---
OCI_IMAGE="${1:?ERROR: OCI image reference is required. Usage: $0 <image> [version]}"
BUILD_VERSION="${2:-0.0}"

# --- 配置 ---
RAW_OUTPUT_DIR="./output"
RAW_IMAGE="${RAW_OUTPUT_DIR}/disk.raw"
CONFIG_TOML="./scripts/config.toml"

ROOTFS_IMG="fedora-${BUILD_VERSION}-nabu-rootfs.img"
ESP_IMG="esp-${BUILD_VERSION}.img"

# ESP 参数 (与现有方案对齐)
ESP_SIZE_BYTES=350105600
ESP_LOGICAL_SECTOR=4096
ESP_SECTORS_PER_CLUSTER=1
ESP_RESERVED_SECTORS=32
ESP_HIDDEN_SECTORS=21234176
ESP_VOLUME_LABEL="ESPNABU"
ESP_VOLUME_ID="5C7A09AD"

# --- 清理函数 ---
cleanup() {
    echo "INFO: Cleaning up temporary files..."
    rm -rf "${RAW_OUTPUT_DIR}" "${MOUNT_DIR:-}" "${ESP_MOUNT:-}"
}
trap cleanup EXIT

# ==============================================================================
# 步骤 1: 使用 bootc-image-builder 生成 raw 磁盘镜像
# ==============================================================================
echo ">>> [1/5] Building raw disk image from ${OCI_IMAGE}..."
mkdir -p "${RAW_OUTPUT_DIR}"

# bootc-image-builder 在容器中运行，需要 --privileged
# 使用 --local 标志表示镜像来自本地存储而非远端 registry
podman run \
    --rm \
    --privileged \
    --pull=newer \
    --security-opt label=type:unconfined_t \
    -v "${RAW_OUTPUT_DIR}:/output" \
    -v /var/lib/containers/storage:/var/lib/containers/storage \
    -v "$(realpath ${CONFIG_TOML}):/config.toml:ro" \
    quay.io/centos-bootc/bootc-image-builder:latest \
    --type raw \
    --config /config.toml \
    --local \
    "${OCI_IMAGE}"

if [ ! -f "${RAW_IMAGE}" ]; then
    # bootc-image-builder 可能输出到子目录
    RAW_IMAGE=$(find "${RAW_OUTPUT_DIR}" -name "*.raw" -type f | head -1)
    if [ -z "${RAW_IMAGE}" ]; then
        echo "❎ ERROR: No raw image found in ${RAW_OUTPUT_DIR}" >&2
        ls -lR "${RAW_OUTPUT_DIR}" >&2
        exit 1
    fi
fi
echo "✅ Raw image generated: ${RAW_IMAGE}"

# ==============================================================================
# 步骤 2: 使用 sfdisk 解析分区表并用 dd 提取 rootfs
# ==============================================================================
echo ">>> [2/5] Extracting rootfs partition from raw image..."

# 使用 sfdisk -J 获取 JSON 格式的分区表
PART_JSON=$(sfdisk -J "${RAW_IMAGE}")

# 获取扇区大小
SECTOR_SIZE=$(echo "${PART_JSON}" | python3 -c "
import json, sys
pt = json.load(sys.stdin)['partitiontable']
print(pt.get('sectorsize', 512))
")

# 查找最大的分区（即 rootfs 分区）
# ESP 通常很小（~几百MB），rootfs 是最大的那个
read -r ROOT_START ROOT_SIZE <<< $(echo "${PART_JSON}" | python3 -c "
import json, sys
pt = json.load(sys.stdin)['partitiontable']
parts = pt['partitions']
# 按大小排序，取最大的分区作为 rootfs
largest = max(parts, key=lambda p: p['size'])
print(largest['start'], largest['size'])
")

ROOT_OFFSET=$((ROOT_START * SECTOR_SIZE))
ROOT_BYTES=$((ROOT_SIZE * SECTOR_SIZE))

echo "  Sector size: ${SECTOR_SIZE}"
echo "  Root partition: start=${ROOT_START} sectors, size=${ROOT_SIZE} sectors"
echo "  Root offset: ${ROOT_OFFSET} bytes, total: ${ROOT_BYTES} bytes"

dd if="${RAW_IMAGE}" \
    of="${ROOTFS_IMG}" \
    bs="${SECTOR_SIZE}" \
    skip="${ROOT_START}" \
    count="${ROOT_SIZE}" \
    status=progress

echo "✅ Rootfs extracted: ${ROOTFS_IMG} ($(du -h "${ROOTFS_IMG}" | cut -f1))"

# ==============================================================================
# 步骤 3: 从 OCI 镜像中提取 EFI 文件并合成 ESP 镜像
# ==============================================================================
echo ">>> [3/5] Building ESP image from OCI container content..."

# 挂载 OCI 镜像以提取文件
CONTAINER_ID=$(podman create "${OCI_IMAGE}" /bin/true)
MOUNT_DIR=$(podman mount "${CONTAINER_ID}")

# 查找 UKI 文件 — 优先搜索 bootc-native 路径
UKI_FILES=$(find "${MOUNT_DIR}/usr/lib/modules" -path "*/uki/*.efi" -type f 2>/dev/null || true)
DUALBOOT_DIR="${MOUNT_DIR}/boot/efi/EFI"

if [ -z "${UKI_FILES}" ]; then
    echo "  No UKI in /usr/lib/modules/*/uki/, trying legacy /boot/efi/..."
    UKI_FILES=$(find "${MOUNT_DIR}/boot/efi" -name "*.efi" -path "*/fedora/*" -type f 2>/dev/null || true)
fi

if [ -z "${UKI_FILES}" ]; then
    echo "❎ ERROR: No UKI .efi files found in the container image." >&2
    exit 1
fi

# 创建 ESP 镜像
echo "  Creating FAT32 ESP image (${ESP_SIZE_BYTES} bytes)..."
truncate -s ${ESP_SIZE_BYTES} "${ESP_IMG}"

mkfs.vfat \
    -F 32 \
    -S ${ESP_LOGICAL_SECTOR} \
    -s ${ESP_SECTORS_PER_CLUSTER} \
    -R ${ESP_RESERVED_SECTORS} \
    -h ${ESP_HIDDEN_SECTORS} \
    -n "${ESP_VOLUME_LABEL}" \
    -i "${ESP_VOLUME_ID}" \
    -f 2 \
    "${ESP_IMG}"

ESP_MOUNT=$(mktemp -d)
mount -o loop "${ESP_IMG}" "${ESP_MOUNT}"

# 复制 dualboot EFI 文件 (rEFInd 等)
if [ -d "${DUALBOOT_DIR}" ]; then
    echo "  Copying dualboot EFI structure..."
    cp -r "${DUALBOOT_DIR}" "${ESP_MOUNT}/"
fi

# 复制 UKI 文件到 ESP
mkdir -p "${ESP_MOUNT}/EFI/fedora"
if [ -n "${UKI_FILES}" ]; then
    echo "  Copying UKI files..."
    for uki in ${UKI_FILES}; do
        cp "${uki}" "${ESP_MOUNT}/EFI/fedora/"
        echo "    -> $(basename ${uki})"
    done
fi

umount "${ESP_MOUNT}"
rmdir "${ESP_MOUNT}"
unset ESP_MOUNT

# 清理容器挂载
podman unmount "${CONTAINER_ID}"
podman rm "${CONTAINER_ID}"
unset MOUNT_DIR

echo "✅ ESP image created: ${ESP_IMG}"

# ==============================================================================
# 步骤 4: 压缩输出
# ==============================================================================
echo ">>> [4/5] Compressing output images with zstd..."

zstd -T0 -v "${ROOTFS_IMG}"
echo "✅ Compressed: ${ROOTFS_IMG}.zst"

zstd -T0 -v "${ESP_IMG}"
echo "✅ Compressed: ${ESP_IMG}.zst"

# ==============================================================================
# 步骤 5: 打包 EFI 文件的 zip (兼容现有发布格式)
# ==============================================================================
echo ">>> [5/5] Creating efi-files.zip for manual ESP users..."

# 重新挂载 ESP 镜像提取 zip
ESP_ZIP_MOUNT=$(mktemp -d)
mount -o loop,ro "${ESP_IMG}" "${ESP_ZIP_MOUNT}"
(cd "${ESP_ZIP_MOUNT}" && zip -r "${OLDPWD}/efi-files.zip" .)
umount "${ESP_ZIP_MOUNT}"
rmdir "${ESP_ZIP_MOUNT}"

echo "✅ Created: efi-files.zip"

# 清理未压缩的原始文件
rm -f "${ROOTFS_IMG}" "${ESP_IMG}"

echo "=============================================================================="
echo "✅ Build complete! Output files:"
echo "  - ${ROOTFS_IMG}.zst    (Rootfs image, flashable with fastboot)"
echo "  - ${ESP_IMG}.zst       (ESP image, flashable with fastboot)"
echo "  - efi-files.zip        (EFI files for manual placement)"
echo "=============================================================================="
