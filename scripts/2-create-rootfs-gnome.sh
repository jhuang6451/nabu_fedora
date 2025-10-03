#!/bin/bash

# ==============================================================================
# 2-create-rootfs-gnome.sh
#
# 功能: 在基础 rootfs 之上安装 GNOME 桌面环境，并打包成最终的镜像文件。
#
# 作者: jhuang6451
# 版本: 2.0
# ==============================================================================

set -e

# 检查是否提供了基础 rootfs 目录
if [ -z "$1" ]; then
    echo "错误: 基础 rootfs 目录的路径未提供。" >&2
    exit 1
fi

# 定义变量
BASE_ROOTFS_DIR="$1"
VARIANT_NAME="gnome"
ROOTFS_DIR="$PWD/fedora-rootfs-$VARIANT_NAME"
RELEASEVER="42"
ARCH="aarch64"
BUILD_VERSION="${BUILD_VERSION:-42.2}"
ROOTFS_NAME="fedora-${BUILD_VERSION}-nabu-rootfs-${VARIANT_NAME}.img"
IMG_SIZE="8G"

# 1. 从基础 rootfs 复制
echo "Creating $VARIANT_NAME rootfs from base..."
rm -rf "$ROOTFS_DIR" # 清理旧目录
cp -a "$BASE_ROOTFS_DIR" "$ROOTFS_DIR"

# Mount/Unmount 函数
mount_chroot_fs() {
    mount --bind /proc "$ROOTFS_DIR/proc"
    mount --bind /sys "$ROOTFS_DIR/sys"
    mount --bind /dev "$ROOTFS_DIR/dev"
    mount --bind /dev/pts "$ROOTFS_DIR/dev/pts"
}
umount_chroot_fs() {
    umount "$ROOTFS_DIR/dev/pts" || true
    umount "$ROOTFS_DIR/dev" || true
    umount "$ROOTFS_DIR/sys" || true
    umount "$ROOTFS_DIR/proc" || true
}
trap umount_chroot_fs EXIT

# 2. 挂载 chroot 所需的文件系统
echo "Mounting filesystems for chroot..."
mount_chroot_fs

# 3. 在 Chroot 环境中安装 GNOME 等软件包以及配置
echo "Installing GNOME desktop environment inside chroot..."
chroot "$ROOTFS_DIR" /bin/bash <<CHROOT_SCRIPT
set -e

echo "Installing GNOME desktop and additional packages..."
dnf install -y \
    --releasever=$RELEASEVER \
    --nogpgcheck \
    --setopt=install_weak_deps=False \
    --repofrompath="jhuang6451-copr,https://download.copr.fedorainfracloud.org/results/jhuang6451/nabu_fedora_packages_uefi/fedora-$RELEASEVER-$ARCH/" \
    --exclude gnome-boxes \
    --exclude gnome-connections \
    --exclude yelp \
    --exclude gnome-classic-session \
    --exclude gnome-maps \
    --exclude gnome-user-docs \
    --exclude gnome-weather \
    --exclude simple-scan \
    --exclude snapshot \
    --exclude gnome-tour \
    --exclude malcontent-control \
    @standard \
    @base-graphical \
    @gnome-desktop \
    firefox \
    fcitx5 \
    fcitx5-configtool \
    fcitx5-gtk \
    fcitx5-qt \
    fcitx5-chinese-addons \
    glibc-langpack-zh \
    nabu-fedora-configs-gnome
    

echo "Cleaning dnf cache..."
dnf clean all

CHROOT_SCRIPT

# 4. 卸载文件系统
echo "Unmounting chroot filesystems..."
umount_chroot_fs
trap - EXIT
sync

# 5. 将 rootfs 打包为 img 文件
echo "Creating rootfs image: $ROOTFS_NAME (size: $IMG_SIZE)..."
fallocate -l "$IMG_SIZE" "$ROOTFS_NAME"
mkfs.ext4 -L fedora_root -F "$ROOTFS_NAME"
MOUNT_DIR=$(mktemp -d)
trap 'umount "$MOUNT_DIR" &>/dev/null; rmdir -- "$MOUNT_DIR"' EXIT
mount -o loop "$ROOTFS_NAME" "$MOUNT_DIR"

echo "Copying rootfs contents to image..."
rsync -aHAXx --info=progress2 "$ROOTFS_DIR/" "$MOUNT_DIR/"

echo "Unmounting image..."
umount "$MOUNT_DIR"
rmdir "$MOUNT_DIR"
trap - EXIT
sync

# 6. 最小化并压缩 img 文件
echo "Minimizing the image file..."
e2fsck -f -y "$ROOTFS_NAME" || true
resize2fs -M "$ROOTFS_NAME"
e2fsck -f -y "$ROOTFS_NAME" || true

MIN_BLOCKS=$(dumpe2fs -h "$ROOTFS_NAME" 2>/dev/null | grep 'Block count:' | awk '{print $3}')
BLOCK_SIZE_KB=$(dumpe2fs -h "$ROOTFS_NAME" 2>/dev/null | grep 'Block size:' | awk '{print $3 / 1024}')

if ! [[ "$MIN_BLOCKS" =~ ^[0-9]+$ ]] || ! [[ "$BLOCK_SIZE_KB" =~ ^[0-9]+$ ]]; then
    echo "Error: Failed to retrieve block size or block count from image." >&2
    exit 1
fi

MIN_SIZE_KB=$((MIN_BLOCKS * BLOCK_SIZE_KB))
SAFETY_MARGIN_KB=204800
NEW_SIZE_KB=$((MIN_SIZE_KB + SAFETY_MARGIN_KB))

truncate -s "${NEW_SIZE_KB}K" "$ROOTFS_NAME"
resize2fs "$ROOTFS_NAME"

echo "=============================================================================="
echo "GNOME rootfs image created successfully: $ROOTFS_NAME"
echo "=============================================================================="