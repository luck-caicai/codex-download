"""Test the Windows repair orchestration with inert fixtures and mocked processes."""
from pathlib import Path
import os, subprocess, json, shutil

site = Path(__file__).resolve().parent.parent
root = site.parent
work = root / 'outputs/tiancai-qa/repair-wrapper-fixtures'
work.mkdir(parents=True, exist_ok=True)
code = (site / 'assets/localize/修复中文显示.bat').read_text(encoding='utf-8').split('\n# POWERSHELL-BEGIN\n', 1)[1]
code = code[:code.rindex('if ($MyInvocation.InvocationName')]
(work / 'functions.ps1').write_text(code, encoding='utf-8')
# Override shared functions after loading the real standalone entry.
fake_base = r'''
# POWERSHELL-BEGIN
function Resolve-CodexApp { $script:fakeApp }
function ConvertTo-CodexChineseConfig { param($Text); $Text }
function Get-CodexGuiProcesses {
    param($Executable)
    if ($script:events.Contains('closed')) { return }
    $process = [pscustomobject]@{ Path=$Executable }
    $process | Add-Member ScriptMethod CloseMainWindow { $script:events.Add('close'); return $true }
    $process
}
function Wait-CodexGuiState {
    param($Executable, $Running, $Seconds)
    if ($Running) { $script:events.Add('wait-open'); return ($script:scenario -ne 'launch-failed') }
    if ($script:scenario -eq 'exit-busy') { $script:events.Add('busy'); return $false }
    $script:events.Add('closed'); return $true
}
function Set-CodexChineseConfig {
    param($ConfigPath)
    if (-not $ConfigPath.StartsWith($script:fixtureRoot + '\')) { throw 'Out-of-fixture config' }
    $script:events.Add('config'); [IO.File]::WriteAllText($ConfigPath, 'fixture-written')
    [pscustomobject]@{ Changed=$true; Backup='' }
}
'''
(work / 'codex-zh-cn.bat').write_text(fake_base, encoding='utf-8')
(work / 'repair-i18n.cjs').write_text('// inert helper fixture', encoding='utf-8')
source = work / 'source with spaces & 中文'
(source / 'resources/cua_node/bin').mkdir(parents=True, exist_ok=True)
for relative in ['ChatGPT.exe', 'resources/app.asar', 'resources/cua_node/bin/node.exe']:
    (source / relative).write_text('INERT FIXTURE: NEVER EXECUTE', encoding='ascii')

harness = r'''
$ErrorActionPreference = 'Stop'
$script:fixtureRoot = $env:TC_REPAIR_TEST_ROOT
$code = [IO.File]::ReadAllText((Join-Path $script:fixtureRoot 'functions.ps1'), [Text.Encoding]::UTF8)
$tokens = $null; $errors = $null
[void][Management.Automation.Language.Parser]::ParseInput($code, [ref]$tokens, [ref]$errors)
if ($errors.Count) { throw ($errors | Out-String) }
. ([ScriptBlock]::Create($code))
$fakeCode = ([IO.File]::ReadAllText((Join-Path $script:fixtureRoot 'codex-zh-cn.bat'), [Text.Encoding]::UTF8) -split '(?m)^# POWERSHELL-BEGIN\r?$',2)[1]
. ([ScriptBlock]::Create($fakeCode))
$script:fakeApp = [pscustomobject]@{ Executable=(Join-Path $script:fixtureRoot 'source with spaces & 中文\ChatGPT.exe'); Activation='' }
$checks = New-Object 'System.Collections.Generic.List[string]'
function Assert-Test($Condition, $Name) { if (-not $Condition) { throw ('FAILED: ' + $Name) }; $checks.Add($Name) }
function Read-Host { throw 'Interactive input is forbidden in the standalone flow' }
function Stop-Process { throw 'Force-stopping an application is forbidden' }
function Invoke-I18nHelper {
    param($Node, $Helper, $Mode, $AppRoot, $Destination)
    $script:events.Add($Mode)
    if ($Mode -eq 'inspect' -and $script:scenario -eq 'unsupported') { throw 'Unsupported fixture' }
    if ($Mode -in @('inspect-tree', 'copy-app')) {
        if ($Mode -eq 'copy-app' -and $script:scenario -eq 'copy-failed') { throw 'fixture: copying ChatGPT.exe failed' }
        [Console]::OutputEncoding = New-Object Text.UTF8Encoding($false)
        $arguments = @($env:TC_COPY_TEST_HELPER, $Mode, $AppRoot)
        if ($Destination) { $arguments += $Destination }
        $output = @(& $env:TC_COPY_TEST_NODE @arguments 2>&1)
        if ($LASTEXITCODE -ne 0) { throw ($output -join "`n") }
        $tree = ($output -join "`n") | ConvertFrom-Json
        if ($Mode -eq 'copy-app' -and $script:scenario -eq 'copy-changed') { $tree.manifestHash = 'changed-source-fixture' }
        return $tree
    }
    if ($Mode -eq 'patch-copy') {
        Assert-Test ($AppRoot.StartsWith($env:LOCALAPPDATA + '\TiancaiAI\CodexChinese\')) 'copy stays inside owned fixture folder'
        $marker = [IO.File]::ReadAllText((Join-Path $AppRoot '.tiancai-i18n-copy.json')) | ConvertFrom-Json
        Assert-Test ($marker.source -eq [IO.Path]::GetDirectoryName($script:fakeApp.Executable)) 'copy marker preserves original source'
    }
    [pscustomobject]@{ version='fixture'; chineseResources=1; patchedGetters=2; integrity='保留可执行文件'; headerHash=('0' * 64) }
}
function New-ChineseCopyLauncher {
    param($CopyRoot, $Executable, $CodexHome, $UserData)
    $script:events.Add('shortcut')
    [pscustomobject]@{ Launcher=(Join-Path $CopyRoot 'fixture.vbs'); Shortcut=(Join-Path $script:fixtureRoot 'fixture.lnk') }
}
function Start-Process {
    param($FilePath, $ArgumentList, $WindowStyle)
    $script:events.Add('launch')
    # Intentionally no process start, including Windows Script Host.
}
$savedLocal = $env:LOCALAPPDATA; $savedHome = $env:CODEX_HOME; $savedScript = $env:TC_CODEX_REPAIR_SCRIPT
try {
    $env:TC_CODEX_REPAIR_SCRIPT = Join-Path $script:fixtureRoot 'fixture-repair.bat'
    foreach ($scenario in @('normal', 'unsupported', 'copy-failed', 'copy-changed', 'exit-busy', 'launch-failed')) {
        $script:scenario = $scenario
        $script:events = New-Object 'System.Collections.Generic.List[string]'
        $env:LOCALAPPDATA = Join-Path $script:fixtureRoot ('local-' + $scenario)
        $env:CODEX_HOME = Join-Path $script:fixtureRoot ('config-' + $scenario)
        [void][IO.Directory]::CreateDirectory($env:CODEX_HOME)
        $config = Join-Path $env:CODEX_HOME 'config.toml'
        [IO.File]::WriteAllText($config, 'fixture-original')
        $result = Invoke-CodexChineseRepair
        if ($scenario -in @('unsupported', 'copy-failed', 'copy-changed', 'exit-busy')) {
            Assert-Test (-not $script:events.Contains('config') -and -not $script:events.Contains('launch') -and -not $script:events.Contains('closed') -and [IO.File]::ReadAllText($config) -eq 'fixture-original') ($scenario + ': no config or process changes')
            if ($scenario -in @('copy-failed', 'copy-changed')) { Assert-Test (-not $script:events.Contains('patch-copy')) ($scenario + ': no patch attempted') }
        } else {
            Assert-Test ($script:events.IndexOf('patch-copy') -lt $script:events.IndexOf('closed') -and $script:events.IndexOf('config') -gt $script:events.IndexOf('closed') -and $script:events.IndexOf('launch') -gt $script:events.IndexOf('config')) ($scenario + ': patch copy, exit, config, launch order')
        }
        Assert-Test ($result -eq $(if ($scenario -eq 'normal') { 0 } else { 1 })) ($scenario + ': correct result')
    }
} finally { $env:LOCALAPPDATA=$savedLocal; $env:CODEX_HOME=$savedHome; $env:TC_CODEX_REPAIR_SCRIPT=$savedScript }
[IO.File]::WriteAllText((Join-Path $script:fixtureRoot 'results.json'), ($checks | ConvertTo-Json), (New-Object Text.UTF8Encoding($false)))
'''
(work / 'harness.ps1').write_text(harness, encoding='utf-8')
env = dict(os.environ, TC_REPAIR_TEST_ROOT=str(work), TC_REPAIR_TEST_HARNESS=str(work / 'harness.ps1'),
           TC_COPY_TEST_NODE=shutil.which('node'), TC_COPY_TEST_HELPER=str(site / 'assets/localize/repair-i18n.cjs'))
run = subprocess.run([r'C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe', '-NoLogo', '-NoProfile', '-Command', '& ([ScriptBlock]::Create([IO.File]::ReadAllText($env:TC_REPAIR_TEST_HARNESS,[Text.Encoding]::UTF8)))'], env=env, capture_output=True, timeout=30)
assert run.returncode == 0, (run.stdout.decode('utf-8', errors='replace'), run.stderr.decode('utf-8', errors='replace'))
checks = json.loads((work / 'results.json').read_text(encoding='utf-8'))
report = {'checks_passed': len(checks), 'checks': checks, 'scope': 'Native Windows PowerShell 5.1; real Node helper copies inert fixtures; all process operations and desktop shortcut creation mocked'}
(work.parent / 'repair-wrapper-verification.json').write_text(json.dumps(report, indent=2), encoding='utf-8')
print(json.dumps(report, indent=2))
