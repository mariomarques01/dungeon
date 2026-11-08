const {chromium}=require('playwright-core');const assert=require('node:assert/strict');const fs=require('node:fs');
const out=process.env.SCREENSHOT_DIR||'artifacts/mutable-actions';fs.mkdirSync(out,{recursive:true});
const costs={golem:4,goblin:2,wall:3,portal:2,skeleton:2,mage:3,orc:4,fire:4,heal:3,wisp:1};
const sleep=ms=>new Promise(r=>setTimeout(r,ms));
(async()=>{const browser=await chromium.launch({executablePath:process.env.CHROMIUM_PATH||'/usr/bin/chromium',headless:true,args:['--no-sandbox','--enable-unsafe-swiftshader']});try{
 const errors=[];
 async function open(){const p=await browser.newPage({viewport:{width:720,height:1280}});p.on('pageerror',e=>errors.push(e.message));p.on('console',m=>{if(m.type()==='error')errors.push(m.text())});const url=new URL(process.env.DUNGEON_URL||'http://127.0.0.1:8766/godot/');url.searchParams.set('qa','1');url.searchParams.set('server',process.env.ROOM_URL||'ws://127.0.0.1:9080');await p.goto(url.href);await p.waitForFunction(()=>window.dungeonArena,null,{timeout:120000});return p}
 const state=p=>p.evaluate(()=>window.dungeonArena);
 async function button(p,text){const s=await state(p),r=s.buttons.find(b=>b.text.startsWith(text)).rect;await p.mouse.click(r[0]+r[2]/2,r[1]+r[3]/2);await sleep(100)}
 async function play(p,index,x,y){let s=await state(p);const side=s.side;const count=s.state.casts[side];await p.waitForFunction(({index,costs})=>{const s=dungeonArena;return s.state.energy[s.side]>=costs[s.state.hands[s.side][index]]},{index,costs},{timeout:20000});await p.mouse.click(110+index*148,1080);await p.mouse.click(x,y);await p.waitForFunction(({side,count})=>dungeonArena.state.casts[side]>count,{side,count},{timeout:5000})}
 async function frames(p,prefix,count=8){for(let i=0;i<count;i++){await p.screenshot({path:`${out}/${prefix}-${String(i).padStart(2,'0')}.jpg`,type:'jpeg',quality:82});await sleep(65)}}
 const a=await open(),b=await open();await button(a,'DUELO PvP');await button(a,'CRIAR');await a.waitForFunction(()=>dungeonArena.mode==='waiting');const code=(await state(a)).room;await button(b,'DUELO PvP');const input=(await state(b)).inputs.find(i=>i.placeholder==='Código da sala').rect;await b.mouse.click(input[0]+25,input[1]+20);await b.keyboard.type(code);await button(b,'ENTRAR');await a.waitForFunction(()=>dungeonArena.mode==='online');await b.waitForFunction(()=>dungeonArena.mode==='online');
 await play(a,2,240,670);await play(a,0,350,535);await play(b,0,350,550);
 await a.waitForFunction(()=>dungeonArena.state.strikes.length>0,null,{timeout:10000});await frames(a,'attack',10);
 await a.waitForFunction(()=>dungeonArena.state.units.some(u=>u.hp<u.max_hp&&u.hurt_time>0),null,{timeout:5000});console.log('PASS attack windup and defender reaction in authoritative match');
 await play(b,1,350,650);
 await a.waitForFunction(()=>dungeonArena.state.energy[0]>=2);await a.mouse.click(554,1080);await a.mouse.click(360,600);
 await a.waitForFunction(()=>dungeonArena.state.units.some(u=>u.side===1&&u.warp_time>0));const warping=(await state(a)).state.units.find(u=>u.side===1&&u.warp_time>0);assert(warping.y<=335);assert(warping.warp_from_y>warping.y);await b.waitForFunction(()=>dungeonArena.state.units.some(u=>u.side===1&&u.y<=335&&u.warp_time>0));await frames(a,'portal',7);
console.log('PASS portal vortex and return to original base on both clients');
 for(let turn=0;turn<12;turn++){let s=await state(a),hand=s.state.hands[0];const wall=hand.indexOf('wall');if(wall>=0){await play(a,wall,320,650);break}let index=hand.reduce((best,id,i)=>costs[id]<costs[hand[best]]?i:best,0);await play(a,index,350,680)}
 await a.waitForFunction(()=>dungeonArena.state.units.filter(u=>u.side===0&&u.id==='wall').length===2);const walls=(await state(a)).state.units.filter(u=>u.side===0&&u.id==='wall');assert.equal(walls[1].x-walls[0].x,82);assert.equal(walls[1].y-walls[0].y,-32);assert.deepEqual(walls[0].links,[1]);assert.deepEqual(walls[1].links,[-1]);
 await b.waitForFunction(()=>dungeonArena.state.units.filter(u=>u.side===0&&u.id==='wall'&&u.links.length===1).length===2);await a.screenshot({path:out+'/connected-walls.png'});await b.screenshot({path:out+'/connected-walls-opponent.png'});console.log('PASS adjacent walls snap and connect identically for both players');
 assert.deepEqual(errors,[]);console.log('MUTABLE_ACTIONS_BROWSER_OK grounded combat poses, attack/defense, portal, connected walls, two clients, zero console errors');
 }finally{await browser.close()}})().catch(e=>{console.error(e);process.exit(1)});
