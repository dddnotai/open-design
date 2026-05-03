#!/bin/bash
# Open Design 一键安装启动脚本
# 双击此文件即可自动安装并运行

set -e

echo "============================================"
echo "   Open Design 一键安装启动"
echo "============================================"
echo ""

# 进入脚本所在目录
cd "$(dirname "$0")"
PROJECT_DIR="$(pwd)"

# 自动拉取最新代码（如果是 git 仓库）
if [ -d .git ]; then
    echo "🔄 检查更新..."
    git pull --ff-only 2>/dev/null && echo "   已更新到最新版本" || echo "   跳过更新（可能有本地修改）"
fi

# 检查是否已安装 Homebrew
if ! command -v brew &>/dev/null; then
    echo "📦 正在安装 Homebrew（macOS 包管理器）..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi
# 确保 brew 在 PATH 中
if [ -f /opt/homebrew/bin/brew ]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
elif [ -f /usr/local/bin/brew ]; then
    eval "$(/usr/local/bin/brew shellenv)"
fi

# 安装 Node.js 24 并强制使用它
install_node() {
    echo "📦 正在通过 Homebrew 安装 Node.js 24..."
    brew install node@24 2>/dev/null || brew upgrade node@24 2>/dev/null || true
    brew link --overwrite --force node@24 2>/dev/null || true
}

# 强制将 brew 的 node@24 放在 PATH 最前面（覆盖 nvm 等）
use_brew_node() {
    if [ -d /opt/homebrew/opt/node@24/bin ]; then
        export PATH="/opt/homebrew/opt/node@24/bin:$PATH"
    elif [ -d /usr/local/opt/node@24/bin ]; then
        export PATH="/usr/local/opt/node@24/bin:$PATH"
    fi
}

# 禁用 nvm 避免它覆盖 PATH
unset NVM_DIR 2>/dev/null || true

if command -v node &>/dev/null; then
    NODE_MAJOR=$(node -v | sed 's/v\([0-9]*\).*/\1/')
    if [ "$NODE_MAJOR" -lt 24 ]; then
        echo "⚠️  当前 Node.js 版本过低 ($(node -v))，需要 v24"
        install_node
        use_brew_node
    else
        echo "✅ Node.js $(node -v) 已就绪"
    fi
else
    install_node
    use_brew_node
fi

# 确认 node 版本
echo "   使用 Node.js: $(node -v) ($(which node))"
NODE_MAJOR=$(node -v | sed 's/v\([0-9]*\).*/\1/')
if [ "$NODE_MAJOR" -lt 24 ]; then
    echo "❌ Node.js 24 未能正确加入 PATH，请手动运行："
    echo "   brew link --overwrite --force node@24"
    echo "   然后重新双击此文件"
    read -p "按回车键关闭..."
    exit 1
fi

# 启用 corepack 以获取正确版本的 pnpm
echo "📦 启用 corepack..."
corepack enable 2>/dev/null || sudo corepack enable

# 安装依赖（如果原生模块有版本不匹配则 rebuild）
echo "📦 正在安装项目依赖（首次可能需要几分钟）..."
pnpm install

echo "📦 编译原生模块..."
pnpm rebuild better-sqlite3 2>/dev/null || true

# 清理残留进程（上次未正常关闭时可能遗留）
kill $(lsof -ti :7456) 2>/dev/null || true
kill $(lsof -ti :3000) 2>/dev/null || true
sleep 1

# 启动服务
echo ""
echo "🚀 正在启动 Open Design..."
echo ""
echo "============================================"
echo "   启动成功后会自动打开浏览器"
echo "   如需关闭，直接关闭此终端窗口即可"
echo "============================================"
echo ""

# 启动 daemon
pnpm --filter @open-design/daemon daemon &
DAEMON_PID=$!
sleep 3

# 启动 web（自动找可用端口）
pnpm --filter @open-design/web dev &
WEB_PID=$!
sleep 5

# 打开浏览器
open http://localhost:3000

echo ""
echo "✅ Open Design 已在浏览器中打开！"
echo "   地址: http://localhost:3000"
echo ""
echo "按 Ctrl+C 或关闭此窗口停止服务"

# 等待子进程，Ctrl+C 时清理
trap "kill $DAEMON_PID $WEB_PID 2>/dev/null; exit 0" INT TERM
wait
