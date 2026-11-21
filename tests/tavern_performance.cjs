const { chromium } = require('playwright-core');

(async () => {
  const browser = await chromium.launch({
    executablePath: process.env.CHROMIUM_PATH || '/usr/bin/chromium',
    args: ['--no-sandbox', '--enable-unsafe-swiftshader'],
  });
  try {
    const page = await browser.newPage({
      viewport: { width: 390, height: 844 }, deviceScaleFactor: 1, isMobile: true, hasTouch: true,
    });
    const session = await page.context().newCDPSession(page);
    await session.send('Emulation.setCPUThrottlingRate', { rate: 4 });
    const url = new URL(process.env.DUNGEON_URL || 'http://localhost:8766/godot/');
    url.searchParams.set('qa', '1');
    url.searchParams.set('seed', '69');
    await page.goto(url.href);
    await page.waitForFunction(() => window.__dungeonState?.screen === 'home', null, { timeout: 120000 });
    async function tapRect(getRect) {
      const rect = await page.evaluate(getRect);
      const { scale, x, y } = await page.evaluate(() => window.__dungeonState.transform);
      await page.touchscreen.tap(x + (rect.x + rect.w / 2) * scale, y + (rect.y + rect.h / 2) * scale);
    }
    await tapRect(() => window.__dungeonState.buttons.find(b => b.id === 'start').rect);
    await page.waitForFunction(() => window.__dungeonState?.screen === 'battle');
    await page.waitForTimeout(700);
    await tapRect(() => window.__dungeonState.handViews.find(h => ['scout','skeleton','stoneguard'].includes(h.id)).rect);
    await tapRect(() => window.__dungeonState.drop);
    await page.waitForFunction(() => window.__dungeonState.players[0].board.length > 0);
    await page.waitForTimeout(1500);
    const result = await page.evaluate(() => new Promise(resolve => {
      const intervals = [];
      let start, previous, second, count = 0, minimum = Infinity;
      function frame(time) {
        if (start === undefined) {
          start = previous = second = time;
        } else {
          intervals.push(time - previous);
          previous = time;
          count++;
          if (time - second >= 1000) {
            minimum = Math.min(minimum, 1000 * count / (time - second));
            count = 0;
            second = time;
          }
        }
        if (time - start < 12000) return requestAnimationFrame(frame);
        intervals.sort((a,b) => a-b);
        resolve({ frames: intervals.length, fps: 1000 * intervals.length / (time - start),
          minOneSecondFps: minimum, p95FrameMs: intervals[Math.floor(intervals.length * 0.95)] });
      }
      requestAnimationFrame(frame);
    }));
    console.log(JSON.stringify(result));
  } finally {
    await browser.close();
  }
})().catch(error => { console.error(error); process.exitCode = 1; });
