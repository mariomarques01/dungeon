const {chromium}=require('playwright-core');const assert=require('node:assert');
const path=require('node:path');const fs=require('node:fs');
const output=process.env.SCREENSHOT_DIR||path.resolve('artifacts/browser');fs.mkdirSync(output,{recursive:true});
(async()=>{const browser=await chromium.launch({executablePath:process.env.CHROMIUM_PATH||'/usr/bin/chromium',headless:true,args:['--no-sandbox','--enable-unsafe-swiftshader']});const page=await browser.newPage({viewport:{width:390,height:740},hasTouch:true});const errors=[];page.on('pageerror',e=>errors.push(e.message));page.on('console',m=>{if(m.type()==='error')errors.push(m.text())});
const tap=async(x,y)=>{await page.mouse.click(x,y);await page.waitForTimeout(80)};
const seed={deck:['sword','fire','shield','lightning','heal','spark','ice','water','earth','storm','ember','blade'],coins:50,xp:35,wins:1,losses:0,stage:1};
await page.addInitScript(p=>{if(!localStorage.getItem('test_seeded')){localStorage.setItem('dungeon_cards_v15',JSON.stringify(p));localStorage.setItem('dungeon_sound','off');localStorage.setItem('dungeon_battle_speed','2');localStorage.setItem('test_seeded','1')}},seed);
await page.goto(process.env.DUNGEON_URL||process.argv[2]||'http://127.0.0.1:8765/godot/',{waitUntil:'networkidle'});await page.waitForFunction(()=>!document.querySelector('#status'));await page.screenshot({path:output+'/godot-home.png'});
await tap(270,500);await page.waitForTimeout(100);await tap(180,280);assert.equal(await page.evaluate(()=>localStorage.getItem('dungeon_sound')),'on');await tap(180,280);assert.equal(await page.evaluate(()=>localStorage.getItem('dungeon_sound')),'off');await tap(337,75);
await tap(100,500);await page.waitForTimeout(100);await page.screenshot({path:output+'/godot-tower.png'});await tap(337,75);
await tap(190,440);await tap(300,593);await page.waitForTimeout(100);await tap(65,440);const edited=await page.evaluate(()=>JSON.parse(localStorage.getItem('dungeon_cards_v15')));assert(edited.deck.includes('meteor'));assert(!edited.deck.includes('sword'));assert.equal(edited.deck.length,12);await page.screenshot({path:output+'/godot-deck.png'});await tap(337,75);
await tap(190,560);await page.waitForTimeout(150);await page.screenshot({path:output+'/godot-battle.png'});
await page.mouse.move(40,610);await page.mouse.down();await page.waitForTimeout(650);await page.screenshot({path:output+'/godot-card-detail.png'});await page.mouse.up();await tap(337,75);
await tap(345,435);await page.waitForTimeout(100);await page.screenshot({path:output+'/godot-hero.png'});await tap(337,75);
for(let turn=0;turn<10;turn++){for(let i=4;i>=0;i--){await tap(40+i*76,620);await page.waitForTimeout(420)}await tap(190,715);await page.waitForTimeout(850)}
await page.screenshot({path:output+'/godot-result.png'});const result=await page.evaluate(()=>JSON.parse(localStorage.getItem('dungeon_cards_v15')));assert(result.xp>35,'Battle should reach a persisted result');assert(result.coins>50);await tap(190,500);await page.reload({waitUntil:'networkidle'});await page.waitForFunction(()=>!document.querySelector('#status'));const persisted=await page.evaluate(()=>JSON.parse(localStorage.getItem('dungeon_cards_v15')));assert.deepEqual(persisted,result);
await page.setViewportSize({width:390,height:844});await page.waitForTimeout(100);await page.screenshot({path:output+'/godot-tall.png'});await page.setViewportSize({width:1024,height:768});await page.waitForTimeout(100);await page.screenshot({path:output+'/godot-desktop.png'});
console.log(JSON.stringify({result,errors}));await browser.close();assert.equal(errors.length,0);
})();
