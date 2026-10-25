// 用系统 Edge 抓取 5 个 Java 项目的实拍截图（供运行清单展示）
import { createRequire } from 'node:module';
import fs from 'node:fs';
import path from 'node:path';

const require = createRequire('C:/Users/1/.workbuddy/binaries/node/workspace/node_modules/x.js');
const { chromium } = require('playwright-core');

const OUT = 'D:/code/workbuddy/workbuddy-project/java/_shots';
fs.mkdirSync(OUT, { recursive: true });

const targets = [
  { name: '01-petclinic', url: 'http://127.0.0.1:8081/', wait: 1200 },
  { name: '02-satoken-demo', url: 'http://127.0.0.1:8082/', wait: 1200 },
  { name: '03-xxl-job-login', url: 'http://127.0.0.1:8080/auth/login', wait: 1200 },
  { name: '04-xxl-job-dashboard', url: 'http://127.0.0.1:8080/jobinfo', wait: 1800, needLogin: true },
  { name: '05-sso-server-auth', url: 'http://127.0.0.1:9000/sso/auth', wait: 1200 },
];

const browser = await chromium.launch({ channel: 'msedge', headless: true, args: ['--no-proxy-server'] });
const ctx = await browser.newContext({ viewport: { width: 1280, height: 800 }, deviceScaleFactor: 2 });
const page = await ctx.newPage();

// xxl-job 登录拿 token
const loginResp = await ctx.request.post('http://127.0.0.1:8080/auth/doLogin', {
  form: { userName: 'admin', password: '123456' },
});
const tokenRaw = loginResp.headers()['set-cookie'] || '';
const m = tokenRaw.match(/xxl_job_login_token=([^;]+)/);
if (m) {
  await ctx.addCookies([{ name: 'xxl_job_login_token', value: m[1], domain: '127.0.0.1', path: '/' }]);
  console.log('xxl-job cookie 注入成功');
} else {
  console.log('xxl-job cookie 未取到：', tokenRaw);
}

for (const t of targets) {
  try {
    const resp = await page.goto(t.url, { waitUntil: 'load', timeout: 25000 });
    await page.waitForTimeout(t.wait);
    const file = path.join(OUT, t.name + '.png');
    await page.screenshot({ path: file, fullPage: false });
    const title = await page.title();
    console.log(`OK  ${t.name}  HTTP=${resp ? resp.status() : '-'}  title=${title}`);
  } catch (e) {
    console.log(`ERR ${t.name}  ${e.message.split('\n')[0]}`);
  }
}

await browser.close();
console.log('截图目录：' + OUT);
