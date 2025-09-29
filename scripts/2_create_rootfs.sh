#!/bin/bash

# ==============================================================================
# 4_create_release.sh
#
# 功能: 为 nabu 构建 fedora 根文件系统，安装基础软件包、生成UKI并打包为镜像。
#
# 作者: jhuang6451
# 版本: test ver
# ==============================================================================

set -e

# 定义变量
ROOTFS_DIR="$PWD/fedora-rootfs-aarch64"
RELEASEVER="42"
ARCH="aarch64"
ROOTFS_NAME="fedora-42-nabu-rootfs.img"
IMG_SIZE="8G"

# Mount chroot filesystems 函数
mount_chroot_fs() {
    echo "Mounting chroot filesystems into $ROOTFS_DIR..."
    # 确保目标目录存在
    mkdir -p "$ROOTFS_DIR/proc" "$ROOTFS_DIR/sys" "$ROOTFS_DIR/dev" "$ROOTFS_DIR/dev/pts"
    mount --bind /proc "$ROOTFS_DIR/proc"
    mount --bind /sys "$ROOTFS_DIR/sys"
    mount --bind /dev "$ROOTFS_DIR/dev"
    mount --bind /dev/pts "$ROOTFS_DIR/dev/pts"
}

# Unmount chroot filesystems 函数
umount_chroot_fs() {
    echo "Unmounting chroot filesystems from $ROOTFS_DIR..."
    # 以相反的顺序卸载，并忽略可能发生的错误
    umount "$ROOTFS_DIR/dev/pts" || true
    umount "$ROOTFS_DIR/dev" || true
    umount "$ROOTFS_DIR/sys" || true
    umount "$ROOTFS_DIR/proc" || true
}

# 确保在脚本退出时总是尝试卸载
trap umount_chroot_fs EXIT

# 1. 创建 rootfs 目录
echo "Creating rootfs directory: $ROOTFS_DIR"
mkdir -p "$ROOTFS_DIR"

# 2. 先挂载必要的文件系统，以便后续 chroot 操作
echo "Mounting filesystems for chroot..."
mount_chroot_fs

# 创建临时 DNS 配置 
echo "Temporarily setting up DNS for chroot..."
# 强制删除任何可能存在的旧文件或悬空链接
rm -f "$ROOTFS_DIR/etc/resolv.conf"
# 创建一个新的 resolv.conf 文件
mkdir -p "$ROOTFS_DIR/etc"
cat <<EOF > "$ROOTFS_DIR/etc/resolv.conf"
nameserver 8.8.8.8
nameserver 8.8.4.4
nameserver 1.1.1.1
nameserver 1.0.0.1
EOF

# 3. 引导基础系统 (Bootstrap Phase)
# 安装一个包含 bash 和 dnf 的最小化系统，以便我们可以 chroot 进去
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

echo "Copying first-boot scripts into rootfs..."
# 确保目标目录存在
mkdir -p "$ROOTFS_DIR/usr/local/bin"
# 复制交互式配置脚本
cp ./scripts/post_install.sh "$ROOTFS_DIR/usr/local/bin/post_install.sh"
chmod +x "$ROOTFS_DIR/usr/local/bin/post_install.sh"

# 4. 在 Chroot 环境中安装和配置
echo "Running main installation and configuration inside chroot..."

run_in_chroot() {
    # 将变量导出，以便子 shell (chroot) 可以继承它们
    export RELEASEVER="$RELEASEVER"
    export ARCH="$ARCH"

    # 使用 cat 将此函数内的所有命令通过管道传给 chroot
    cat <<'CHROOT_SCRIPT' | chroot "$ROOTFS_DIR" /bin/bash
set -e
set -o pipefail



# ==========================================================================
# --- 创建 dracut 和 ukify 配置以分别支持 initramfs 和 UKI 生成 ---
# ==========================================================================

# --- 创建 dracut 配置文件以生成 initramfs ---
echo 'Creating dracut config for initramfs...'
cat <<EOF > "/etc/dracut.conf.d/99-nabu-generic.conf"
# Ensure dracut builds a generic image, not one tied to the build host hardware.
hostonly="no"
# 强制包含关键的存储驱动
force_drivers+=" ufs_qcom ufshcd_pltfrm "
#add_drivers+=" ufs_qcom ufshcd_pltfrm qcom-scm arm_smmu arm_smmu_v3 icc-rpmh "
EOF
echo 'Generic dracut config created.'

# --- 创建 systemd-ukify 配置文件 ---
echo 'Creating systemd-ukify config file...'
mkdir -p "/etc/systemd/"
cat <<'EOF' > "/etc/systemd/ukify.conf"
[UKI]
Cmdline=root=PARTLABEL=linux rw quiet systemd.gpt_auto=no cryptomgr.notests
Stub=/usr/lib/systemd/boot/efi/linuxaa64.efi.stub
EOF
echo 'systemd-ukify config file created.'
# --------------------------------------------------------------------------



# ==========================================================================
# --- 提前创建ESP挂载点，作为UKI生成时的存放路径 ---
# ==========================================================================
echo 'Creating ESP mount point for UKI installation...'
mkdir -p /boot/efi
# --------------------------------------------------------------------------



# ==========================================================================
# --- 安装必要的软件包 ---
# ==========================================================================
# Install core packages.
dnf install -y --releasever=$RELEASEVER \
    --nogpgcheck \
    --setopt=install_weak_deps=False \
    @core

# Install basic packages and device specific packages.
# systemd-boot-unsigned会提供生成UKI所需的linuxaarch64.efi.stub。
echo 'Installing basic packages...'
dnf install -y --releasever=$RELEASEVER \
    --repofrompath="jhuang6451-copr,https://download.copr.fedorainfracloud.org/results/jhuang6451/nabu_fedora_packages_uefi/fedora-$RELEASEVER-$ARCH/" \
    --repofrompath="onesaladleaf-copr,https://download.copr.fedorainfracloud.org/results/onesaladleaf/pocketblue/fedora-$RELEASEVER-$ARCH/" \
    --nogpgcheck \
    --setopt=install_weak_deps=False \
    --exclude dracut-config-rescue \
    @hardware-support \
    systemd-boot-unsigned \
    systemd-ukify \
    xiaomi-nabu-firmware \
    xiaomi-nabu-audio \
    binutils \
    xiaomi-nabu-audio \
    qrtr \
    rmtfs \
    pd-mapper \
    tqftpserv \
    NetworkManager-wifi \
    zram-generator \
    glibc-langpack-en

# Seems that kernel-install has a hidden dependency on grubby, but I don't use it now.

# Now, install the kernel. This will trigger UKI generation.
echo "Installing kernel package to trigger UKI generation..."
dnf install -y --releasever=$RELEASEVER \
    --repofrompath="jhuang6451-copr,https://download.copr.fedorainfracloud.org/results/jhuang6451/nabu_fedora_packages_uefi/fedora-$RELEASEVER-$ARCH/" \
    --nogpgcheck \
    --setopt=install_weak_deps=False \
    kernel-sm8150

# Install additional packages.
echo "Installing additional packages..."
dnf install -y \
    --releasever=$RELEASEVER \
    --nogpgcheck \
    --setopt=install_weak_deps=False \
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
    qbootctl \
    firefox \
    NetworkManager-tui \
    fcitx5 \
    fcitx5-configtool \
    fcitx5-gtk \
    fcitx5-qt \
    fcitx5-chinese-addons

# Didn't remove from gnome-desktop:
# totem
# loupe
# PackageKit-command-not-found
# PackageKit
# gnome-clocks
# gnome-text-editor
# baobab
# evince
# evince-djvu
# gnome-system-monitor
# gnome-calculator
# gnome-calendar
# gnome-contacts
# gnome-logs
# gnome-font-viewer
# gnome-characters


# ==========================================================================
# --- 验证 UKI 是否已生成 ---
# ==========================================================================
echo "Verifying UKI Generation after dnf install..."
if [ -d "/boot/efi/EFI/Linux" ] && [ -n "$(find /boot/efi/EFI/Linux -name '*.efi')" ]; then
    echo "SUCCESS: UKI file(s) found!"
    ls -lR /boot/efi/
else
    echo "CRITICAL ERROR: No UKI file found after RPM installation!" >&2
    echo "This means the %posttrans script in the kernel RPM failed to generate the UKI." >&2
    exit 1
fi
# --------------------------------------------------------------------------



# ==========================================================================
# --- 创建并启用 tqftpserv, rmtfs 和 qbootctl 服务 ---
# ==========================================================================
echo 'Creating qbootctl.service file...'
cat <<EOF > "/etc/systemd/system/qbootctl.service"
[Unit]
Description=Qualcomm boot slot ctrl mark boot successful
[Service]
ExecStart=/usr/bin/qbootctl -m
Type=oneshot
RemainAfterExit=yes
[Install]
WantedBy=multi-user.target
EOF

echo 'Enabling systemd services...'
systemctl enable tqftpserv.service
systemctl enable rmtfs.service
systemctl enable qbootctl.service
# --------------------------------------------------------------------------



# ==========================================================================
# --- 创建 /etc/fstab ---
# ==========================================================================
echo 'Creating /etc/fstab for automatic partition mounting...'
cat <<EOF > "/etc/fstab"
# /etc/fstab: static file system information.
PARTLABEL=linux  /                  ext4   rw,errors=remount-ro,x-systemd.growfs  0 1
PARTLABEL=esp    /boot/efi/         vfat   fmask=0022,dmask=0022                  0 1
EOF
# --------------------------------------------------------------------------



# ==========================================================================
# --- 创建 systemd-boot 的 loader.conf ---
# ==========================================================================
echo 'Creating systemd-boot loader configuration...'
mkdir -p "/boot/efi/loader/"
cat <<EOF > "/boot/efi/loader/loader.conf"
# See loader.conf(5) for details
timeout 6
console-mode max
default fedora-*
EOF
#TODO : 这里的 default 配置有没有问题？
# --------------------------------------------------------------------------



# ==========================================================================
# --- 配置 zram 交换分区 ---
# ==========================================================================
echo 'Configuring zram swap for improved performance under memory pressure...'
# zram-generator-defaults is installed but we want to provide our own config
mkdir -p "/etc/systemd/"
cat <<EOF > "/etc/systemd/zram-generator.conf"
# This configuration enables a compressed RAM-based swap device (zram).
# It significantly improves system responsiveness and multitasking on
# devices with a fixed amount of RAM.
[zram0]
# Set the uncompressed swap size to be equal to the total physical RAM.
# This is a balanced value providing a large swap space without risking
# system thrashing under heavy load.
zram-size = ram

# Use zstd compression for the best balance of speed and compression ratio.
compression-algorithm = zstd
EOF
echo 'Zram swap configured.'
# ==========================================================================



# ==========================================================================
# --- 集成首次启动服务 ---
# ==========================================================================

# # --- 1. 创建并启用自动扩展文件系统服务 (非交互式) ---
# echo 'Creating first-boot resize service...'

# cat <<'EOF' > "/usr/local/bin/firstboot-resize.sh"
# #!/bin/bash
# set -e
# # 获取根分区的设备路径 (e.g., /dev/mmcblk0pXX)
# ROOT_DEV=$(findmnt -n -o SOURCE /)
# if [ -z "$ROOT_DEV" ]; then
#     echo "Could not find root device. Aborting resize." >&2
#     exit 1
# fi
# echo "Resizing filesystem on ${ROOT_DEV}..."
# # 扩展文件系统以填充整个分区
# resize2fs "${ROOT_DEV}"
# # 任务完成，禁用并移除此服务，确保下次启动不再运行
# systemctl disable firstboot-resize.service
# rm -f /etc/systemd/system/firstboot-resize.service
# rm -f /usr/local/bin/firstboot-resize.sh
# echo "Filesystem resized and service removed."
# EOF

# # 赋予脚本执行权限
# chmod +x "/usr/local/bin/firstboot-resize.sh"

# # 创建 systemd 服务单元
# cat <<EOF > "/etc/systemd/system/firstboot-resize.service"
# [Unit]
# Description=Resize root filesystem to fill partition on first boot
# # 确保在文件系统挂载后执行
# After=local-fs.target

# [Service]
# Type=oneshot
# ExecStart=/usr/local/bin/firstboot-resize.sh
# # StandardOutput=journal+console
# RemainAfterExit=false

# [Install]
# # 链接到默认的目标，使其能够自启动
# WantedBy=default.target
# EOF

# # 启用服务
# systemctl enable firstboot-resize.service
# echo 'First-boot resize service created and enabled.'
# ---------------------------------------------------------------------------
# THIS IS NOLONGER NEEDED BECAUSE WE ARE USING x-systemd.growfs IN FSTAB
# ---------------------------------------------------------------------------
#TODO: Test then delete this.


    
# # 2. --- 创建并启用交互式配置服务 ---
# echo 'Creating interactive first-boot setup service...'
# cat <<'EOF' > "/etc/systemd/system/first-boot-setup.service"
# [Unit]
# Description=Interactive First-Boot Setup
# # 在 resize 服务之后，在图形界面之前运行
# After=resize-rootfs.service
# Before=graphical.target

# [Service]
# Type=oneshot
# ExecStart=/usr/local/bin/post_install.sh
# # 关键: 将服务的输入输出连接到物理控制台
# StandardInput=tty
# StandardOutput=tty
# StandardError=tty
# RemainAfterExit=no

# [Install]
# WantedBy=default.target
# EOF
# # 启用服务
# systemctl enable first-boot-setup.service

echo 'First-boot services created and enabled.'
#TODO: 交互式配置服务暂时无法正常运行
# --------------------------------------------------------------------------



# ==========================================================================
# --- 添加创建者签名到 /etc/os-release ---
# ==========================================================================
echo 'Adding creator signature to /etc/os-release...'
echo 'BUILD_CREATOR="jhuang6451"' >> "/etc/os-release"
# --------------------------------------------------------------------------



# ===========================================================================================
# --- temporary fix (because interactive post-install script won't work) 临时用户添加部分 ---
# ===========================================================================================
echo 'Adding temporary user "user" with sudo privileges...'

# 1. 创建名为 'user' 的用户，并将其加入 'wheel' 组。
#    --create-home (-m) 确保创建用户的主目录 /home/user。
#    --groups (-G) wheel 是在 Fedora/RHEL/CentOS 上授予 sudo 权限的标准做法。
useradd --create-home --groups wheel user
if [ $? -eq 0 ]; then
    echo 'User "user" created and added to "wheel" group successfully.'
else
    echo 'ERROR: Failed to create user "user".' >&2
    exit 1
fi

# 2. 以非交互方式为用户 'user' 设置密码 'fedora'。
#    使用 'chpasswd' 是在脚本中设置密码最安全、最直接的方法。
echo 'user:fedora' | chpasswd
if [ $? -eq 0 ]; then
    echo 'Password for "user" has been set to "fedora".'
else
    echo 'ERROR: Failed to set password for "user".' >&2
    exit 1
fi

# 3. 确保 'wheel' 组拥有 sudo 权限。
#    这在标准的 Fedora 系统中是默认配置，但为了确保万无一失，我们显式地创建
#    一个 sudoers 配置文件。这样可以避免主 /etc/sudoers 文件被意外修改的风险。
#    注意：sudoers 配置文件必须有严格的权限 (0440)。
SUDOERS_FILE="/etc/sudoers.d/99-wheel-user"
echo '%wheel ALL=(ALL) ALL' > "$SUDOERS_FILE"
chmod 0440 "$SUDOERS_FILE"
echo "Sudo access for group 'wheel' has been configured via $SUDOERS_FILE."
# ===========================================================================================
# --- 临时用户添加结束 ---
#TODO: remove this temporary user after interactive post-install script is fixed.
# ===========================================================================================



# ==========================================================================
# --- 清理 DNF 缓存以节省空间 ---
# ==========================================================================
echo 'Cleaning dnf cache...'
dnf clean all
# --------------------------------------------------------------------------



CHROOT_SCRIPT
}

# 现在执行这个函数
echo "Running main installation and configuration inside chroot..."
run_in_chroot



# 5. 退出 chroot 并卸载文件系统
echo "Chroot operations completed. Unmounting filesystems..."
umount_chroot_fs
# 重置 trap，因为我们已经手动卸载了
trap - EXIT

sync

# 6. 将 rootfs 打包为 img 文件 (注意：这里不再需要 dnf clean all)
echo "Creating rootfs image: $ROOTFS_NAME (size: $IMG_SIZE)..."
fallocate -l "$IMG_SIZE" "$ROOTFS_NAME"
mkfs.ext4 -L fedora_root -F "$ROOTFS_NAME"
MOUNT_DIR=$(mktemp -d)
trap 'umount "$MOUNT_DIR" &>/dev/null; rmdir -- "$MOUNT_DIR"' EXIT # 确保临时挂载目录在脚本退出时被清理
mount -o loop "$ROOTFS_NAME" "$MOUNT_DIR"
echo "Copying rootfs contents to image..."
rsync -aHAXx --info=progress2 "$ROOTFS_DIR/" "$MOUNT_DIR/"
echo "Unmounting image..."
umount "$MOUNT_DIR"
rmdir "$MOUNT_DIR"
trap - EXIT # 再次重置 trap
echo "Rootfs image created as $ROOTFS_NAME"


echo "Ensuring all data is written to the image file..."
sync
echo "Rootfs image created as $ROOTFS_NAME"

# 5. fix:最小化并压缩 img 文件 (更安全的方法)
echo "Minimizing the image file safely..."
# 强制进行文件系统检查并修复
e2fsck -f -y "$ROOTFS_NAME" || true

# 将文件系统缩小到其内容的最小尺寸
echo "Resizing filesystem to minimum size..."
resize2fs -M "$ROOTFS_NAME"

# 再次运行 e2fsck 以确保缩小后的文件系统状态一致
e2fsck -f -y "$ROOTFS_NAME" || true

# --- 关键修复：计算新尺寸时增加安全边界 ---
echo "Calculating new, safe image size..."
# 从 dumpe2fs 获取文件系统所需的最小块数
MIN_BLOCKS=$(dumpe2fs -h "$ROOTFS_NAME" 2>/dev/null | grep 'Block count:' | awk '{print $3}')
# 获取文件系统的块大小 (以 KB 为单位)
BLOCK_SIZE_KB=$(dumpe2fs -h "$ROOTFS_NAME" 2>/dev/null | grep 'Block size:' | awk '{print $3 / 1024}')

# 检查是否成功获取了数值
if ! [[ "$MIN_BLOCKS" =~ ^[0-9]+$ ]] || ! [[ "$BLOCK_SIZE_KB" =~ ^[0-9]+$ ]]; then
    echo "Error: Failed to retrieve block size or block count from image."
    exit 1
fi

# 计算文件系统所需的最小尺寸 (以 KB 为单位)
MIN_SIZE_KB=$((MIN_BLOCKS * BLOCK_SIZE_KB))

# 增加一个 200MB 的安全余量 (204800 KB)
# 这确保了 truncate 永远不会切掉文件系统的实际数据
SAFETY_MARGIN_KB=204800
NEW_SIZE_KB=$((MIN_SIZE_KB + SAFETY_MARGIN_KB))

echo "Filesystem minimum size: ${MIN_SIZE_KB} KB"
echo "Adding safety margin: ${SAFETY_MARGIN_KB} KB"
echo "New safe image size: ${NEW_SIZE_KB} KB"

# 使用 truncate 将镜像文件调整到新的、带有安全边界的尺寸
truncate -s "${NEW_SIZE_KB}K" "$ROOTFS_NAME"
echo "Image minimized successfully with safety margin."

# 最后，让 resize2fs 将文件系统扩展回填满整个镜像文件
# 这样镜像内部的文件系统就是完全健康的
echo "Expanding filesystem to fill the new safe-sized image..."
resize2fs "$ROOTFS_NAME"
echo "Filesystem expanded. Image is now minimized."
