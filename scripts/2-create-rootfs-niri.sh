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
RELEASEVER="44"
ARCH="aarch64"
BUILD_VERSION="${BUILD_VERSION}"
ROOTFS_NAME="fedora-${BUILD_VERSION}-nabu-rootfs-${VARIANT_NAME}.img"
ROOTFS_COMPRESSED_NAME="${ROOTFS_NAME}.zst"
IMG_SIZE="7G" # Btrfs needs a bit more space for metadata initially

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
echo "Installing from nabu_fedora_packages..."
dnf install -y \
    --releasever=$RELEASEVER \
    --nogpgcheck \
    --setopt=install_weak_deps=False \
    --repofrompath="nabu-fedora-packages,https://download.copr.fedorainfracloud.org/results/jhuang6451/nabu_fedora_packages_test/fedora-$RELEASEVER-$ARCH/" \
    swaylock-effects \
    wvkbd \
    sddm-astronaut-theme \
    nabu-fedora-configs-niri

echo "Installing basic & experience packages..."
dnf install -y \
    --releasever=$RELEASEVER \
    --nogpgcheck \
    --setopt=install_weak_deps=False \
    @standard \
    @base-graphical \
    chrony \
    nautilus \
    helium-browser \
    fcitx5 \
    fcitx5-configtool \
    fcitx5-gtk \
    fcitx5-qt \
    fcitx5-chinese-addons

echo "Installing from yalter/niri..."
dnf install -y \
    --releasever=$RELEASEVER \
    --nogpgcheck \
    --setopt=install_weak_deps=False \
    --repofrompath="niri,https://download.copr.fedorainfracloud.org/results/yalter/niri/fedora-$RELEASEVER-$ARCH/" \
    --exclude alacritty \
    --exclude swaybg \
    --exclude swaylock \
    niri

echo "Installing from solopasha/hyprland..."
dnf install -y \
    --releasever=$RELEASEVER \
    --nogpgcheck \
    --setopt=install_weak_deps=False \
    --repofrompath="hyprland,https://download.copr.fedorainfracloud.org/results/solopasha/hyprland/fedora-$RELEASEVER-$ARCH/" \
    swww \
    waypaper

echo "Installing from jhuang6451/nerd-fonts..."
dnf install -y \
    --releasever=$RELEASEVER \
    --nogpgcheck \
    --setopt=install_weak_deps=False \
    agave-nf \
    maple-mono-normal-nf

echo "Installing other tools for niri..."
dnf install -y \
    --releasever=$RELEASEVER \
    --nogpgcheck \
    --setopt=install_weak_deps=False \
    waybar \
    fuzzel \
    mako \
    swayidle \
    kitty \
    fastfetch

echo "Configuring Copr repository..."
dnf copr enable -y yalter/niri
dnf copr enable -y solopasha/hyprland

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

# 5. 将 rootfs 打包为 img 文件
echo "Creating Btrfs rootfs image: $ROOTFS_NAME (size: $IMG_SIZE)..."
truncate -s "$IMG_SIZE" "$ROOTFS_NAME"
mkfs.btrfs -L fedora_root "$ROOTFS_NAME"

MOUNT_DIR=$(mktemp -d)
mount -o loop "$ROOTFS_NAME" "$MOUNT_DIR"

echo "Creating Btrfs subvolumes..."
btrfs subvolume create "$MOUNT_DIR/@root"
btrfs subvolume create "$MOUNT_DIR/@home"
btrfs subvolume create "$MOUNT_DIR/@var"
btrfs subvolume create "$MOUNT_DIR/@log"
btrfs subvolume create "$MOUNT_DIR/@cache"

# 准备挂载点以进行内容复制
TARGET_DIR=$(mktemp -d)
mount -o loop,subvol=@root "$ROOTFS_NAME" "$TARGET_DIR"
mkdir -p "$TARGET_DIR"/{home,var}
mount -o loop,subvol=@home "$ROOTFS_NAME" "$TARGET_DIR/home"
mount -o loop,subvol=@var "$ROOTFS_NAME" "$TARGET_DIR/var"
mkdir -p "$TARGET_DIR/var"/{log,cache}
mount -o loop,subvol=@log "$ROOTFS_NAME" "$TARGET_DIR/var/log"
mount -o loop,subvol=@cache "$ROOTFS_NAME" "$TARGET_DIR/var/cache"

echo "Copying rootfs contents to subvolumes..."
rsync -aHAXx --info=progress2 "$ROOTFS_DIR/" "$TARGET_DIR/"

echo "Unmounting subvolumes and image..."
umount "$TARGET_DIR/var/cache"
umount "$TARGET_DIR/var/log"
umount "$TARGET_DIR/var"
umount "$TARGET_DIR/home"
umount "$TARGET_DIR"
umount "$MOUNT_DIR"
rmdir "$TARGET_DIR" "$MOUNT_DIR"
sync

# 6. Btrfs 镜像优化
echo "Optimizing Btrfs image..."
mount -o loop "$ROOTFS_NAME" "$MOUNT_DIR"
btrfs filesystem defragment -r "$MOUNT_DIR"
sync
umount "$MOUNT_DIR"
rmdir "$MOUNT_DIR"

# 7. 压缩 img 文件
echo "INFO: Compressing '${ROOTFS_NAME}' using zstd..."
# -T0 使用所有可用线程，-v 显示进度
zstd -T0 -v "${ROOTFS_NAME}"

echo "=============================================================================="
echo "✅ Compressed niri rootfs image created successfully: $ROOTFS_COMPRESSED_NAME"
echo "=============================================================================="