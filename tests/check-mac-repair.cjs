'use strict';
// Isolated fixtures only. --app additionally checks a downloaded release on a disposable Mac runner.
const fs = require('node:fs'), os = require('node:os'), path = require('node:path');
const child = require('node:child_process'), assert = require('node:assert/strict'), crypto = require('node:crypto');
const lib = require('../assets/localize/repair-i18n-mac.cjs');
const core = require('../assets/localize/repair-i18n.cjs');
const work = fs.mkdtempSync(path.join(os.tmpdir(), 'tiancai-mac-check-'));
const hash = value => crypto.createHash('sha256').update(value).digest('hex');
const checks = [];
function check(name, body) { body(); checks.push(name); }

function fixture(name, integrity = true, digest = false) {
  const root = path.join(work, name + '.app');
  const files = {
    'package.json': JSON.stringify({ name: 'openai-codex-electron', version: 'mac-fixture' }),
    'webview/assets/app-initial-test.js': 'const gate=l?.get("enable_i18n",false);function f(){throw Error("Failed to load locale messages")};export{gate}',
    'webview/assets/general-settings-test.js': 'const visible=Zt(`72216192`)?.get(`enable_i18n`,!0);export{visible}',
    'webview/assets/zh-CN-test.js': 'export default {label:"中文"}',
    '.vite/build/bootstrap-test.js': 'const path=process.env.CODEX_ELECTRON_USER_DATA_PATH;',
    'untouched.txt': 'English 中文 preserve bytes'
  };
  const header = { files: {} }, body = []; let offset = 0;
  for (const [name, value] of Object.entries(files)) {
    const bytes = Buffer.from(value), parts = name.split('/'), last = parts.pop(); let node = header;
    for (const part of parts) node = node.files[part] ||= { files: {} };
    const blocks = [];
    for (let i = 0; i < bytes.length; i += 32) blocks.push(hash(bytes.subarray(i, i + 32)));
    node.files[last] = { size: bytes.length, offset: String(offset), integrity: { algorithm: 'SHA256', hash: hash(bytes), blockSize: 32, blocks } };
    offset += bytes.length; body.push(bytes);
  }
  const bytes = Buffer.from(JSON.stringify(header)), padding = Buffer.alloc((-bytes.length >>> 0) % 4), prefix = Buffer.alloc(16);
  prefix.writeUInt32LE(4, 0); prefix.writeUInt32LE(8 + bytes.length + padding.length, 4); prefix.writeUInt32LE(4 + bytes.length + padding.length, 8); prefix.writeUInt32LE(bytes.length, 12);
  fs.mkdirSync(path.join(root, 'Contents/Resources'), { recursive: true });
  fs.mkdirSync(path.join(root, 'Contents/MacOS'), { recursive: true });
  fs.mkdirSync(path.join(root, 'Contents/Frameworks/Codex Framework.framework'), { recursive: true });
  fs.writeFileSync(path.join(root, 'Contents/MacOS/ChatGPT'), 'INERT FIXTURE');
  fs.writeFileSync(path.join(root, 'Contents/Resources/app.asar'), Buffer.concat([prefix, bytes, padding, ...body]));
  fs.writeFileSync(path.join(root, 'Contents/Info.plist'), JSON.stringify({ CFBundleIdentifier: 'com.openai.codex', CFBundleExecutable: 'ChatGPT', LSEnvironment: { MallocNanoZone: '0' }, ElectronAsarIntegrity: { 'Resources/app.asar': { algorithm: 'SHA256', hash: hash(bytes) } } }));
  fs.writeFileSync(path.join(root, 'Contents/Frameworks/Codex Framework.framework/Codex Framework'), Buffer.concat([
    Buffer.from('INERT dL7pKGdnNz796PbbjQWNKmHXBZaB9tsX'), Buffer.from([1, 9]), Buffer.from(integrity ? '101110011' : '101100011'),
    Buffer.from('AGbevlPCksUGKNL8TSn7wGmJEuJsXb2A'), Buffer.from([digest ? 1 : 0, 1]), Buffer.alloc(32)
  ]));
  return root;
}

const realSpawn = child.spawnSync;
// Use a small stand-in for native plist tools during the portable fixture checks.
child.spawnSync = (command, args, options) => {
  try {
    const file = args.at(-1);
    if (command === '/usr/bin/plutil') {
      if (args[0] === '-convert') return { status: 0, stdout: fs.readFileSync(file, 'utf8'), stderr: '' };
      const info = JSON.parse(fs.readFileSync(file, 'utf8'));
      info[args[1]] = JSON.parse(args[3]); fs.writeFileSync(file, JSON.stringify(info));
      return { status: 0, stdout: '', stderr: '' };
    }
    if (command === '/usr/libexec/PlistBuddy') {
      const info = JSON.parse(fs.readFileSync(file, 'utf8'));
      info.ElectronAsarIntegrity['Resources/app.asar'].hash = args[1].split(' ').at(-1);
      fs.writeFileSync(file, JSON.stringify(info)); return { status: 0, stdout: '', stderr: '' };
    }
    return realSpawn(command, args, options);
  } catch (error) { return { status: 1, stdout: '', stderr: error.message }; }
};
try {
  for (const integrity of [false, true]) {
    const original = fixture('source-' + integrity, integrity), info = lib.inspectBundle(original);
    const asar = path.join(original, 'Contents/Resources/app.asar'), before = fs.readFileSync(asar);
    check('recognize runtime and two getters: ' + integrity, () => {
      assert.equal(info.runtime.integrityEnabled, integrity);
      assert.equal(info.changes.reduce((n, c) => n + c.count, 0), 2);
    });
    const build = path.join(work, 'build-' + integrity), copy = path.join(build, 'ChatGPT.app');
    fs.cpSync(original, copy, { recursive: true });
    fs.writeFileSync(path.join(build, '.tiancai-i18n-copy.json'), JSON.stringify({ tool: 'tiancai-i18n-mac-2', source: original, sourceHeaderHash: info.oldHash }));
    const result = lib.patchBundle(copy, info, build, '/fixture/配置 含空格', '/fixture/UserData');
    check('archive hashes, Chinese bytes, unrelated bytes, offsets: ' + integrity, () => {
      const ar = core.readArchive(path.join(copy, 'Contents/Resources/app.asar'));
      try {
        assert.equal(hash(ar.bytes), result.newHash);
        for (const [name, entry] of ar.entries) {
          const bytes = ar.read(name); assert.equal(hash(bytes), entry.integrity.hash);
          for (let i = 0; i < bytes.length; i += 32) assert.equal(hash(bytes.subarray(i, i + 32)), entry.integrity.blocks[i / 32]);
        }
        assert.equal(ar.read('untouched.txt').toString(), 'English 中文 preserve bytes');
        assert.equal(ar.read('webview/assets/zh-CN-test.js').toString(), 'export default {label:"中文"}');
      } finally { ar.close(); }
    });
    check('original unchanged, plist and environment updated: ' + integrity, () => {
      assert.deepEqual(fs.readFileSync(asar), before);
      const plist = JSON.parse(fs.readFileSync(path.join(copy, 'Contents/Info.plist')));
      assert.equal(plist.ElectronAsarIntegrity['Resources/app.asar'].hash, result.newHash);
      assert.equal(plist.LSEnvironment.MallocNanoZone, '0');
      assert.equal(plist.LSEnvironment.CODEX_HOME, '/fixture/配置 含空格');
    });
    check('original and already patched bundle rejected: ' + integrity, () => {
      assert.throws(() => lib.patchBundle(original, info, build, '', ''));
      assert.throws(() => lib.inspectBundle(copy), /已经/);
    });
  }
  check('enabled embedded digest is rejected before writes', () => assert.throws(() => lib.inspectBundle(fixture('digest-enabled', true, true)), /摘要校验/));
  check('mismatched plist header is rejected', () => {
    const root = fixture('bad-plist'), file = path.join(root, 'Contents/Info.plist');
    const info = JSON.parse(fs.readFileSync(file)); info.ElectronAsarIntegrity['Resources/app.asar'].hash = '0'.repeat(64);
    fs.writeFileSync(file, JSON.stringify(info)); assert.throws(() => lib.inspectBundle(root), /校验值/);
  });
  check('local signing retains JIT and removes identity-specific claims', () => {
    const result = lib.localEntitlements({ 'com.apple.security.cs.allow-jit': true, 'com.apple.developer.aps-environment': 'production', 'keychain-access-groups': ['vendor'], 'com.apple.security.application-groups': ['vendor'] });
    assert.equal(result.kept['com.apple.security.cs.allow-jit'], true);
    assert.equal(result.kept['com.apple.security.cs.disable-library-validation'], true);
    assert.equal(result.removed.length, 3);
    assert.throws(() => lib.localEntitlements({ 'com.apple.security.app-sandbox': true }), /Sandbox/);
  });
  check('launcher preserves spaces, Unicode, quotes and shell metacharacters as data', () => {
    const launcher = lib.launcherContent("/Applications/添财 ' $`&.app", '/fixture/配置', '/fixture/data');
    assert(launcher.includes("'\\''")); assert(launcher.includes('--env')); assert(launcher.includes('--lang=zh-CN'));
  });
  check('desktop launcher preserves unrelated files', () => {
    const home = path.join(work, 'home'), build = path.join(work, 'launcher-build');
    fs.mkdirSync(path.join(home, 'Desktop'), { recursive: true }); fs.mkdirSync(build);
    const target = path.join(home, 'Desktop', 'Codex 中文修复版（添财AI）.command');
    fs.writeFileSync(target, 'USER FILE');
    const created = lib.createLauncher('/fixture/app', '/fixture/config', '/fixture/data', home, build);
    assert.equal(fs.readFileSync(target, 'utf8'), 'USER FILE'); assert.notEqual(created, target);
  });
} finally { child.spawnSync = realSpawn; }

function nativeCheck(app) {
  assert.equal(process.platform, 'darwin');
  const original = lib.inspectBundle(app), before = hash(fs.readFileSync(original.archiveFile));
  const home = path.join(work, 'native-user'), codexHome = path.join(home, '.codex');
  fs.mkdirSync(path.join(home, 'Desktop'), { recursive: true }); fs.mkdirSync(codexHome);
  fs.writeFileSync(path.join(codexHome, 'config.toml'), 'model = "fixture-model"\n[desktop]\nlocaleOverride = "en-US"\n');
  const result = realSpawn('/bin/sh', [path.join(__dirname, '../assets/localize/repair-i18n-mac.sh'), app], {
    input: 'Y\n', encoding: 'utf8', timeout: 600000, maxBuffer: 4 * 1024 * 1024,
    env: { ...process.env, HOME: home, CODEX_HOME: codexHome }
  });
  console.log(result.stdout); if (result.stderr) console.error(result.stderr);
  assert.equal(result.status, 0, 'native repair failed: ' + result.stderr + result.stdout);
  const base = path.join(home, 'Library/Application Support/TiancaiAI/CodexChinese');
  const build = fs.readdirSync(base).find(name => name.startsWith('build-'));
  const copy = path.join(base, build, path.basename(app));
  const verify = realSpawn('/usr/bin/codesign', ['--verify', '--deep', '--strict', copy], { encoding: 'utf8' });
  assert.equal(verify.status, 0, verify.stderr);
  assert.equal(hash(fs.readFileSync(original.archiveFile)), before, 'original application changed');
  const config = fs.readFileSync(path.join(codexHome, 'config.toml'), 'utf8');
  assert(config.includes('localeOverride = "zh-CN"')); assert(config.includes('fixture-model'));
  assert(fs.readdirSync(codexHome).some(name => name.includes('.before-zh-cn.')));
  assert(lib.runningApps().some(item => fs.realpathSync(item.path) === fs.realpathSync(copy)), 'repaired app exited after startup');
  lib.runningApps('quit', [copy]);
  checks.push('real Mac native copy, signing, config backup, launch and graceful quit: ' + process.arch);
}
try {
  const index = process.argv.indexOf('--app');
  if (index >= 0) nativeCheck(process.argv[index + 1]);
  console.log(JSON.stringify({ passed: checks.length, checks, native: index >= 0, work }, null, 2));
} catch (error) {
  console.error('::error::' + error.message.replace(/\r?\n/g, '%0A'));
  process.exitCode = 1;
}
