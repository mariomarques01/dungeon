const {chromium}=require('playwright-core');const assert=require('node:assert/strict');const fs=require('node:fs');
const out=process.env.SCREENSHOT_DIR||'artifacts/mutable';fs.mkdirSync(out,{recursive:true});
const base=process.env.DUNGEON_URL||'http://127.0.0.1:8766/godot/';
const sleep=ms=>new Promise(r=>setTimeout(r,ms));
(async()=>{
 const browser=await chromium.launch({executablePath:process.env.CHROMIUM_PATH||'/usr/bin/chromium',headless:true,args:['--no-sandbox','--enable-unsafe-swiftshader']});
 const errors=[];
 async function open(options={}){const context=await browser.newContext(options);const p=await context.newPage();p.on('pageerror',e=>errors.push(e.message));p.on('console',m=>{if(m.type()==='error'&&!m.text().includes('favicon'))errors.push(m.text())});const url=new URL(base);url.searchParams.set('qa','1');url.searchParams.set('server',process.env.ROOM_URL||'ws://127.0.0.1:9080');await p.goto(url.href);await p.waitForFunction(()=>window.dungeonArena,null,{timeout:120000});return p}
 const state=p=>p.evaluate(()=>window.dungeonArena);
 async function coords(p,x,y,logical=true){return p.evaluate(({x,y,logical})=>{const s=window.dungeonArena,c=document.getElementById('canvas').getBoundingClientRect();if(logical){x=s.board[0]+x*s.board[2];y=s.board[1]+y*s.board[2]}return {x:c.left+x/s.viewport[0]*c.width,y:c.top+y/s.viewport[1]*c.height}},{x,y,logical})}
 async function tap(p,x,y,touch=false,logical=true){const q=await coords(p,x,y,logical);if(touch)await p.touchscreen.tap(q.x,q.y);else await p.mouse.click(q.x,q.y);await sleep(150)}
 async function button(p,prefix,touch=false){const s=await state(p),b=s.buttons.find(b=>b.text.startsWith(prefix));assert(b,'button '+prefix);await tap(p,b.rect[0]+b.rect[2]/2,b.rect[1]+b.rect[3]/2,touch,false)}
 async function shot(p,n){await p.screenshot({path:out+'/'+n+'.png'})}
 const p=await open({viewport:{width:1280,height:800}});await shot(p,'desktop-home');await button(p,'JOGAR');await p.waitForFunction(()=>window.dungeonArena.mode==='practice');
 await tap(p,110,1080);assert.equal((await state(p)).selected,0);await tap(p,360,350);assert.equal((await state(p)).state.casts[0],0,'invalid summon keeps resources');
 await tap(p,260,550);assert.equal((await state(p)).state.casts[0],1);assert((await state(p)).state.units.some(u=>u.side===0&&u.id==='golem'));
 await tap(p,258,1080);await tap(p,290,625);assert.equal((await state(p)).state.casts[0],2);await shot(p,'desktop-battle');
 await tap(p,650,940);await tap(p,400,400);assert((await state(p)).state.cooldowns[0]>20);
 await tap(p,675,50);await button(p,'CONTINUAR');await sleep(100);assert.equal((await state(p)).mode,'practice');
 await p.setViewportSize({width:720,height:1280});await sleep(300);await shot(p,'approved-composition');
 await p.setViewportSize({width:844,height:390});await sleep(300);const rotated=await state(p);assert(rotated.state.casts[0]===2,'rotation keeps battle');assert(rotated.board[0]>=0&&rotated.board[1]>=0,'arena fits without clipping');await shot(p,'landscape');console.log('PASS desktop, rotation, ability, pause');await p.close();
 const mobile=await open({viewport:{width:390,height:844},deviceScaleFactor:3,isMobile:true,hasTouch:true});await button(mobile,'JOGAR',true);await tap(mobile,110,1080,true);await tap(mobile,260,550,true);assert.equal((await state(mobile)).state.casts[0],1,'real mobile touch summons once');await shot(mobile,'mobile-battle');console.log('PASS mobile DPR3 summon');
 await tap(mobile,675,50,true);await button(mobile,'SAIR',true);await button(mobile,'MODO CLÁSSICO',true);await mobile.waitForFunction(()=>window.__dungeonState,{timeout:30000});
 const old=await mobile.evaluate(()=>window.__dungeonState);const back=old.buttons.find(b=>b.id==='arena');assert(back,'classic has return to arena');const cp=await mobile.evaluate(r=>{const s=window.__dungeonState,c=document.getElementById('canvas').getBoundingClientRect();return{x:c.left+(s.transform.x+(r.x+r.w/2)*s.transform.scale)*c.width/document.getElementById('canvas').width,y:c.top+(s.transform.y+(r.y+r.h/2)*s.transform.scale)*c.height/document.getElementById('canvas').height}},back.rect);await mobile.touchscreen.tap(cp.x,cp.y);await mobile.waitForFunction(()=>window.dungeonArena.mode==='home');await button(mobile,'JOGAR',true);await tap(mobile,110,1080,true);await tap(mobile,260,550,true);assert.equal((await state(mobile)).state.casts[0],1,'touch works after classic roundtrip');console.log('PASS classic roundtrip');await mobile.close();
 const a=await open({viewport:{width:720,height:1280}}),b=await open({viewport:{width:720,height:1280}});
 await button(a,'DUELO PvP');await button(a,'CRIAR');await a.waitForFunction(()=>window.dungeonArena.mode==='waiting');const code=(await state(a)).room;console.log('PASS room created',code);
 await button(b,'DUELO PvP');let inp=(await state(b)).inputs.find(i=>i.placeholder==='Código da sala');await tap(b,inp.rect[0]+50,inp.rect[1]+25,false,false);await b.keyboard.type(code);await button(b,'ENTRAR');await a.waitForFunction(()=>window.dungeonArena.mode==='online');await b.waitForFunction(()=>window.dungeonArena.mode==='online');assert.equal((await state(b)).side,1);
 await tap(a,110,1080);await tap(a,260,550);await b.waitForFunction(()=>window.dungeonArena.state.casts[0]===1);
 await tap(b,110,1080);await tap(b,260,550);await a.waitForFunction(()=>window.dungeonArena.state.casts[1]===1);await shot(a,'pvp-player-one');await shot(b,'pvp-player-two');
 await b.close();await a.waitForFunction(()=>window.dungeonArena.state.winner===0);await sleep(200);assert((await state(a)).buttons.some(b=>b.text==='JOGAR NOVAMENTE'));await shot(a,'pvp-disconnect-result');
 assert.deepEqual(errors,[]);console.log('MUTABLE_BROWSER_OK desktop, mobile DPR3, invalid/legal actions, ability, pause, rotation, classic roundtrip, two browser PvP clients, disconnect reward');
 await browser.close();
})().catch(e=>{console.error(e);process.exit(1)});
