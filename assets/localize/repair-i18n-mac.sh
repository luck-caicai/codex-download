#!/bin/sh
# 添财AI · Mac 中文显示修复 2.0，Apple 芯片 / Intel 共用。
set -eu
if [ "$(uname -s)" != Darwin ]; then printf '%s\n' '此工具仅用于 macOS。' >&2; exit 1; fi
if [ "$(id -u)" = 0 ]; then printf '%s\n' '请以当前用户运行，不要使用 sudo。' >&2; exit 1; fi
tool_dir=$(CDPATH= cd "$(dirname "$0")" && pwd) || exit 1
for name in repair-i18n.cjs repair-i18n-mac.cjs codex-zh-cn.sh; do
    if [ ! -f "$tool_dir/$name" ]; then printf '%s\n' '请完整解压 Mac 压缩包，保留其中全部文件。' >&2; exit 1; fi
done
printf '%s\n' '添财AI · Mac 中文显示修复 2.0'
codex_app=${1:-}
if [ -z "$codex_app" ]; then
    matches=0
    for candidate in /Applications/ChatGPT.app /Applications/Codex.app "$HOME/Applications/ChatGPT.app" "$HOME/Applications/Codex.app"; do
        if [ -f "$candidate/Contents/Resources/app.asar" ] && [ "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$candidate/Contents/Info.plist" 2>/dev/null || :)" = com.openai.codex ]; then
            codex_app=$candidate
            matches=$((matches + 1))
        fi
    done
    if [ "$matches" -ne 1 ]; then
        printf '%s\n' '请在弹出的窗口选择已经安装的原版 Codex 或新版 ChatGPT。'
        if ! codex_app=$(/usr/bin/osascript -e 'POSIX path of (choose application with prompt "选择已经安装的原版 Codex / ChatGPT，不要选中文修复副本" as alias)' 2>/dev/null); then
            printf '%s\n' '已取消选择。'; exit 0
        fi
    fi
fi
if [ ! -d "$codex_app/Contents" ]; then printf '%s\n' '请选择 .app 应用，不要选择 .dmg 安装包。' >&2; exit 1; fi
node_runtime="$codex_app/Contents/Resources/cua_node/bin/node"
if [ ! -x "$node_runtime" ]; then
    node_runtime=$(command -v node || :)
fi
if [ -z "$node_runtime" ] || ! "$node_runtime" -e 'process.exit(Number(process.versions.node.split(".")[0]) >= 18 && typeof require("node:fs").statfsSync === "function" ? 0 : 1)' >/dev/null 2>&1; then
    printf '%s\n' '此版本缺少可用的内置 Node.js。请更新与本机芯片匹配的 Codex 安装包后重试。' '修复工具不会自动下载或安装开发环境。' >&2
    exit 1
fi
exec "$node_runtime" "$tool_dir/repair-i18n-mac.cjs" "$codex_app"
