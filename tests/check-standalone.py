"""Exercise each download entry alone, with closed stdin and inert backends."""
from pathlib import Path
import json
import os
import re
import shutil
import subprocess
import tempfile
import zipfile

site = Path(__file__).resolve().parent.parent
assets = site / 'assets/localize'
work = Path(tempfile.mkdtemp(prefix='tiancai-standalone-'))
checks = []
for archive_name, entry_name, mode in [('codex-zh-cn-windows.zip', '修复中文显示.bat', 0o644), ('codex-zh-cn-mac.zip', '修复中文显示.command', 0o755)]:
    with zipfile.ZipFile(assets/archive_name) as archive:
        assert archive.testzip() is None
        assert archive.namelist() == [entry_name]
        assert archive.read(entry_name) == (assets/entry_name).read_bytes()
        assert (archive.getinfo(entry_name).external_attr >> 16) & 0o777 == mode
    checks.append(archive_name + ': exactly one complete entry')

if os.name == 'nt':
    source = (assets/'修复中文显示.bat').read_text(encoding='utf-8')
    assert 'Read-Host' not in source
    for status in [0, 7]:
        folder = work/f'Windows {status} 中文 & [单文件]'
        folder.mkdir()
        entry = folder/'修复中文显示.bat'
        replacement = '''if ($MyInvocation.InvocationName -ne '.') {
    [IO.File]::WriteAllText($env:TC_EMBEDDED_CAPTURE, $script:TiancaiCoreSource, (New-Object Text.UTF8Encoding($false)))
    Write-Output 'STANDALONE_BOOTSTRAP_OK'
    exit ([int]$env:TC_EMBEDDED_STATUS)
}'''
        # Replace only dispatch; parsing, embedded JS, shared functions and BAT entry are real.
        inert = source[:source.rindex('if ($MyInvocation.InvocationName')] + replacement + '\n'
        entry.write_bytes(inert.replace('\n', '\r\n').encode('utf-8'))
        capture = folder/'captured.cjs'
        env = dict(os.environ, TC_EMBEDDED_CAPTURE=str(capture), TC_EMBEDDED_STATUS=str(status))
        command = '"' + env['COMSPEC'] + '" /d /s /c ""' + str(entry) + '""'
        result = subprocess.run(command, input=b'', capture_output=True, env=env, timeout=30)
        assert result.returncode == status, (result.returncode, result.stdout, result.stderr)
        assert b'STANDALONE_BOOTSTRAP_OK' in result.stdout
        assert capture.read_text(encoding='utf-8').strip() == (assets/'repair-i18n.cjs').read_text(encoding='utf-8').strip()
        checks.append(f'Windows standalone: closed stdin, embedded payload, exit {status}')

shell = '/bin/sh'
if os.name == 'nt':
    # Windows' system32/bash.exe may be WSL and cannot read Windows paths.
    shell = None
    git = shutil.which('git')
    if git:
        candidate = Path(git).resolve().parent.parent/'bin/bash.exe'
        if candidate.is_file():
            shell = str(candidate)
assert shell, 'A POSIX shell is required for the Mac entry checks'
original = (assets/'修复中文显示.command').read_text(encoding='utf-8')
assert not re.search(r'question\(|输入 Y', original)
subprocess.run([shell, '-n', (assets/'修复中文显示.command').as_posix()], check=True, timeout=30)
stub = '''const fs=require('node:fs');
const core=require('./repair-i18n.cjs');
if(typeof core.planArchive!=='function'||!fs.existsSync(__dirname+'/修复中文显示.command')) process.exit(91);
fs.writeFileSync(process.env.TC_MAC_CAPTURE,JSON.stringify({args:process.argv.slice(2),directory:__dirname}));
process.exit(Number(process.env.TC_MAC_STATUS));
'''
for name, status, expected in [('success',0,0),('child-failure',7,7),('missing-payload',0,1),('wrong-system',0,1),('wrong-app',0,1)]:
    folder = work/(name + " 中文 & ' $`")
    folder.mkdir()
    source = re.sub(r'(?m)(^# TIANCAI BEGIN MAC\n)[\s\S]*?(?=^# TIANCAI END MAC$)', lambda match: match.group(1) + ('' if name == 'missing-payload' else stub), original)
    system = 'UnsupportedOS' if name == 'wrong-system' else 'Darwin'
    source = source.replace('# MAIN ENTRY\n', '# MAIN ENTRY\nuname() { printf "%s\\n" '+system+'; }\nid() { printf "%s\\n" 501; }\n', 1)
    entry = folder/'修复中文显示.command'
    entry.write_text(source, encoding='utf-8', newline='\n')
    app = folder/'App 中文.app'
    if name != 'wrong-app':
        (app/'Contents').mkdir(parents=True)
    capture = folder/'arguments.json'
    env = dict(os.environ, TC_MAC_CAPTURE=str(capture), TC_MAC_STATUS=str(status))
    env.pop('MSYS_NO_PATHCONV', None)
    env.pop('MSYS2_ARG_CONV_EXCL', None)
    result = subprocess.run([shell, entry.as_posix(), app.as_posix()], input='', encoding='utf-8', capture_output=True, env=env, timeout=30)
    assert result.returncode == expected, (name, result.returncode, result.stdout, result.stderr)
    if name in ('success','child-failure'):
        record = json.loads(capture.read_text(encoding='utf-8'))
        assert Path(record['args'][0]).resolve() == app.resolve()
        assert not Path(record['directory']).exists(), 'Temporary embedded helpers were not cleaned up'
    else:
        assert not capture.exists(), name
    checks.append('Mac standalone: ' + name)

print(json.dumps({'passed':len(checks),'checks':checks,'fixtures':str(work)},ensure_ascii=False,indent=2))
