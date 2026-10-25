// Edge 自动化：youlai-cloud 登录（验证码由外部读图提供）→ 密码模式 token → 仪表盘
import { createRequire } from 'node:module';
const require = createRequire('C:/Users/1/.workbuddy/binaries/node/workspace/node_modules/x.js');
const { chromium } = require('playwright-core');
import fs from 'node:fs';

const BASE = 'http://127.0.0.1:9527';
const OUT = 'D:/code/workbuddy/workbuddy-project/java/microservices/_shots';
fs.mkdirSync(OUT, { recursive: true });
const CAP_PNG = `${OUT}/captcha.png`;
const ANS_FILE = `${OUT}/captcha-answer.txt`;
try { fs.unlinkSync(ANS_FILE); } catch {}

const browser = await chromium.launch({ channel: 'msedge', headless: true, args: ['--no-proxy-server'] });
const ctx = await browser.newContext({ viewport: { width: 1440, height: 860 }, deviceScaleFactor: 2 });
const page = await ctx.newPage();
page.on('console', m => { if (m.type() === 'error' || m.type() === 'warning') console.log('PAGE_' + m.type().toUpperCase() + ':', m.text().slice(0, 250)); });
page.on('pageerror', e => console.log('PAGE_EXCEPTION:', String(e).slice(0, 400)));
page.on('response', r => { if (r.status() >= 400 && !r.url().includes('favicon')) console.log('HTTP_FAIL:', r.status(), r.url().slice(0, 150)); });

let captchaId = null;
page.on('response', async res => {
  if (res.url().includes('/auth/captcha')) {
    try {
      const j = await res.json();
      const d = j.data || j;
      captchaId = d.captchaId;
      let b64 = d.captchaBase64 || '';
      if (b64.includes(',')) b64 = b64.split(',')[1];
      fs.writeFileSync(CAP_PNG, Buffer.from(b64, 'base64'));
      console.log('CAPTCHA_SAVED captchaId=' + captchaId);
    } catch (e) { console.log('captcha save fail:', e.message); }
  }
});

await page.goto(BASE, { waitUntil: 'load', timeout: 30000 });
await page.waitForTimeout(3500);
await page.screenshot({ path: `${OUT}/01-youlai-login.png` });
console.log('OK 01-youlai-login.png');

for (let i = 0; i < 30 && !fs.existsSync(CAP_PNG); i++) await new Promise(r => setTimeout(r, 500));
if (!fs.existsSync(CAP_PNG)) { console.log('NO CAPTCHA CAPTURED'); await browser.close(); process.exit(1); }

// 视觉上填好表单
await page.locator('input[placeholder*="用户名"]').first().fill('admin');
await page.locator('input[type="password"]').first().fill('123456');
console.log('filled admin/123456, waiting for answer file...');

// 轮询答案文件（最多 150s）
let ans = null;
for (let i = 0; i < 300; i++) {
  if (fs.existsSync(ANS_FILE)) { ans = fs.readFileSync(ANS_FILE, 'utf8').trim(); if (ans) break; }
  await new Promise(r => setTimeout(r, 500));
}
if (!ans) { console.log('NO ANSWER RECEIVED'); await browser.close(); process.exit(1); }
console.log('answer:', ans);
await page.locator('input[placeholder*="验证码"]').first().fill(ans);
await page.screenshot({ path: `${OUT}/02-youlai-filled.png` });

// 页面内走密码模式拿 token（Basic mall-admin:123456）
const loginResult = await page.evaluate(async ({ captchaId, code }) => {
  const fd = new FormData();
  fd.append('username', 'admin');
  fd.append('password', '123456');
  fd.append('captchaId', captchaId || '');
  fd.append('captchaCode', code);
  fd.append('grant_type', 'password');
  const r = await fetch('/dev-api/youlai-auth/oauth2/token', {
    method: 'POST',
    headers: { Authorization: 'Basic bWFsbC1hZG1pbjoxMjM0NTY=' },
    body: fd,
  });
  return r.json();
}, { captchaId, code: ans });
console.log('token api code:', loginResult.code);
const token = loginResult?.data?.access_token;
if (!token) { console.log('NO TOKEN:', JSON.stringify(loginResult).slice(0, 300)); await browser.close(); process.exit(1); }
const tokenType = loginResult?.data?.token_type || 'Bearer';
await page.evaluate(t => localStorage.setItem('token', t), `${tokenType} ${token}`);
console.log('token saved to localStorage');

// 重载 → 路由守卫拉用户信息 → 仪表盘
await page.goto(BASE + '/#/dashboard', { waitUntil: 'load', timeout: 30000 }).catch(() => {});
await page.waitForTimeout(6000);
console.log('after login URL:', page.url());
await page.screenshot({ path: `${OUT}/04-youlai-dashboard.png` });
console.log('OK 04-youlai-dashboard.png');
if (page.url().includes('login')) {
  const err = await page.evaluate(() => document.body.innerText.slice(0, 300));
  console.log('STILL LOGIN:', err.replace(/\n+/g, ' | '));
}
await browser.close();
console.log('DONE');
