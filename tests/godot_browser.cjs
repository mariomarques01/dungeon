const {chromium}=require('playwright-core');
const assert=require('node:assert/strict');
const path=require('node:path');
const fs=require('node:fs');
const output=process.env.SCREENSHOT_DIR||path.resolve('artifacts/browser-v2');
fs.mkdirSync(output,{recursive:true});
const cards=JSON.parse(fs.readFileSync(path.resolve(__dirname,'../godot/assets/cards.json'),'utf8'));
(async()=>{
 const browser=await chromium.launch({executablePath:process.env.CHROMIUM_PATH||'/usr/bin/chromium',headless:true,args:['--no-sandbox','--enable-unsafe-swiftshader']});
 const page=await browser.newPage({viewport:{width:390,height:740},hasTouch:true});
 const errors=[];
 page.on('pageerror',e=>errors.push(e.message));
 page.on('console',m=>{if(m.type()==='error')errors.push(m.text())});
 const url=new URL(process.env.DUNGEON_URL||'http://127.0.0.1:8765/godot/');url.searchParams.set('qa','1');
 const seed={deck:['sword','fire','shield','lightning','heal','spark','ice','water','earth','storm','ember','blade'],coins:50,xp:35,wins:1,losses:0,stage:1};
 await page.addInitScript(profile=>{if(!localStorage.getItem('test_seeded')){localStorage.setItem('dungeon_cards_v15',JSON.stringify(profile));localStorage.setItem('dungeon_sound','on');localStorage.setItem('dungeon_battle_speed','1');localStorage.setItem('test_seeded','1')}},seed);
 await page.goto(url.href,{waitUntil:'networkidle',timeout:120000});
 await page.waitForFunction(()=>window.__dungeonState,null,{timeout:60000});
 const state=()=>page.evaluate(()=>window.__dungeonState);
 const tap=async(x,y)=>{const s=await state();await page.mouse.click(x,y+(s.screen==='battle'?20:0));await page.waitForTimeout(70)};
 const idle=()=>page.waitForFunction(()=>!window.__dungeonState.busy,null,{timeout:12000});
 const shot=async(name)=>{const s=await state();await page.screenshot({path:path.join(output,name+'.png'),...(s.screen==='battle'?{clip:{x:0,y:20,width:390,height:700}}:{})})};
 await shot('home');
 await tap(270,500);await tap(190,410);await shot('credits');assert.equal((await state()).panel,'credits');await tap(337,75);
 await tap(190,440);await tap(300,593);await tap(65,440);
 const edited=await page.evaluate(()=>JSON.parse(localStorage.getItem('dungeon_cards_v15')));
 assert(edited.deck.includes('meteor'));assert(!edited.deck.includes('sword'));assert.equal(edited.deck.length,12);
 await shot('deck');await tap(337,75);await tap(190,560);
 await page.waitForFunction(()=>window.__dungeonState.screen==='battle');
 assert((await state()).musicPlaying,'Orchestral score should start after the battle gesture');
 await shot('battle');
 // Select a real damaging card; avoid freeze here so the defense test gets an enemy attack.
 let before=await state();let index=before.hand.findIndex(id=>cards[id].damage&&!cards[id].freeze&&cards[id].cost<=before.energy);
 while(index<0){await tap(190,676);await idle();before=await state();index=before.hand.findIndex(id=>cards[id].damage&&!cards[id].freeze&&cards[id].cost<=before.energy)}
 const id=before.hand[index],card=cards[id];
 await tap(43+index*76,585);
 await tap(43+index*76,585);await tap(190,676);
 let charging=await state();assert(charging.busy);assert.equal(charging.energy,before.energy-card.cost);assert.equal(charging.round,before.round);assert.equal(charging.enemy,before.enemy,'No damage before impact');assert.equal(charging.hand.length,before.hand.length-1,'Repeated clicks must not spend another card');
 await page.waitForFunction(()=>window.__dungeonState.animationTime>=0.42&&window.__dungeonState.animationTime<0.9);await shot('empower');
 await page.waitForFunction(()=>window.__dungeonState.animationTime>=0.8&&window.__dungeonState.animationTime<1.05);await shot('release');
 await page.waitForFunction(hp=>window.__dungeonState.enemy<hp,before.enemy);await shot('impact');await idle();
 let after=await state();assert.equal(after.enemy,Math.max(0,before.enemy-card.damage));assert(after.audio.some(e=>e.kind===({sword:'steel',storm:'storm'}[card.art]||card.art)));assert(after.audio.some(e=>e.kind==='charge'));
 // Replenish mana and find a defense card through normal turns.
 await tap(190,676);await idle();let defended=await state();index=defended.hand.findIndex(id=>cards[id].block&&cards[id].cost<=defended.energy);
 for(let tries=0;index<0&&tries<3;tries++){await tap(190,676);await idle();defended=await state();index=defended.hand.findIndex(id=>cards[id].block&&cards[id].cost<=defended.energy)}
 assert(index>=0,'A defense card should be drawn');const guard=cards[defended.hand[index]];
 await tap(43+index*76,585);await page.waitForFunction(()=>window.__dungeonState.animationTime>1.1);await shot('defense');await idle();
 defended=await state();assert.equal(defended.heroShield,guard.block);
 await tap(190,676);await idle();after=await state();assert(after.hero<=defended.hero);assert.equal(after.heroShield,0);assert.equal(after.round,defended.round+1);
 if(!defended.freeze){const blocks=after.visualEvents.filter(e=>!e.enemy&&e.reaction==='block');assert(blocks.length>0,'Enemy hit should produce a block effect')}
 // Verify audio control pauses the actual music stream, then accelerate the remaining battle.
 await tap(50,489);assert.equal((await state()).sound,false);assert.equal((await state()).musicPlaying,false);await tap(50,489);assert((await state()).musicPlaying);
 await tap(345,489);await tap(345,489);assert.equal((await state()).speed,2);
 for(let round=0;round<10;round++){
  let s=await state();if(s.done)break;
  for(let plays=0;plays<5;plays++){
   s=await state();if(s.done)break;
   const i=s.hand.findIndex(id=>cards[id].cost<=s.energy&&(cards[id].damage||cards[id].block||(cards[id].heal&&s.hero<90)));
   if(i<0)break;await tap(43+i*76,585);await idle();
  }
  if(!(await state()).done){await tap(190,676);await idle()}
 }
 const result=await state();assert(result.done);assert(result.profile.xp>35);assert(result.profile.coins>50);await shot('result');
 await tap(190,500);await page.reload({waitUntil:'networkidle'});await page.waitForFunction(()=>window.__dungeonState);
 assert.deepEqual((await state()).profile,result.profile,'Deck and rewards must survive a reload');
 await page.setViewportSize({width:390,height:844});await page.waitForTimeout(120);await page.screenshot({path:path.join(output,'tall.png')});
 await page.setViewportSize({width:1024,height:768});await page.waitForTimeout(120);await page.screenshot({path:path.join(output,'desktop.png')});
 console.log(JSON.stringify({result:result.profile,errors,attack:id,defense:guard.name}));await browser.close();assert.equal(errors.length,0);
})();
