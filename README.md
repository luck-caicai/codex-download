# 添财AI · 下载与会员服务

纯静态页面，适配电脑和手机，支持浅色 / 深色切换。所有图片、图标、脚本均保存在本地，不依赖外部字体或 CDN。无需 npm、数据库或构建步骤。

三个百度网盘下载链接已配置，提取码均为 `6666`。各系统卡片下方的“查看安装教程”会打开对应飞书文档，Mac 两个版本保留各自的章节定位。

各系统卡片也提供“中文设置脚本”下载。脚本压缩包随网页一起托管，不经过网盘；Mac 两种芯片共用一个压缩包。

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
- Mac：解压 `assets/localize/codex-zh-cn-mac.zip`，双击“启动中文设置.command”；也可以在终端运行同目录的 `codex-zh-cn.sh`。M 系列与 Intel 通用，不需要额外安装开发工具。

先结束任务并保存文件。脚本在用户输入 Y 后退出 Codex，备份原配置，将 `config.toml` 中 `[desktop]` 的 `localeOverride` 设置为 `"zh-CN"`，然后重新打开应用。配置已是 `zh-CN` 时不会重复添加字段。完整用法、备份恢复方法和适用范围见压缩包内的“使用说明.txt”，每个包只介绍对应系统的操作。

1.1 版会显示应用版本、应用位置和配置路径。Windows 优先识别正在运行的 Codex，兼容 MSIX 和含原始应用资源的独立目录；多份安装时让用户选择。只对选定应用路径的 GUI 进程执行退出，等待完全退出后才写入配置，并尝试重新打开同一份应用。Windows 还会只读检查应用身份和中文资源条目，在 `%LOCALAPPDATA%\TiancaiAI\CodexLocale` 保存诊断结果，不记录完整配置、聊天或账号密钥。Mac 无法确认退出状态时停止写入。

“配置已写入”和“检测到进程重开”不代表已验证界面语言。若设置显示简体中文、界面仍是英文，先在 `Settings > General > Language` 选择 `English`，再选“简体中文”，并检查下次重开是否保持。手动切换能生效说明翻译可用；仅凭这一现象无法确定是启动、状态刷新还是运行时国际化开关的问题。脚本不修改 `app.asar`、应用可执行文件或用户数据目录。

配置编辑已通过 22 组独立样例验证，Windows 文件写入与备份使用 Windows PowerShell 5.1 验证。Windows 应用识别、退出等待、取消、重开失败和配置被改回等分支使用模拟应用与进程验证；没有运行这些应用。Mac 的 shell 语法和配置处理逻辑已检查。两个系统的真实应用退出和重开流程均尚未实机验证，测试没有修改当前用户的实际 Codex 配置或重启应用。

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
