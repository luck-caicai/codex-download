# 添财AI · 下载与会员服务

纯静态页面，适配电脑和手机，支持浅色 / 深色切换。所有图片、图标、脚本均保存在本地，不依赖外部字体或 CDN。无需 npm、数据库或构建步骤。

三个百度网盘下载链接已配置，提取码均为 `6666`。各系统卡片下方的“查看安装教程”会打开对应飞书文档，Mac 两个版本保留各自的章节定位。

各系统卡片统一提供“汉化脚本下载”入口。汉化脚本压缩包随网页一起托管，不经过网盘；Mac 两种芯片共用一个压缩包。

下载卡片上方和“如何把 Codex 界面切换成中文？”说明中已补充使用指引：有魔法时，登录后从左下角“设置 → 常规 → 语言设置 → 简体中文”切换；没有魔法时，下载对应系统的汉化脚本压缩包，解压后双击唯一的脚本，自动修复和重启。

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
| 各下载项的 `localizationScriptUrl` | 汉化脚本压缩包，默认使用本地 `./assets/localize/` 路径 |
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

## 汉化脚本 3.0

下载包已合并为单文件，不再要求输入 Y。先结束任务并保存文件，再解压、双击对应脚本：

| 系统 | 下载 ZIP | ZIP 中唯一的文件 |
| --- | --- | --- |
| Windows | `assets/localize/codex-zh-cn-windows.zip` | `修复中文显示.bat` |
| Mac（M 系列 / Intel 通用） | `assets/localize/codex-zh-cn-mac.zip` | `修复中文显示.command` |

脚本内置全部 JS 和配置编辑代码，运行时释放到独立临时目录，结束后清理这些临时文件。无需额外保留 `.cjs`、`.sh` 或普通设置脚本。正常窗口仅显示检查、修复、重启三个步骤和完成结果；技术细节保存在诊断记录中。成功后不等待输入，失败时才保留提示。Mac 终端窗口是否自动关闭取决于系统设置。

工具自动识别已安装的原版应用；发现多个候选或没有找到时，使用系统文件 / 应用选择窗口。先创建并验证修复副本，再请求 Codex 正常退出、备份语言配置、设为 `zh-CN` 并启动副本。无法正常退出时停止，不强制结束进程。以后使用桌面的“Codex 中文修复版（添财AI）”入口，Mac 入口后缀为 `.command`。

平台说明在网页对应链接中查看，源文件为 `assets/localize/使用说明-Windows.txt`、`assets/localize/使用说明-Mac.txt`，不再塞进下载 ZIP。Mac 如果双击打不开，可在终端输入 `sh ` 后拖入脚本、按回车运行。

### 修复范围与保留项

已检查的 `26.908.40834` 中，语言菜单与翻译加载对 `enable_i18n` 使用不同的默认值；仅设置 `zh-CN` 不保证翻译加载启用。修复在独立副本中启用两处受支持的国际化读取，更新 ASAR 文件与分块哈希，保留原安装。中文资源、应用身份、脚本哈希、代码结构或运行时校验不符合预期时停止，不补造缺失翻译。

副本额外占用约 2 GB，执行前检查实际空间。修复版使用独立界面数据目录 `CodexChinese/UserData`，可能需要重新登录；`CODEX_HOME` 仍指向原来的配置与会话目录。配置已有 `zh-CN` 时不重复添加。需要修改配置时，在原目录创建 `config.toml.before-zh-cn.时间标识.bak` 备份。

- Windows 副本：`%LOCALAPPDATA%\TiancaiAI\CodexChinese\build-时间-标识`。
- Windows 诊断：`%LOCALAPPDATA%\TiancaiAI\CodexLocale\repair-*.txt`。
- Mac 副本：`~/Library/Application Support/TiancaiAI/CodexChinese/build-时间-标识/`。
- Mac 诊断：`~/Library/Application Support/TiancaiAI/CodexLocale/repair-mac-*.txt`。

Windows 保留 2.1 的复制修复：临时复制应用内置 Node.js，用它逐文件复制到新目录，避免 Robocopy 与 PowerShell 的扩展路径兼容问题；核对文件路径和字节数后才开始修补。文件复制不继承 WindowsApps 的加密或只读属性。完整性校验原本关闭时保留 EXE；开启时仅更新可识别的副本哈希，这类版本的副本可能无法保留原厂数字签名；不会关闭校验开关。

Mac 使用内置 Node.js、系统 `ditto` 和签名工具。复制保留应用内部链接，拒绝指向外部的链接。更新 `Info.plist` 中的资源哈希，为主应用进行本机临时签名，并验证签名；嵌套代码保留原签名。主应用移除依赖厂商身份的推送、应用组、共享钥匙串等签名权限，保留普通运行权限。本机签名不等于原厂公证，可能需要重新登录或授权，部分系统集成功能可能受影响；异常时仍可使用原版。未知额外摘要校验会停止处理。

原版升级后，先退出修复版，再运行脚本创建新版副本。旧副本不会自动升级，可在退出后手动删除不需要的 `build-` 目录；不要删除整个 `.codex`。

### 维护与验证

单文件由源码生成，请修改源码后运行构建，不要直接改生成文件：

- `scripts/localize/windows-repair.ps1`：Windows 自动修复流程。
- `scripts/localize/mac-entry.command.in`：Mac 双击入口与配置编辑模板。
- `assets/localize/repair-i18n.cjs`、`repair-i18n-mac.cjs`：内嵌修补逻辑。
- `assets/localize/codex-zh-cn.bat`：构建时复用其中的配置与应用识别函数；旧主流程不进入下载包。

```sh
python scripts/build-localize.py
python scripts/build-localize.py --check
python tests/check-standalone.py
node tests/check-windows-copy.cjs
node tests/check-mac-repair.cjs
```

Windows 上另运行 `python tests/check-windows-flow.py`。测试使用隔离配置和模拟应用进程，不关闭当前用户的 Codex。单文件检查覆盖 ZIP 只有一个完整入口、Mac 执行权限、没有键盘输入时运行、特殊字符路径、错误退出码及临时辅助文件清理。Windows 流程覆盖复制失败、源目录变动、应用未正常退出和重开失败；复制检查覆盖长路径、Unicode、已有副本保护、部分写入和目录链接。

GitHub Actions 的 `.github/workflows/macos-localization.yml` 在 Apple 芯片与 Intel 的 macOS 15 原生环境中验证：把唯一 `.command` 放进空目录，关闭标准输入，使用固定官方 `26.908.40834` 完成复制、签名、配置备份和实际启动，并发送正常退出请求。测试使用临时配置，不使用真实账号；应用进程启动不等于已验证账号内的全部界面与功能。

3.0 单文件版本在两个架构上均已通过[原生验证](https://github.com/luck-caicai/codex-download/actions/runs/35045395998)，每个架构 14 项修复检查通过。Windows 本地通过 20 项隔离流程检查、8 项复制检查；另有 9 项单文件入口与打包检查，以及两个平台各 22 组配置编辑样例。

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
- `assets/localize/`：汉化代码、生成的单文件脚本、分系统说明及可下载 ZIP。
- `scripts/`：单文件构建程序与入口模板。
- `tests/`：单文件、复制与修复流程的隔离检查。
- `assets/favicon.svg`：添财AI 图标。
- `assets/PHOSPHOR-LICENSE.txt`：Phosphor Icons 2.1.1 的 MIT 许可。
- `.nojekyll`：静态文件发布标记。
- `.gitignore`：忽略临时文件、备份和大型安装包，保留网页使用的两个脚本 ZIP。
- `.gitattributes`：固定 BAT 为 Windows 换行，SH / COMMAND 为 Unix 换行，并保留 ZIP 与图片的原始字节。

## 上线前实际检查

填写自己的三个下载链接后，分别打开确认文件与系统匹配；用微信实际扫描群二维码和咨询二维码。页面不处理支付或收集账号信息，套餐按钮用于咨询。群二维码到期后只需替换图片并重新上传。
