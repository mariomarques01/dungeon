const {chromium}=require('playwright-core');
const assert=require('node:assert/strict');
const path=require('node:path');

(async()=>{
 const browser=await chromium.launch({executablePath:process.env.CHROMIUM_PATH||'/usr/bin/chromium',args:['--no-sandbox','--enable-unsafe-swiftshader']});
 try {
  const page=await browser.newPage({viewport:{width:390,height:844},deviceScaleFactor:1,hasTouch:true,isMobile:true});
  const url=new URL(process.env.DUNGEON_URL||'http://localhost:8766/godot/');
  url.searchParams.set('qa','1');url.searchParams.set('seed','69');
  await page.goto(url.href);
  await page.waitForFunction(()=>window.__dungeonState?.screen==='home');
  const manifest=await page.evaluate(async()=> (await fetch(document.querySelector('link[rel=manifest]').href)).json());
  assert.equal(manifest.display,'fullscreen');
  async function tapButton(id){
   const p=await page.evaluate(id=>{
    const s=window.__dungeonState,r=s.buttons.find(b=>b.id===id).rect;
    return {x:s.transform.x+(r.x+r.w/2)*s.transform.scale,y:s.transform.y+(r.y+r.h/2)*s.transform.scale};
   },id);
   await page.touchscreen.tap(p.x,p.y);
  }
  await tapButton('start');
  await page.waitForFunction(()=>window.__dungeonState?.screen==='battle');
  await page.waitForTimeout(800);
  const buttons=await page.evaluate(()=>window.__dungeonState.buttons);
  const gear=buttons.find(b=>b.id==='settings').rect,help=buttons.find(b=>b.id==='help').rect;
  assert(help.y>=gear.y+gear.h);
  assert(await page.evaluate(()=>window.__dungeonState.tutorial));
  const points=await page.evaluate(()=>{
   const s=window.__dungeonState;
   const center=r=>({x:s.transform.x+(r.x+r.w/2)*s.transform.scale,y:s.transform.y+(r.y+r.h/2)*s.transform.scale});
   return [center(s.handViews.find(h=>['scout','stoneguard'].includes(h.id)).rect),center(s.drop)];
  });
  for(const p of points)await page.touchscreen.tap(p.x,p.y);
  await page.waitForFunction(()=>!window.__dungeonState.tutorial && window.__dungeonState.players[0].board.length===1);
  await tapButton('help');
  await page.waitForFunction(()=>window.__dungeonState.tutorial);
  await page.waitForFunction(()=>{const s=window.__dungeonState;return !s.busy && !s.toast && s.players[0].mana>=1 && Object.keys(s.players[0].cooldowns).length===0;});
  await page.waitForTimeout(200);
  await page.screenshot({path:process.env.HUD_CAPTURE||path.resolve('/tmp/tavern-hud-390x844.png')});
  await page.evaluate(()=>{document.documentElement.style.setProperty('--safe-top','30px');document.documentElement.style.setProperty('--safe-bottom','20px');});
  await page.setViewportSize({width:391,height:844});
  await page.waitForFunction(()=>window.__dungeonState.transform.y>=29);
  assert(await page.evaluate(()=>document.querySelector('canvas').getBoundingClientRect().height>=844));
  await page.reload();
  await page.waitForFunction(()=>window.__dungeonState?.screen==='home');
  await tapButton('start');
  await page.waitForFunction(()=>window.__dungeonState?.screen==='battle');
  assert.equal(await page.evaluate(()=>window.__dungeonState.tutorial),false);
 } finally {await browser.close();}
})().catch(e=>{console.error(e);process.exitCode=1;});
