const {chromium}=require('playwright-core');
const assert=require('node:assert/strict');const fs=require('node:fs');const path=require('node:path');
const cards=JSON.parse(fs.readFileSync(path.resolve(__dirname,'../godot/tavern_assets/cards.json'),'utf8'));
const out=process.env.SCREENSHOT_DIR||path.resolve('artifacts/tavern');fs.mkdirSync(out,{recursive:true});
const sleep=ms=>new Promise(r=>setTimeout(r,ms));
(async()=>{
 const browser=await chromium.launch({executablePath:process.env.CHROMIUM_PATH||'/usr/bin/chromium',headless:true,args:['--no-sandbox','--enable-unsafe-swiftshader']});
 const page=await browser.newPage({viewport:{width:1280,height:800}});const errors=[];
 page.on('pageerror',e=>errors.push(e.message));page.on('console',m=>{if(m.type()==='error')errors.push(m.text())});
 const url=new URL(process.env.DUNGEON_URL||'http://127.0.0.1:8766/godot/');url.searchParams.set('qa','1');url.searchParams.set('mode','classic');
 const initial={deck:['scout','scout','stoneguard','stoneguard','wolf','wolf','apprentice','apprentice','drake','drake','shieldbearer','shieldbearer','dryad','dryad','bolt','bolt','healing','healing','frost','frost','blessing','blessing','barrier','barrier','rune_blade','rune_blade','crystal','crystal','wisdom','wisdom'],coins:50,xp:35,wins:1,losses:0};
 await page.addInitScript(profile=>{if(!localStorage.getItem('tavern_test_seed')){localStorage.setItem('dungeon_tavern_v3',JSON.stringify(profile));localStorage.setItem('dungeon_battle_speed','2');localStorage.setItem('dungeon_sound','on');localStorage.setItem('tavern_test_seed','1')}},initial);
 await page.goto(url.href,{waitUntil:'networkidle',timeout:120000});await page.waitForFunction(()=>window.__dungeonState,null,{timeout:60000});
 const state=()=>page.evaluate(()=>window.__dungeonState);
 const point=(s,p)=>({x:s.transform.x+p.x*s.transform.scale,y:s.transform.y+p.y*s.transform.scale});
 const center=r=>({x:r.x+r.w/2,y:r.y+r.h/2});
 const click=async id=>{const s=await state();const b=s.buttons.find(b=>b.id===id&&b.enabled);assert(b,`Button ${id} should be enabled`);const p=point(s,center(b.rect));await page.mouse.click(p.x,p.y);await sleep(100)};
 const idle=()=>page.waitForFunction(()=>!window.__dungeonState.busy,null,{timeout:12000});
 const mine=()=>page.waitForFunction(()=>window.__dungeonState.done||(window.__dungeonState.active===0&&!window.__dungeonState.busy),null,{timeout:45000});
 const shot=name=>page.screenshot({path:path.join(out,name+'.png')});
 const targetPoint=(s,t)=>center(t.hero?s.heroes[t.side]:s.unitViews.find(u=>u.uid===t.uid).rect);
 const cardPoint=(s,index)=>{const v=s.handViews[index],r=v.rect;const x=-r.w/2+23,y=-r.h/2+64;return {x:r.x+r.w/2+x*Math.cos(v.angle)-y*Math.sin(v.angle),y:r.y+r.h/2+x*Math.sin(v.angle)+y*Math.cos(v.angle)}};
 const drag=async(from,to,screenshot)=>{let s=await state();let a=point(s,from),b=point(s,to);await page.mouse.move(a.x,a.y);await page.mouse.down();await sleep(45);await page.mouse.move(b.x,b.y,{steps:18});await sleep(70);if(screenshot)await shot(screenshot);await page.mouse.up();await sleep(90);if(screenshot){const a=(await state()).animation;if(a&&a.kind){await shot(screenshot+'-cast');await sleep(160);await shot(screenshot+'-impact')}}await idle()};
 await shot('home');await click('collection');await shot('collection');let library=await state();let entry=library.collection.find(c=>library.profile.deck.includes(c.id));let q=point(library,{x:entry.rect.x+entry.rect.w/2,y:entry.rect.y+entry.rect.h+14});await page.mouse.click(q.x,q.y);await sleep(100);assert.equal((await state()).profile.deck.length,29);q=point(await state(),{x:entry.rect.x+entry.rect.w/2,y:entry.rect.y+70});await page.mouse.click(q.x,q.y);await sleep(100);assert.equal((await state()).profile.deck.length,30);await click('home');await click('start');await mine();await shot('opening');
 let s=await state();let index=s.players[0].hand.findIndex(id=>cards[id].kind==='minion'&&cards[id].cost===1);assert(index>=0);
 let before=JSON.parse(JSON.stringify(s));const cheap=s.players[0].hand[index];
 await drag(cardPoint(s,index),{x:20,y:250},'invalid-drag');s=await state();assert.equal(s.players[0].hand.length,before.players[0].hand.length);assert.equal(s.players[0].mana,1);assert.equal(s.players[0].board.length,0);
 index=s.players[0].hand.indexOf(cheap);await drag(cardPoint(s,index),center(s.drop),'summoning-drag');s=await state();
 assert.equal(s.players[0].mana,0);assert.equal(s.players[0].board.length,1);assert.equal(s.players[0].hand.length,3);assert.equal(s.players[0].board[0].attacks,0);assert(s.audioHistory.some(e=>e.kind==='card_soft'));assert(!s.audioHistory.some(e=>e.kind==='charge'));assert(s.effectHistory.some(e=>e.phase==='cast'&&e.id===cheap));await shot('summoned');
 let own=s.players[0].board[0],view=s.unitViews.find(u=>u.uid===own.uid);before=JSON.parse(JSON.stringify(s));
 await drag(center(view.rect),center(s.heroes[1]));s=await state();assert.equal(s.players[1].health,30,'Summoning sickness must prevent an immediate attack');assert.equal(s.turn,before.turn);
 await click('end');await mine();s=await state();assert.equal(s.players[0].max_mana,2);assert.equal(s.players[0].mana,2);assert(s.players[1].board.length>0);own=s.players[0].board.find(u=>u.uid===own.uid);assert.equal(own.attacks,1);
 const enemy=s.players[1].board.find(u=>u.keywords.includes('taunt'))||s.players[1].board[0];view=s.unitViews.find(u=>u.uid===own.uid);before=JSON.parse(JSON.stringify(s));
 await drag(center(view.rect),targetPoint(s,{side:1,uid:enemy.uid}),'attack-arrow');s=await state();
 const remaining=s.players[0].board.find(u=>u.uid===own.uid);assert(!remaining||remaining.attacks===0);const damaged=s.players[1].board.find(u=>u.uid===enemy.uid);assert(enemy.shield?damaged&&!damaged.shield:!damaged||damaged.health===enemy.health-own.attack);await shot('combat');
 let spellPlayed=false,creaturesPlayed=1,attacks=1;
 function spellTarget(s,c){
  const rule=c.target||'none';
  if(rule==='none')return null;
  if(rule==='enemy')return {side:1,hero:true};
  if(rule==='enemy_minion'){const u=s.players[1].board[0];return u?{side:1,uid:u.uid}:undefined}
  if(rule==='friendly'){if(c.effect==='heal'&&s.players[0].health===30)return undefined;return {side:0,hero:true}}
  if(rule==='friendly_minion'){const u=s.players[0].board.find(u=>u.health>0);return u?{side:0,uid:u.uid}:undefined}
 }
 // Play only through pointer gestures, using real mana/targets. No engine state injection.
 for(let turns=0;turns<38;turns++){
  await mine();s=await state();if(s.done)break;
  for(let actions=0;actions<16;actions++){
   s=await state();if(s.done)break;
   let choice=-1,target;
   for(let i=0;i<s.players[0].hand.length;i++){
    const c=cards[s.players[0].hand[i]];if(c.cost>s.players[0].mana)continue;
    if(c.kind==='minion'){if(s.players[0].board.length<7){choice=i;target=null;break}continue}
    const t=spellTarget(s,c);if(t===undefined)continue;if(c.effect==='armor'&&s.players[0].armor>10)continue;
    choice=i;target=t;break;
   }
   if(choice<0)break;
   const c=cards[s.players[0].hand[choice]],mana=s.players[0].mana,count=s.players[0].hand.length;
   const destination=c.kind==='minion'?center(s.drop):target?targetPoint(s,target):{x:s.logical.x/2,y:s.logical.y*0.45};
   await drag(cardPoint(s,choice),destination,c.kind==='spell'&&!spellPlayed?'spell-target':undefined);
   const after=await state();assert(after.busy===false);assert(after.players[0].mana<=10);assert(after.players[0].hand.length!==count||c.effect==='draw'||c.effect==='weaken','A released legal card should resolve: '+JSON.stringify({card:c.id||c.name,choice,mana,count,hand:after.players[0].hand,afterMana:after.players[0].mana,toast:after.toast,turn:after.turn,active:after.active}));
   if(c.kind==='spell'){spellPlayed=true;if(!fs.existsSync(path.join(out,'spell-impact.png')))await shot('spell-impact')}else creaturesPlayed++;
   if(!fs.existsSync(path.join(out,'populated-board.png'))&&after.players[0].board.length>=3)await shot('populated-board');
  }
  for(let a=0;a<16;a++){
   s=await state();if(s.done)break;
   const unit=s.players[0].board.find(u=>u.attacks>0&&u.attack>0);if(!unit)break;
   const guards=s.players[1].board.filter(u=>u.keywords.includes('taunt'));
   const victim=guards[0]||s.players[1].board.find(u=>u.health<=unit.attack&&!u.shield);
   let target=victim?{side:1,uid:victim.uid}:{side:1,hero:true};
   if(unit.sleeping&&!unit.keywords.includes('charge')&&target.hero){const u=s.players[1].board[0];if(!u)break;target={side:1,uid:u.uid}}
   await drag(targetPoint(s,{side:0,uid:unit.uid}),targetPoint(s,target));attacks++;
  }
  s=await state();if(!s.done)await click('end');
 }
 await mine();s=await state();assert(s.done,'Complete match should end');assert(spellPlayed,'A spell should have been dragged and resolved');assert(creaturesPlayed>1&&attacks>1);assert(s.profile.coins>50&&s.profile.xp>35);await shot('result');
 const saved=s.profile;await click('home');await page.reload({waitUntil:'networkidle'});await page.waitForFunction(()=>window.__dungeonState);assert.deepEqual((await state()).profile,saved);
 // Touch-only mobile drag: one finger, no synthetic mouse fallback.
 const mobile=await browser.newPage({viewport:{width:390,height:844},hasTouch:true,isMobile:true});mobile.on('pageerror',e=>errors.push(e.message));mobile.on('console',m=>{if(m.type()==='error')errors.push(m.text())});
 await mobile.addInitScript(p=>{localStorage.setItem('dungeon_tavern_v3',JSON.stringify(p));localStorage.setItem('dungeon_sound','off')},initial);
 await mobile.goto(url.href,{waitUntil:'networkidle',timeout:120000});await mobile.waitForFunction(()=>window.__dungeonState);
 let m=await mobile.evaluate(()=>window.__dungeonState);let b=m.buttons.find(b=>b.id==='start');let p=point(m,center(b.rect));await mobile.touchscreen.tap(p.x,p.y);await mobile.waitForFunction(()=>window.__dungeonState.screen==='battle');m=await mobile.evaluate(()=>window.__dungeonState);
 index=m.players[0].hand.findIndex(id=>cards[id].kind==='minion'&&cards[id].cost===1);assert(index>=0);
 const start=point(m,cardPoint(m,index)),end=point(m,center(m.drop));const cdp=await mobile.context().newCDPSession(mobile);
 await cdp.send('Input.dispatchTouchEvent',{type:'touchStart',touchPoints:[{x:start.x,y:start.y}]});
 for(let step=1;step<=18;step++){await cdp.send('Input.dispatchTouchEvent',{type:'touchMove',touchPoints:[{x:start.x+(end.x-start.x)*step/18,y:start.y+(end.y-start.y)*step/18}]});await sleep(15)}
 await mobile.screenshot({path:path.join(out,'mobile-touch-drag.png')});await cdp.send('Input.dispatchTouchEvent',{type:'touchEnd',touchPoints:[]});await mobile.waitForFunction(()=>window.__dungeonState.players[0].board.length===1&&!window.__dungeonState.busy);
 m=await mobile.evaluate(()=>window.__dungeonState);assert.equal(m.players[0].mana,0);assert.equal(m.players[0].hand.length,3);await mobile.screenshot({path:path.join(out,'mobile-board.png')});
 console.log(JSON.stringify({outcome:s.outcome,profile:saved,creaturesPlayed,attacks,spellPlayed,touchDrag:true,errors}));await browser.close();assert.equal(errors.length,0);
})();
