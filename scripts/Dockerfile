# 使用官方的 Fedora 42 镜像作为基础
FROM fedora:42


# 添加 GitHub CLI 仓库，更新 dnf 缓存并安装所有需要的工具
RUN dnf config-manager addrepo --from-repofile=https://cli.github.com/packages/rpm/gh-cli.repo && \
    dnf makecache && \
    dnf install -y \
    coreutils \
    dnf-utils \
    dnf-plugins-core \
    dnf5-plugins \
    gh \
    qemu-user-static \
    tar \
    gzip \
    curl \
    findutils \
    util-linux \
    rsync \
    gawk \
    dosfstools \
    mtools \
    e2fsprogs \
    grub2-tools \
    grub2-efi-aa64-modules \
    libguestfs-tools \
    systemd-container \
    rpm-build \
    cpio \
    systemd-boot \
    && dnf clean all