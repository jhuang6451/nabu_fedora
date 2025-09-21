#!/bin/bash
# ==============================================================================
# 3_create_esp.sh (v1.0)
#
# 功能:
#   1. 创建并格式化 ESP 镜像。
#   2. 安装 systemd-boot 引导加载程序到 ESP。
#   3. 将 rootfs 中由 kernel-install 管理的整个 /boot/efi 目录内容
#      (包括 UKIs, loader configs) 同步到 ESP。
# ==============================================================================

set -e
set -u
set -o pipefail

# --- 变量定义 ---
ESP_NAME="esp.img"
ESP_SIZE_MB=512
ROOTFS_NAME="fedora-42-nabu-rootfs.img"
ROOTFS_MNT_POINT=$(mktemp -d)
ESP_MNT_POINT=$(mktemp -d)

cleanup() {
    echo "INFO: Performing cleanup..."
    umount -l "$ESP_MNT_POINT" 2>/dev/null || true
    umount -l "$ROOTFS_MNT_POINT" 2>/dev/null || true
    rmdir "$ESP_MNT_POINT" 2>/dev/null || true
    rmdir "$ROOTFS_MNT_POINT" 2>/dev/null || true
    echo "INFO: Cleanup complete."
}
trap cleanup EXIT

# 1. 创建并挂载 ESP
echo "INFO: Creating ESP image '$ESP_NAME'..."
fallocate -l "${ESP_SIZE_MB}M" "$ESP_NAME"
mkfs.vfat -F 32 -n "ESP" "$ESP_NAME"
mount -o loop "$ESP_NAME" "$ESP_MNT_POINT"
echo "INFO: ESP mounted at '$ESP_MNT_POINT'."

# 2. 安装 systemd-boot 到 ESP
# 这会将 UEFI 引导程序 (BOOTAA64.EFI) 安装到 ESP 的标准路径
echo "INFO: Installing systemd-boot to the ESP..."
bootctl --esp-path="$ESP_MNT_POINT" install

# 3. 以只读方式挂载 Rootfs
echo "INFO: Mounting rootfs image '$ROOTFS_NAME'..."
mount -o loop,ro "$ROOTFS_NAME" "$ROOTFS_MNT_POINT"
echo "INFO: Rootfs mounted at '$ROOTFS_MNT_POINT'."

# 4. 将 rootfs 中 /boot/efi 的内容同步到 ESP
ROOTFS_EFI_CONTENT="${ROOTFS_MNT_POINT}/boot/efi/"
if [ ! -d "$ROOTFS_EFI_CONTENT" ] || [ -z "$(ls -A "$ROOTFS_EFI_CONTENT")" ]; then
    echo "ERROR: The directory '$ROOTFS_EFI_CONTENT' in rootfs is empty or does not exist." >&2
    echo "ERROR: Please ensure 'kernel-install' ran successfully in the previous step." >&2
    exit 1
fi

echo "INFO: Syncing EFI content (UKIs, loader configs) from rootfs to ESP..."
# 使用 rsync 将所有由 kernel-install 生成的文件和目录 (EFI/Linux, loader/)
# 复制到 ESP 分区中。
rsync -a "$ROOTFS_EFI_CONTENT" "$ESP_MNT_POINT/"

echo "SUCCESS: ESP image '$ESP_NAME' created and populated with a full systemd-boot environment."
exit 0