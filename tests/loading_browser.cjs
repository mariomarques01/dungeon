const { chromium } = require('playwright-core');
const assert = require('node:assert/strict');
(async () => {
  const browser = await chromium.launch({executablePath:'/usr/bin/chromium', headless:true,
    args:['--no-sandbox','--enable-unsafe-swiftshader']});
  const context = await browser.newContext({viewport:{width:390,height:844},deviceScaleFactor:3,isMobile:true,hasTouch:true});
  const page = await context.newPage();
  const errors = [];
  page.on('pageerror', e => errors.push(e.message));
  const session = await context.newCDPSession(page);
  await session.send('Network.enable');
  await session.send('Network.setCacheDisabled', {cacheDisabled:true});
  let downloads = [];
  session.on('Network.requestWillBeSent', e => {
    if (/\.(wasm|pck)$/.test(e.request.url)) downloads.push(e.request.url);
  });
  const url = new URL(process.env.DUNGEON_URL || 'http://127.0.0.1:8766/godot/');
  url.searchParams.set('qa','1');url.searchParams.set('mode','classic');
  const start = Date.now();
  await page.goto(url.href,{waitUntil:'domcontentloaded'});
  await page.waitForFunction(()=>window.__dungeonState,null,{timeout:120000});
  const coldMs = Date.now()-start;
  console.log('First mobile load:', coldMs, 'ms');
  assert.equal(downloads.length,2,'First visit downloads pack and runtime');
  await page.evaluate(()=>window.dungeonDownloadsReady);
  console.log('Persistent downloads saved');
  downloads=[];
  const warm = Date.now();
  await page.reload({waitUntil:'domcontentloaded'});
  await page.waitForFunction(()=>window.__dungeonState,null,{timeout:120000});
  assert.equal(downloads.length,0,'Reopening reuses persistent downloads even with HTTP cache disabled');
  const warmMs=Date.now()-warm;
  console.log('Cached mobile load:',warmMs,'ms');
  const tap = async id => {
    const p = await page.evaluate(id=>{
      const s=window.__dungeonState, r=s.buttons.find(b=>b.id===id).rect, t=s.transform;
      // Godot draws in device pixels; browser touch positions use CSS pixels.
      const canvas=document.getElementById('canvas'), c=canvas.getBoundingClientRect();
      return {x:c.left+(t.x+(r.x+r.w/2)*t.scale)*c.width/canvas.width,
              y:c.top+(t.y+(r.y+r.h/2)*t.scale)*c.height/canvas.height};
    },id);
    await page.touchscreen.tap(p.x,p.y);
    await page.waitForTimeout(150);
  };
  await tap('collection');
  await page.waitForFunction(()=>window.__dungeonState.screen==='collection');
  await tap('home');
  await tap('start');
  await page.waitForFunction(()=>window.__dungeonState.screen==='battle');
  const gesture = await page.evaluate(()=>{
    const s=window.__dungeonState,c=document.getElementById('canvas'),r=c.getBoundingClientRect(),t=s.transform;
    const point=p=>({x:r.left+(t.x+p.x*t.scale)*r.width/c.width,y:r.top+(t.y+p.y*t.scale)*r.height/c.height});
    const v=s.handViews.find(v=>['scout','stoneguard','skeleton'].includes(v.id));
    return {from:point({x:v.rect.x+23,y:v.rect.y+65}),to:point({x:s.drop.x+s.drop.w/2,y:s.drop.y+s.drop.h/2})};
  });
  await session.send('Input.dispatchTouchEvent',{type:'touchStart',touchPoints:[gesture.from]});
  for(let step=1;step<=18;step++){
    await session.send('Input.dispatchTouchEvent',{type:'touchMove',touchPoints:[{
      x:gesture.from.x+(gesture.to.x-gesture.from.x)*step/18,
      y:gesture.from.y+(gesture.to.y-gesture.from.y)*step/18}]});
    await page.waitForTimeout(15);
  }
  await session.send('Input.dispatchTouchEvent',{type:'touchEnd',touchPoints:[]});
  await page.waitForFunction(()=>window.__dungeonState.players[0].board.length===1&&!window.__dungeonState.busy);
  await page.screenshot({path:'/tmp/dungeon-browser/loading-mobile.png'});
  const beforeRotation=await page.evaluate(()=>({health:window.__dungeonState.players[0].health,hand:window.__dungeonState.players[0].hand}));
  await page.setViewportSize({width:844,height:390});
  await page.waitForFunction(()=>Math.abs(window.__dungeonState.logical.x/window.__dungeonState.logical.y-844/390)<0.01);
  let rotated=await page.evaluate(()=>window.__dungeonState);
  assert(Math.abs(rotated.transform.x)<1 && Math.abs(rotated.transform.y)<1,'Landscape should fill the available canvas');
  assert.deepEqual({health:rotated.players[0].health,hand:rotated.players[0].hand},beforeRotation,'Rotation preserves the match');
  for(const card of rotated.handViews)assert(card.rect.y+card.rect.h<=rotated.logical.y+10,'Hand stays on screen in landscape');
  await tap('settings');await page.waitForFunction(()=>window.__dungeonState.panel==='settings');
  await tap('close');await page.waitForFunction(()=>window.__dungeonState.panel==='');
  await page.screenshot({path:'/tmp/dungeon-browser/loading-landscape.png'});
  await page.setViewportSize({width:390,height:844});
  await page.waitForFunction(()=>window.__dungeonState.logical.y>window.__dungeonState.logical.x);
  assert.equal(errors.length,0);
  // Storage denial must fall back to regular fetch and still open the game.
  await page.addInitScript(()=>{CacheStorage.prototype.open=()=>Promise.reject(new Error('Storage unavailable'))});
  await page.reload({waitUntil:'domcontentloaded'});
  await page.waitForFunction(()=>window.__dungeonState,null,{timeout:120000});
  assert.equal(errors.length,0);
  console.log(JSON.stringify({coldMs,warmMs,warmLargeDownloads:0,retinaTouchMenu:true,touchDrag:true,rotation:true,storageFallback:true,errors}));
  await browser.close();
})().catch(e=>{console.error(e);process.exit(1)});
