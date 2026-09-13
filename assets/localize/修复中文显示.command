#!/bin/sh
tool_dir=$(CDPATH= cd "$(dirname "$0")" && pwd) || exit 1
result=0
/bin/sh "$tool_dir/repair-i18n-mac.sh" "$@" || result=$?
printf '\n按回车关闭此窗口。'
read -r finish || :
exit "$result"
