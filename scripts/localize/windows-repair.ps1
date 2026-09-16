# 添财AI · Windows 中文显示修复 3.0：单文件入口，自动修复。

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
    param([string]$Node, [string]$Helper, [string]$Mode, [string]$AppRoot, [string]$Destination)
    [Console]::OutputEncoding = New-Object Text.UTF8Encoding($false)
    $helperArgs = @($Helper, $Mode, $AppRoot)
    if ($Destination) { $helperArgs += $Destination }
    $lines = @(& $Node @helperArgs 2>&1)
    if ($LASTEXITCODE -ne 0) { throw ('应用处理失败：' + ($lines -join "`n")) }
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
    $report.Add('添财AI · Windows 中文显示修复 3.0')
    $report.Add('时间：' + (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'))
    $report.Add('Windows 版本：' + [Environment]::OSVersion.VersionString)
    $report.Add('PowerShell 版本：' + $PSVersionTable.PSVersion.ToString())
    try {
        Write-Host '添财AI · Windows 中文显示修复 3.0' -ForegroundColor Green
        $phase = '检查原安装'
        Write-Host '[1/3] 正在检查 Codex……'
        $sourceApp = Resolve-CodexApp
        $sourceRoot = [IO.Path]::GetDirectoryName($sourceApp.Executable)
        $node = Join-Path $sourceRoot 'resources\cua_node\bin\node.exe'
        if (-not [IO.File]::Exists($node)) { throw '该版本没有所需的内置 Node.js，请先更新 Codex；无需自行安装开发工具。' }
        $runtime = Copy-CodexNodeRuntime $node
        $node = $runtime.Executable
        $helper = Join-Path $runtime.Directory 'repair-i18n.cjs'
        [IO.File]::WriteAllText($helper, $script:TiancaiCoreSource, (New-Object Text.UTF8Encoding($false)))
        $inspection = Invoke-I18nHelper $node $helper 'inspect' $sourceRoot
        $report.Add('原应用：' + $sourceApp.Executable)
        $report.Add('应用版本：' + $inspection.version)
        $report.Add('中文资源数：' + $inspection.chineseResources)
        $report.Add('待修复的国际化开关数：' + $inspection.patchedGetters)
        $report.Add('完整性处理：' + $inspection.integrity)
        $phase = '统计原应用文件'
        $sourceTree = Invoke-I18nHelper $node $helper 'inspect-tree' $sourceRoot
        $bytes = $sourceTree.bytes
        if ($sourceTree.files -lt 1) { throw '原应用目录中没有文件，停止复制。' }
        $report.Add('原应用文件数：' + $sourceTree.files + '；总字节数：' + $bytes)
        $baseRoot = [IO.Path]::GetFullPath((Join-Path $env:LOCALAPPDATA 'TiancaiAI\CodexChinese'))
        $disk = New-Object IO.DriveInfo([IO.Path]::GetPathRoot($baseRoot))
        if ($disk.AvailableFreeSpace -lt $bytes + 104857600) { throw '磁盘空间不足，需要额外保存一份 Codex 应用。' }
        $codexHome = if ([string]::IsNullOrWhiteSpace($env:CODEX_HOME)) { Join-Path ([Environment]::GetFolderPath('UserProfile')) '.codex' } else { $env:CODEX_HOME }
        $codexHome = [IO.Path]::GetFullPath($codexHome)
        $configPath = Join-Path $codexHome 'config.toml'
        if ([IO.File]::Exists($configPath)) { [void](ConvertTo-CodexChineseConfig ([IO.File]::ReadAllText($configPath, [Text.Encoding]::UTF8))) }
        $report.Add('副本空间需求约 ' + [Math]::Ceiling($bytes / 1MB) + ' MB')
        $phase = '复制应用'
        $copyRoot = [IO.Path]::GetFullPath((Join-Path $baseRoot ('build-' + (Get-Date -Format 'yyyyMMdd-HHmmss') + '-' + [guid]::NewGuid().ToString('N').Substring(0, 6))))
        if (-not $copyRoot.StartsWith($baseRoot.TrimEnd('\') + '\', [StringComparison]::OrdinalIgnoreCase) -or $copyRoot.StartsWith($sourceRoot.TrimEnd('\') + '\', [StringComparison]::OrdinalIgnoreCase)) { throw '应用副本路径检查失败。' }
        if (Test-Path -LiteralPath $copyRoot) { throw '副本目录已存在，请重新运行。' }
        [void][IO.Directory]::CreateDirectory($baseRoot)
        $report.Add('副本位置：' + $copyRoot)
        $report.Add('复制方式：内置 Node.js 逐文件复制，不使用 Robocopy 或 PowerShell 扩展路径枚举')
        Write-Host '[2/3] 正在复制并修复，请稍候……'
        $copiedTree = Invoke-I18nHelper $node $helper 'copy-app' $sourceRoot $copyRoot
        $phase = '核对应用副本'
        $report.Add('副本文件数：' + $copiedTree.files + '；总字节数：' + $copiedTree.bytes)
        if ($copiedTree.manifestHash -ne $sourceTree.manifestHash) { throw '原应用文件清单在复制期间发生变化，请等待原版更新完成后重试。' }
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
        Write-Host '[3/3] 正在设置中文并重启 Codex……'
        $restoreOriginal = $true
        foreach ($process in @(Get-CodexGuiProcesses $sourceApp.Executable)) { try { [void]$process.CloseMainWindow() } catch { } }
        if (-not (Wait-CodexGuiState $sourceApp.Executable $false 15)) {
            $restoreOriginal = $false
            throw '原应用尚未正常退出，未改动语言配置。请先保存文件、结束任务并退出 Codex，再双击此脚本。'
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
        Write-Host '修复完成，已打开 Codex，请检查界面是否显示中文。' -ForegroundColor Green
        Write-Host '以后请使用桌面的“Codex 中文修复版（添财AI）”。'
    } catch {
        $exitCode = 1
        Write-Host ('未完成：' + $_.Exception.Message) -ForegroundColor Red
        $report.Add('失败阶段：' + $phase)
        $report.Add('错误：' + $_.Exception.Message)
        if ($copyRoot) { Write-Host ('保留副本用于检查：' + $copyRoot) }
    } finally {
        if ($runtime) {
            try {
                [IO.File]::Delete((Join-Path $runtime.Directory 'repair-i18n.cjs'))
                [IO.File]::Delete($runtime.Executable)
                [IO.Directory]::Delete($runtime.Directory)
            } catch { }
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
            if ($exitCode -ne 0) { Write-Host ('诊断记录：' + $log) }
        } catch { Write-Host '无法写入诊断记录，请保留窗口提示。' }
    }
    return $exitCode
}
if ($MyInvocation.InvocationName -ne '.') { exit (Invoke-CodexChineseRepair) }
