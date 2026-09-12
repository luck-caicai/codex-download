@echo off
setlocal DisableDelayedExpansion
chcp 65001 >nul
set "TC_CODEX_REPAIR_SCRIPT=%~f0"
powershell.exe -NoLogo -NoProfile -Command "$s=[IO.File]::ReadAllText($env:TC_CODEX_REPAIR_SCRIPT,[Text.Encoding]::UTF8); $p=($s -split '(?m)^# POWERSHELL-BEGIN\r?$',2)[1]; & ([ScriptBlock]::Create($p))"
set "TC_CODEX_RESULT=%ERRORLEVEL%"
echo.
pause
exit /b %TC_CODEX_RESULT%
# POWERSHELL-BEGIN
# 添财AI · Windows 中文显示修复 2.0：使用独立应用副本，保留原安装。

function ConvertTo-CodexExtendedPath {
    param([string]$Path)
    $full = [IO.Path]::GetFullPath($Path)
    if ($full.StartsWith('\\?\')) { return $full }
    if ($full.StartsWith('\\')) { return '\\?\UNC\' + $full.Substring(2) }
    return '\\?\' + $full
}

function Copy-CodexNodeRuntime {
    param([string]$Source)
    $directory = Join-Path ([IO.Path]::GetTempPath()) ('TiancaiAI-Codex-Node-' + [guid]::NewGuid().ToString('N'))
    [void][IO.Directory]::CreateDirectory($directory)
    $destination = Join-Path $directory 'node.exe'
    $inputFile = $null; $outputFile = $null; $copied = $false
    try {
        # Copy bytes instead of package attributes or encryption metadata.
        $inputFile = [IO.File]::OpenRead($Source)
        $outputFile = [IO.File]::Open($destination, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write)
        $inputFile.CopyTo($outputFile)
        $copied = $true
    } finally {
        if ($outputFile) { $outputFile.Dispose() }
        if ($inputFile) { $inputFile.Dispose() }
        if (-not $copied) { try { [IO.File]::Delete($destination); [IO.Directory]::Delete($directory) } catch { } }
    }
    return [pscustomobject]@{ Directory=$directory; Executable=$destination }
}

function Invoke-I18nHelper {
    param([string]$Node, [string]$Helper, [string]$Mode, [string]$AppRoot)
    [Console]::OutputEncoding = New-Object Text.UTF8Encoding($false)
    $lines = @(& $Node $Helper $Mode $AppRoot 2>&1)
    if ($LASTEXITCODE -ne 0) { throw ('国际化检查 / 修复失败：' + ($lines -join "`n")) }
    return (($lines -join "`n") | ConvertFrom-Json)
}

function New-ChineseCopyLauncher {
    param([string]$CopyRoot, [string]$Executable, [string]$CodexHome, [string]$UserData)
    $launcher = Join-Path $CopyRoot '启动修复版.vbs'
    $template = @'
Option Explicit
Dim shell, env, exe, command
Set shell = CreateObject("WScript.Shell")
Set env = shell.Environment("PROCESS")
exe = "__EXE__"
env("CODEX_HOME") = "__HOME__"
env("CODEX_ELECTRON_USER_DATA_PATH") = "__DATA__"
env("ELECTRON_LOCALE_OVERRIDE") = "zh-CN"
command = Chr(34) & exe & Chr(34) & " --lang=zh-CN"
shell.Run command, 1, False
'@
    $template = $template.Replace('__EXE__', $Executable.Replace('"', '""')).Replace('__HOME__', $CodexHome.Replace('"', '""')).Replace('__DATA__', $UserData.Replace('"', '""'))
    [IO.File]::WriteAllText($launcher, $template, [Text.Encoding]::Unicode)
    $desktop = [Environment]::GetFolderPath('Desktop')
    if (-not $desktop) { throw '无法找到桌面目录，未创建快捷方式。' }
    $shortcutPath = Join-Path $desktop 'Codex 中文修复版（添财AI）.lnk'
    $shell = New-Object -ComObject WScript.Shell
    $shortcut = $shell.CreateShortcut($shortcutPath)
    $shortcut.TargetPath = Join-Path $env:WINDIR 'System32\wscript.exe'
    $shortcut.Arguments = '"' + $launcher + '"'
    $shortcut.WorkingDirectory = $CopyRoot
    $shortcut.IconLocation = "$Executable,0"
    $shortcut.Description = '添财AI · 启用 Codex 内置翻译的独立副本'
    $shortcut.Save()
    return [pscustomobject]@{ Launcher=$launcher; Shortcut=$shortcutPath }
}

function Invoke-CodexChineseRepair {
    $ErrorActionPreference = 'Stop'
    $phase = '读取工具'; $copyRoot = ''; $sourceApp = $null; $restoreOriginal = $false; $exitCode = 0; $runtime = $null
    $report = New-Object 'System.Collections.Generic.List[string]'
    $report.Add('添财AI · Windows 中文显示修复 2.0')
    $report.Add('时间：' + (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'))
    try {
        $toolRoot = [IO.Path]::GetDirectoryName($env:TC_CODEX_REPAIR_SCRIPT)
        $baseScript = Join-Path $toolRoot 'codex-zh-cn.bat'
        $helper = Join-Path $toolRoot 'repair-i18n.cjs'
        if (-not [IO.File]::Exists($baseScript) -or -not [IO.File]::Exists($helper)) { throw '请解压整个 Windows 压缩包，保留其中全部文件，然后重新运行。' }
        $baseCode = ([IO.File]::ReadAllText($baseScript, [Text.Encoding]::UTF8) -split '(?m)^# POWERSHELL-BEGIN\r?$', 2)[1]
        # Dot-sourcing loads only the shared functions; it does not run the basic setup.
        . ([ScriptBlock]::Create($baseCode))
        Write-Host '添财AI · Windows 中文显示修复 2.0' -ForegroundColor Green
        $phase = '检查原安装'
        $sourceApp = Resolve-CodexApp
        $sourceRoot = [IO.Path]::GetDirectoryName($sourceApp.Executable)
        $node = Join-Path $sourceRoot 'resources\cua_node\bin\node.exe'
        if (-not [IO.File]::Exists($node)) { throw '该版本没有所需的内置 Node.js，请先更新 Codex；无需自行安装开发工具。' }
        $runtime = Copy-CodexNodeRuntime $node
        $node = $runtime.Executable
        $inspection = Invoke-I18nHelper $node $helper 'inspect' $sourceRoot
        $report.Add('原应用：' + $sourceApp.Executable)
        $report.Add('应用版本：' + $inspection.version)
        $report.Add('中文资源数：' + $inspection.chineseResources)
        $report.Add('待修复的国际化开关数：' + $inspection.patchedGetters)
        $report.Add('完整性处理：' + $inspection.integrity)
        Write-Host ('原应用：' + $sourceApp.Executable)
        Write-Host ('应用版本：' + $inspection.version)
        Write-Host ('已识别内置中文资源和 ' + $inspection.patchedGetters + ' 处国际化开关。')
        $sourceItems = @(Get-ChildItem -LiteralPath (ConvertTo-CodexExtendedPath $sourceRoot) -Recurse -Force -ErrorAction Stop)
        if (@($sourceItems | Where-Object { $_.Attributes -band [IO.FileAttributes]::ReparsePoint }).Count) { throw '应用目录含有链接，暂不支持自动复制。原安装未改动。' }
        $bytes = ($sourceItems | Where-Object { -not $_.PSIsContainer } | Measure-Object Length -Sum).Sum
        $baseRoot = [IO.Path]::GetFullPath((Join-Path $env:LOCALAPPDATA 'TiancaiAI\CodexChinese'))
        $disk = New-Object IO.DriveInfo([IO.Path]::GetPathRoot($baseRoot))
        if ($disk.AvailableFreeSpace -lt $bytes + 104857600) { throw '磁盘空间不足，需要额外保存一份 Codex 应用。' }
        $codexHome = if ([string]::IsNullOrWhiteSpace($env:CODEX_HOME)) { Join-Path ([Environment]::GetFolderPath('UserProfile')) '.codex' } else { $env:CODEX_HOME }
        $codexHome = [IO.Path]::GetFullPath($codexHome)
        $configPath = Join-Path $codexHome 'config.toml'
        if ([IO.File]::Exists($configPath)) { [void](ConvertTo-CodexChineseConfig ([IO.File]::ReadAllText($configPath, [Text.Encoding]::UTF8))) }
        Write-Host ('将额外占用约 ' + [Math]::Ceiling($bytes / 1MB) + ' MB，用于创建中文修复副本。')
        Write-Host '请先结束任务并保存文件。继续后会关闭原应用，修改副本里的语言加载开关，并创建桌面快捷方式。'
        Write-Host '修复版使用独立的界面数据目录，可能需要重新登录。原安装保留，可随时从原快捷方式打开。'
        if (@($inspection.integrity) -match '更新副本哈希') { Write-Host '该版本需要更新副本的可执行文件校验值，因此副本将不再具有原厂数字签名。' }
        if ((Read-Host '输入 Y 继续，其他输入取消') -notmatch '^[Yy]$') { $report.Add('结果：用户取消'); return 0 }
        $phase = '复制应用'
        $copyRoot = [IO.Path]::GetFullPath((Join-Path $baseRoot ('build-' + (Get-Date -Format 'yyyyMMdd-HHmmss') + '-' + [guid]::NewGuid().ToString('N').Substring(0, 6))))
        if (-not $copyRoot.StartsWith($baseRoot.TrimEnd('\') + '\', [StringComparison]::OrdinalIgnoreCase) -or $copyRoot.StartsWith($sourceRoot.TrimEnd('\') + '\', [StringComparison]::OrdinalIgnoreCase)) { throw '应用副本路径检查失败。' }
        if (Test-Path -LiteralPath $copyRoot) { throw '副本目录已存在，请重新运行。' }
        [void][IO.Directory]::CreateDirectory($copyRoot)
        $report.Add('副本位置：' + $copyRoot)
        Write-Host '正在复制应用文件，请稍候……'
        & (Join-Path $env:WINDIR 'System32\robocopy.exe') $sourceRoot $copyRoot /E /COPY:DAT /DCOPY:DAT /R:0 /W:0 /XJ /NFL /NDL /NJH /NJS /NP | Out-Null
        if ($LASTEXITCODE -ge 8) { throw ('应用复制失败，Robocopy 返回 ' + $LASTEXITCODE + '。原安装未改动。') }
        $copyItems = @(Get-ChildItem -LiteralPath (ConvertTo-CodexExtendedPath $copyRoot) -File -Recurse -Force)
        if ($copyItems.Count -ne @($sourceItems | Where-Object { -not $_.PSIsContainer }).Count) { throw '复制后的文件数不一致，已停止。' }
        $copyExe = Join-Path $copyRoot ([IO.Path]::GetFileName($sourceApp.Executable))
        foreach ($relative in @('resources\app.asar', 'ChatGPT.exe', 'Codex.exe')) {
            $file = Join-Path $copyRoot $relative
            if ([IO.File]::Exists($file)) { [IO.File]::SetAttributes($file, ([IO.File]::GetAttributes($file) -band (-bnot [IO.FileAttributes]::ReadOnly))) }
        }
        $marker = @{ tool='tiancai-i18n-2'; source=$sourceRoot; sourceHeaderHash=$inspection.headerHash; version=$inspection.version }
        [IO.File]::WriteAllText((Join-Path $copyRoot '.tiancai-i18n-copy.json'), ($marker | ConvertTo-Json), (New-Object Text.UTF8Encoding($false)))
        $phase = '修复国际化开关'
        $patched = Invoke-I18nHelper $node $helper 'patch-copy' $copyRoot
        $report.Add('国际化修复：' + $patched.patchedGetters + ' 处；文件内容与哈希复核通过')
        $phase = '退出原应用'
        $restoreOriginal = $true
        foreach ($process in @(Get-CodexGuiProcesses $sourceApp.Executable)) { try { [void]$process.CloseMainWindow() } catch { } }
        if (-not (Wait-CodexGuiState $sourceApp.Executable $false 8)) {
            Get-CodexGuiProcesses $sourceApp.Executable | Stop-Process -Force -ErrorAction SilentlyContinue
            if (-not (Wait-CodexGuiState $sourceApp.Executable $false 8)) { $restoreOriginal = $false; throw '原应用仍在运行，尚未改动配置。请手动退出后重试。' }
        }
        $phase = '写入语言配置'
        $result = Set-CodexChineseConfig $configPath
        $report.Add('配置文件：' + $configPath)
        $report.Add('语言配置：zh-CN')
        if ($result.Backup) { $report.Add('配置备份：' + $result.Backup) }
        $phase = '启动修复版'
        $userData = Join-Path $baseRoot 'UserData'
        [void][IO.Directory]::CreateDirectory($userData)
        $launcher = New-ChineseCopyLauncher $copyRoot $copyExe $codexHome $userData
        $report.Add('桌面快捷方式：' + $launcher.Shortcut)
        $report.Add('修复版界面数据：' + $userData)
        Start-Process -FilePath (Join-Path $env:WINDIR 'System32\wscript.exe') -ArgumentList ('"' + $launcher.Launcher + '"') -WindowStyle Hidden
        if (-not (Wait-CodexGuiState $copyExe $true 15)) { throw '修复版暂未启动，请查看诊断记录。桌面已保留修复版快捷方式。' }
        $restoreOriginal = $false
        $report.Add('应用启动：已检测到修复副本进程；请人工确认界面')
        Write-Host '国际化修复与中文配置已完成，已检测到修复版进程。请检查界面是否显示中文。' -ForegroundColor Green
        Write-Host '以后请使用桌面的“Codex 中文修复版（添财AI）”，原来的快捷方式仍打开原版。'
        Write-Host ('副本目录：' + $copyRoot)
    } catch {
        $exitCode = 1
        Write-Host ('未完成：' + $_.Exception.Message) -ForegroundColor Red
        $report.Add('失败阶段：' + $phase)
        $report.Add('错误：' + $_.Exception.Message)
        if ($copyRoot) { Write-Host ('保留副本用于检查：' + $copyRoot) }
    } finally {
        if ($runtime) {
            try { [IO.File]::Delete($runtime.Executable); [IO.Directory]::Delete($runtime.Directory) } catch { }
        }
        if ($restoreOriginal -and $sourceApp) {
            try {
                if ($sourceApp.Activation) { Start-Process -FilePath (Join-Path $env:WINDIR 'explorer.exe') -ArgumentList $sourceApp.Activation }
                else { Start-Process -FilePath $sourceApp.Executable }
                Write-Host '已尝试重新打开原版 Codex。'
            } catch { Write-Host '请手动从原来的快捷方式打开 Codex。' }
        }
        try {
            $logRoot = Join-Path $env:LOCALAPPDATA 'TiancaiAI\CodexLocale'
            [void][IO.Directory]::CreateDirectory($logRoot)
            $log = Join-Path $logRoot ('repair-' + (Get-Date -Format 'yyyyMMdd-HHmmss') + '-' + [guid]::NewGuid().ToString('N').Substring(0, 6) + '.txt')
            [IO.File]::WriteAllLines($log, $report, (New-Object Text.UTF8Encoding($true)))
            Write-Host ('诊断记录：' + $log)
        } catch { Write-Host '无法写入诊断记录，请保留窗口提示。' }
    }
    return $exitCode
}
if ($MyInvocation.InvocationName -ne '.') { exit (Invoke-CodexChineseRepair) }
