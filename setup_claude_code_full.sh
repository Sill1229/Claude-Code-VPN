#!/bin/bash

# ============================================
#  Claude Code 一键部署脚本 (macOS) v2
#  包含：终端代理配置 + 环境部署 + 登录引导
#  适用于全新/旧 Mac
# ============================================

# ---------------------
# 颜色定义
# ---------------------
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# ---------------------
# 默认代理端口（可在此修改）
# ---------------------
DEFAULT_PROXY_PORT=7897

echo ""
echo -e "${BLUE}================================================${NC}"
echo -e "${BLUE}  Claude Code 一键部署脚本 v2 (macOS)${NC}"
echo -e "${BLUE}  终端代理 + Homebrew + Node.js + Claude Code${NC}"
echo -e "${BLUE}================================================${NC}"
echo ""

# =============================================
# STEP 0: 管理员权限预获取
# =============================================
echo -e "${BLUE}[0/7] 获取管理员权限...${NC}"
echo -e "  → Homebrew 安装需要管理员权限，请输入开机密码"
if sudo -v; then
    echo -e "  ${GREEN}✅ 管理员权限已获取${NC}"
    # 保持 sudo 会话活跃
    while true; do sudo -n true; sleep 50; kill -0 "$$" || exit; done 2>/dev/null &
    SUDO_KEEP_PID=$!
else
    echo -e "  ${RED}❌ 无法获取管理员权限，请确认当前用户是管理员账户${NC}"
    exit 1
fi

# =============================================
# STEP 1: 终端代理配置
# =============================================
echo ""
echo -e "${BLUE}[1/7] 配置终端代理...${NC}"

SHELL_RC="$HOME/.zprofile"

# 询问代理端口
read -p "  请输入 VPN 代理端口 (默认 ${DEFAULT_PROXY_PORT}): " INPUT_PORT
PROXY_PORT=${INPUT_PORT:-$DEFAULT_PROXY_PORT}

# 清除旧配置（如果有）
if grep -q '# Terminal Proxy - Start' "$SHELL_RC" 2>/dev/null; then
    echo -e "  → 检测到旧代理配置，正在替换..."
    sed -i '' '/# Terminal Proxy - Start/,/# Terminal Proxy - End/d' "$SHELL_RC"
fi

# 写入新配置
cat >> "$SHELL_RC" << PROXY_EOF

# Terminal Proxy - Start
PROXY_PORT=${PROXY_PORT}

export http_proxy="http://127.0.0.1:\${PROXY_PORT}"
export https_proxy="http://127.0.0.1:\${PROXY_PORT}"
export all_proxy="socks5://127.0.0.1:\${PROXY_PORT}"
export HTTP_PROXY="http://127.0.0.1:\${PROXY_PORT}"
export HTTPS_PROXY="http://127.0.0.1:\${PROXY_PORT}"
export ALL_PROXY="socks5://127.0.0.1:\${PROXY_PORT}"

export no_proxy="localhost,127.0.0.1,10.0.0.0/8,172.16.0.0/12,192.168.0.0/16,.local"
export NO_PROXY="localhost,127.0.0.1,10.0.0.0/8,172.16.0.0/12,192.168.0.0/16,.local"

proxy_on() {
    export http_proxy="http://127.0.0.1:\${PROXY_PORT}"
    export https_proxy="http://127.0.0.1:\${PROXY_PORT}"
    export all_proxy="socks5://127.0.0.1:\${PROXY_PORT}"
    export HTTP_PROXY="http://127.0.0.1:\${PROXY_PORT}"
    export HTTPS_PROXY="http://127.0.0.1:\${PROXY_PORT}"
    export ALL_PROXY="socks5://127.0.0.1:\${PROXY_PORT}"
    echo "✅ 代理已开启 (端口: \${PROXY_PORT})"
}

proxy_off() {
    unset http_proxy https_proxy all_proxy HTTP_PROXY HTTPS_PROXY ALL_PROXY
    echo "⛔ 代理已关闭"
}

proxy_status() {
    if [ -n "\$http_proxy" ]; then
        echo "✅ 代理状态: 开启"
        echo "   HTTP:  \$http_proxy"
        echo "   HTTPS: \$https_proxy"
        echo "   SOCKS: \$all_proxy"
    else
        echo "⛔ 代理状态: 关闭"
    fi
}
# Terminal Proxy - End
PROXY_EOF

# 立即生效
export http_proxy="http://127.0.0.1:${PROXY_PORT}"
export https_proxy="http://127.0.0.1:${PROXY_PORT}"
export all_proxy="socks5://127.0.0.1:${PROXY_PORT}"
export HTTP_PROXY="http://127.0.0.1:${PROXY_PORT}"
export HTTPS_PROXY="http://127.0.0.1:${PROXY_PORT}"
export ALL_PROXY="socks5://127.0.0.1:${PROXY_PORT}"

echo -e "  ${GREEN}✅ 代理已配置 (端口: ${PROXY_PORT})，永久生效${NC}"
echo -e "  快捷命令: proxy_on / proxy_off / proxy_status"

# =============================================
# STEP 2: 网络连通性预检（使用 curl 走 HTTPS）
# =============================================
echo ""
echo -e "${BLUE}[2/7] 网络连通性预检...${NC}"

check_network() {
    local target_name=$1
    local target_url=$2

    echo -e "  → 检测 ${target_name}..."
    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout 10 "$target_url")
    if [ "$HTTP_CODE" = "200" ] || [ "$HTTP_CODE" = "301" ] || [ "$HTTP_CODE" = "302" ]; then
        echo -e "  ${GREEN}✅ ${target_name} 连接正常 (HTTP ${HTTP_CODE})${NC}"
        return 0
    else
        echo ""
        echo -e "  ${RED}❌ 无法连接 ${target_name} (HTTP ${HTTP_CODE})${NC}"
        echo -e "  ${YELLOW}⚠️  请确认 VPN 已开启，或尝试切换 VPN 节点${NC}"
        echo ""
        read -p "  切换好后按 Enter 重试，输入 s 跳过... " choice
        if [[ "$choice" == "s" || "$choice" == "S" ]]; then
            echo -e "  ${YELLOW}⏭  已跳过${NC}"
            return 0
        fi
        check_network "$target_name" "$target_url"
    fi
}

check_network "GitHub" "https://github.com"
check_network "Homebrew API" "https://formulae.brew.sh"
check_network "npm Registry" "https://registry.npmjs.org"

# =============================================
# STEP 3: Xcode Command Line Tools
# =============================================
echo ""
echo -e "${BLUE}[3/7] 检查 Xcode Command Line Tools...${NC}"
if ! xcode-select -p &>/dev/null; then
    echo "  → 正在安装（会弹出系统窗口，请点击"安装"）..."
    xcode-select --install
    echo ""
    echo -e "  ${YELLOW}⚠️  请在弹出的窗口中点击"安装"，等安装完成后按 Enter 继续${NC}"
    read -p "  按 Enter 继续..."
    if ! xcode-select -p &>/dev/null; then
        echo -e "  ${RED}❌ 安装未完成，请手动安装后重新运行脚本${NC}"
        exit 1
    fi
    echo -e "  ${GREEN}✅ Xcode Command Line Tools 安装完成${NC}"
else
    echo -e "  ${GREEN}✅ Xcode Command Line Tools 已安装${NC}"
fi

# =============================================
# STEP 4: Homebrew（卸载旧版 + 全新安装）
# =============================================
echo ""
echo -e "${BLUE}[4/7] 处理 Homebrew...${NC}"

# 带超时监控的执行函数
run_with_timeout_watch() {
    local description=$1
    local timeout_seconds=$2
    shift 2

    eval "$@" &
    local cmd_pid=$!

    (
        sleep "$timeout_seconds"
        if kill -0 "$cmd_pid" 2>/dev/null; then
            echo ""
            echo -e "  ${YELLOW}⚠️  ${description} 已等待超过 ${timeout_seconds} 秒${NC}"
            echo -e "  ${YELLOW}💡 如果一直卡住：Ctrl+C 中断 → 切换 VPN 节点 → 重新运行脚本${NC}"
            echo ""
        fi
    ) &
    local timer_pid=$!

    wait "$cmd_pid" 2>/dev/null
    local exit_code=$?

    kill "$timer_pid" 2>/dev/null
    wait "$timer_pid" 2>/dev/null

    return $exit_code
}

if command -v brew &>/dev/null; then
    CURRENT_BREW_VERSION=$(brew --version 2>/dev/null | head -n1)
    echo -e "  → 检测到已安装: ${CURRENT_BREW_VERSION}"
    echo -e "  → ${YELLOW}为避免旧版本兼容问题，将卸载后重新安装${NC}"
    echo ""
    read -p "  确认卸载并重装 Homebrew？(Y/n): " confirm
    if [[ "$confirm" == "n" || "$confirm" == "N" ]]; then
        echo -e "  ${YELLOW}⏭  跳过重装，使用现有版本${NC}"
    else
        echo "  → 正在卸载旧版 Homebrew..."
        NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/uninstall.sh)" || true

        if [[ $(uname -m) == "arm64" ]]; then
            sudo rm -rf /opt/homebrew 2>/dev/null || true
        else
            sudo rm -rf /usr/local/Homebrew 2>/dev/null || true
        fi
        hash -r 2>/dev/null

        echo -e "  ${GREEN}✅ 旧版已卸载${NC}"
        echo ""
        echo "  → 正在安装最新版 Homebrew..."
        run_with_timeout_watch "Homebrew 安装" 90 \
            'NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"'
        echo -e "  ${GREEN}✅ Homebrew 重新安装完成${NC}"
    fi
else
    echo "  → 未检测到 Homebrew，正在全新安装..."
    run_with_timeout_watch "Homebrew 安装" 90 \
        'NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"'
    echo -e "  ${GREEN}✅ Homebrew 安装完成${NC}"
fi

# 配置 Homebrew 环境变量（兼容 Apple Silicon / Intel）
if [[ $(uname -m) == "arm64" ]]; then
    BREW_PATH="/opt/homebrew/bin/brew"
else
    BREW_PATH="/usr/local/bin/brew"
fi

if ! grep -q 'eval.*brew shellenv' "$SHELL_RC" 2>/dev/null; then
    echo '' >> "$SHELL_RC"
    echo '# Homebrew' >> "$SHELL_RC"
    echo "eval \"\$(${BREW_PATH} shellenv)\"" >> "$SHELL_RC"
fi
eval "$($BREW_PATH shellenv)"

echo -e "  当前版本: $(brew --version | head -n1)"

# =============================================
# STEP 5: Node.js
# =============================================
echo ""
echo -e "${BLUE}[5/7] 检查 Node.js...${NC}"
if ! command -v node &>/dev/null; then
    echo "  → 正在通过 Homebrew 安装 Node.js..."
    run_with_timeout_watch "Node.js 安装" 120 "brew install node"
    echo -e "  ${GREEN}✅ Node.js 安装完成 ($(node -v))${NC}"
else
    echo -e "  ${GREEN}✅ Node.js 已安装 ($(node -v))${NC}"
fi

# =============================================
# STEP 6: Claude Code（通过 npm 安装）
# =============================================
echo ""
echo -e "${BLUE}[6/7] 安装 Claude Code...${NC}"
echo -e "  ${YELLOW}注意：Claude Code 是命令行工具，通过 npm 安装${NC}"
echo -e "  ${YELLOW}      （brew install claude 安装的是桌面客户端，不是 Claude Code）${NC}"

if command -v claude &>/dev/null && claude --version 2>/dev/null | grep -q "Claude Code"; then
    echo -e "  ${GREEN}✅ Claude Code 已安装 ($(claude --version 2>/dev/null))${NC}"
else
    echo "  → 正在通过 npm 安装 Claude Code..."
    run_with_timeout_watch "Claude Code 安装" 120 "npm install -g @anthropic-ai/claude-code"

    if command -v claude &>/dev/null; then
        echo -e "  ${GREEN}✅ Claude Code 安装完成 ($(claude --version 2>/dev/null))${NC}"
    else
        echo -e "  ${RED}❌ Claude Code 安装失败，请手动执行: npm install -g @anthropic-ai/claude-code${NC}"
    fi
fi

# =============================================
# STEP 7: 验证安装
# =============================================
echo ""
echo -e "${BLUE}[7/7] 验证安装结果...${NC}"

ALL_OK=true

if command -v brew &>/dev/null; then
    echo -e "  ${GREEN}✅ Homebrew:    $(brew --version | head -n1)${NC}"
else
    echo -e "  ${RED}❌ Homebrew 未找到${NC}"
    ALL_OK=false
fi

if command -v node &>/dev/null; then
    echo -e "  ${GREEN}✅ Node.js:     $(node -v)${NC}"
else
    echo -e "  ${RED}❌ Node.js 未找到${NC}"
    ALL_OK=false
fi

if command -v claude &>/dev/null; then
    echo -e "  ${GREEN}✅ Claude Code: $(claude --version 2>/dev/null)${NC}"
else
    echo -e "  ${RED}❌ Claude Code 未找到${NC}"
    ALL_OK=false
fi

echo -e "  ${GREEN}✅ 终端代理:    端口 ${PROXY_PORT} (永久生效)${NC}"

# 清理 sudo 保活进程
kill "$SUDO_KEEP_PID" 2>/dev/null

# =============================================
# 完成
# =============================================
echo ""
if $ALL_OK; then
    echo -e "${GREEN}================================================${NC}"
    echo -e "${GREEN}  ✅ 全部部署完成！${NC}"
    echo -e "${GREEN}================================================${NC}"
    echo ""
    echo "  接下来："
    echo ""
    echo "  1. 关闭当前终端，重新打开一个新终端"
    echo "  2. 输入: claude"
    echo "  3. 输入: /login"
    echo "  4. 在浏览器中登录你的 Pro 账号"
    echo ""
    echo "  代理快捷命令（任何终端可用）："
    echo "    proxy_on      → 开启代理"
    echo "    proxy_off     → 临时关闭代理"
    echo "    proxy_status  → 查看代理状态"
    echo ""
    echo -e "  ${YELLOW}提示：如果 'claude' 命令找不到，${NC}"
    echo -e "  ${YELLOW}请确保已关闭旧终端并打开新终端。${NC}"
    echo -e "${GREEN}================================================${NC}"
else
    echo -e "${RED}================================================${NC}"
    echo -e "${RED}  ⚠️  部分组件安装失败${NC}"
    echo -e "${RED}  建议：切换 VPN 节点后重新运行本脚本${NC}"
    echo -e "${RED}  脚本支持断点续装，已完成的步骤会自动跳过${NC}"
    echo -e "${RED}================================================${NC}"
fi
