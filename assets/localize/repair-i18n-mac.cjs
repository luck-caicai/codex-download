'use strict';
// 添财AI · Mac 中文显示修复。只改本工具创建的副本；不下载依赖。
const fs = require('node:fs');
const path = require('node:path');
const os = require('node:os');
const crypto = require('node:crypto');
const child = require('node:child_process');
const readline = require('node:readline/promises');
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
  const source = fs.readFileSync(path.join(__dirname, 'codex-zh-cn.sh'), 'utf8');
  const parts = source.split('# MAIN ENTRY');
  check(parts.length === 2, '普通设置脚本不完整，请重新解压整个 Mac 压缩包');
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
  const report = ['添财AI · Mac 中文显示修复 2.0', '时间：' + new Date().toISOString()];
  const log = text => { console.log(text); report.push(text); };
  let phase = '检查原安装', source, build, restore = false;
  try {
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
    log('请先结束任务并保存文件，继续后会退出 Codex 并打开修复副本。');
    const prompt = readline.createInterface({ input: process.stdin, output: process.stdout });
    let answer;
    try { answer = await prompt.question('输入 Y 继续，其他输入取消：'); } finally { prompt.close(); }
    if (!/^[yY]$/.test(answer)) { log('已取消。'); return; }
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
    restore = true;
    await closeApps(source.root, base);
    phase = '写入语言配置';
    log(writeConfig(configPath));
    fs.mkdirSync(userData, { recursive: true });
    phase = '创建启动入口';
    const launcher = createLauncher(copy, codexHome, userData, home, build);
    log('以后请使用：' + launcher);
    phase = '打开修复副本';
    run('/usr/bin/open', ['-n', '--env', 'CODEX_HOME=' + codexHome, '--env', 'CODEX_ELECTRON_USER_DATA_PATH=' + userData, '--env', 'ELECTRON_LOCALE_OVERRIDE=zh-CN', copy, '--args', '--lang=zh-CN']);
    let started = false;
    for (let i = 0; i < 15; i++) {
      if (runningApps().some(item => fs.realpathSync(item.path) === fs.realpathSync(copy))) { started = true; break; }
      await delay(1000);
    }
    check(started, '暂未检测到修复版进程。请保留诊断记录；启动入口已保存。');
    restore = false;
    log('已检测到修复副本进程，请确认页面是否显示中文。启动成功不等于已验证界面语言。');
  } catch (error) {
    report.push('失败阶段：' + phase);
    log('未完成：' + error.message);
    if (build) log('保留副本供检查：' + build);
    if (restore && source) {
      try { if (!runningApps().length) run('/usr/bin/open', [source.root]); } catch { }
      log('可从原来的入口打开原版 Codex。');
    }
    process.exitCode = 1;
  } finally {
    const file = path.join(logRoot, 'repair-mac-' + Date.now() + '.txt');
    fs.writeFileSync(file, report.join('\n') + '\n');
    console.log('诊断记录：' + file);
  }
}

module.exports = { inside, realFile, inspectMacRuntime, inspectBundle, inspectTree, localEntitlements, patchBundle, runningApps, closeApps, writeConfig, launcherContent, createLauncher, main };
if (require.main === module) main(process.argv[2]).catch(error => { console.error(error.message); process.exitCode = 1; });
