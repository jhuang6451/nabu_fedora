#!/bin/bash
# ==============================================================================
# post_install.sh - 首次启动交互式配置向导 (多语言版)
# ==============================================================================

set -e

# --- 语言字符串定义 ---

# English
MSG_WELCOME_EN="Welcome! This wizard will guide you through the basic setup of your system."
MSG_HEADER_EN="Fedora for Nabu - First Boot Setup"
MSG_ONCE_EN="This will only run once."
MSG_USER_SETUP_EN="--- 1. User Account Setup ---"
MSG_ROOT_PASS_EN="First, we need to set a password for the root (administrator) user."
MSG_PASS_FAIL_EN="Password setting failed, please try again."
MSG_CREATE_USER_EN="Next, let's create a standard user account for daily use."
PROMPT_USERNAME_EN="Please enter your username (e.g., nabu): "
ERR_INVALID_USER_EN="Error: Invalid username. Please use lowercase letters, numbers, underscores, or hyphens, starting with a letter."
MSG_USER_CREATED_EN="User '%s' has been created."
MSG_SET_USER_PASS_EN="Now, set a password for the user '%s'."
MSG_HOSTNAME_SETUP_EN="--- 2. Hostname Setup ---"
PROMPT_HOSTNAME_EN="Please enter a hostname for this device (e.g., nabu-pad): "
MSG_HOSTNAME_SET_EN="Hostname has been set to '%s'."
MSG_TIMEZONE_SETUP_EN="--- 3. Timezone Setup ---"
MSG_TIMEZONE_INFO_EN="You can find a list of timezones here: https://en.wikipedia.org/wiki/List_of_tz_database_time_zones"
MSG_TIMEZONE_EXAMPLE_EN="Examples: 'Asia/Shanghai', 'Europe/London', 'America/New_York'"
PROMPT_TIMEZONE_EN="Please enter your timezone: "
MSG_TIMEZONE_SET_EN="Timezone has been set to '%s'."
ERR_TIMEZONE_FAIL_EN="Error: Failed to set timezone. The default (UTC) will be kept."
MSG_MIRROR_SETUP_EN="--- 4. Repository Mirror Setup (Optional) ---"
PROMPT_MIRROR_EN="Are you in mainland China and wish to use Tsinghua University mirrors for faster software downloads? (y/N): "
MSG_MIRROR_CONFIGURING_EN="Configuring Tsinghua University mirrors..."
MSG_MIRROR_DONE_EN="Mirror configuration complete."
MSG_MIRROR_SKIP_EN="Skipping mirror configuration."
MSG_COMPLETE_EN="--- Setup Complete ---"
MSG_CLEANUP_EN="Removing the first-boot service..."
MSG_REBOOT_EN="All configuration is complete! The system will reboot into the graphical environment in 5 seconds."

# 中文
MSG_WELCOME_ZH="欢迎使用！此向导将帮助您完成系统的基本配置。"
MSG_HEADER_ZH="Fedora for Nabu - 首次启动配置向导"
MSG_ONCE_ZH="这只会运行一次。"
MSG_USER_SETUP_ZH="--- 1. 用户账户配置 ---"
MSG_ROOT_PASS_ZH="首先，我们需要为 root (管理员) 用户设置密码。"
MSG_PASS_FAIL_ZH="密码设置失败，请重试。"
MSG_CREATE_USER_ZH="接下来，创建一个日常使用的普通用户。"
PROMPT_USERNAME_ZH="请输入您的用户名 (例如: nabu): "
ERR_INVALID_USER_ZH="错误: 用户名不合法。请使用小写字母、数字、下划线或连字符，并以字母开头。"
MSG_USER_CREATED_ZH="用户 '%s' 已创建。"
MSG_SET_USER_PASS_ZH="现在，为用户 '%s' 设置密码。"
MSG_HOSTNAME_SETUP_ZH="--- 2. 主机名配置 ---"
PROMPT_HOSTNAME_ZH="请输入设备的主机名 (网络中的名称，例如: nabu-pad): "
MSG_HOSTNAME_SET_ZH="主机名已设置为 '%s'。"
MSG_TIMEZONE_SETUP_ZH="--- 3. 时区配置 ---"
MSG_TIMEZONE_INFO_ZH="您可以访问 https://en.wikipedia.org/wiki/List_of_tz_database_time_zones 查看所有可用时区。"
MSG_TIMEZONE_EXAMPLE_ZH="例如: 'Asia/Shanghai', 'Europe/London', 'America/New_York'"
PROMPT_TIMEZONE_ZH="请输入您的时区: "
MSG_TIMEZONE_SET_ZH="时区已设置为 '%s'。"
ERR_TIMEZONE_FAIL_ZH="错误: 时区设置失败。将保留默认设置 (UTC)。"
MSG_MIRROR_SETUP_ZH="--- 4. 镜像源配置 (可选) ---"
PROMPT_MIRROR_ZH="您是否位于中国大陆，希望使用清华大学镜像源以加速软件下载? (y/N): "
MSG_MIRROR_CONFIGURING_ZH="正在配置清华大学镜像源..."
MSG_MIRROR_DONE_ZH="镜像源配置完成。"
MSG_MIRROR_SKIP_ZH="跳过镜像源配置。"
MSG_COMPLETE_ZH="--- 配置完成 ---"
MSG_CLEANUP_ZH="正在移除首次启动服务..."
MSG_REBOOT_ZH="所有配置均已完成！系统将在 5 秒后重启进入图形桌面环境。"

# --- 语言选择 ---
clear
echo "============================================="
echo " Please choose your language / 请选择你的语言 "
echo "============================================="
echo " 1. English"
echo " 2. 中文 (Chinese)"
echo
read -p "Enter your choice (1-2): " LANG_CHOICE

case "$LANG_CHOICE" in
    2)
        # 使用中文
        for i in $(compgen -v | grep '_ZH$'); do
            var_name=${i%_ZH}
            eval "$var_name=\"${!i}\""
        done
        ;;
    *)
        # 默认使用英文
        for i in $(compgen -v | grep '_EN$'); do
            var_name=${i%_EN}
            eval "$var_name=\"${!i}\""
        done
        ;;
esac

# --- 函数定义 ---
print_header() {
    clear
    echo "========================================================"
    echo "    $MSG_HEADER"
    echo "========================================================"
    echo
    echo "$MSG_WELCOME"
    echo "$MSG_ONCE"
    echo
}

setup_user_accounts() {
    echo "$MSG_USER_SETUP"
    echo "$MSG_ROOT_PASS"
    until passwd root; do echo "$MSG_PASS_FAIL"; done
    echo
    echo "$MSG_CREATE_USER"
    local USERNAME
    while true; do
        read -p "$PROMPT_USERNAME" USERNAME
        if [[ "$USERNAME" =~ ^[a-z_][a-z0-9_-]*$ ]]; then break;
        else echo "$ERR_INVALID_USER"; fi
    done
    useradd -m -G wheel "$USERNAME"
    printf -- "$MSG_USER_CREATED\n" "$USERNAME"
    printf -- "$MSG_SET_USER_PASS\n" "$USERNAME"
    until passwd "$USERNAME"; do echo "$MSG_PASS_FAIL"; done
    echo
}

setup_hostname() {
    echo "$MSG_HOSTNAME_SETUP"
    read -p "$PROMPT_HOSTNAME" HOSTNAME
    hostnamectl set-hostname "$HOSTNAME"
    printf -- "$MSG_HOSTNAME_SET\n" "$HOSTNAME"
    echo
}

setup_timezone() {
    echo "$MSG_TIMEZONE_SETUP"
    echo "$MSG_TIMEZONE_INFO"
    echo "$MSG_TIMEZONE_EXAMPLE"
    read -p "$PROMPT_TIMEZONE" TIMEZONE
    if timedatectl set-timezone "$TIMEZONE"; then
        printf -- "$MSG_TIMEZONE_SET\n" "$TIMEZONE"
    else
        echo "$ERR_TIMEZONE_FAIL"
    fi
    echo
}

setup_mirrors() {
    # 仅当用户选择中文时，才提供此选项，因为这强烈暗示了他们的地理位置。
    if [ "$LANG_CHOICE" = "2" ]; then
        echo "$MSG_MIRROR_SETUP"
        local CHOICE
        read -p "$PROMPT_MIRROR" CHOICE
        case "$CHOICE" in
            [Yy]*)
                echo "$MSG_MIRROR_CONFIGURING"
                sed -e 's|^metalink=|#metalink=|g' \
                    -e 's|^#baseurl=http://download.example/pub/fedora/linux|baseurl=https://mirrors.tuna.tsinghua.edu.cn/fedora|g' \
                    -i.bak \
                    /etc/yum.repos.d/fedora.repo \
                    /etc/yum.repos.d/fedora-updates.repo
                echo "$MSG_MIRROR_DONE"
                ;;
            *)
                echo "$MSG_MIRROR_SKIP"
                ;;
        esac
        echo
    fi
}

cleanup_and_reboot() {
    echo "$MSG_COMPLETE"
    echo "$MSG_CLEANUP"
    systemctl disable first-boot-setup.service
    rm -f /etc/systemd/system/first-boot-setup.service
    rm -f "$0" # 删除脚本自身
    echo
    echo "$MSG_REBOOT"
    sleep 5
    reboot
}

# --- 主逻辑 ---
print_header
setup_user_accounts
setup_hostname
setup_timezone
setup_mirrors
cleanup_and_reboot

exit 0