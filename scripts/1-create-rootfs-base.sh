#!/bin/bash

# ==============================================================================
# 1-create-rootfs-base.sh
#
# 功能: 
#   1. 为 nabu 构建一个基础的 fedora 根文件系统，包含核心软件包和内核。
#   2. 打包 efi 文件并制作esp分区镜像。
#
# 作者: jhuang6451
# 版本: 2.1
# ==============================================================================

set -e

# 定义变量
ROOTFS_DIR="$PWD/fedora-rootfs-base"
RELEASEVER="42"
ARCH="aarch64"

# 发行版本号从 Workflow 获取
BUILD_VERSION="${BUILD_VERSION}"

# Mount chroot filesystems 函数
mount_chroot_fs() {
    echo "Mounting chroot filesystems into $ROOTFS_DIR..."
    mkdir -p "$ROOTFS_DIR/proc" "$ROOTFS_DIR/sys" "$ROOTFS_DIR/dev" "$ROOTFS_DIR/dev/pts"
    mount --bind /proc "$ROOTFS_DIR/proc"
    mount --bind /sys "$ROOTFS_DIR/sys"
    mount --bind /dev "$ROOTFS_DIR/dev"
    mount --bind /dev/pts "$ROOTFS_DIR/dev/pts"
}

# Unmount chroot filesystems 函数
umount_chroot_fs() {
    echo "Unmounting chroot filesystems from $ROOTFS_DIR..."
    umount "$ROOTFS_DIR/dev/pts" || true
    umount "$ROOTFS_DIR/dev" || true
    umount "$ROOTFS_DIR/sys" || true
    umount "$ROOTFS_DIR/proc" || true
}

# 确保在脚本退出时总是尝试卸载
trap umount_chroot_fs EXIT

# 1. 创建 rootfs 目录
echo "Creating base rootfs directory: $ROOTFS_DIR"
rm -rf "$ROOTFS_DIR" # 清理旧目录
mkdir -p "$ROOTFS_DIR"

# 2. 先挂载必要的文件系统，以便后续 chroot 操作
echo "Mounting filesystems for chroot..."
mount_chroot_fs

# 创建临时 DNS 配置
echo "Temporarily setting up DNS for chroot..."
rm -f "$ROOTFS_DIR/etc/resolv.conf"
mkdir -p "$ROOTFS_DIR/etc"
cat <<EOF > "$ROOTFS_DIR/etc/resolv.conf"
nameserver 8.8.8.8
nameserver 8.8.4.4
nameserver 1.1.1.1
nameserver 1.0.0.1
EOF

# 3. 引导基础系统
echo "Bootstrapping Fedora repositories for $ARCH..."
TEMP_REPO_DIR=$(mktemp -d)
cat <<EOF > "${TEMP_REPO_DIR}/temp-fedora.repo"
[temp-fedora]
name=Temporary Fedora $RELEASEVER - $ARCH
metalink=https://mirrors.fedoraproject.org/metalink?repo=fedora-$RELEASEVER&arch=$ARCH
enabled=1
gpgcheck=0
skip_if_unavailable=False
EOF

echo "Bootstrapping base system into rootfs..."
dnf install -y --installroot="$ROOTFS_DIR" --forcearch="$ARCH" \
    --releasever="$RELEASEVER" \
    --setopt=install_weak_deps=False \
    --setopt="reposdir=${TEMP_REPO_DIR}" \
    --nogpgcheck \
    fedora-repos \
    bash \
    dnf

echo "Cleaning up temporary repository..."
rm -rf -- "$TEMP_REPO_DIR"

# 4. 在 Chroot 环境中安装和配置
echo "Running main installation and configuration inside chroot..."

run_in_chroot() {
    export RELEASEVER="$RELEASEVER"
    export ARCH="$ARCH"
    export BUILD_VERSION="$BUILD_VERSION"

    cat <<'CHROOT_SCRIPT' | chroot "$ROOTFS_DIR" /bin/bash
set -e
set -o pipefail

# ==========================================================================
# --- 安装基础软件包和配置 ---
# ==========================================================================
echo 'Installing core...'
dnf install -y --releasever=$RELEASEVER \
    --nogpgcheck \
    --setopt=install_weak_deps=False \
    --allowerasing \
    @core

echo 'Installing basic packages...'
dnf install -y --releasever=$RELEASEVER \
    --repofrompath="pocketblue,https://download.copr.fedorainfracloud.org/results/onesaladleaf/pocketblue/fedora-$RELEASEVER-$ARCH/" \
    --repofrompath="nabu_fedora_packages,https://download.copr.fedorainfracloud.org/results/jhuang6451/nabu_fedora_packages/fedora-$RELEASEVER-$ARCH/" \
    --nogpgcheck \
    --setopt=install_weak_deps=False \
    --exclude dracut-config-rescue \
    @hardware-support \
    alsa-utils \
    pulseaudio-utils \
    pipewire-pulseaudio \
    pipewire-alsa \
    systemd-boot-unsigned \
    systemd-ukify \
    xiaomi-nabu-firmware \
    binutils \
    qrtr \
    rmtfs \
    pd-mapper \
    tqftpserv \
    q6voiced \
    NetworkManager-wifi \
    glibc-langpack-en \
    qbootctl \
    nabu-fedora-configs-core
# systemd-boot-unsigned provides efi stub.

# ==========================================================================
# --- 安装额外软件包和配置 ---
# ==========================================================================
echo 'Installing extra packages...'
dnf install -y --releasever=$RELEASEVER \
    --repofrompath="pocketblue,https://download.copr.fedorainfracloud.org/results/onesaladleaf/pocketblue/fedora-$RELEASEVER-$ARCH/" \
    --repofrompath="nabu_fedora_packages,https://download.copr.fedorainfracloud.org/results/jhuang6451/nabu_fedora_packages/fedora-$RELEASEVER-$ARCH/" \
    --nogpgcheck \
    --setopt=install_weak_deps=False \
    NetworkManager-tui \
    glibc-langpack-zh \
    glibc-langpack-ru \
    vim

# ==========================================================================
# --- 配置 Copr ---
# ==========================================================================
echo "Configuring Copr repositories..."
dnf copr enable -y jhuang6451/nabu_fedora_packages
dnf copr enable -y onesaladleaf/pocketblue
dnf copr enable -y jhuang6451/jhuang6451

# ==========================================================================
# --- 安装内核 ---
# ==========================================================================
echo "Installing kernel package to trigger UKI generation..."
dnf install -y --releasever=$RELEASEVER \
    --repofrompath="nabu_fedora_packages,https://download.copr.fedorainfracloud.org/results/jhuang6451/nabu_fedora_packages/fedora-$RELEASEVER-$ARCH/" \
    --nogpgcheck \
    --setopt=install_weak_deps=False \
    kernel-sm8150

echo "Verifying UKI Generation..."
if [ -d "/boot/efi/EFI/fedora" ] && [ -n "$(find /boot/efi/EFI/fedora -name '*.efi')" ]; then
    echo "SUCCESS: UKI file(s) found!"
    ls -lR /boot/efi/
else
    echo "❎ ERROR: No UKI file found after RPM installation!" >&2
    exit 1
fi

# ==========================================================================
# --- 安装双启动efi ---
# ==========================================================================
echo 'Installing dualboot efi...'
dnf install -y --releasever=$RELEASEVER \
    --repofrompath="nabu_fedora_packages,https://download.copr.fedorainfracloud.org/results/jhuang6451/nabu_fedora_packages/fedora-$RELEASEVER-$ARCH/" \
    --nogpgcheck \
    --setopt=install_weak_deps=False \
    nabu-fedora-dualboot-efi

# ==========================================================================
# --- 清理 DNF 缓存 ---
# ==========================================================================
echo 'Cleaning dnf cache...'
dnf clean all


CHROOT_SCRIPT
}

# 执行 chroot 内的脚本
run_in_chroot

# 5. 退出 chroot 并卸载文件系统
echo "Chroot operations completed. Unmounting filesystems..."
umount_chroot_fs
trap - EXIT
sync

# 6. 打包 EFI 文件
echo "Packaging EFI files..."
EFI_DIR="$ROOTFS_DIR/boot/efi"
if [ -d "$EFI_DIR" ] && [ -n "$(ls -A "$EFI_DIR")" ]; then
    PROJECT_ROOT="$PWD"
    echo "Found EFI files to package:"
    ls -lR "$EFI_DIR"
    (cd "$EFI_DIR" && zip -r "$PROJECT_ROOT/efi-files.zip" .)
    echo "✅ EFI files packaged into efi-files.zip"

# 7. 创建可刷写的 ESP 镜像
    echo "Creating flashable ESP image (flashable_esp.img)..."
    # --- 配置参数 ---
    ESP_IMAGE="$PROJECT_ROOT/flashable_esp.img"
    IMG_SIZE_BYTES=350105600
    LOGICAL_SECTOR_SIZE=4096
    SECTORS_PER_CLUSTER=1 # (因为 Cluster Size 4096 / Sector Size 4096 = 1)
    RESERVED_SECTORS=32
    HIDDEN_SECTORS=21234176
    VOLUME_LABEL="ESPNABU"
    VOLUME_ID="5C7A09AD" # mkfs.vfat接受不带'0x'的十六进制ID

    MOUNT_POINT=$(mktemp -d)

    # --- 脚本执行 ---
    echo ">>> [1/5] Creating empty image file..."
    truncate -s ${IMG_SIZE_BYTES} ${ESP_IMAGE}

    echo ">>> [2/5] Formatting image with precise device geometry..."
    mkfs.vfat \
        -F 32 \
        -S ${LOGICAL_SECTOR_SIZE} \
        -s ${SECTORS_PER_CLUSTER} \
        -R ${RESERVED_SECTORS} \
        -h ${HIDDEN_SECTORS} \
        -n "${VOLUME_LABEL}" \
        -i "${VOLUME_ID}" \
        -f 2 \
        ${ESP_IMAGE}

    echo ">>> [3/5] Mounting the image file..."
    mount -o loop ${ESP_IMAGE} ${MOUNT_POINT}

    echo ">>> [4/5] Copying EFI files..."
    # 确保源目录存在
    if [ ! -d "${EFI_DIR}" ]; then
        echo "❎ ERROR: EFI source directory '${EFI_DIR}' not found!"
        umount ${MOUNT_POINT}
        exit 1
    fi
    cp -r ${EFI_DIR}/* ${MOUNT_POINT}/

    echo ">>> [5/5] Unmounting the image file..."
    umount ${MOUNT_POINT}

    echo "✅ Successfully created bootable ${ESP_IMAGE}"

    ESP_IMAGE_COMPRESSED="${ESP_IMAGE}.zst"

    # 使用 zstd 进行压缩
    echo "INFO: Compressing '${ESP_IMAGE}' using zstd..."
    # -T0 使用所有可用线程，-v 显示进度
    zstd -T0 -v "${ESP_IMAGE}"

    echo "✅ Flashable ESP image compressed"

else
    echo "❎ ERROR: EFI directory '$EFI_DIR' is empty or does not exist." >&2
    echo "Listing contents of '$ROOTFS_DIR/boot' for debugging:" >&2
    ls -lR "$ROOTFS_DIR/boot" || echo "Directory '$ROOTFS_DIR/boot' not found." >&2
    exit 1
fi


echo "=============================================================================="
echo "Base rootfs created successfully at: $ROOTFS_DIR"
echo "This directory can now be used as a base for creating specific variants."
echo "=============================================================================="