@echo off
setlocal DisableDelayedExpansion
chcp 65001 >nul
set "TC_CODEX_SCRIPT=%~f0"
powershell.exe -NoLogo -NoProfile -Command "$s=[IO.File]::ReadAllText($env:TC_CODEX_SCRIPT,[Text.Encoding]::UTF8); $p=($s -split '(?m)^# POWERSHELL-BEGIN\r?$',2)[1]; & ([ScriptBlock]::Create($p))"
set "TC_CODEX_RESULT=%ERRORLEVEL%"
echo.
pause
exit /b %TC_CODEX_RESULT%
# POWERSHELL-BEGIN
# 添财AI：只切换 Codex 桌面版界面语言。无需管理员权限，不下载或运行外部代码。

function ConvertTo-CodexChineseConfig {
    param([AllowEmptyString()][string]$Text)
    $newline = if ($Text.Contains("`r`n")) { "`r`n" } else { "`n" }
    $rows = New-Object 'System.Collections.Generic.List[string]'
    foreach ($row in ($Text -split '\r?\n')) { $rows.Add($row) }
    $desktopKey = '(?:desktop|"desktop"|''desktop'')'
    $localeKey = '(?:localeOverride|"localeOverride"|''localeOverride'')'
    $inDesktop = $false; $root = $true; $header = -1; $firstHeader = -1
    $localeLine = -1; $rootDotted = $false; $multi = ''; $depth = 0
    $replacementKey = 'localeOverride'
    for ($lineNo = 0; $lineNo -lt $rows.Count; $lineNo++) {
        $line = $rows[$lineNo]
        $eligible = $multi -eq '' -and $depth -eq 0
        if ($eligible) {
            if ($line -cmatch ('^\s*\[\s*' + $desktopKey + '\s*\]\s*(?:#.*)?$')) {
                if ($header -ge 0) { throw '检测到重复的 [desktop]，原配置不会改动。请先修复配置。' }
                $header = $lineNo; $inDesktop = $true; $root = $false
                if ($firstHeader -lt 0) { $firstHeader = $lineNo }
            } elseif ($line -cmatch '^\s*\[') {
                $inDesktop = $false; $root = $false
                if ($firstHeader -lt 0) { $firstHeader = $lineNo }
            }
            if ($root -and $line -cmatch ('^\s*' + $desktopKey + '\s*=')) {
                throw '检测到 desktop 内联配置，请在 Codex 的语言设置中调整。原配置不会改动。'
            }
            if ($root -and $line -cmatch ('^\s*' + $desktopKey + '\s*\.')) { $rootDotted = $true }
            $localMatch = $inDesktop -and $line -cmatch ('^\s*' + $localeKey + '\s*=')
            $dottedMatch = $root -and $line -cmatch ('^\s*' + $desktopKey + '\s*\.\s*' + $localeKey + '\s*=')
            if ($localMatch -or $dottedMatch) {
                if ($localeLine -ge 0) { throw '检测到重复的语言配置，原配置不会改动。' }
                $localeLine = $lineNo
                if ($dottedMatch) { $replacementKey = 'desktop.localeOverride' }
            }
        }
        # 跳过注释、引号、多行字符串和数组中的内容，避免把示例文字当成设置。
        $quote = ''; $i = 0
        while ($i -lt $line.Length) {
            $char = [string]$line[$i]
            if ($multi -ne '') {
                if ($multi -eq '"' -and $char -eq '\') { $i += 2; continue }
                if ($i + 2 -lt $line.Length -and $line.Substring($i, 3) -ceq ($multi * 3)) {
                    $closing = $multi; $multi = ''
                    while ($i -lt $line.Length -and [string]$line[$i] -ceq $closing) { $i++ }
                    continue
                }
            } elseif ($quote -ne '') {
                if ($quote -eq '"' -and $char -eq '\') { $i += 2; continue }
                if ($char -ceq $quote) { $quote = '' }
            } else {
                if ($char -eq '#') { break }
                if ($char -eq '"' -or $char -eq "'") {
                    if ($i + 2 -lt $line.Length -and $line.Substring($i, 3) -ceq ($char * 3)) {
                        $multi = $char; $i += 3; continue
                    }
                    $quote = $char
                } elseif ($char -eq '[' -or $char -eq '{') { $depth++ }
                elseif ($char -eq ']' -or $char -eq '}') { $depth-- }
            }
            $i++
        }
        if ($quote -ne '' -or $depth -lt 0) { throw '配置中的引号或括号不完整，原文件不会改动。' }
        if ($localeLine -eq $lineNo -and ($multi -ne '' -or $depth -ne 0)) {
            throw '语言字段使用了多行写法，请在 Codex 设置中调整。原配置不会改动。'
        }
    }
    if ($multi -ne '' -or $depth -ne 0) { throw '配置中的多行字符串或数组未结束，原文件不会改动。' }
    if ($localeLine -ge 0) {
        $old = $rows[$localeLine]
        if ($old -cmatch '^([^=]+=\s*)(?:"[^"\r\n]*"|''[^''\r\n]*'')(\s*(?:#.*)?)$') {
            $rows[$localeLine] = $Matches[1] + '"zh-CN"' + $Matches[2]
        } else {
            $rows[$localeLine] = [regex]::Match($old, '^\s*').Value + $replacementKey + ' = "zh-CN"'
        }
    } elseif ($header -ge 0) {
        $rows.Insert($header + 1, 'localeOverride = "zh-CN"')
    } elseif ($rootDotted) {
        $position = if ($firstHeader -ge 0) { $firstHeader } else { $rows.Count }
        $rows.Insert($position, 'desktop.localeOverride = "zh-CN"')
    } else {
        if ($rows.Count -gt 0 -and $rows[$rows.Count - 1] -ne '') { $rows.Add('') }
        $rows.Add('[desktop]'); $rows.Add('localeOverride = "zh-CN"'); $rows.Add('')
    }
    return [string]::Join($newline, $rows)
}

function Set-CodexChineseConfig {
    param([string]$ConfigPath)
    $ConfigPath = [IO.Path]::GetFullPath($ConfigPath)
    $exists = [IO.File]::Exists($ConfigPath)
    if (Test-Path -LiteralPath $ConfigPath) {
        $item = Get-Item -LiteralPath $ConfigPath -Force
        if ($item.PSIsContainer -or ($item.Attributes -band [IO.FileAttributes]::ReparsePoint)) {
            throw '配置路径是目录或链接，请手动设置语言，避免影响原文件。'
        }
    }
    $utf8 = New-Object Text.UTF8Encoding($false, $true)
    [byte[]]$original = @(if ($exists) { [IO.File]::ReadAllBytes($ConfigPath) })
    $text = $utf8.GetString($original).TrimStart([char]0xFEFF)
    $updated = ConvertTo-CodexChineseConfig $text
    if ($exists -and $updated -ceq $text) { return [pscustomobject]@{ Changed = $false; Backup = '' } }
    $directory = [IO.Path]::GetDirectoryName($ConfigPath)
    [void][IO.Directory]::CreateDirectory($directory)
    $tag = (Get-Date -Format 'yyyyMMdd-HHmmss-fff') + '-' + [guid]::NewGuid().ToString('N').Substring(0, 6)
    $backup = ''
    $temporary = Join-Path $directory ('.config.toml.zh-cn.' + $tag + '.tmp')
    try {
        [IO.File]::WriteAllText($temporary, $updated, $utf8)
        if ($exists) {
            if ([Convert]::ToBase64String([IO.File]::ReadAllBytes($ConfigPath)) -cne [Convert]::ToBase64String($original)) {
                throw '配置刚刚被其他程序修改，请关闭 Codex 后重新运行。'
            }
            $backup = $ConfigPath + '.before-zh-cn.' + $tag + '.bak'
            [IO.File]::Replace($temporary, $ConfigPath, $backup)
        } else { [IO.File]::Move($temporary, $ConfigPath) }
    } finally {
        if ([IO.File]::Exists($temporary)) { [IO.File]::Delete($temporary) }
    }
    return [pscustomobject]@{ Changed = $true; Backup = $backup }
}

function Get-CodexAppInfo {
    param([string]$Executable, [string]$Activation = '')
    $ErrorActionPreference = 'Stop'
    # Only read the archive header and package identity. No application code is executed.
    if (-not [IO.File]::Exists($Executable)) { return }
    $Executable = [IO.Path]::GetFullPath($Executable)
    $archivePath = Join-Path ([IO.Path]::GetDirectoryName($Executable)) 'resources\app.asar'
    if (-not [IO.File]::Exists($archivePath)) { return }
    $stream = $null; $reader = $null
    try {
        $stream = [IO.File]::Open($archivePath, [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::ReadWrite)
        $reader = New-Object IO.BinaryReader($stream)
        $prefix = $reader.ReadBytes(16)
        if ($prefix.Length -ne 16) { return }
        $headerSize = [BitConverter]::ToUInt32($prefix, 4)
        $jsonLength = [BitConverter]::ToUInt32($prefix, 12)
        if ($jsonLength -lt 2 -or $jsonLength -gt 33554432 -or $headerSize -lt $jsonLength + 8 -or 8L + $headerSize -gt $stream.Length) { return }
        $headerBytes = $reader.ReadBytes([int]$jsonLength)
        if ($headerBytes.Length -ne $jsonLength) { return }
        $header = [Text.Encoding]::UTF8.GetString($headerBytes) | ConvertFrom-Json
        $entry = $header.files.'package.json'
        if (-not $entry -or $entry.unpacked -or $entry.size -lt 2 -or $entry.size -gt 1048576) { return }
        $position = 8L + $headerSize + [long]$entry.offset
        if ($position -lt 8L + $headerSize -or $position + [long]$entry.size -gt $stream.Length) { return }
        [void]$stream.Seek($position, [IO.SeekOrigin]::Begin)
        $metadata = [Text.Encoding]::UTF8.GetString($reader.ReadBytes([int]$entry.size)) | ConvertFrom-Json
        if ($metadata.name -cne 'openai-codex-electron') { return }
        $assets = $header.files.webview.files.assets.files
        $chineseEntries = @($assets.PSObject.Properties | Where-Object { $_.Name -cmatch '^zh-CN(?:-[A-Za-z0-9_-]+)?\.(?:js|json)$' -and $_.Value.size -gt 0 })
        $nativeEntry = $header.files.'native-menu-locales'.files.'zh-CN.json'
        return [pscustomobject]@{
            Executable = $Executable; Activation = $Activation; Version = [string]$metadata.version
            ChineseResource = ($chineseEntries.Count -gt 0); NativeChineseResource = ($null -ne $nativeEntry)
        }
    } catch { return }
    finally { if ($reader) { $reader.Dispose() } elseif ($stream) { $stream.Dispose() } }
}

function Get-CodexGuiProcesses {
    param([string]$Executable)
    Get-Process -Name Codex,ChatGPT -ErrorAction SilentlyContinue | Where-Object {
        try { $_.Path -and $_.Path.Equals($Executable, [StringComparison]::OrdinalIgnoreCase) } catch { $false }
    }
}

function Resolve-CodexApp {
    $apps = @{}
    foreach ($package in @(Get-AppxPackage -Name OpenAI.Codex -ErrorAction SilentlyContinue)) {
        try {
            [xml]$manifest = [IO.File]::ReadAllText((Join-Path $package.InstallLocation 'AppxManifest.xml'))
            $entry = @($manifest.Package.Applications.Application) | Where-Object { $_.Executable -match '(?:Codex|ChatGPT)\.exe$' } | Select-Object -First 1
            if (-not $entry) { continue }
            $app = Get-CodexAppInfo (Join-Path $package.InstallLocation ([string]$entry.Executable)) ('shell:AppsFolder\' + $package.PackageFamilyName + '!' + $entry.Id)
            if ($app) { $apps[$app.Executable] = $app }
        } catch { }
    }
    $runningPaths = @(Get-Process -Name Codex,ChatGPT -ErrorAction SilentlyContinue | ForEach-Object { try { if ($_.Path) { $_.Path } } catch { } } | Sort-Object -Unique)
    $paths = @($runningPaths)
    foreach ($root in @((Join-Path $env:LOCALAPPDATA 'Programs\Codex'), (Join-Path $env:ProgramFiles 'Codex'))) {
        $paths += Join-Path $root 'ChatGPT.exe'
        $paths += Join-Path $root 'Codex.exe'
    }
    foreach ($path in @($paths | Sort-Object -Unique)) {
        if ($apps.ContainsKey($path)) { continue }
        $app = Get-CodexAppInfo $path
        if ($app) { $apps[$app.Executable] = $app }
    }
    $running = @($apps.Values | Where-Object { $runningPaths -contains $_.Executable })
    if ($running.Count -eq 1) { return $running[0] }
    $choices = @($apps.Values | Sort-Object Executable)
    if ($choices.Count -eq 1) { return $choices[0] }
    if ($choices.Count -gt 1) {
        Write-Host '发现多份 Codex，请选择要设置中文的应用：'
        for ($i = 0; $i -lt $choices.Count; $i++) { Write-Host ('{0}. {1}  {2}' -f ($i + 1), $choices[$i].Version, $choices[$i].Executable) }
        $number = 0
        if (-not [int]::TryParse((Read-Host '输入编号'), [ref]$number) -or $number -lt 1 -or $number -gt $choices.Count) { throw '未选择有效的 Codex，配置尚未修改。' }
        return $choices[$number - 1]
    }
    $path = (Read-Host '未自动找到 Codex。请粘贴 Codex.exe 或 ChatGPT.exe 的完整路径，回车取消').Trim().Trim('"')
    if ($path) {
        $app = Get-CodexAppInfo $path
        if ($app) { return $app }
    }
    throw '未识别到 Codex 桌面应用，配置尚未修改。请先安装或打开 Codex，再运行脚本。'
}

function Wait-CodexGuiState {
    param([string]$Executable, [bool]$Running, [int]$Seconds = 10)
    $timer = [Diagnostics.Stopwatch]::StartNew()
    do {
        $present = @(Get-CodexGuiProcesses $Executable).Count -gt 0
        if ($present -eq $Running) { return $true }
        Start-Sleep -Milliseconds 250
    } while ($timer.Elapsed.TotalSeconds -lt $Seconds)
    return $false
}

function Invoke-CodexChineseSetup {
    $ErrorActionPreference = 'Stop'
    $reopen = $false; $app = $null; $configFile = ''; $phase = '检查安装'; $written = $false; $exitCode = 0
    $report = New-Object 'System.Collections.Generic.List[string]'
    $report.Add('添财AI · Codex 中文设置 1.1')
    $report.Add('时间：' + (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'))
    try {
        Write-Host '添财AI · Codex 简体中文设置 1.1' -ForegroundColor Green
        $app = Resolve-CodexApp
        Write-Host ('应用版本：' + $app.Version)
        Write-Host ('启动文件：' + $app.Executable)
        $report.Add('应用版本：' + $app.Version)
        $report.Add('启动文件：' + $app.Executable)
        $report.Add('内置中文界面资源条目：' + $app.ChineseResource)
        $report.Add('内置中文菜单资源条目：' + $app.NativeChineseResource)
        $report.Add('运行时国际化开关：未检测；资源存在不代表界面已加载。')
        if (-not $app.ChineseResource) { throw '未识别到内置中文界面资源，配置尚未修改。请更新 Codex 或提供本次诊断记录。' }
        $codexDirectory = if ([string]::IsNullOrWhiteSpace($env:CODEX_HOME)) { Join-Path ([Environment]::GetFolderPath('UserProfile')) '.codex' } else { $env:CODEX_HOME }
        $configFile = [IO.Path]::GetFullPath((Join-Path $codexDirectory 'config.toml'))
        Write-Host ('配置文件：' + $configFile)
        $report.Add('配置文件：' + $configFile)
        if ([IO.File]::Exists($configFile)) { [void](ConvertTo-CodexChineseConfig ([IO.File]::ReadAllText($configFile, [Text.Encoding]::UTF8))) }
        Write-Host '请先结束任务并保存文件。继续后将关闭上面这份 Codex；残留应用进程会被结束，然后重新打开。'
        if ((Read-Host '输入 Y 继续，其他输入取消') -notmatch '^[Yy]$') { Write-Host '已取消。'; $report.Add('结果：用户取消'); return 0 }
        $phase = '退出应用'
        # 只处理注册 Codex 应用的 GUI 路径，不按进程名批量结束 CLI 或其他应用。
        $processes = @(Get-CodexGuiProcesses $app.Executable)
        $reopen = $true
        foreach ($process in $processes) {
            try { if ($process.MainWindowHandle -ne 0) { [void]$process.CloseMainWindow() } } catch { }
        }
        if (-not (Wait-CodexGuiState $app.Executable $false 8)) {
            Get-CodexGuiProcesses $app.Executable | Stop-Process -Force -ErrorAction SilentlyContinue
            if (-not (Wait-CodexGuiState $app.Executable $false 8)) {
                $reopen = $false
                throw 'Codex 尚未完全退出。请手动退出后重新运行，配置尚未修改。'
            }
        }
        Start-Sleep -Milliseconds 500
        if (@(Get-CodexGuiProcesses $app.Executable).Count -gt 0) { $reopen = $false; throw 'Codex 又被打开了，配置尚未修改。请关闭其他启动程序后重试。' }
        $phase = '写入配置'
        $result = Set-CodexChineseConfig $configFile
        $written = $true
        Write-Host '语言配置已写入：zh-CN。界面是否生效，请在应用重新打开后确认。' -ForegroundColor Green
        $report.Add('配置写入：成功（zh-CN）')
        if ($result.Backup) { Write-Host ('配置备份：' + $result.Backup); $report.Add('配置备份：' + $result.Backup) }
    } catch {
        Write-Host ('未完成：' + $_.Exception.Message) -ForegroundColor Red
        $report.Add('失败阶段：' + $phase)
        $report.Add('错误：' + $_.Exception.Message)
        $exitCode = 1
    } finally {
        if ($reopen -and $app) {
            try {
                if ($app.Activation) { Start-Process -FilePath (Join-Path $env:WINDIR 'explorer.exe') -ArgumentList $app.Activation }
                else { Start-Process -FilePath $app.Executable -WorkingDirectory ([IO.Path]::GetDirectoryName($app.Executable)) -ArgumentList '--lang=zh-CN' }
                if (Wait-CodexGuiState $app.Executable $true 12) {
                    Write-Host '已检测到同一份 Codex 的进程重新启动。'
                    $report.Add('应用重开：已检测到进程；未验证界面语言')
                } else {
                    Write-Host '暂未检测到应用进程，请手动打开上面这份 Codex。'
                    $report.Add('应用重开：超时，需手动打开')
                    $exitCode = 1
                }
            } catch { Write-Host '请手动打开上面这份 Codex。'; $report.Add('应用重开失败：' + $_.Exception.Message); $exitCode = 1 }
        }
        if ($written) {
            try {
                $current = [IO.File]::ReadAllText($configFile, [Text.Encoding]::UTF8)
                if ((ConvertTo-CodexChineseConfig $current) -ceq $current) { $report.Add('重开后配置检查：仍为 zh-CN') }
                else { $report.Add('重开后配置检查：语言字段发生变化'); Write-Host '注意：应用重开后语言配置发生变化，请查看诊断记录。'; $exitCode = 1 }
            } catch { $report.Add('重开后配置检查：无法读取或解析'); $exitCode = 1 }
            Write-Host '如果页面仍是英文：打开 Settings > General > Language，先选 English，再选 简体中文。'
            Write-Host '如果手动切换能生效，说明翻译资源可用；请确认下次重开后是否保持中文。'
        }
        try {
            $reportDir = Join-Path $env:LOCALAPPDATA 'TiancaiAI\CodexLocale'
            [void][IO.Directory]::CreateDirectory($reportDir)
            $reportPath = Join-Path $reportDir ('diagnostic-' + (Get-Date -Format 'yyyyMMdd-HHmmss') + '-' + [guid]::NewGuid().ToString('N').Substring(0, 6) + '.txt')
            [IO.File]::WriteAllLines($reportPath, $report, (New-Object Text.UTF8Encoding($true)))
            Write-Host ('诊断记录：' + $reportPath)
        } catch { Write-Host '无法保存诊断记录，请保留本窗口提示。' }
    }
    return $exitCode
}

if ($MyInvocation.InvocationName -ne '.') { exit (Invoke-CodexChineseSetup) }
