#!/bin/bash
set -euo pipefail

# 颜色定义
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# 打印提示信息
info() {
    echo -e "${YELLOW}[*] $1${NC}"
}

# 打印成功信息
success() {
    echo -e "${GREEN}[+] $1${NC}"
}

# 打印错误信息并退出
error() {
    echo -e "${RED}[!] $1${NC}"
    exit 1
}

# 检测系统类型
detect_os() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS=$ID
        VERSION=$VERSION_ID
    else
        error "无法检测操作系统类型，请手动确认系统兼容性"
    fi

    case $OS in
        ubuntu|debian)
            PKG_MANAGER="apt-get"
            UPDATE_CMD="sudo $PKG_MANAGER update -y"
            INSTALL_CMD="sudo $PKG_MANAGER install -y"
            JDK_PKG="openjdk-11-jdk"
            PYTHON_PKG="python3 python3-pip"
            ;;
        centos|fedora|rhel)
            PKG_MANAGER="dnf"
            if [ "$OS" = "centos" ] && [ "$VERSION" -lt 8 ]; then
                PKG_MANAGER="yum"
            fi
            UPDATE_CMD="sudo $PKG_MANAGER check-update -y"
            INSTALL_CMD="sudo $PKG_MANAGER install -y"
            JDK_PKG="java-11-openjdk-devel"
            PYTHON_PKG="python3 python3-devel"
            ;;
        *)
            error "不支持的操作系统: $OS"
            ;;
    esac
}

# 安装系统依赖
install_system_deps() {
    info "正在更新系统包索引..."
    eval "$UPDATE_CMD" || error "更新包索引失败"

    info "正在安装系统依赖..."
    local deps=(
        gcc g++ make git wget curl libssl-dev zlib1g-dev
        libncurses5 libncursesw5 libtinfo5  # 兼容部分旧版工具链
    )
    eval "$INSTALL_CMD ${deps[*]}" || error "安装系统依赖失败"
}

# 安装 JDK
install_jdk() {
    info "正在安装 JDK 11..."
    eval "$INSTALL_CMD $JDK_PKG" || error "安装 JDK 失败"

    # 配置 JAVA_HOME（适用于大多数发行版）
    local java_home
    java_home=$(dirname $(dirname $(readlink -f $(which javac))))
    echo "export JAVA_HOME=$java_home" >> ~/.bashrc
    echo "export PATH=\$JAVA_HOME/bin:\$PATH" >> ~/.bashrc
    export JAVA_HOME
    export PATH=$JAVA_HOME/bin:$PATH

    success "JDK 安装完成，版本验证："
    java -version 2>&1 | head -n 1
}

# 安装 Python
install_python() {
    info "正在安装 Python 3.8+..."
    eval "$INSTALL_CMD $PYTHON_PKG" || error "安装 Python 失败"

    # 检查 Python 版本
    local py_version=$(python3 -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')")
    if [ "$py_version" -lt 38 ]; then
        error "Python 版本过低（需要 3.8+，当前 $py_version）"
    fi
    success "Python 安装完成，版本：$py_version"
}

# 安装 GN 和 Ninja
install_build_tools() {
    info "正在安装 GN 构建工具..."
    GN_URL="https://storage.googleapis.com/chromium-gn/gn-latest-linux-x86_64.tar.xz"
    wget -q "$GN_URL" -O gn.tar.xz || error "下载 GN 失败"
    mkdir -p /tmp/gn && tar -xf gn.tar.xz -C /tmp/gn --strip-components=1
    sudo mv /tmp/gn/gn /usr/local/bin/ || error "移动 GN 失败"
    rm -rf /tmp/gn gn.tar.xz
    success "GN 安装完成，版本验证："
    gn --version

    info "正在安装 Ninja 构建工具..."
    NINJA_URL="https://github.com/ninja-build/ninja/releases/latest/download/ninja-linux.zip"
    wget -q "$NINJA_URL" -O ninja.zip || error "下载 Ninja 失败"
    unzip -q ninja.zip -d /tmp/ninja
    sudo mv /tmp/ninja/ninja /usr/local/bin/ || error "移动 Ninja 失败"
    rm -rf /tmp/ninja ninja.zip
    success "Ninja 安装完成，版本验证："
    ninja --version
}

# 主函数
main() {
    info "===== 开始安装 OpenHarmony 开发环境 ====="
    detect_os
    install_system_deps
    install_jdk
    install_python
    install_build_tools

    success "===== 环境安装完成 ====="
    echo -e "\n请根据需要克隆 OpenHarmony 源码（示例）："
    echo "git clone https://gitee.com/openharmony/openharmony.git"
    echo -e "\n环境变量已自动配置（需重启终端生效），可通过以下命令验证："
    echo "java -version && python3 --version && gn --version && ninja --version"
}

# 执行主函数
main
