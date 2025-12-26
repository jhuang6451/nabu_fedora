#!/bin/bash

# ==============================================================================
# 2-create-rootfs-niri.sh
#
# 功能: 在基础 rootfs 之上安装 niri 合成器，并打包成最终的镜像文件。
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
VARIANT_NAME="niri"
ROOTFS_DIR="$PWD/fedora-rootfs-$VARIANT_NAME"
RELEASEVER="43"
ARCH="aarch64"
BUILD_VERSION="${BUILD_VERSION}"
ROOTFS_NAME="fedora-${BUILD_VERSION}-nabu-rootfs-${VARIANT_NAME}.img"
ROOTFS_COMPRESSED_NAME="${ROOTFS_NAME}.zst"
IMG_SIZE="5G"

SUDOERS_FILE="/etc/sudoers.d/99-wheel-user"

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

# 3. 在 Chroot 环境中安装特定软件包以及配置
echo "Installing packages inside chroot..."
chroot "$ROOTFS_DIR" /bin/bash <<CHROOT_SCRIPT
set -e

# ==========================================================================
# --- 安装软件包和配置 ---
# ==========================================================================
# echo "Installing config files..."
# dnf install -y \
#     --releasever=$RELEASEVER \
#     --nogpgcheck \
#     --setopt=install_weak_deps=False \
#     --repofrompath="nabu-fedora-packages,https://download.copr.fedorainfracloud.org/results/jhuang6451/nabu_fedora_packages/fedora-$RELEASEVER-$ARCH/" \
#     nabu-fedora-configs-niri

echo "Installing testing config files..."
dnf install -y \
    --releasever=$RELEASEVER \
    --nogpgcheck \
    --setopt=install_weak_deps=False \
    --repofrompath="nabu-fedora-packages-test,https://download.copr.fedorainfracloud.org/results/jhuang6451/nabu_fedora_packages_test/fedora-$RELEASEVER-$ARCH/" \
    nabu-fedora-configs-niri

echo "Installing basic packages..."
dnf install -y \
    --releasever=$RELEASEVER \
    --nogpgcheck \
    --setopt=install_weak_deps=False \
    @standard \
    @base-graphical \
    chrony

echo "Installing experience packages..."
dnf install -y \
    --releasever=$RELEASEVER \
    --nogpgcheck \
    --setopt=install_weak_deps=False \
    nautilus \
    fcitx5 \
    fcitx5-configtool \
    fcitx5-gtk \
    fcitx5-qt \
    fcitx5-chinese-addons \
    fastfetch \
    kitty \
    qt6-multimedia \
    wl-clipboard \
    cava \
    mate-polkit \
    greetd

echo "Installing niri..."
dnf install -y \
    --releasever=$RELEASEVER \
    --nogpgcheck \
    --setopt=install_weak_deps=False \
    --repofrompath="niri,https://download.copr.fedorainfracloud.org/results/yalter/niri/fedora-$RELEASEVER-$ARCH/" \
    --exclude alacritty \
    --exclude swaybg \
    --exclude swaylock \
    niri

echo "Installing DMS..."
dnf install -y \
    --releasever=$RELEASEVER \
    --nogpgcheck \
    --setopt=install_weak_deps=False \
    --repofrompath="danklinux,https://download.copr.fedorainfracloud.org/results/avengemedia/danklinux/fedora-$RELEASEVER-$ARCH/" \
    --repofrompath="dms,https://download.copr.fedorainfracloud.org/results/avengemedia/dms/fedora-$RELEASEVER-$ARCH/" \
    dms \
    quickshell \
    matugen \
    dms-greeter \
    cliphist \
    danksearch \
    dgop

# ==========================================================================
# --- 配置 Copr ---
# ==========================================================================
echo "Configuring Copr repository..."
dnf copr enable -y avengemedia/danklinux
dnf copr enable -y avengemedia/dms

# ==========================================================================
# --- 创建临时用户 ---
# ==========================================================================
echo 'Adding temporary user "user" with sudo privileges...'
useradd --create-home --groups wheel user
echo 'user:fedora' | chpasswd
SUDOERS_FILE="/etc/sudoers.d/99-wheel-user"
echo '%wheel ALL=(ALL) ALL' > "$SUDOERS_FILE"
chmod 0440 "$SUDOERS_FILE"
echo "Sudo access for group 'wheel' has been configured."

# ==========================================================================
# --- 应用 Systemd Preset 设置 ---
# ==========================================================================
echo "Applying systemd presets..."
systemctl preset-all
systemctl set-default graphical.target
echo "Systemd presets applied."

# ==========================================================================
# --- 清理 DNF 缓存 ---
# ==========================================================================
echo "Cleaning dnf cache..."
dnf clean all

CHROOT_SCRIPT

# 4. 卸载文件系统
echo "Unmounting chroot filesystems..."
umount_chroot_fs
trap - EXIT
sync

# 5. 创建文件系统，并将 rootfs 打包为 img 文件
echo "Creating btrfs rootfs image: $ROOTFS_NAME (size: $IMG_SIZE)..."
fallocate -l "$IMG_SIZE" "$ROOTFS_NAME"
mkfs.btrfs -L fedora_root "$ROOTFS_NAME"

MOUNT_DIR=$(mktemp -d)

umount_btrfs() {
    echo "Cleaning up..."
    umount -l "$MOUNT_DIR/var/cache" 2>/dev/null || true
    umount -l "$MOUNT_DIR/var/log" 2>/dev/null || true
    umount -l "$MOUNT_DIR/home" 2>/dev/null || true
    umount -l "$MOUNT_DIR" 2>/dev/null || true
    rmdir -- "$MOUNT_DIR"
}
trap umount_btrfs EXIT

echo "Creating subvolumes: @, @home, @log, @cache..."
mount "$ROOTFS_NAME" "$MOUNT_DIR"
btrfs subvolume create "$MOUNT_DIR/@"
btrfs subvolume create "$MOUNT_DIR/@home"
btrfs subvolume create "$MOUNT_DIR/@log"
btrfs subvolume create "$MOUNT_DIR/@cache"
umount "$MOUNT_DIR"

echo "Mounting subvolumes..."
mount -o subvol=@ "$ROOTFS_NAME" "$MOUNT_DIR"
mkdir -p "$MOUNT_DIR/home"
mkdir -p "$MOUNT_DIR/var/log"
mkdir -p "$MOUNT_DIR/var/cache"
mount -o subvol=@home "$ROOTFS_NAME" "$MOUNT_DIR/home"
mount -o subvol=@log "$ROOTFS_NAME" "$MOUNT_DIR/var/log"
mount -o subvol=@cache "$ROOTFS_NAME" "$MOUNT_DIR/var/cache"

echo "Copying rootfs contents to image..."
rsync -aHAXx --info=progress2 "$ROOTFS_DIR/" "$MOUNT_DIR/"

echo "Minimizing the Btrfs image..."
sync
USED_SIZE=$(btrfs inspect-internal min-dev-size "$MOUNT_DIR" | awk '{print $1}')
SAFETY_MARGIN=$((500 * 1024 * 1024))
NEW_FS_SIZE=$((USED_SIZE + SAFETY_MARGIN))

echo "Resizing filesystem to ${NEW_FS_SIZE} bytes..."
btrfs filesystem resize "$NEW_FS_SIZE" "$MOUNT_DIR"

umount_btrfs
trap - EXIT

# 6. 截断 img 文件多余空间
echo "Truncating image file..."
truncate -s "$NEW_FS_SIZE" "$ROOTFS_NAME"

# 7. 压缩 img 文件
echo "INFO: Compressing '${ROOTFS_NAME}' using zstd..."
# -T0 使用所有可用线程，-v 显示进度
zstd -T0 -v "${ROOTFS_NAME}"

echo "=============================================================================="
echo "✅ Compressed niri rootfs image created successfully: $ROOTFS_COMPRESSED_NAME"
echo "=============================================================================="