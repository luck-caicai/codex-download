# 添财AI · 下载与会员服务

纯静态页面，适配电脑和手机，支持浅色 / 深色切换。所有图片、图标、脚本均保存在本地，不依赖外部字体或 CDN。无需 npm、数据库或构建步骤。

三个百度网盘下载链接已配置，提取码均为 `6666`。各系统卡片下方的“查看安装教程”会打开对应飞书文档，Mac 两个版本保留各自的章节定位。

各系统卡片统一提供“汉化脚本下载”入口。汉化脚本压缩包随网页一起托管，不经过网盘；Mac 两种芯片共用一个压缩包。

下载卡片上方和“如何把 Codex 界面切换成中文？”说明中已补充使用指引：有魔法时，登录后从左下角“设置 → 常规 → 语言设置 → 简体中文”切换；没有魔法时，下载对应系统的汉化包，按照压缩包内教程执行。

顶部导航突出显示“AI会员小铺”，会员代充区域和套餐咨询弹窗也提供同名店铺入口，均在新窗口打开配置中的店铺地址。手机端导航分两行排列，店铺入口保持可见。

已加入真实的 Codex 交流群二维码，首屏与交流群区域说明“免费协助解决安装和无法使用问题”。远程协助入口指向用户提供的 UU 远程下载地址；访客先安装工具，再进群联系。没有填写个人微信联系方式时，套餐咨询弹窗会引导访客进群联系添财。

当前二维码图片标注 **9 月 19 日前有效**，到期后请替换 `assets/wechat-group.jpg` 并更新配置中的有效期文案。套餐时长仍待确认。

## 修改链接和联系信息

用文本编辑器打开 `site-config.js`，填写双引号里的内容：

| 配置 | 用途 |
| --- | --- |
| `downloads.windows.url` | Windows x64 安装包的网盘链接 |
| `downloads.macApple.url` | Mac Apple 芯片安装包的网盘链接 |
| `downloads.macIntel.url` | Mac Intel 安装包的网盘链接 |
| 各下载项的 `extractionCode` | 网盘提取码，没有则留空 |
| 各下载项的 `installGuideUrl` | 对应系统的安装教程链接，可包含章节定位 |
| 各下载项的 `localizationScriptUrl` | 中文设置脚本压缩包，默认使用本地 `./assets/localize/` 路径 |
| 各下载项的 `size` / `version` | 按实际上传文件更新大小、版本或架构 |
| `support.remoteToolUrl` | UU 远程工具下载链接 |
| `shopUrl` | AI会员小铺地址，统一用于顶部导航、代充区域与咨询弹窗的店铺入口 |
| `contact.wechatId` | 公开的联系微信号 |
| `contact.consultQr` | 代充咨询的微信二维码图片路径 |
| `contact.groupQr` | 微信群二维码图片路径 |
| `contact.groupJoinUrl` | 可选的入群说明页面链接 |
| `plans` 中的 `price` / `period` | 套餐价格和时长 |

当前群二维码原图保存在 `assets/wechat-group.jpg`，配置为：

```js
groupQr: "./assets/wechat-group.jpg",
```

请使用英文文件名，注意大小写一致。咨询二维码可以类似命名为 `wechat-contact.png`。PNG、JPG、WebP 都可以，保留二维码周围白边。

下载链接支持 HTTPS 网盘分享链接；二维码支持本地 `./assets/文件名` 路径或 HTTPS 图片直链。微信号、群二维码、入群链接可以按实际情况组合填写。配置留空时会显示“待更新”，不会跳转到其他人的网盘，也不会显示虚构二维码。

价格已设为 Plus ¥135、Pro 5× ¥740、Pro 20× ¥1250。时长尚未确认，默认不显示“每月”；确认后在对应 `period` 中填写，例如 `/ 月`。到账时间、售后承诺没有预设，需要在正文或咨询说明中填写自己的真实约定。

此配置文件是公开的，请只写准备向访客公开的联系信息，不要写账号密码或密钥。

## 中文设置脚本

- Windows：解压 `assets/localize/codex-zh-cn-windows.zip`，双击 `codex-zh-cn.bat`。
- Windows 已设置中文但文字仍是英文：完整解压同一个包，双击新增的“修复中文显示.bat”，按提示创建修复副本；以后使用桌面上的“Codex 中文修复版（添财AI）”。保留包内 `codex-zh-cn.bat` 和 `repair-i18n.cjs`，工具会自动调用它们。
- Mac：将 `assets/localize/codex-zh-cn-mac.zip` 解压到新文件夹，直接双击“修复中文显示.command”，按提示创建并签名修复副本。M 系列与 Intel 通用，包内只保留一个运行入口，无需先做普通中文设置或额外运行 `.sh`。两个 `.cjs` 文件与入口保存在同一目录。以后使用桌面的“Codex 中文修复版（添财AI）.command”。

先结束任务并保存文件。脚本在用户输入 Y 后退出 Codex，备份原配置，将 `config.toml` 中 `[desktop]` 的 `localeOverride` 设置为 `"zh-CN"`，然后重新打开应用。配置已是 `zh-CN` 时不会重复添加字段。完整用法、备份恢复方法和适用范围见压缩包内的“使用说明.txt”，每个包只介绍对应系统的操作。

1.1 版会显示应用版本、应用位置和配置路径。Windows 优先识别正在运行的 Codex，兼容 MSIX 和含原始应用资源的独立目录；多份安装时让用户选择。只对选定应用路径的 GUI 进程执行退出，等待完全退出后才写入配置，并尝试重新打开同一份应用。Windows 还会只读检查应用身份和中文资源条目，在 `%LOCALAPPDATA%\TiancaiAI\CodexLocale` 保存诊断结果，不记录完整配置、聊天或账号密钥。Mac 无法确认退出状态时停止写入。

“配置已写入”和“检测到进程重开”不代表已验证界面语言。Windows 普通设置脚本不修改应用文件；显示修复工具会创建应用副本。Mac 包直接提供显示修复入口，配置编辑包含在修复流程中。

### Windows 中文显示修复 2.1

已检查的 `26.908.40834` 中，语言菜单与翻译加载对 `enable_i18n` 使用不同的默认值；设置为 `zh-CN` 并不保证翻译加载被启用。修复工具在 `%LOCALAPPDATA%\TiancaiAI\CodexChinese\build-时间-标识` 创建独立应用副本，在副本中将受支持的国际化布尔读取改为启用，并更新 ASAR 文件及分块哈希。它保留完整性校验的原状态：关闭时保留可执行文件，开启时更新副本中匹配的哈希；无法识别时停止处理，不会关闭校验功能。原安装不修改。

当前版本的副本额外占用约 2 GB；脚本运行前显示实际估算值。包内 Node 工具先复制到临时目录执行，以兼容 WindowsApps 的执行限制。修复版使用独立的界面数据目录 `CodexChinese\UserData`，可能需要重新登录；`CODEX_HOME` 仍指向用户的配置目录。新建的桌面快捷方式始终指向修复副本。原版升级后可重新运行修复工具创建新版副本；旧副本可在退出后手动删除。

2.1 针对复制后留下空目录、检查副本时提示 `Cannot find path` 的情况，将 Robocopy 和 PowerShell 的 `\\?\` 路径枚举改为内置 Node.js 直接读取、复制文件。只写入新建的副本目录，不合并或覆盖已有副本，不继承 WindowsApps 的加密或只读属性；复制完成后核对目录结构、文件相对路径和字节数。失败时停止后续修补、配置与启动，诊断记录包含具体出错文件、Windows / PowerShell 版本和原应用与副本的文件数量。

修复范围只包括内置翻译开关和语言配置，不补造缺失翻译文件。中文资源、应用身份、原始脚本哈希、代码结构或运行时校验检查未通过时会停止。诊断文件位于 `%LOCALAPPDATA%\TiancaiAI\CodexLocale\repair-*.txt`。对于必须更新可执行文件哈希的版本，副本签名会失效，操作前有明确提示。

验证包括：20 项修补检查（开关缺省 / 关闭 / 开启、真实翻译加载函数配合模拟运行时、归档偏移与分块哈希、原文件保留、未知结构拒绝）和 18 项 Windows 流程检查，覆盖复制失败或文件清单变化时停止处理。新增 `node tests/check-windows-copy.cjs` 的 8 项复制检查，覆盖超过 260 字符的路径、中文 / 空格 / 方括号路径、空文件与空目录、已有副本保护、写入失败、部分写入、目录链接与 Windows PowerShell 5.1 调用。当前版本支持的修补点为两处。真实界面是否生效仍需在目标电脑确认。

同版本实际安装文件的测试副本已完成 5,466 个文件的复制和修补，兼容长路径；原安装的 ASAR、EXE、DLL 哈希保持一致，副本 EXE / DLL 字节未变，EXE 签名仍有效。此项验证使用独立配置文件，进程操作与桌面快捷方式创建使用模拟实现，没有启动或关闭当前 Codex。

配置编辑已通过 22 组独立样例验证，Windows 文件写入与备份使用 Windows PowerShell 5.1 验证。Windows 应用识别、退出等待、取消、重开失败和配置被改回等分支使用模拟应用与进程验证；没有运行这些应用。Mac 配置编辑函数已合并到修复 `.command` 中，保留原有备份和重复运行检查逻辑。以上本地检查没有修改当前用户的实际 Codex 配置或重启应用；Mac 显示修复入口的原生环境验证见下方。

### Mac 中文显示修复 2.1

Apple 芯片和 Intel 共用“修复中文显示.command”双击入口。2.1 版将应用识别、配置编辑和启动逻辑合并到该文件，移除旧的普通设置入口和两个 `.sh` 文件。Mac 压缩包只有四个文件：该入口、`repair-i18n.cjs`、`repair-i18n-mac.cjs` 和“使用说明.txt”。两个 `.cjs` 由入口自动调用，用户无需单独运行。

脚本识别已经安装的原版 `Codex.app` 或 `ChatGPT.app`，使用其内置 Node.js。存在多个安装时由用户选择；不会自动下载开发环境。已检查两个架构的官方 `26.908.40834` 安装包，两种架构的资源归档均支持相同的两处翻译开关修补。

副本保存在 `~/Library/Application Support/TiancaiAI/CodexChinese/build-时间-标识/`，运行前检查并显示空间需求。复制保留应用内部的框架链接，拒绝指向外部的链接；原安装不写入。修补复用 Windows 版的归档编辑逻辑，更新文件及分块哈希，同时更新 Mac `Info.plist` 中的 `ElectronAsarIntegrity`。保留运行时校验开关的原状态；开启额外框架摘要校验的版本当前会停止处理，不会关闭校验功能。

Mac 副本的主应用采用本机临时签名，不再具有 OpenAI 原厂签名。保留嵌套代码的原始签名，为主应用保留 JIT 等普通权限，移除依赖厂商签名的推送、应用组、共享钥匙串等权限，并允许主应用加载未修改的原厂框架。脚本随后执行 `codesign --verify --deep --strict`。这不等于原厂公证；用户可能需要重新登录或授权，部分系统集成功能可能受影响，异常时使用原版。

副本使用独立 `CodexChinese/UserData`，显式保留原来的 `CODEX_HOME`。脚本在用户确认后请求原版及本工具旧副本正常退出，确认退出才备份和修改语言配置。无法退出时停止，不强制结束任务。创建桌面 `.command` 启动入口；桌面不可写时，保留在副本父目录，并显示路径。诊断位于 `~/Library/Application Support/TiancaiAI/CodexLocale/repair-mac-*.txt`。

验证脚本为 `tests/check-mac-repair.cjs`，包括资源哈希、原安装保留、未知摘要拒绝、签名权限转换和特殊字符路径等 13 项隔离检查。2.1 版的单一 `.command` 入口在 Apple 芯片与 Intel 的 macOS 15 原生环境均已通过[验证运行](https://github.com/luck-caicai/codex-download/actions/runs/34734191907)：使用固定官方 `26.908.40834` 版本完成复制、签名、配置备份和实际启动，并发送正常退出请求。每个架构 14 项检查通过，使用临时测试配置，不使用真实账号。另有 5 项入口检查验证成功、子进程失败状态保留、缺少辅助文件、错误系统和错误应用路径。用户已反馈 Mac 修复可生效；完整系统功能仍需在实际使用电脑上确认。

参考：[Electron 的 Mac 资源完整性校验](https://www.electronjs.org/docs/latest/tutorial/asar-integrity)、[Apple 代码签名说明](https://developer.apple.com/library/archive/technotes/tn2206/)。

两份说明源文件分别保存在 `assets/localize/使用说明-Windows.txt` 和 `assets/localize/使用说明-Mac.txt`。打包时，将对应系统的说明放进 ZIP，并命名为“使用说明.txt”。更新脚本或说明后，请同步重新打包对应 ZIP；页面下载的是 ZIP 文件。

## 本地查看

双击 `index.html` 即可查看页面。如需通过本地网址检查，可以在这个文件夹中执行：

```sh
python -m http.server 4176
```

然后访问 `http://localhost:4176/`。

## 托管说明

页面使用相对路径，可部署在域名根目录，也可部署在 `/仓库名/` 这样的子目录。将此文件夹内的内容上传到静态托管的发布目录即可，确保 `index.html` 位于该目录第一层。整个网页不包含数百 MB 的软件安装包，安装包继续放在你的网盘中。

**GitHub Pages 使用范围：** GitHub 官方限制主要用于促成商业交易的网站使用 Pages 免费托管。本页含代充报价及咨询入口，正式商业运营建议选择明确允许该用途的托管服务；代码可以保存在 GitHub。请按 [GitHub Pages 官方限制](https://docs.github.com/en/pages/getting-started-with-github-pages/github-pages-limits) 确认适用范围。

对于符合 GitHub Pages 使用范围的版本，发布方式为：

1. 将 `index.html`、`styles.css`、`app.js`、`site-config.js`、`.nojekyll` 和整个 `assets` 文件夹放到仓库根目录。
2. 进入仓库 **Settings → Pages**。
3. **Source** 选择 **Deploy from a branch**。
4. 分支选择 `main`，目录选择 `/(root)`，保存。
5. 等待部署完成，打开 Pages 页面显示的网址。

参考：[GitHub Pages 发布源配置](https://docs.github.com/en/pages/getting-started-with-github-pages/configuring-a-publishing-source-for-your-github-pages-site)。

上传代码到 GitHub 后，网站发布仍需单独配置静态托管。

## 文件说明

- `index.html`：页面内容，包含本地 Phosphor 图标。
- `styles.css`：配色、排版、手机适配和主题切换样式。
- `site-config.js`：网盘链接、提取码、价格和微信信息。
- `app.js`：配置读取、咨询弹窗、复制、外观切换。
- `assets/download-art.webp`：为本页面生成的下载主题配图。
- `assets/wechat-group.jpg`：用户提供的交流群二维码原图，未重新绘制或压缩。
- `assets/localize/`：Windows / Mac 中文设置脚本、双击启动文件、说明及可下载 ZIP。
- `assets/favicon.svg`：添财AI 图标。
- `assets/PHOSPHOR-LICENSE.txt`：Phosphor Icons 2.1.1 的 MIT 许可。
- `.nojekyll`：静态文件发布标记。
- `.gitignore`：忽略临时文件、备份和大型安装包，保留网页使用的两个脚本 ZIP。
- `.gitattributes`：固定 BAT 为 Windows 换行，SH / COMMAND 为 Unix 换行，并保留 ZIP 与图片的原始字节。

## 上线前实际检查

填写自己的三个下载链接后，分别打开确认文件与系统匹配；用微信实际扫描群二维码和咨询二维码。页面不处理支付或收集账号信息，套餐按钮用于咨询。群二维码到期后只需替换图片并重新上传。
