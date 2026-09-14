'use strict';
// Read/write only fresh fixtures. No Codex process or user configuration is opened.
const fs = require('node:fs'), path = require('node:path'), os = require('node:os');
const assert = require('node:assert/strict'), child = require('node:child_process');
const { inspectTree, treeSummary, copyApplication } = require('../assets/localize/repair-i18n.cjs');
const work = fs.mkdtempSync(path.join(os.tmpdir(), 'tiancai-copy-check-'));
const source = path.join(work, 'source with spaces & 中文 [原版]');
const target = path.join(work, 'build-中文 副本 [copy]');
const checks = [];
function check(name, test) { test(); checks.push(name); }
function put(relative, bytes) {
  const file = path.join(source, relative);
  fs.mkdirSync(path.dirname(file), { recursive: true });
  fs.writeFileSync(file, bytes);
}
const longName = path.join('resources', ...Array.from({ length: 9 }, (_, i) => 'nested-' + i + '-' + 'a'.repeat(24)), '中文 [long] & file.bin');
put('ChatGPT.exe', 'INERT: never execute');
put('resources/app.asar', Buffer.from([0, 255, 19, 10]));
put('resources/empty.bin', Buffer.alloc(0));
put(longName, Buffer.alloc(1024 * 1024 + 37, 173));
fs.mkdirSync(path.join(source, 'empty-directory'));
const before = treeSummary(inspectTree(source));

check('copies long paths, Unicode, spaces, brackets, empty files and empty directories', () => {
  assert.ok(path.join(source, longName).length > 260);
  assert.deepEqual(copyApplication(source, target), before);
  for (const file of inspectTree(source).files) {
    assert.deepEqual(fs.readFileSync(path.join(target, file.relative)), fs.readFileSync(path.join(source, file.relative)));
  }
  assert.ok(fs.statSync(path.join(target, 'empty-directory')).isDirectory());
  assert.deepEqual(treeSummary(inspectTree(source)), before);
});

check('existing destination is preserved and never merged or overwritten', () => {
  fs.writeFileSync(path.join(target, 'keep.txt'), 'existing destination');
  assert.throws(() => copyApplication(source, target), { code: 'EEXIST' });
  assert.equal(fs.readFileSync(path.join(target, 'keep.txt'), 'utf8'), 'existing destination');
});

check('rejects a destination inside the source without changing the source', () => {
  const nested = path.join(source, 'do-not-create');
  assert.throws(() => copyApplication(source, nested), /不能位于原应用目录内/);
  assert.equal(fs.existsSync(nested), false);
  assert.deepEqual(treeSummary(inspectTree(source)), before);
});

check('missing source fails before creating the destination', () => {
  const absent = path.join(work, 'not-created');
  assert.throws(() => copyApplication(path.join(work, 'missing'), absent), { code: 'ENOENT' });
  assert.equal(fs.existsSync(absent), false);
});

check('copy failures report the file and underlying error', () => {
  const original = fs.writeSync;
  try {
    fs.writeSync = () => { throw new Error('fixture: disk full'); };
    assert.throws(() => copyApplication(source, path.join(work, 'disk-full')), /复制文件失败：ChatGPT\.exe；fixture: disk full/);
  } finally { fs.writeSync = original; }
  assert.deepEqual(treeSummary(inspectTree(source)), before);
});

check('incomplete native writes are completed before advancing to the next buffer', () => {
  const original = fs.writeSync;
  try {
    fs.writeSync = (fd, buffer, offset, length, position) => original(fd, buffer, offset, Math.min(length, 997), position);
    const partial = path.join(work, 'partial-write');
    assert.deepEqual(copyApplication(source, partial), before);
    assert.deepEqual(fs.readFileSync(path.join(partial, longName)), fs.readFileSync(path.join(source, longName)));
  } finally { fs.writeSync = original; }
});

check('does not traverse junctions or symbolic links', () => {
  const linked = path.join(work, 'linked-source'), outside = path.join(work, 'outside');
  fs.mkdirSync(linked); fs.mkdirSync(outside);
  fs.writeFileSync(path.join(outside, 'keep.txt'), 'outside fixture');
  fs.symlinkSync(outside, path.join(linked, 'link'), process.platform === 'win32' ? 'junction' : 'dir');
  assert.throws(() => copyApplication(linked, path.join(work, 'linked-copy')), /含有链接/);
  assert.equal(fs.existsSync(path.join(work, 'linked-copy')), false);
});

if (process.platform === 'win32') check('Windows PowerShell 5.1 can invoke the real copy helper without extended path enumeration', () => {
  const helper = path.resolve(__dirname, '../assets/localize/repair-i18n.cjs');
  const destination = path.join(work, 'powershell 中文 & [copy]');
  const script = '[Console]::OutputEncoding = New-Object Text.UTF8Encoding($false); & $env:TC_COPY_NODE $env:TC_COPY_HELPER copy-app $env:TC_COPY_SOURCE $env:TC_COPY_TARGET; exit $LASTEXITCODE';
  const result = child.spawnSync(path.join(process.env.WINDIR, 'System32/WindowsPowerShell/v1.0/powershell.exe'), ['-NoLogo', '-NoProfile', '-Command', script], {
    encoding: 'utf8', windowsHide: true, timeout: 30000,
    env: { ...process.env, TC_COPY_NODE: process.execPath, TC_COPY_HELPER: helper, TC_COPY_SOURCE: source, TC_COPY_TARGET: destination }
  });
  assert.equal(result.status, 0, result.stderr || result.stdout);
  assert.deepEqual(JSON.parse(result.stdout), before);
  assert.deepEqual(fs.readFileSync(path.join(destination, longName)), fs.readFileSync(path.join(source, longName)));
});

console.log(JSON.stringify({ checksPassed: checks.length, checks, fixtureDirectory: work }, null, 2));
