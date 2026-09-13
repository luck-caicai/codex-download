#!/bin/sh
# 添财AI · Mac 中文显示修复 2.1，Apple 芯片 / Intel 共用。
set -eu

write_chinese_config() {
    config_path=$1
    if [ -L "$config_path" ] || { [ -e "$config_path" ] && [ ! -f "$config_path" ]; }; then
        printf '%s\n' '配置路径是链接或目录，请手动设置语言，原文件未改动。' >&2
        return 1
    fi
    config_dir=$(dirname "$config_path")
    umask 077
    mkdir -p "$config_dir" || return 1
    temporary=$(mktemp "$config_dir/.config.toml.zh-cn.XXXXXX") || return 1
    trap 'rm -f "$temporary"' 0
    source_path=$config_path
    if [ ! -f "$source_path" ]; then source_path=/dev/null; fi
    original_sum=$(cksum < "$source_path") || return 1
    # BEGIN TOML EDITOR
    if ! awk '
    function fail(message) { print message > "/dev/stderr"; failed=1; exit 1 }
    function scan(line,    i,c,q,closing) {
        q=""
        for (i=1; i<=length(line); i++) {
            c=substr(line,i,1)
            if (multi!="") {
                if (multi==dq && c=="\\") { i++; continue }
                if (substr(line,i,3)==multi multi multi) {
                    closing=multi; multi=""
                    while (i<=length(line) && substr(line,i,1)==closing) i++
                    i--; continue
                }
            } else if (q!="") {
                if (q==dq && c=="\\") { i++; continue }
                if (c==q) q=""
            } else {
                if (c=="#") break
                if (c==dq || c==sq) {
                    if (substr(line,i,3)==c c c) { multi=c; i+=2; continue }
                    q=c
                } else if (c=="[" || c=="{") depth++
                else if (c=="]" || c=="}") depth--
            }
        }
        if (q!="" || depth<0) fail("配置中的引号或括号不完整，原文件未改动。")
    }
    BEGIN {
        dq=sprintf("%c",34); sq=sprintf("%c",39)
        dk="(desktop|" dq "desktop" dq "|" sq "desktop" sq ")"
        lk="(localeOverride|" dq "localeOverride" dq "|" sq "localeOverride" sq ")"
        root=1; replacement="localeOverride"
    }
    {
        raw=$0; line=raw; sub(/\r$/, "", line)
        if (NR==1 && raw ~ /\r$/) cr="\r"
        rows[NR]=raw
        if (multi=="" && depth==0) {
            if (line ~ "^[ \t]*\\[[ \t]*" dk "[ \t]*\\][ \t]*(#.*)?$") {
                if (header) fail("检测到重复的 [desktop]，原文件未改动。")
                header=NR; inside=1; root=0
                if (!first_header) first_header=NR
            } else if (line ~ /^[ \t]*\[/) {
                inside=0; root=0
                if (!first_header) first_header=NR
            }
            if (root && line ~ "^[ \t]*" dk "[ \t]*=") fail("desktop 使用内联配置，请在 Codex 设置中调整语言。原文件未改动。")
            if (root && line ~ "^[ \t]*" dk "[ \t]*\\.") dotted=1
            local_match=inside && line ~ "^[ \t]*" lk "[ \t]*="
            dotted_match=root && line ~ "^[ \t]*" dk "[ \t]*\\.[ \t]*" lk "[ \t]*="
            if (local_match || dotted_match) {
                if (locale_line) fail("检测到重复的语言字段，原文件未改动。")
                locale_line=NR
                if (dotted_match) replacement="desktop.localeOverride"
            }
        }
        scan(line)
        if (locale_line==NR && (multi!="" || depth!=0)) fail("语言字段使用了多行写法，请在 Codex 设置中调整。原文件未改动。")
    }
    END {
        if (failed) exit 1
        if (multi!="" || depth!=0) { print "配置中的多行字符串或数组未结束，原文件未改动。" > "/dev/stderr"; exit 1 }
        value="localeOverride = " dq "zh-CN" dq
        if (locale_line) {
            line=rows[locale_line]; sub(/\r$/, "", line)
            prefix=line; sub(/=.*/, "", prefix)
            tail=line; sub(/^[^=]*=[ \t]*/, "", tail)
            quote=substr(tail,1,1)
            if ((quote==dq || quote==sq) && index(substr(tail,2),quote)>0) {
                ending=substr(tail,index(substr(tail,2),quote)+2)
                rows[locale_line]=prefix "= " dq "zh-CN" dq ending cr
            } else {
                match(line,/^[ \t]*/)
                rows[locale_line]=substr(line,1,RLENGTH) replacement " = " dq "zh-CN" dq cr
            }
        }
        for (n=1; n<=NR; n++) {
            if (!locale_line && !header && dotted && first_header==n) print "desktop." value cr
            print rows[n]
            if (!locale_line && header==n) print value cr
        }
        if (!locale_line && !header) {
            if (dotted) { if (!first_header) print "desktop." value cr }
            else { if (NR && rows[NR]!="") print cr; print "[desktop]" cr; print value cr }
        }
    }
    ' "$source_path" > "$temporary"; then
        return 1
    fi
    # END TOML EDITOR
    if [ -f "$config_path" ] && cmp -s "$config_path" "$temporary"; then
        printf '%s\n' '语言配置已经是 zh-CN，无需改动配置。界面是否生效，请在重开后确认。'
        return 0
    fi
    if [ -f "$config_path" ]; then
        if [ "$(cksum < "$config_path")" != "$original_sum" ]; then
            printf '%s\n' '配置被其他程序修改，请关闭 Codex 后重新运行。' >&2
            return 1
        fi
        backup="$config_path.before-zh-cn.$(date +%Y%m%d-%H%M%S).${temporary##*.}.bak"
        cp -p "$config_path" "$backup" || return 1
        # 保留原文件权限，再以同一目录中的临时文件替换。
        chmod "$(stat -f %Lp "$config_path")" "$temporary" || return 1
        printf '配置备份：%s\n' "$backup"
    fi
    mv -f "$temporary" "$config_path" || return 1
    trap - 0
    printf '%s\n' '语言配置已写入：zh-CN。界面是否生效，请在重开后确认。'
}

# MAIN ENTRY
finish_command() {
    result=$?
    trap - 0
    if [ -t 0 ]; then
        printf '\n按回车关闭此窗口。'
        read -r finish || :
    fi
    exit "$result"
}
trap finish_command 0
if [ "$(uname -s)" != Darwin ]; then printf '%s\n' '此工具仅用于 macOS。' >&2; exit 1; fi
if [ "$(id -u)" = 0 ]; then printf '%s\n' '请以当前用户运行，不要使用 sudo。' >&2; exit 1; fi
tool_dir=$(CDPATH= cd "$(dirname "$0")" && pwd) || exit 1
for name in repair-i18n.cjs repair-i18n-mac.cjs; do
    if [ ! -f "$tool_dir/$name" ]; then printf '%s\n' '请完整解压 Mac 压缩包，保留其中全部文件。' >&2; exit 1; fi
done
printf '%s\n' '添财AI · Mac 中文显示修复 2.1'
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
"$node_runtime" "$tool_dir/repair-i18n-mac.cjs" "$codex_app"
