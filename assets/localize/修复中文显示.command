#!/bin/sh
# 添财AI · Mac 中文显示修复 3.0，Apple 芯片 / Intel 共用，单文件自动运行。
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
tool_dir=
finish_command() {
    result=$?
    trap - 0
    if [ -n "$tool_dir" ]; then
        rm -f "$tool_dir/repair-i18n.cjs" "$tool_dir/repair-i18n-mac.cjs" "$tool_dir/修复中文显示.command" || :
        rmdir "$tool_dir" 2>/dev/null || :
    fi
    if [ "$result" -ne 0 ] && [ -t 0 ]; then
        printf '\n按回车关闭此窗口。'
        read -r finish || :
    fi
    exit "$result"
}
trap finish_command 0
if [ "$(uname -s)" != Darwin ]; then printf '%s\n' '此工具仅用于 macOS。' >&2; exit 1; fi
if [ "$(id -u)" = 0 ]; then printf '%s\n' '请以当前用户运行，不要使用 sudo。' >&2; exit 1; fi
printf '%s\n' '添财AI · Mac 中文显示修复 3.0'
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
umask 077
tool_dir=$(mktemp -d "${TMPDIR:-/tmp}/tiancai-codex-zh.XXXXXX") || exit 1
awk '/^# TIANCAI BEGIN CORE$/{copy=1;next}/^# TIANCAI END CORE$/{copy=0}copy' "$0" > "$tool_dir/repair-i18n.cjs"
awk '/^# TIANCAI BEGIN MAC$/{copy=1;next}/^# TIANCAI END MAC$/{copy=0}copy' "$0" > "$tool_dir/repair-i18n-mac.cjs"
cp "$0" "$tool_dir/修复中文显示.command"
if [ ! -s "$tool_dir/repair-i18n.cjs" ] || [ ! -s "$tool_dir/repair-i18n-mac.cjs" ]; then
    printf '%s\n' '脚本内容不完整，请重新下载。' >&2; exit 1
fi
"$node_runtime" "$tool_dir/repair-i18n-mac.cjs" "$codex_app"
exit 0

: <<'TIANCAI_CORE_PAYLOAD'
# TIANCAI BEGIN CORE
'use strict';
// 添财AI：只在标记过的应用副本中启用内置翻译，不下载或执行应用脚本。
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const { spawnSync } = require('node:child_process');
const MARKER = '/*TCZH2*/';
const sha = bytes => crypto.createHash('sha256').update(bytes).digest('hex');
function requireCondition(ok, message) { if (!ok) throw new Error(message); }

function inspectTree(root) {
  root = path.resolve(root);
  const files = [], directories = [];
  function visit(relative) {
    const full = path.join(root, relative), info = fs.lstatSync(full);
    requireCondition(!info.isSymbolicLink(), '应用目录含有链接，停止复制：' + full);
    if (info.isDirectory()) {
      directories.push(relative);
      for (const name of fs.readdirSync(full).sort()) visit(path.join(relative, name));
    } else {
      requireCondition(info.isFile(), '应用目录含有不支持的文件类型：' + full);
      files.push({ relative, size: info.size });
    }
  }
  requireCondition(fs.lstatSync(root).isDirectory(), '应用路径不是目录：' + root);
  visit('');
  return { root, files, directories };
}

function treeSummary(tree) {
  const entries = [
    ...tree.directories.map(name => ['directory', name]),
    ...tree.files.map(file => ['file', file.relative, file.size])
  ];
  return { files: tree.files.length, directories: tree.directories.length,
    bytes: tree.files.reduce((total, file) => total + file.size, 0),
    manifestHash: sha(Buffer.from(JSON.stringify(entries))) };
}

function copyApplication(source, destination) {
  const tree = inspectTree(source);
  requireCondition(tree.files.length > 0, '原应用目录中没有文件，停止复制');
  destination = path.resolve(destination);
  // Resolve an existing parent before making any changes to either tree.
  destination = path.join(fs.realpathSync(path.dirname(destination)), path.basename(destination));
  const relative = path.relative(fs.realpathSync(tree.root), destination);
  requireCondition(relative && (relative === '..' || relative.startsWith('..' + path.sep) || path.isAbsolute(relative)), '副本目录不能位于原应用目录内');
  // A fresh destination is required; never merge into or overwrite an existing copy.
  fs.mkdirSync(destination);
  for (const name of tree.directories) if (name) fs.mkdirSync(path.join(destination, name), { recursive: true });
  const buffer = Buffer.alloc(1024 * 1024);
  for (const file of tree.files) {
    let input, output;
    try {
      input = fs.openSync(path.join(tree.root, file.relative), 'r');
      output = fs.openSync(path.join(destination, file.relative), 'wx');
      let copied = 0, length;
      // Copy bytes only, without inheriting WindowsApps encryption or file attributes.
      while ((length = fs.readSync(input, buffer, 0, buffer.length, null)) > 0) {
        let offset = 0;
        while (offset < length) {
          const written = fs.writeSync(output, buffer, offset, length - offset);
          requireCondition(written > 0, '文件写入未完成');
          offset += written;
        }
        copied += length;
      }
      requireCondition(copied === file.size && fs.fstatSync(output).size === file.size, '复制前后大小不一致，原文件可能正在更新');
    } catch (error) {
      throw new Error('复制文件失败：' + file.relative + '；' + error.message);
    } finally {
      if (output !== undefined) fs.closeSync(output);
      if (input !== undefined) fs.closeSync(input);
    }
  }
  let result;
  try { result = treeSummary(inspectTree(destination)); }
  catch (error) { throw new Error('核对副本失败：' + error.message); }
  requireCondition(result.manifestHash === treeSummary(tree).manifestHash, '复制后的文件清单或大小不一致，停止修复');
  return result;
}

function readArchive(file) {
  const fd = fs.openSync(file, 'r');
  try {
    const length = fs.fstatSync(fd).size;
    const prefix = Buffer.alloc(16);
    requireCondition(fs.readSync(fd, prefix, 0, 16, 0) === 16, 'ASAR 文件头不完整');
    const jsonSize = prefix.readUInt32LE(12), start = 8 + prefix.readUInt32LE(4);
    requireCondition(jsonSize > 0 && jsonSize < 32 * 1024 * 1024 && start >= 16 + jsonSize && start <= length, 'ASAR 文件头范围无效');
    const bytes = Buffer.alloc(jsonSize);
    requireCondition(fs.readSync(fd, bytes, 0, jsonSize, 16) === jsonSize, '无法读取完整 ASAR 文件头');
    const text = bytes.toString('utf8'), header = JSON.parse(text), entries = new Map();
    function visit(node, prefix = '') {
      for (const [name, entry] of Object.entries(node.files || {})) {
        const key = prefix + name;
        if (entry.files) visit(entry, key + '/');
        else entries.set(key, entry);
      }
    }
    visit(header);
    function read(name) {
      const entry = entries.get(name), offset = Number(entry?.offset), size = entry?.size;
      requireCondition(entry && !entry.unpacked && !entry.link && Number.isSafeInteger(size) && size >= 0 && Number.isSafeInteger(offset) && offset >= 0 && start + offset + size <= length, '不支持的 ASAR 文件条目：' + name);
      requireCondition(size <= 64 * 1024 * 1024, '应用脚本过大，停止自动修补：' + name);
      const content = Buffer.alloc(size);
      requireCondition(fs.readSync(fd, content, 0, size, start + offset) === size, '应用文件读取不完整：' + name);
      return content;
    }
    return { fd, header, text, bytes, start, entries, read, close: () => fs.closeSync(fd) };
  } catch (error) { fs.closeSync(fd); throw error; }
}

function patchSource(source) {
  // Match only the known i18n boolean getter; other experiment settings are untouched.
  const calls = [...source.matchAll(/\.get\(\s*([`"'])enable_i18n\1\s*,/g)].length;
  const getter = /(?<![\w$.?])[$A-Z_a-z][\w$]*(?:\(\s*([`"'])72216192\1\s*\))?(?:\?\.|\.)get\(\s*([`"'])enable_i18n\2\s*,\s*(?:![01]|true|false)\s*\)/g;
  let count = 0;
  const code = source.replace(getter, match => {
    count++;
    return ('true' + MARKER).padEnd(match.length, ' ');
  });
  requireCondition(count === calls, '国际化代码结构已变化，停止自动修补');
  return { code, count };
}

function inspectRuntime(root, headerHash) {
  const sentinel = Buffer.from('dL7pKGdnNz796PbbjQWNKmHXBZaB9tsX');
  let fuseState;
  for (const name of ['ChatGPT.exe', 'Codex.exe', 'chrome.dll']) {
    const file = path.join(root, name);
    if (!fs.existsSync(file)) continue;
    const bytes = fs.readFileSync(file), offset = bytes.indexOf(sentinel);
    if (offset < 0) continue;
    requireCondition(bytes.indexOf(sentinel, offset + 1) < 0, '完整性校验标记不唯一：' + name);
    const wire = offset + sentinel.length;
    requireCondition(bytes[wire] === 1 && bytes[wire + 1] >= 5 && wire + 2 + bytes[wire + 1] <= bytes.length, '无法识别此版本的完整性校验格式');
    const state = bytes[wire + 6]; // Fuse V1 index 4: EmbeddedAsarIntegrityValidation.
    requireCondition(state === 48 || state === 49, '不支持的完整性校验状态');
    requireCondition(fuseState === undefined || fuseState === state, '检测到不同的完整性校验状态');
    fuseState = state;
  }
  requireCondition(fuseState !== undefined, '无法识别应用运行时，请提供版本和诊断记录');
  if (fuseState === 48) return { mode: '校验开关原本关闭；保留可执行文件', patches: [] };
  const patches = [];
  for (const name of ['ChatGPT.exe', 'Codex.exe']) {
    const file = path.join(root, name);
    if (!fs.existsSync(file)) continue;
    const bytes = fs.readFileSync(file);
    for (const encoding of ['utf8', 'utf16le']) for (const upper of [false, true]) {
      const needle = Buffer.from(upper ? headerHash.toUpperCase() : headerHash, encoding);
      let offset = bytes.indexOf(needle);
      while (offset >= 0) {
        patches.push({ name, offset, encoding, upper, length: needle.length });
        offset = bytes.indexOf(needle, offset + needle.length);
      }
    }
  }
  requireCondition(patches.length > 0, '完整性校验已开启，但未找到匹配的原始哈希；停止修补');
  return { mode: '保留完整性校验并更新副本哈希', patches };
}

function planArchive(file) {
  const archive = readArchive(file);
  try {
    const metadata = JSON.parse(archive.read('package.json'));
    requireCondition(metadata.name === 'openai-codex-electron', '所选目录不是支持的 Codex 桌面应用');
    const chinese = [...archive.entries.keys()].filter(name => /^webview\/assets\/zh-CN(?:-[\w-]+)?\.(?:js|json)$/.test(name));
    requireCondition(chinese.length > 0, '没有找到内置中文翻译文件，请先更新安装包');
    for (const name of chinese) {
      const bytes = archive.read(name), entry = archive.entries.get(name);
      requireCondition(bytes.length > 0 && entry.integrity?.algorithm === 'SHA256' && sha(bytes) === entry.integrity.hash, '中文翻译文件不完整，请重新安装原始安装包：' + name);
    }
    const changes = [];
    let providerCount = 0, already = 0;
    for (const name of archive.entries.keys()) {
      if (!/^webview\/assets\/[^/]+\.js$/.test(name)) continue;
      const original = archive.read(name), source = original.toString('utf8');
      if (source.includes(MARKER)) already++;
      if (!source.includes('enable_i18n')) continue;
      const changed = patchSource(source);
      if (!changed.count) continue;
      if (source.includes('Failed to load locale messages')) providerCount++;
      const replacement = Buffer.from(changed.code);
      requireCondition(replacement.length === original.length, '修补会改变文件长度，已停止：' + name);
      const syntax = spawnSync(process.execPath, ['--check', '--input-type=module'], { input: replacement, encoding: 'utf8', timeout: 30000, windowsHide: true });
      requireCondition(syntax.status === 0, '修补后 JavaScript 语法检查失败：' + name);
      const entry = archive.entries.get(name), integrity = entry.integrity;
      requireCondition(integrity?.algorithm === 'SHA256' && integrity.hash === sha(original), '原始脚本完整性检查失败：' + name);
      const blockSize = integrity.blockSize;
      requireCondition(Number.isSafeInteger(blockSize) && blockSize > 0 && Array.isArray(integrity.blocks) && integrity.blocks.length === Math.ceil(original.length / blockSize), '不支持的文件分块校验格式：' + name);
      const blocks = [];
      for (let i = 0; i < original.length; i += blockSize) {
        requireCondition(integrity.blocks[i / blockSize] === sha(original.subarray(i, i + blockSize)), '原始文件分块校验失败：' + name);
        blocks.push(sha(replacement.subarray(i, i + blockSize)));
      }
      entry.integrity = { ...integrity, hash: sha(replacement), blocks };
      changes.push({ name, count: changed.count, offset: archive.start + Number(entry.offset), content: replacement });
    }
    requireCondition(already === 0, '所选来源已经是添财AI修复副本，请直接使用修复版快捷方式，或选择原安装目录');
    requireCondition(providerCount === 1 && changes.length > 0, '未找到唯一、受支持的翻译加载入口，停止自动修补');
    const nextHeader = Buffer.from(JSON.stringify(archive.header));
    requireCondition(nextHeader.length === archive.bytes.length, 'ASAR 文件头格式发生变化，停止自动修补');
    const oldHash = sha(archive.bytes), newHash = sha(nextHeader);
    return { version: metadata.version, chinese, changes, nextHeader, oldHash, newHash };
  } finally { archive.close(); }
}

function plan(root) {
  const result = planArchive(path.join(root, 'resources', 'app.asar'));
  return { ...result, runtime: inspectRuntime(root, result.oldHash) };
}

function writeArchive(asar, result) {
  const before = readArchive(asar);
  try { requireCondition(sha(before.bytes) === result.oldHash, '写入前应用资源已变化，请重新运行'); }
  finally { before.close(); }
  const fd = fs.openSync(asar, 'r+');
  try {
    for (const item of result.changes) requireCondition(fs.writeSync(fd, item.content, 0, item.content.length, item.offset) === item.content.length, '脚本写入不完整');
    requireCondition(fs.writeSync(fd, result.nextHeader, 0, result.nextHeader.length, 16) === result.nextHeader.length, '文件头写入不完整');
    fs.fsyncSync(fd);
  } finally { fs.closeSync(fd); }
  const verified = readArchive(asar);
  try {
    requireCondition(sha(verified.bytes) === result.newHash, '修补后的文件头校验失败');
    for (const item of result.changes) {
      const content = verified.read(item.name), entry = verified.entries.get(item.name);
      requireCondition(content.equals(item.content) && sha(content) === entry.integrity.hash, '修补后文件校验失败：' + item.name);
    }
  } finally { verified.close(); }
}

function patchCopy(root) {
  const realRoot = fs.realpathSync(root);
  const markerPath = path.join(realRoot, '.tiancai-i18n-copy.json');
  const marker = JSON.parse(fs.readFileSync(markerPath, 'utf8').replace(/^\uFEFF/, ''));
  requireCondition(marker.tool === 'tiancai-i18n-2' && path.resolve(marker.source).toLowerCase() !== realRoot.toLowerCase(), '只能修补添财AI创建的独立应用副本');
  requireCondition(!realRoot.toLowerCase().includes('\\windowsapps\\'), '不允许修改 WindowsApps 中的安装文件');
  const result = plan(realRoot);
  requireCondition(result.oldHash === marker.sourceHeaderHash, '复制后的应用资源与检查时不一致，请重新运行');
  const asar = path.join(realRoot, 'resources', 'app.asar');
  // The source installation is the recovery copy. Failed builds receive no shortcut.
  writeArchive(asar, result);
  for (const item of result.runtime.patches) {
    const hash = item.upper ? result.newHash.toUpperCase() : result.newHash;
    const bytes = Buffer.from(hash, item.encoding);
    const fd = fs.openSync(path.join(realRoot, item.name), 'r+');
    try { requireCondition(fs.writeSync(fd, bytes, 0, bytes.length, item.offset) === bytes.length, '可执行文件校验值写入失败'); fs.fsyncSync(fd); }
    finally { fs.closeSync(fd); }
  }
  for (const item of result.runtime.patches) {
    const exe = fs.readFileSync(path.join(realRoot, item.name));
    requireCondition(exe.subarray(item.offset, item.offset + item.length).toString(item.encoding).toLowerCase() === result.newHash, '应用完整性哈希复核失败');
  }
  fs.writeFileSync(markerPath, JSON.stringify({ ...marker, patched: true, headerHash: result.newHash, files: result.changes.map(x => x.name) }, null, 2));
  return result;
}

function summary(result) {
  return { version: result.version, chineseResources: result.chinese.length, patchedGetters: result.changes.reduce((n, x) => n + x.count, 0), files: result.changes.map(x => x.name), headerHash: result.oldHash, newHeaderHash: result.newHash, integrity: result.runtime.mode };
}
module.exports = { inspectTree, treeSummary, copyApplication, readArchive, patchSource, planArchive, writeArchive, inspectRuntime, plan, patchCopy, summary };
if (require.main === module) {
  try {
    const [mode, root, destination] = process.argv.slice(2);
    requireCondition(root && ['inspect', 'patch-copy', 'inspect-tree', 'copy-app'].includes(mode), '用法：repair-i18n.cjs inspect|patch-copy|inspect-tree|copy-app 应用目录 [新副本目录]');
    requireCondition(mode !== 'copy-app' || destination, '复制应用时必须指定新副本目录');
    const result = mode === 'inspect-tree' ? treeSummary(inspectTree(root))
      : mode === 'copy-app' ? copyApplication(root, destination)
      : summary(mode === 'inspect' ? plan(root) : patchCopy(root));
    process.stdout.write(JSON.stringify(result));
  } catch (error) { process.stderr.write(error.message + '\n'); process.exitCode = 1; }
}
# TIANCAI END CORE
TIANCAI_CORE_PAYLOAD

: <<'TIANCAI_MAC_PAYLOAD'
# TIANCAI BEGIN MAC
'use strict';
// 添财AI · Mac 中文显示修复。只改本工具创建的副本；不下载依赖。
const fs = require('node:fs');
const path = require('node:path');
const os = require('node:os');
const crypto = require('node:crypto');
const child = require('node:child_process');
const { planArchive, writeArchive, readArchive } = require('./repair-i18n.cjs');
const TITLE = 'Codex 中文修复版（添财AI）';
const TAG = '# TiancaiAI Codex Chinese launcher v2';
const sha = value => crypto.createHash('sha256').update(value).digest('hex');
const check = (ok, message) => { if (!ok) throw new Error(message); };

function run(command, args, options = {}) {
  const result = child.spawnSync(command, args, { encoding: 'utf8', timeout: 60000, maxBuffer: 8 * 1024 * 1024, ...options });
  check(result.status === 0, `${path.basename(command)} 执行失败：${(result.error?.message || result.stderr || result.stdout || '未返回成功状态').trim().slice(0, 3000)}`);
  return result.stdout.trim();
}
function inside(root, target) {
  const relative = path.relative(root, target);
  return relative !== '' && relative !== '..' && !relative.startsWith('..' + path.sep) && !path.isAbsolute(relative);
}
function realFile(root, relative) {
  const file = fs.realpathSync(path.join(root, relative));
  check(inside(root, file) && fs.statSync(file).isFile(), '应用文件路径超出所选目录：' + relative);
  return file;
}
function readPlist(file) { return JSON.parse(run('/usr/bin/plutil', ['-convert', 'json', '-o', '-', file])); }

function inspectMacRuntime(root) {
  const frameworks = path.join(root, 'Contents', 'Frameworks');
  const sentinel = Buffer.from('dL7pKGdnNz796PbbjQWNKmHXBZaB9tsX');
  const digest = Buffer.from('AGbevlPCksUGKNL8TSn7wGmJEuJsXb2A');
  const found = [];
  for (const name of fs.readdirSync(frameworks)) {
    if (!name.endsWith('.framework')) continue;
    const relative = path.join('Contents', 'Frameworks', name, name.slice(0, -10));
    if (!fs.existsSync(path.join(root, relative))) continue;
    const file = realFile(root, relative), bytes = fs.readFileSync(file);
    let cursor = bytes.indexOf(sentinel), state;
    if (cursor < 0) continue;
    let slices = 0;
    while (cursor >= 0) {
      const wire = cursor + sentinel.length;
      check(bytes[wire] === 1 && bytes[wire + 1] >= 5 && wire + 2 + bytes[wire + 1] <= bytes.length, '无法识别 Mac 运行时校验格式');
      const current = bytes[wire + 6];
      check((current === 48 || current === 49) && (state === undefined || current === state), '不同架构的资源校验状态不一致');
      state = current; slices++;
      cursor = bytes.indexOf(sentinel, wire);
    }
    let digests = 0;
    for (let offset = bytes.indexOf(digest); offset >= 0; offset = bytes.indexOf(digest, offset + digest.length)) {
      check(offset + digest.length + 34 <= bytes.length, 'Mac 摘要校验标记不完整');
      // Enabled digests also seal the framework. Do not silently disable them.
      check(bytes[offset + digest.length] === 0, '该版本启用了额外的 ASAR 摘要校验，当前修复工具暂不支持。请保留版本和诊断记录。');
      digests++;
    }
    found.push({ file: path.relative(root, file), sha256: sha(bytes), integrityEnabled: state === 49, slices, digest: digests ? 'off' : 'absent' });
  }
  check(found.length === 1, '未找到唯一、受支持的 Mac 应用运行时');
  return found[0];
}

function inspectBundle(app) {
  const root = fs.realpathSync(app);
  check(root.endsWith('.app'), '请选择已经安装的原版 Codex / ChatGPT.app');
  const infoFile = realFile(root, 'Contents/Info.plist'), info = readPlist(infoFile);
  check(info.CFBundleIdentifier === 'com.openai.codex', '所选应用不是本工具支持的 Codex 桌面版');
  check(typeof info.CFBundleExecutable === 'string' && !/[\/\\\r\n]/.test(info.CFBundleExecutable), '应用启动文件信息不正确');
  const executable = realFile(root, path.join('Contents', 'MacOS', info.CFBundleExecutable));
  const archiveFile = realFile(root, 'Contents/Resources/app.asar'), result = planArchive(archiveFile);
  const integrity = info.ElectronAsarIntegrity?.['Resources/app.asar'];
  check(integrity?.algorithm === 'SHA256' && integrity.hash === result.oldHash, 'Info.plist 的原始资源校验值不匹配，请重新安装原版后再试');
  // Confirm the independent-profile mechanism exists before choosing a new profile.
  const archive = readArchive(archiveFile);
  let profileSupported = false;
  try {
    for (const name of archive.entries.keys()) {
      if (/^\.vite\/build\/bootstrap[^/]*\.js$/.test(name) && archive.read(name).includes('CODEX_ELECTRON_USER_DATA_PATH')) profileSupported = true;
    }
  } finally { archive.close(); }
  check(profileSupported, '该版本的独立界面数据目录机制无法识别，停止自动修复');
  const runtime = inspectMacRuntime(root);
  return { ...result, root, info, infoHash: sha(fs.readFileSync(infoFile)), executable, archiveFile, runtime };
}

function inspectTree(root, makeWritable = false) {
  let bytes = 0, files = 0;
  function visit(directory) {
    if (makeWritable) fs.chmodSync(directory, fs.statSync(directory).mode | 0o700);
    for (const name of fs.readdirSync(directory)) {
      const file = path.join(directory, name), stat = fs.lstatSync(file);
      if (stat.isSymbolicLink()) {
        check(inside(root, fs.realpathSync(file)), '应用中存在指向外部的链接，停止处理：' + path.relative(root, file));
      } else if (stat.isDirectory()) visit(file);
      else {
        check(stat.isFile(), '应用中存在不支持的特殊文件');
        check(!makeWritable || stat.nlink === 1, '副本中存在硬链接，停止处理');
        if (makeWritable) fs.chmodSync(file, stat.mode | 0o600);
        bytes += stat.size; files++;
      }
    }
  }
  visit(root);
  return { bytes, files };
}

function localEntitlements(original) {
  check(original['com.apple.security.app-sandbox'] !== true, '暂不支持 App Sandbox 版的本机重新签名');
  const kept = {}, removed = [];
  for (const [key, value] of Object.entries(original)) {
    if (['application-identifier', 'com.apple.application-identifier', 'keychain-access-groups', 'com.apple.security.application-groups'].includes(key) || key.startsWith('com.apple.developer.')) {
      removed.push(key);
    } else {
      check(key.startsWith('com.apple.security.'), '暂不支持的应用签名能力：' + key);
      kept[key] = value;
    }
  }
  // The local main executable must load the unchanged, vendor-signed frameworks.
  kept['com.apple.security.cs.disable-library-validation'] = true;
  return { kept, removed };
}
function readEntitlements(app) {
  const xml = run('/usr/bin/codesign', ['-d', '--entitlements', ':-', app]);
  const start = xml.indexOf('<?xml'), end = xml.indexOf('</plist>');
  check(start >= 0 && end > start, '无法读取原应用的签名权限；原安装未改动');
  return localEntitlements(JSON.parse(run('/usr/bin/plutil', ['-convert', 'json', '-o', '-', '-'], { input: xml.slice(start, end + 8) })));
}

function patchBundle(copy, source, build, codexHome, userData) {
  const root = fs.realpathSync(copy), parent = fs.realpathSync(build);
  check(path.dirname(root) === parent && root !== source.root && !inside(source.root, root), '只能修改独立应用副本');
  const marker = JSON.parse(fs.readFileSync(path.join(parent, '.tiancai-i18n-copy.json'), 'utf8'));
  check(marker.tool === 'tiancai-i18n-mac-2' && marker.source === source.root && marker.sourceHeaderHash === source.oldHash, '应用副本标记检查失败');
  const copied = inspectBundle(root);
  check(copied.oldHash === source.oldHash && copied.infoHash === source.infoHash && copied.runtime.sha256 === source.runtime.sha256, '复制时原版发生了变化，请重新运行');
  writeArchive(copied.archiveFile, copied);
  const infoFile = realFile(root, 'Contents/Info.plist');
  run('/usr/libexec/PlistBuddy', ['-c', 'Set :ElectronAsarIntegrity:Resources/app.asar:hash ' + copied.newHash, infoFile]);
  const environment = { ...copied.info.LSEnvironment, CODEX_HOME: codexHome, CODEX_ELECTRON_USER_DATA_PATH: userData, ELECTRON_LOCALE_OVERRIDE: 'zh-CN' };
  run('/usr/bin/plutil', [copied.info.LSEnvironment ? '-replace' : '-insert', 'LSEnvironment', '-json', JSON.stringify(environment), infoFile]);
  const updated = readPlist(infoFile);
  check(updated.ElectronAsarIntegrity['Resources/app.asar'].hash === copied.newHash && updated.LSEnvironment.CODEX_HOME === codexHome && updated.LSEnvironment.CODEX_ELECTRON_USER_DATA_PATH === userData, '修复副本的启动配置复核失败');
  check(sha(fs.readFileSync(realFile(root, copied.runtime.file))) === source.runtime.sha256, '运行时文件意外改变，停止处理');
  return copied;
}

const WORKSPACE_SCRIPT = `ObjC.import('AppKit');
function run(argv) {
  var apps = $.NSWorkspace.sharedWorkspace.runningApplications, result = [];
  for (var i = 0; i < apps.count; i++) {
    var app = apps.objectAtIndex(i);
    if (ObjC.unwrap(app.bundleIdentifier) !== 'com.openai.codex') continue;
    var p = ObjC.unwrap(app.bundleURL.path);
    if (argv[0] === 'quit' && argv.slice(1).indexOf(p) >= 0) app.terminate;
    result.push({path:p, pid:Number(app.processIdentifier)});
  }
  return JSON.stringify(result);
}`;
function runningApps(action = 'list', targets = []) {
  const items = JSON.parse(run('/usr/bin/osascript', ['-l', 'JavaScript', '-e', WORKSPACE_SCRIPT, action, ...targets]));
  check(Array.isArray(items) && items.every(item => typeof item.path === 'string' && Number.isInteger(item.pid)), '无法确认 Codex 的运行状态');
  return items;
}
const delay = ms => new Promise(resolve => setTimeout(resolve, ms));
async function closeApps(source, base) {
  const apps = runningApps();
  const targets = apps.map(item => item.path);
  for (const app of targets) {
    const real = fs.realpathSync(app);
    const markerFile = path.join(path.dirname(real), '.tiancai-i18n-copy.json');
    const owned = inside(base, real) && fs.existsSync(markerFile) && JSON.parse(fs.readFileSync(markerFile, 'utf8')).tool === 'tiancai-i18n-mac-2';
    check(real === source || owned, '请先手动退出其他位置的 Codex / ChatGPT，再重新运行修复工具');
  }
  if (!targets.length) return;
  runningApps('quit', targets);
  for (let i = 0; i < 15; i++) {
    if (!runningApps().length) return;
    await delay(1000);
  }
  throw new Error('Codex 未能正常退出，尚未写入语言配置。请手动退出后重新运行。');
}

function writeConfig(configPath) {
  const source = fs.readFileSync(path.join(__dirname, '修复中文显示.command'), 'utf8');
  const parts = source.split(/^# MAIN ENTRY$/m);
  check(parts.length === 2, '修复入口不完整，请重新解压整个 Mac 压缩包');
  return run('/bin/sh', ['-s', '--', configPath], { input: parts[0] + '\nwrite_chinese_config "$1"\n' });
}
const quote = value => "'" + value.replace(/'/g, "'\\''") + "'";
function launcherContent(copy, codexHome, userData) {
  return `#!/bin/sh\n${TAG}\nexec /usr/bin/open -n --env ${quote('CODEX_HOME=' + codexHome)} --env ${quote('CODEX_ELECTRON_USER_DATA_PATH=' + userData)} --env ELECTRON_LOCALE_OVERRIDE=zh-CN ${quote(copy)} --args --lang=zh-CN\n`;
}
function createLauncher(copy, codexHome, userData, home, build) {
  const text = launcherContent(copy, codexHome, userData), local = path.join(build, TITLE + '.command');
  fs.writeFileSync(local, text, { flag: 'wx', mode: 0o755 });
  const desktop = path.join(home, 'Desktop');
  if (!fs.existsSync(desktop)) return local;
  let target = path.join(desktop, TITLE + '.command');
  if (fs.existsSync(target) || (() => { try { return fs.lstatSync(target).isSymbolicLink(); } catch { return false; } })()) {
    const stat = fs.lstatSync(target);
    if (!stat.isFile() || stat.isSymbolicLink() || stat.nlink !== 1 || !fs.readFileSync(target, 'utf8').startsWith('#!/bin/sh\n' + TAG + '\n')) target = path.join(desktop, TITLE + '-' + path.basename(build) + '.command');
  }
  try {
    const temporary = path.join(desktop, '.tiancai-launcher-' + crypto.randomBytes(6).toString('hex'));
    fs.writeFileSync(temporary, text, { flag: 'wx', mode: 0o755 });
    fs.renameSync(temporary, target);
    return target;
  } catch { return local; }
}

async function main(app) {
  check(process.platform === 'darwin', '此工具只能在 macOS 上运行');
  check(process.getuid() !== 0, '请以当前用户运行，不要使用 sudo');
  process.umask(0o077);
  const home = os.homedir(), support = path.join(home, 'Library', 'Application Support', 'TiancaiAI');
  const logRoot = path.join(support, 'CodexLocale');
  fs.mkdirSync(logRoot, { recursive: true });
  const report = ['添财AI · Mac 中文显示修复 3.0', '时间：' + new Date().toISOString()];
  const log = text => report.push(text);
  const progress = text => { console.log(text); log(text); };
  let phase = '检查原安装', source, build, restore = false;
  try {
    progress('[1/3] 正在检查 Codex……');
    source = inspectBundle(app);
    log('原应用：' + source.root);
    log('应用版本：' + source.version);
    log('内置中文资源：' + source.chinese.length + '；待启用翻译开关：' + source.changes.reduce((n, c) => n + c.count, 0));
    log('资源校验开关：' + (source.runtime.integrityEnabled ? '开启，更新副本 Info.plist 哈希' : '原本关闭，保持原状态'));
    run('/usr/bin/codesign', ['--verify', '--deep', '--strict', source.root], { timeout: 180000 });
    const entitlements = readEntitlements(source.root), tree = inspectTree(source.root);
    const basePath = path.join(support, 'CodexChinese');
    fs.mkdirSync(basePath, { recursive: true });
    const base = fs.realpathSync(basePath);
    check(!inside(source.root, base) && base !== source.root, '副本位置不能位于原应用内');
    const codexHome = path.resolve(process.env.CODEX_HOME || path.join(home, '.codex'));
    const configPath = path.join(codexHome, 'config.toml');
    log('配置文件：' + configPath);
    const disk = fs.statfsSync(base);
    check(disk.bavail * disk.bsize > tree.bytes + 150 * 1024 * 1024, '磁盘空间不足，需要额外保存一份应用');
    log('将额外占用约 ' + Math.ceil(tree.bytes / 1048576) + ' MB。原安装保留。');
    log('副本会修改内置翻译开关，并使用本机临时签名，无法保留原厂签名。');
    log('可能需要重新登录、重新授予系统权限；原厂推送及共享钥匙串等功能可能受影响。');
    progress('[2/3] 正在复制并修复，请稍候……');
    phase = '复制应用';
    build = fs.mkdtempSync(path.join(base, 'build-' + new Date().toISOString().replace(/[^0-9]/g, '').slice(0, 14) + '-'));
    const copy = path.join(build, path.basename(source.root)), userData = path.join(base, 'UserData');
    fs.writeFileSync(path.join(build, '.tiancai-i18n-copy.json'), JSON.stringify({ tool: 'tiancai-i18n-mac-2', source: source.root, sourceHeaderHash: source.oldHash }), { flag: 'wx' });
    log('正在复制应用：' + copy);
    run('/usr/bin/ditto', ['--noqtn', source.root, copy], { timeout: 600000 });
    const copiedTree = inspectTree(copy, true);
    check(copiedTree.bytes === tree.bytes && copiedTree.files === tree.files, '复制后的文件数或大小不一致，请重新运行');
    phase = '启用中文翻译';
    const patched = patchBundle(copy, source, build, codexHome, userData);
    phase = '签名并验证副本';
    const entitlementsFile = path.join(build, 'local-entitlements.plist');
    fs.writeFileSync(entitlementsFile, run('/usr/bin/plutil', ['-convert', 'xml1', '-o', '-', '-'], { input: JSON.stringify(entitlements.kept) }));
    // Only the main bundle changed. Keep the nested executables' original signatures.
    run('/usr/bin/codesign', ['--force', '--sign', '-', '--options', 'runtime', '--entitlements', entitlementsFile, '--generate-entitlement-der', copy], { timeout: 180000 });
    run('/usr/bin/codesign', ['--verify', '--deep', '--strict', copy], { timeout: 180000 });
    log('副本资源与本机签名校验通过。');
    report.push('本机签名移除的厂商专属权限：' + entitlements.removed.join(', '));
    report.push('修补文件：' + patched.changes.map(c => c.name).join(', '));
    phase = '退出 Codex';
    progress('[3/3] 正在设置中文并重启 Codex……');
    restore = true;
    await closeApps(source.root, base);
    phase = '写入语言配置';
    log(writeConfig(configPath));
    fs.mkdirSync(userData, { recursive: true });
    phase = '创建启动入口';
    const launcher = createLauncher(copy, codexHome, userData, home, build);
    log('启动入口：' + launcher);
    phase = '打开修复副本';
    run('/usr/bin/open', ['-n', '--env', 'CODEX_HOME=' + codexHome, '--env', 'CODEX_ELECTRON_USER_DATA_PATH=' + userData, '--env', 'ELECTRON_LOCALE_OVERRIDE=zh-CN', copy, '--args', '--lang=zh-CN']);
    let started = false;
    for (let i = 0; i < 15; i++) {
      if (runningApps().some(item => fs.realpathSync(item.path) === fs.realpathSync(copy))) { started = true; break; }
      await delay(1000);
    }
    check(started, '暂未检测到修复版进程。请保留诊断记录；启动入口已保存。');
    restore = false;
    log('已检测到修复副本进程；未自动验证界面语言。');
    progress('修复完成，已打开 Codex，请检查界面是否显示中文。');
    progress('以后请使用：' + launcher);
  } catch (error) {
    report.push('失败阶段：' + phase);
    progress('未完成：' + error.message);
    if (build) log('保留副本供检查：' + build);
    if (restore && source) {
      try { if (!runningApps().length) run('/usr/bin/open', [source.root]); } catch { }
      progress('可从原来的入口打开原版 Codex。');
    }
    process.exitCode = 1;
  } finally {
    const file = path.join(logRoot, 'repair-mac-' + Date.now() + '.txt');
    fs.writeFileSync(file, report.join('\n') + '\n');
    if (process.exitCode) console.log('诊断记录：' + file);
  }
}

module.exports = { inside, realFile, inspectMacRuntime, inspectBundle, inspectTree, localEntitlements, patchBundle, runningApps, closeApps, writeConfig, launcherContent, createLauncher, main };
if (require.main === module) main(process.argv[2]).catch(error => { console.error(error.message); process.exitCode = 1; });
# TIANCAI END MAC
TIANCAI_MAC_PAYLOAD
