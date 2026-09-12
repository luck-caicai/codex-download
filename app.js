(() => {
  'use strict';
  const config = window.TIANCAI_CONFIG || {};
  const contact = config.contact || {};
  const defaultPlans = {
    plus: { name: 'Plus', price: 135, period: '' },
    pro5: { name: 'Pro 5×', price: 740, period: '' },
    pro20: { name: 'Pro 20×', price: 1250, period: '' },
  };
  const plans = Object.fromEntries(Object.entries(defaultPlans).map(([key, fallback]) => {
    const supplied = config.plans?.[key] || {};
    const price = Number(supplied.price);
    return [key, { name: String(supplied.name || fallback.name), price: Number.isFinite(price) && price > 0 ? price : fallback.price, period: String(supplied.period || '') }];
  }));
  const money = (value) => Number(value).toLocaleString('zh-CN', { maximumFractionDigits: 2, useGrouping: false });
  let selectedPlan = 'plus';
  let toastTimer;

  function publicUrl(raw, allowRelative = false) {
    if (typeof raw !== 'string' || !raw.trim()) return '';
    const value = raw.trim();
    if (allowRelative && /^(\.\/)?assets\/[\w./%-]+$/i.test(value) && !value.includes('..')) return value;
    try { const url = new URL(value); return url.protocol === 'https:' ? url.href : ''; } catch (_) { return ''; }
  }

  function notify(message) {
    const toast = document.querySelector('.toast');
    const targetDialog = document.querySelector('dialog[open]');
    (targetDialog || document.body).append(toast);
    toast.textContent = message;
    toast.hidden = false;
    clearTimeout(toastTimer);
    toastTimer = setTimeout(() => { toast.hidden = true; }, 3200);
  }

  async function copyText(text, message) {
    try {
      if (!navigator.clipboard?.writeText) throw new Error('Clipboard unavailable');
      await navigator.clipboard.writeText(text);
      notify(message);
    } catch (_) {
      const input = document.createElement('textarea');
      input.value = text;
      input.setAttribute('aria-label', '可复制的文本');
      Object.assign(input.style, { position: 'fixed', left: '0', top: '0', width: '1px', height: '1px', opacity: '0' });
      (document.querySelector('dialog[open]') || document.body).append(input);
      input.select();
      let copied = false;
      try { copied = document.execCommand('copy'); } catch (_) {}
      input.remove();
      notify(copied ? message : '浏览器未允许复制，请手动复制页面中的信息。');
    }
  }

  document.querySelectorAll('[data-download]').forEach(card => {
    const item = config.downloads?.[card.dataset.download] || {};
    const url = publicUrl(item.url);
    const link = card.querySelector('[data-download-link]');
    if (item.size) card.querySelector('[data-file-size]').textContent = String(item.size);
    if (item.version) card.querySelector('[data-file-version]').textContent = String(item.version);
    if (url) {
      link.href = url;
      link.target = '_blank';
      link.rel = 'noopener noreferrer';
      link.removeAttribute('aria-disabled');
      link.removeAttribute('role');
      link.removeAttribute('tabindex');
      link.querySelector('span').textContent = '打开网盘下载';
    }
    const code = typeof item.extractionCode === 'string' ? item.extractionCode.trim() : '';
    if (url && code) {
      const copyButton = card.querySelector('[data-copy-code]');
      copyButton.textContent = `提取码 ${code} · 点击复制`;
      copyButton.hidden = false;
      copyButton.addEventListener('click', () => copyText(code, '提取码已复制'));
    }
    const guideUrl = publicUrl(item.installGuideUrl);
    if (guideUrl) {
      const guideLink = card.querySelector('[data-install-guide]');
      guideLink.href = guideUrl;
      guideLink.hidden = false;
    }
    const scriptUrl = publicUrl(item.localizationScriptUrl, true);
    if (scriptUrl) {
      const scriptLink = card.querySelector('[data-localization-script]');
      scriptLink.href = scriptUrl;
      scriptLink.hidden = false;
    }
  });

  Object.entries(plans).forEach(([key, plan]) => {
    const row = document.querySelector(`[data-plan="${key}"]`);
    row.querySelector('[data-price]').textContent = money(plan.price);
    row.querySelector('[data-period]').textContent = plan.period;
  });

  const shopUrl = publicUrl(config.shopUrl);
  if (shopUrl) {
    document.querySelectorAll('[data-shop-link]').forEach(link => {
      link.href = shopUrl;
      link.hidden = false;
    });
  }

  const remoteToolUrl = publicUrl(config.support?.remoteToolUrl);
  if (remoteToolUrl) {
    const remoteLink = document.querySelector('[data-remote-tool-link]');
    remoteLink.href = remoteToolUrl;
    remoteLink.hidden = false;
  }

  const wechatId = typeof contact.wechatId === 'string' ? contact.wechatId.trim() : '';
  if (wechatId) {
    document.querySelectorAll('[data-copy-wechat]').forEach(button => {
      button.hidden = false;
      button.querySelector('[data-wechat-label]').textContent = `复制微信号：${wechatId}`;
      button.addEventListener('click', () => copyText(wechatId, '微信号已复制，打开微信添加好友'));
    });
  }

  const groupUrl = publicUrl(contact.groupJoinUrl);
  if (groupUrl) {
    const link = document.querySelector('[data-group-link]');
    link.href = groupUrl;
    link.hidden = false;
  }
  const groupQr = publicUrl(contact.groupQr, true);
  if (groupQr) {
    const image = document.querySelector('[data-qr-image="group"]');
    const placeholder = document.querySelector('[data-qr-placeholder="group"]');
    const openQr = document.querySelector('[data-group-qr-open]');
    image.addEventListener('load', () => {
      image.hidden = false;
      placeholder.hidden = true;
      openQr.href = groupQr;
      openQr.hidden = false;
      document.querySelector('[data-group-caption]').textContent = String(contact.groupCaption || '微信扫一扫，加入交流群');
      document.querySelector('[data-group-note]').textContent = String(contact.groupNote || '二维码失效时，请联系添财。');
    });
    image.addEventListener('error', () => {
      image.hidden = true;
      placeholder.hidden = false;
      openQr.hidden = true;
      placeholder.querySelector('span').textContent = '二维码暂时无法显示';
      document.querySelector('[data-group-caption]').textContent = wechatId ? '请复制微信号，联系添财入群' : '请稍后再查看入群方式';
    });
    image.src = groupQr;
  } else if (wechatId) {
    document.querySelector('[data-group-caption]').textContent = '复制微信号，联系添财入群';
    document.querySelector('[data-group-note]').textContent = '添加好友时，可以备注“添财AI 交流群”。';
  } else if (groupUrl) {
    document.querySelector('[data-group-caption]').textContent = '点击“加入微信群”查看入群方式';
    document.querySelector('[data-group-note]').textContent = '';
  } else {
    document.querySelector('[data-group-note]').textContent = '聊工具、聊方法，也聊你的新发现。';
  }

  const consultQr = publicUrl(contact.consultQr, true);
  const consultImage = document.querySelector('[data-consult-qr]');
  const consultNote = document.querySelector('[data-consult-note]');
  if (wechatId) consultNote.textContent = String(contact.consultNote || '请添加微信，并发送你想咨询的套餐。');
  if (consultQr) {
    consultImage.addEventListener('load', () => { consultImage.hidden = false; consultNote.textContent = String(contact.consultNote || '用微信扫码，咨询你选择的套餐。'); });
    consultImage.addEventListener('error', () => { consultImage.hidden = true; if (!wechatId) consultNote.textContent = '联系二维码暂时无法显示，请稍后再试。'; });
    consultImage.src = consultQr;
  }
  const consultGroupLink = document.querySelector('[data-consult-group]');
  if (!wechatId && !consultQr && (groupQr || groupUrl)) {
    consultNote.textContent = '可以先加入交流群，联系添财咨询套餐。';
    consultGroupLink.hidden = false;
  }

  const helpDialog = document.querySelector('#help-dialog');
  const contactDialog = document.querySelector('#contact-dialog');
  consultGroupLink.addEventListener('click', () => contactDialog.close());
  document.querySelectorAll('[data-open-help]').forEach(button => button.addEventListener('click', () => helpDialog.showModal()));
  document.querySelectorAll('[data-consult]').forEach(button => button.addEventListener('click', () => {
    selectedPlan = button.dataset.consult;
    const plan = plans[selectedPlan];
    document.querySelector('[data-selected-plan]').textContent = plan.name;
    document.querySelector('[data-selected-price]').textContent = `¥${money(plan.price)}${plan.period}`;
    document.querySelector('#contact-title').textContent = `咨询 ${plan.name} 代充`;
    contactDialog.showModal();
  }));
  document.querySelectorAll('[data-close-dialog]').forEach(button => button.addEventListener('click', () => button.closest('dialog').close()));
  document.querySelectorAll('dialog').forEach(dialog => {
    dialog.addEventListener('click', event => {
      if (event.target !== dialog) return;
      const box = dialog.getBoundingClientRect();
      if (event.clientX < box.left || event.clientX > box.right || event.clientY < box.top || event.clientY > box.bottom) dialog.close();
    });
    dialog.addEventListener('close', () => {
      const toast = document.querySelector('.toast');
      toast.hidden = true;
      document.body.append(toast);
      clearTimeout(toastTimer);
    });
  });
  document.querySelector('[data-copy-inquiry]').addEventListener('click', () => {
    const plan = plans[selectedPlan];
    copyText(`你好，我想咨询 ChatGPT ${plan.name} 代充，添财AI 页面报价为 ¥${money(plan.price)}${plan.period}。请帮我确认套餐时长、到账时间和售后说明。`, '咨询内容已复制，可以发送给添财');
  });

  const themeToggle = document.querySelector('.theme-toggle');
  const systemTheme = matchMedia('(prefers-color-scheme: dark)');
  const currentTheme = () => document.documentElement.dataset.theme || (systemTheme.matches ? 'dark' : 'light');
  function themeLabel() {
    themeToggle.setAttribute('aria-label', `切换${currentTheme() === 'dark' ? '浅色' : '深色'}外观`);
    document.querySelector('meta[name="theme-color"]').content = currentTheme() === 'dark' ? '#121b16' : '#f6f8f7';
  }
  themeToggle.addEventListener('click', () => {
    const next = currentTheme() === 'dark' ? 'light' : 'dark';
    document.documentElement.dataset.theme = next;
    try { localStorage.setItem('tiancai-theme', next); } catch (_) {}
    themeLabel();
  });
  systemTheme.addEventListener('change', themeLabel);
  themeLabel();
  document.querySelector('[data-year]').textContent = String(new Date().getFullYear());
})();
