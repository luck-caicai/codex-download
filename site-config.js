/**
 * 添财AI 网站公开配置。修改后重新上传即可，不需要构建。
 * 此文件会发送给访问者，请只填写公开的链接、价格和联系信息。
 * 缺少下载链接时，页面会显示“下载入口待更新”，不会跳转到其他人的网盘。
 */
window.TIANCAI_CONFIG = {
  downloads: {
    windows: {
      url: "https://pan.baidu.com/s/14ZiH4eubAj3FguJSQ7UIbQ?pwd=6666", // Windows x64 网盘分享链接
      extractionCode: "6666", // 无提取码则留空
      installGuideUrl: "https://my.feishu.cn/docx/VP9zdWIvAoxbwrxlSvNc2b4Nnod", // Windows 安装教程
      localizationScriptUrl: "./assets/localize/codex-zh-cn-windows.zip",
      size: "约 770 MB",
      version: "26.903.8094.0",
    },
    macApple: {
      url: "https://pan.baidu.com/s/1_cFE5Ny_Dn3-dmHn3iKPDg?pwd=6666", // Mac Apple 芯片版网盘链接
      extractionCode: "6666",
      installGuideUrl: "https://my.feishu.cn/docx/VP9zdWIvAoxbwrxlSvNc2b4Nnod#share-LIPsd0xKdoPmAMx7py3cu2GTnAe", // Mac M 芯片安装教程
      localizationScriptUrl: "./assets/localize/codex-zh-cn-mac.zip",
      size: "约 624 MB",
      version: "ARM64", // 确认下载的实际版本后可改为版本号
    },
    macIntel: {
      url: "https://pan.baidu.com/share/init?surl=UZk8eDUrpF_MCTRY6zlGVw&pwd=6666", // Mac Intel 芯片版网盘链接
      extractionCode: "6666",
      installGuideUrl: "https://my.feishu.cn/docx/VP9zdWIvAoxbwrxlSvNc2b4Nnod#share-Ug3WdGK7moV3vkxnNbucUeBsneb", // Mac Intel 安装教程
      localizationScriptUrl: "./assets/localize/codex-zh-cn-mac.zip",
      size: "约 611 MB",
      version: "x64",
    },
  },
  plans: {
    plus: { name: "Plus", price: 135, period: "" },
    pro5: { name: "Pro 5×", price: 740, period: "" },
    pro20: { name: "Pro 20×", price: 1250, period: "" },
    // 只有确认按月收费后，才把 period 改为“/ 月”。
  },
  support: {
    remoteToolUrl: "https://uuyc.163.com/", // 需要远程协助时，先下载安装 UU 远程
  },
  contact: {
    wechatId: "", // 公开联系微信号
    consultQr: "", // 如：./assets/wechat-contact.png。先将真实图片放进 assets 文件夹
    groupQr: "./assets/wechat-group.jpg", // 群二维码到期后替换这张图片
    groupJoinUrl: "", // 如有可直接打开的入群页面，填在这里；没有则留空
    groupCaption: "微信扫一扫，加入 Codex 交流群",
    groupNote: "二维码标注：9 月 19 日前有效。",
    consultNote: "请添加微信，并发送你想咨询的套餐。",
  },
};
