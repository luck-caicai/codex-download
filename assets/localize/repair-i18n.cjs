'use strict';
// 添财AI：只在标记过的应用副本中启用内置翻译，不下载或执行应用脚本。
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const { spawnSync } = require('node:child_process');
const MARKER = '/*TCZH2*/';
const sha = bytes => crypto.createHash('sha256').update(bytes).digest('hex');
function requireCondition(ok, message) { if (!ok) throw new Error(message); }

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

function plan(root) {
  const archive = readArchive(path.join(root, 'resources', 'app.asar'));
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
    const runtime = inspectRuntime(root, oldHash);
    return { version: metadata.version, chinese, changes, nextHeader, oldHash, newHash, runtime };
  } finally { archive.close(); }
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
  const fd = fs.openSync(asar, 'r+');
  try {
    for (const item of result.changes) requireCondition(fs.writeSync(fd, item.content, 0, item.content.length, item.offset) === item.content.length, '脚本写入不完整');
    requireCondition(fs.writeSync(fd, result.nextHeader, 0, result.nextHeader.length, 16) === result.nextHeader.length, '文件头写入不完整');
    fs.fsyncSync(fd);
  } finally { fs.closeSync(fd); }
  for (const item of result.runtime.patches) {
    const hash = item.upper ? result.newHash.toUpperCase() : result.newHash;
    const bytes = Buffer.from(hash, item.encoding);
    const fd = fs.openSync(path.join(realRoot, item.name), 'r+');
    try { requireCondition(fs.writeSync(fd, bytes, 0, bytes.length, item.offset) === bytes.length, '可执行文件校验值写入失败'); fs.fsyncSync(fd); }
    finally { fs.closeSync(fd); }
  }
  const verified = readArchive(asar);
  try {
    requireCondition(sha(verified.bytes) === result.newHash, '修补后的文件头校验失败');
    for (const item of result.changes) {
      const content = verified.read(item.name), entry = verified.entries.get(item.name);
      requireCondition(content.equals(item.content) && sha(content) === entry.integrity.hash, '修补后文件校验失败：' + item.name);
    }
  } finally { verified.close(); }
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
module.exports = { readArchive, patchSource, inspectRuntime, plan, patchCopy, summary };
if (require.main === module) {
  try {
    const [mode, root] = process.argv.slice(2);
    requireCondition(root && ['inspect', 'patch-copy'].includes(mode), '用法：repair-i18n.cjs inspect|patch-copy 应用目录');
    process.stdout.write(JSON.stringify(summary(mode === 'inspect' ? plan(root) : patchCopy(root))));
  } catch (error) { process.stderr.write(error.message + '\n'); process.exitCode = 1; }
}
