#!/bin/sh
# 添财AI · Codex 简体中文设置。Mac Apple / Intel 通用，不需要 Python 或 Homebrew。
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
        printf '%s\n' '已经是简体中文，无需改动配置。'
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
    printf '%s\n' '已设置为简体中文。'
}

main() {
    if [ "$(uname -s)" != Darwin ]; then printf '%s\n' '此脚本仅用于 macOS。' >&2; return 1; fi
    printf '%s\n' '添财AI · Codex 简体中文设置'
    if ! codex_app=$(/usr/bin/osascript -e 'POSIX path of (path to application id "com.openai.codex")' 2>/dev/null); then
        printf '%s\n' '未找到 Codex，请先将 Codex 安装到“应用程序”，再运行脚本。' >&2
        return 1
    fi
    printf '%s\n' '请先结束正在进行的任务并保存文件。继续后将退出并重新打开 Codex。'
    printf '输入 Y 继续，其他输入取消：'
    read -r answer || return 1
    case "$answer" in Y|y) ;; *) printf '%s\n' '已取消。'; return 0 ;; esac
    if ! /usr/bin/osascript >/dev/null 2>&1 <<'APPLESCRIPT'
with timeout of 10 seconds
    if application id "com.openai.codex" is running then
        tell application id "com.openai.codex" to quit
    end if
end timeout
APPLESCRIPT
    then
        printf '%s\n' 'Codex 未能正常退出，配置尚未修改。请手动退出后重新运行。' >&2
        return 1
    fi
    attempt=0
    while [ "$(/usr/bin/osascript -e 'application id "com.openai.codex" is running' 2>/dev/null)" = true ]; do
        attempt=$((attempt + 1))
        if [ "$attempt" -ge 10 ]; then
            printf '%s\n' 'Codex 仍在运行，配置尚未修改。请手动退出后重新运行。' >&2
            return 1
        fi
        sleep 1
    done
    codex_dir=${CODEX_HOME:-"$HOME/.codex"}
    # 在子 shell 中完成写入，失败时也能返回并重新打开原应用。
    result=0
    (write_chinese_config "$codex_dir/config.toml") || result=$?
    if ! /usr/bin/open "$codex_app"; then printf '%s\n' '请从“应用程序”手动打开 Codex。' >&2; fi
    return "$result"
}

# MAIN ENTRY
main "$@"
