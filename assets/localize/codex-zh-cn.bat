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

function Invoke-CodexChineseSetup {
    $ErrorActionPreference = 'Stop'
    $reopen = $false; $activation = ''
    try {
        Write-Host '添财AI · Codex 简体中文设置' -ForegroundColor Green
        $package = Get-AppxPackage -Name OpenAI.Codex | Sort-Object Version -Descending | Select-Object -First 1
        if (-not $package) { throw '未找到 Windows 版 Codex。请先安装官网 / MSIX 版本，再运行脚本。' }
        [xml]$manifest = [IO.File]::ReadAllText((Join-Path $package.InstallLocation 'AppxManifest.xml'))
        $entry = @($manifest.Package.Applications.Application) | Where-Object { $_.Executable -match '(?:Codex|ChatGPT)\.exe$' } | Select-Object -First 1
        if (-not $entry) { throw '无法识别 Codex 的启动入口，未修改任何配置。' }
        $executable = [IO.Path]::GetFullPath((Join-Path $package.InstallLocation ([string]$entry.Executable)))
        $activation = 'shell:AppsFolder\' + $package.PackageFamilyName + '!' + $entry.Id
        $codexDirectory = if ([string]::IsNullOrWhiteSpace($env:CODEX_HOME)) { Join-Path ([Environment]::GetFolderPath('UserProfile')) '.codex' } else { $env:CODEX_HOME }
        $configFile = Join-Path $codexDirectory 'config.toml'
        if ([IO.File]::Exists($configFile)) { [void](ConvertTo-CodexChineseConfig ([IO.File]::ReadAllText($configFile, [Text.Encoding]::UTF8))) }
        Write-Host '请先结束正在进行的任务并保存文件。继续后将完全关闭并重新打开 Codex。'
        if ((Read-Host '输入 Y 继续，其他输入取消') -notmatch '^[Yy]$') { Write-Host '已取消。'; return 0 }
        # 只处理注册 Codex 应用的 GUI 路径，不按进程名批量结束 CLI 或其他应用。
        $processes = @(Get-Process -Name Codex,ChatGPT -ErrorAction SilentlyContinue | Where-Object { $_.Path -and $_.Path.Equals($executable, [StringComparison]::OrdinalIgnoreCase) })
        $reopen = $true
        foreach ($process in $processes) { if ($process.MainWindowHandle -ne 0) { [void]$process.CloseMainWindow() } }
        if ($processes.Count -gt 0) { Start-Sleep -Seconds 2 }
        Get-Process -Name Codex,ChatGPT -ErrorAction SilentlyContinue | Where-Object { $_.Path -and $_.Path.Equals($executable, [StringComparison]::OrdinalIgnoreCase) } | Stop-Process -Force -ErrorAction SilentlyContinue
        if (@(Get-Process -Name Codex,ChatGPT -ErrorAction SilentlyContinue | Where-Object { $_.Path -and $_.Path.Equals($executable, [StringComparison]::OrdinalIgnoreCase) }).Count -gt 0) {
            throw 'Codex 尚未完全退出。请手动退出后重新运行，配置尚未修改。'
        }
        $result = Set-CodexChineseConfig $configFile
        Write-Host '已设置为简体中文。' -ForegroundColor Green
        if ($result.Backup) { Write-Host ('配置备份：' + $result.Backup) }
        return 0
    } catch {
        Write-Host ('未完成：' + $_.Exception.Message) -ForegroundColor Red
        return 1
    } finally {
        if ($reopen -and $activation) {
            try { Start-Process -FilePath (Join-Path $env:WINDIR 'explorer.exe') -ArgumentList $activation; Write-Host '已发起重新打开 Codex。' }
            catch { Write-Host '请从开始菜单手动打开 Codex。' }
        }
    }
}

if ($MyInvocation.InvocationName -ne '.') { exit (Invoke-CodexChineseSetup) }
