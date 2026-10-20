"use strict";
const C={sword:{name:"Espada Rúnica",cost:1,damage:10,art:"sword",icon:"⚔️",glow:"#c4a079"},fire:{name:"Bola de Fogo",cost:2,damage:14,burn:2,art:"fire",icon:"🔥",glow:"#d86945"},shield:{name:"Escudo Arcano",cost:1,block:12,art:"shield",icon:"🛡️",glow:"#5ab9ee"},lightning:{name:"Raio Celeste",cost:2,damage:16,art:"lightning",icon:"⚡",glow:"#a99aff"},heal:{name:"Cura Divina",cost:2,heal:12,art:"heal",icon:"💚",glow:"#65dca4"},spark:{name:"Faísca",cost:0,block:8,art:"shield",icon:"✨",glow:"#f6c965"},ice:{name:"Prisão Glacial",cost:2,damage:9,freeze:1,art:"ice",icon:"❄️",glow:"#77dfff"},water:{name:"Maré Curativa",cost:1,heal:8,block:4,art:"water",icon:"🌊",glow:"#58bfff"},earth:{name:"Muralha de Pedra",cost:2,block:20,art:"earth",icon:"🪨",glow:"#c7a16d"},storm:{name:"Tempestade",cost:3,damage:24,art:"storm",icon:"🌩️",glow:"#bbadff"},ember:{name:"Chama Viva",cost:1,damage:7,burn:2,art:"fire",icon:"🔥",glow:"#ff794d"},blade:{name:"Golpe Duplo",cost:2,damage:17,art:"sword",icon:"🗡️",glow:"#f5ce91"},meteor:{"name":"Meteoro Infernal","cost":3,"damage":27,"burn":2,"art":"fire","icon":"☄️","glow":"#ff7444"},frostguard:{"name":"Barreira Glacial","cost":2,"block":17,"freeze":1,"art":"ice","icon":"🧊","glow":"#79e8ff"},thunder:{"name":"Lança Trovejante","cost":1,"damage":9,"art":"lightning","icon":"⚡","glow":"#9f9dff"},nature:{"name":"Benção da Floresta","cost":2,"heal":10,"block":7,"art":"heal","icon":"🌿","glow":"#61ffb0"},quakes:{"name":"Terremoto","cost":3,"damage":21,"block":6,"art":"earth","icon":"🪨","glow":"#e4ac70"},tidal:{"name":"Onda Protetora","cost":2,"block":12,"heal":7,"art":"water","icon":"🌊","glow":"#55dfff"},inferno:{"name":"Corte Flamejante","cost":2,"damage":13,"burn":2,"art":"fire","icon":"🔥","glow":"#ff7e55"},glacier:{"name":"Lâmina de Gelo","cost":1,"damage":8,"freeze":1,"art":"ice","icon":"❄️","glow":"#70e5ff"},aegis:{"name":"Égide Celestial","cost":3,"block":26,"art":"shield","icon":"🛡️","glow":"#fbdc8c"},renew:{"name":"Renascimento","cost":3,"heal":23,"art":"heal","icon":"💚","glow":"#8affb5"},tempest:{"name":"Fúria dos Céus","cost":3,"damage":22,"art":"storm","icon":"🌩️","glow":"#d58bff"},stones:{"name":"Punho de Pedra","cost":1,"damage":7,"block":5,"art":"earth","icon":"👊","glow":"#d7a16c"}};
const BASE=["sword","fire","shield","lightning","heal","spark","ice","water","earth","storm","ember","blade","meteor","frostguard","thunder","nature","quakes","tidal","inferno","glacier","aegis","renew","tempest","stones"];const $=id=>document.getElementById(id);const reduced=matchMedia("(prefers-reduced-motion: reduce)").matches;let s,audio;
const STORAGE_KEY="dungeon_cards_v15";
const DEFAULT_DECK=["sword","fire","shield","lightning","heal","spark","ice","water","earth","storm","ember","blade"];
function loadProfile(){try{const p=JSON.parse(localStorage.getItem(STORAGE_KEY));if(p&&Array.isArray(p.deck)&&p.deck.length===12&&p.deck.every(id=>C[id])&&Number.isFinite(p.coins)&&Number.isFinite(p.xp))return{deck:p.deck,coins:Math.max(0,p.coins),xp:Math.max(0,p.xp),wins:Math.max(0,p.wins||0),losses:Math.max(0,p.losses||0),stage:Math.min(4,Math.max(0,p.stage||0))}}catch(e){}return{deck:[...DEFAULT_DECK],coins:0,xp:0,wins:0,losses:0,stage:0}}
let profile=loadProfile();
function saveProfile(){try{localStorage.setItem(STORAGE_KEY,JSON.stringify(profile))}catch(e){console.warn("Não foi possível salvar progresso",e)}}
function profileLevel(){return 1+Math.floor(profile.xp/100)}
function refreshProfile(){const p=$("profileStats");if(p)p.textContent="⭐ NV "+profileLevel()+" · 🪙 "+profile.coins+" · 🏆 "+profile.wins+" vitórias · 🏰 FASE "+((profile.stage||0)+1)+"/5";const d=$("deckCount");if(d&&s)d.textContent=s.deck.length;const selected=$("deckSelection");if(selected)selected.textContent="BARALHO "+profile.deck.length+"/12"}
function toggleDeckCard(id){if(s&&!s.done&&s.round>1){$("deckNotice").textContent="O novo baralho entra na próxima batalha.";}$("deckNotice").textContent="Alterações valem na próxima batalha.";const ix=profile.deck.indexOf(id);if(ix>=0){if(profile.deck.length<=12){$("deckNotice").textContent="O baralho deve ter exatamente 12 cartas. Escolha outra carta para trocar.";return}profile.deck.splice(ix,1)}else if(profile.deck.length<12){profile.deck.push(id)}else{const outgoing=profile.deck.shift();profile.deck.push(id);$("deckNotice").textContent="Substituída "+C[outgoing].name+" por "+C[id].name+". A troca vale na próxima batalha."}saveProfile();showCollection();refreshProfile()}

function sound(freq=320){try{audio??=new(window.AudioContext||window.webkitAudioContext)();const o=audio.createOscillator(),g=audio.createGain();o.type="triangle";o.frequency.setValueAtTime(freq,audio.currentTime);o.frequency.exponentialRampToValueAtTime(freq*.65,audio.currentTime+.16);g.gain.setValueAtTime(.045,audio.currentTime);g.gain.exponentialRampToValueAtTime(.001,audio.currentTime+.16);o.connect(g);g.connect(audio.destination);o.start();o.stop(audio.currentTime+.16)}catch{}}
const STAGES=[
{name:"MALGRUK",title:"O CORROMPIDO",zone:"SANTUÁRIO DAS SOMBRAS",hp:100,attack:12,guard:10,portrait:"assets/malgruk-elite.svg",element:"shadow",ability:"GOLPE SOMBRIO",description:"O guardião corrompido protege o primeiro portal."},
{name:"VORAK",title:"O INCENDIÁRIO",zone:"FORNALHA INFERNAL",hp:115,attack:14,guard:12,portrait:"assets/malgruk-elite.svg",element:"fire",ability:"FÚRIA DE BRASAS",description:"Vorak domina a lava e ataca com força crescente."},
{name:"SKAEL",title:"O GUARDIÃO GLACIAL",zone:"FORTALEZA DE GELO",hp:130,attack:15,guard:16,portrait:"assets/malgruk-elite.svg",element:"ice",ability:"PRISÃO ETERNA",description:"Skael protege o caminho com escudos de cristal."},
{name:"DRAKOR",title:"O TITÃ DA TERRA",zone:"RUÍNAS DO COLOSSO",hp:145,attack:17,guard:18,portrait:"assets/malgruk-elite.svg",element:"earth",ability:"PUNHO DO COLOSSO",description:"Drakor resiste a ataques e contra-ataca brutalmente."},
{name:"NOCTHAR",title:"O SENHOR DA TORRE",zone:"TRONO DAS TREVAS",hp:165,attack:19,guard:20,portrait:"assets/malgruk-elite.svg",element:"storm",ability:"TEMPESTADE FINAL",description:"O último chefe reúne a força dos elementos."}
];
function currentStage(){return STAGES[Math.min(s?.stageIndex??profile.stage??0,STAGES.length-1)]}
function updateStageUI(){const e=currentStage();$("enemyName").textContent=e.name;$("enemyTitle").textContent=e.title;$("enemyLabel").textContent=e.name;$("enemyPortrait").src=e.portrait;$("enemyPortrait").alt=e.name;$("enemyLevel").textContent="LV "+(12+(s?.stageIndex??profile.stage??0)*3);$("enemyAbility").textContent=e.ability;$("missionTitle").textContent="DERROTE "+e.name;$("missionText").textContent=e.description+" Vença antes da 10ª rodada!";$("missionZone").textContent=e.zone;$("stageProgress").textContent="FASE "+((profile.stage||0)+1)+" / "+STAGES.length;$("enemyArt").dataset.boss=e.element;HERO_LORE.enemy={name:e.name,role:e.title+" • NÍVEL "+(12+(profile.stage||0)*3),desc:e.description,ability:e.ability+" — "+e.attack+" dano base por ataque.",image:e.portrait}}
function bossDamage(){return currentStage().attack+(s.round%3===0?4:0)}

function shuffle(a){a=[...a];for(let i=a.length-1;i>0;i--){let j=Math.floor(Math.random()*(i+1));[a[i],a[j]]=[a[j],a[i]]}return a}
function draw(){while(s.hand.length<5){if(!s.deck.length){if(!s.discard.length)break;s.deck=shuffle(s.discard);s.discard=[]}s.hand.push(s.deck.pop())}}
function start(){resetBattleSprites();s={stageIndex:profile.stage||0,hero:100,enemy:STAGES[profile.stage||0].hp,heroShield:0,enemyShield:0,energy:3,burn:0,freeze:0,round:1,combo:0,lastElement:"",deck:shuffle(profile.deck),discard:[],hand:[],done:false,busy:false};updateStageUI();draw();$("result").classList.add("hidden");stage("SUA VEZ","ready");log("⚔ Prepare seu primeiro ataque!");render()}

const elementFor=c=>c.art==="sword"?"steel":c.art==="shield"?"ice":c.art==="heal"?"water":c.art==="spark"?"lightning":c.art;
function elementScene(element){const arena=$("arena");arena.classList.remove("element-fire","element-ice","element-earth","element-water","element-lightning","element-storm");void arena.offsetWidth;arena.classList.add("element-"+element);setTimeout(()=>arena.classList.remove("element-"+element),reduced?150:1300);if(element==="storm"||element==="lightning")lightningFlash();if(element==="fire")burst("enemyArt","fire",28);if(element==="ice")burst("enemyArt","ice",25);if(element==="water")burst("heroArt","heal",24);if(element==="earth")burst("heroArt","gold",26)}
function lightningFlash(){const e=document.createElement("div");e.className="lightning-flash";$("arena").append(e);setTimeout(()=>e.remove(),600)}
function alertCheck(){const critical=s.hero<=30&&!s.done;document.body.classList.toggle("danger-health",critical);$("dangerNotice").textContent=critical?"⚠ VIDA CRÍTICA — PROTEJA ELYRA!":""}
function cardInfo(c){let x=[];if(c.damage)x.push(c.damage+" dano");if(c.block)x.push(c.block+" defesa");if(c.heal)x.push(c.heal+" cura");if(c.burn)x.push("queima");if(c.freeze)x.push("congela");return x.join(" · ")}
const HERO_LORE={hero:{name:"ELYRA",role:"GUARDIÃ ARCANA • NÍVEL 08",desc:"Herdeira dos cristais celestiais. Canaliza a magia elemental para proteger a Torre Infinita.",ability:"✧ ESSÊNCIA ARCANA — A magia de Elyra brilha ao receber escudo ou recuperar vida.",image:"assets/elyra-elite.svg"},enemy:{name:"MALGRUK",role:"O CORROMPIDO • NÍVEL 12",desc:"Antigo protetor da cidadela, consumido pelo poder das sombras. Sua armadura guarda a última centelha de honra.",ability:"☾ GOLPE SOMBRIO — Malgruk anuncia sua próxima ação antes de atacar.",image:"assets/malgruk-elite.svg"}};
function showHeroDetails(which){const h=HERO_LORE[which],p=$("heroDetails");if(!h||!p)return;$("heroDetailImage").src=h.image;$("heroDetailName").textContent=h.name;$("heroDetailClass").textContent=h.role;$("heroDetailDesc").textContent=h.desc;$("heroDetailAbility").textContent=h.ability;p.classList.add("open");p.setAttribute("aria-hidden","false")}
function hideHeroDetails(){const p=$("heroDetails");p.classList.remove("open");p.setAttribute("aria-hidden","true")}
function cardFlavor(c){if(c.freeze)return "Aprisiona o inimigo em cristais glaciais e impede a próxima ação.";if(c.burn)return "As chamas continuam causando dano no início do turno inimigo.";if(c.block&&c.heal)return "Restaura vida e fortalece sua proteção.";if(c.block)return "Cria uma barreira mágica que absorve dano recebido.";if(c.heal)return "Canaliza energia vital para recuperar pontos de vida.";if(c.art==="storm")return "Invoca relâmpagos devastadores contra o adversário.";return "Concentra poder arcano em um golpe direto contra o inimigo."}
function showCardDetails(id){const c=C[id],panel=$("cardDetails");if(!panel||!c)return;panel.querySelector(".detail-art").src="assets/card-"+c.art+".svg";panel.querySelector(".detail-title").textContent=c.name;panel.querySelector(".detail-cost").textContent="💎 "+c.cost+" mana";panel.querySelector(".detail-effect").textContent=cardInfo(c);panel.querySelector(".detail-flavor").textContent=cardFlavor(c);panel.classList.add("open");panel.setAttribute("aria-hidden","false")}
function showCollection(){const p=$("collectionPanel"),grid=$("collectionGrid");grid.replaceChildren();Object.entries(C).forEach(([id,c])=>{const b=document.createElement("button");b.type="button";b.className="collection-item"+(profile.deck.includes(id)?" selected":"");const img=document.createElement("img");img.src="assets/card-"+c.art+".svg";img.alt="";const title=document.createElement("b");title.textContent=c.name;const desc=document.createElement("small");desc.textContent="💎 "+c.cost+" · "+cardInfo(c);const chosen=document.createElement("span");chosen.className="deck-tag";chosen.textContent=profile.deck.includes(id)?"✓ NO DECK":"＋ TROCAR";b.append(img,title,desc,chosen);b.addEventListener("click",()=>toggleDeckCard(id));b.addEventListener("contextmenu",e=>{e.preventDefault();showCardDetails(id)});grid.append(b)});refreshProfile();p.classList.remove("hidden")}
function hideCollection(){$("collectionPanel").classList.add("hidden")}
function hideCardDetails(){const p=$("cardDetails");if(p){p.classList.remove("open");p.setAttribute("aria-hidden","true")}}
function elementalSound(type){if(!audio)return;try{let now=audio.currentTime;const types={fire:[140,220,90],ice:[920,650,1100],water:[370,480,620],earth:[90,125,80],lightning:[880,220,760],storm:[110,760,170],steel:[320,210,390]};const notes=types[type]||[350,470,600];notes.forEach((f,i)=>{let o=audio.createOscillator(),g=audio.createGain();o.type=type==="lightning"||type==="storm"?"sawtooth":"sine";o.frequency.setValueAtTime(f,now+i*.095);g.gain.setValueAtTime(.0001,now+i*.095);g.gain.exponentialRampToValueAtTime(.035,now+i*.095+.02);g.gain.exponentialRampToValueAtTime(.001,now+i*.095+.19);o.connect(g);g.connect(audio.destination);o.start(now+i*.095);o.stop(now+i*.095+.2)})}catch{}}
function log(t){$("log").textContent=t}
function damage(who,n){let k=who==="enemy"?"enemyShield":"heroShield",absorbed=Math.min(s[k],n);s[k]-=absorbed;let actual=n-absorbed;s[who]=Math.max(0,s[who]-actual);return actual}
function float(id,t,healing=false){let e=$(id).getBoundingClientRect(),r=$("arena").getBoundingClientRect(),f=document.createElement("span");f.className="float"+(healing?" heal":"");f.textContent=t;f.style.left=e.left-r.left+e.width*.2+"px";f.style.top=e.top-r.top+"px";$("fx").append(f);setTimeout(()=>f.remove(),1100)}
function impact(id,t,healing=false){let e=$(id);e.classList.remove("hit","healed");void e.offsetWidth;e.classList.add(healing?"healed":"hit");float(id,t,healing);setTimeout(()=>e.classList.remove("hit","healed"),480);if(navigator.vibrate&&!reduced)navigator.vibrate(35)}
function projectile(from,to,emoji,color){if(reduced)return;let b=$("arena").getBoundingClientRect(),a=$(from).getBoundingClientRect(),z=$(to).getBoundingClientRect(),sx=a.left+a.width/2-b.left,sy=a.top+a.height/2-b.top,tx=z.left+z.width/2-b.left,ty=z.top+z.height/2-b.top,p=document.createElement("span");p.className="projectile";p.textContent=emoji;p.style.left=sx+"px";p.style.top=sy+"px";p.style.setProperty("--dx",tx-sx+"px");p.style.setProperty("--dy",ty-sy+"px");p.style.setProperty("--glow",color);$("fx").append(p);setTimeout(()=>p.remove(),520)}

const wait=ms=>new Promise(resolve=>setTimeout(resolve,reduced?20:ms));
let animationToken=0;
function stage(text,kind="attack"){const el=$("phase");el.textContent=text;el.className="stage "+kind}
function actor(id,action,duration=650){const el=$(id);el.classList.remove("cast-fire","cast-bolt","cast-guard","cast-heal","lunge","recoil","parry","channel");void el.offsetWidth;el.classList.add(action);setTimeout(()=>el.classList.remove(action),duration)}
function burst(id,type="fire",count=16){const b=$("arena").getBoundingClientRect(),r=$(id).getBoundingClientRect(),x=r.left+r.width/2-b.left,y=r.top+r.height/2-b.top;const fx=$("fx");for(let i=0;i<count;i++){const p=document.createElement("i");p.className="combat-particle "+type;const angle=Math.PI*2*i/count,dist=24+Math.random()*65;p.style.left=x+"px";p.style.top=y+"px";p.style.setProperty("--tx",Math.cos(angle)*dist+"px");p.style.setProperty("--ty",Math.sin(angle)*dist+"px");p.style.setProperty("--delay",Math.random()*80+"ms");fx.append(p);setTimeout(()=>p.remove(),850)}}
function shieldBubble(id){const r=$(id),existing=r.querySelector(".bubble");if(existing)existing.remove();const e=document.createElement("div");e.className="bubble";e.textContent="✦";r.append(e);setTimeout(()=>e.remove(),950)}
function hitFlash(id,kind="hit"){const e=$(id);e.classList.remove("impact-red","impact-blue","block-hit");void e.offsetWidth;e.classList.add(kind==="block"?"block-hit":kind==="heal"?"impact-blue":"impact-red");setTimeout(()=>e.classList.remove("impact-red","impact-blue","block-hit"),720)}
function screenPulse(type){const e=document.createElement("div");e.className="screen-pulse "+type;$("arena").append(e);setTimeout(()=>e.remove(),480)}
async function animateAttack(from,to,card,amount,blocked=0){
 const source=$(from),target=$(to);stage(card.name.toUpperCase(),"attack");
 actor(from,card.art==="fire"?"cast-fire":card.art==="lightning"?"cast-bolt":"lunge",700);
 source.classList.add("active-fighter");
 await wait(270);
 projectile(from,to,card.icon,card.glow);
 await wait(430);
 if(blocked){shieldBubble(to);actor(to,"parry",650);hitFlash(to,"block");burst(to,"ice",12);float(to,"🛡 −"+blocked,true)}
 if(amount){actor(to,"recoil",600);hitFlash(to);burst(to,card.art==="fire"?"fire":card.art==="lightning"?"electric":"gold",20);float(to,"−"+amount);screenPulse(card.art==="fire"?"fire":"strike")}
 sound(card.art==="fire"?160:card.art==="lightning"?560:290);
 source.classList.remove("active-fighter");
 await wait(250);
}

function centerOf(el){const r=el.getBoundingClientRect();return{x:r.left+r.width/2,y:r.top+r.height/2}}
async function fuseCard(cardElement,card,heroId="heroArt"){
 if(!cardElement)return;
 const from=cardElement.getBoundingClientRect(),target=centerOf($(heroId));
 const clone=cardElement.cloneNode(true);
 clone.disabled=true;clone.classList.add("flying-card");clone.style.left=from.left+"px";clone.style.top=from.top+"px";clone.style.width=from.width+"px";clone.style.height=from.height+"px";clone.style.margin="0";clone.style.animation="none";clone.style.setProperty("--glow",card.glow+"bb");
 document.body.append(clone);cardElement.style.visibility="hidden";
 stage("CARTA INVOCADA","attack");sound(510);
 await wait(90);
 const dx=target.x-(from.left+from.width/2),dy=target.y-(from.top+from.height/2);
 const anim=clone.animate([{transform:"translate3d(0,0,0) scale(1) rotate(0deg)",opacity:1,filter:"brightness(1)"},{offset:.65,transform:`translate3d(${dx*.7}px,${dy*.7-30}px,0) scale(.8) rotate(-12deg)`,opacity:1,filter:"brightness(1.6)"},{transform:`translate3d(${dx}px,${dy}px,0) scale(.06) rotate(360deg)`,opacity:0,filter:"brightness(4)"}],{duration:reduced?60:650,easing:"cubic-bezier(.25,.1,.3,1)",fill:"forwards"});
 await anim.finished.catch(()=>{});
 clone.remove();
 poseFighter("elyraFighter",card.block?"defend":card.heal?"heal":"cast",850);
 burst("elyraFighter",card.block?"ice":card.heal?"heal":card.art==="fire"?"fire":card.art==="lightning"?"electric":"gold",26);
 aura("elyraFighter",card.glow,card.icon);
 screenPulse(card.block?"shield":card.heal?"heal":"strike");
 await wait(220);
}
function aura(id,color,symbol){
 const host=$(id),e=document.createElement("span");e.className="absorb-aura";e.textContent=symbol;e.style.setProperty("--aura",color);host.append(e);
 setTimeout(()=>e.remove(),1150);
}

function fighterFor(id){return id==="heroArt"?"heroArt":"enemyArt"}
function poseFighter(id,pose,duration=800){const el=$(id);if(!el)return;el.classList.remove("pose-attack","pose-cast","pose-defend","pose-heal","pose-hit");void el.offsetWidth;el.classList.add("pose-"+pose);setTimeout(()=>el.classList.remove("pose-"+pose),duration)}
function resetBattleSprites(){for(const id of ["elyraFighter","malgrukFighter"]){const el=$(id);if(el){el.getAnimations().forEach(a=>a.cancel());el.style.transform="";el.className="battle-sprite "+(id==="elyraFighter"?"battle-elyra":"battle-malgruk")}}}
async function moveActorToTarget(from,to,kind="melee"){
 const fighter=$(fighterFor(from)),opponent=$(fighterFor(to)),arena=$("arena");
 if(!fighter||!opponent)return async()=>{};
 const fr=fighter.getBoundingClientRect(),tr=opponent.getBoundingClientRect();
 const direction=from==="heroArt"?1:-1;
 const dx=(tr.left+tr.width*.5)-(fr.left+fr.width*.5)-direction*(fr.width*.38+tr.width*.38);
 const dy=(tr.top+tr.height*.5)-(fr.top+fr.height*.5);
 poseFighter(fighter.id,kind==="magic"?"cast":"attack",1550);
 fighter.classList.add("moving","duel-card");
 const approach=fighter.animate([
 {transform:"translate3d(0,0,0) scale(1)",offset:0},
 {transform:`translate3d(${dx*.35}px,${dy*.15-18}px,0) scale(1.08)`,offset:.4},
 {transform:`translate3d(${dx*.82}px,${dy*.8}px,0) scale(1.18)`,offset:.82},
 {transform:`translate3d(${dx}px,${dy}px,0) scale(1.2)`,offset:1}
 ],{duration:reduced?100:730,easing:"cubic-bezier(.16,.7,.18,1)",fill:"forwards"});
 await approach.finished.catch(()=>{});
 poseFighter(opponent.id,"hit",650);
 return async()=>{
 const back=fighter.animate([
 {transform:`translate3d(${dx}px,${dy}px,0) scale(1.2)`,offset:0},
 {transform:`translate3d(${dx*.42}px,${dy*.15-8}px,0) scale(1.07)`,offset:.5},
 {transform:"translate3d(0,0,0) scale(1)",offset:1}
 ],{duration:reduced?80:530,easing:"ease-in-out",fill:"forwards"});
 await back.finished.catch(()=>{});
 approach.cancel();back.cancel();fighter.classList.remove("moving","duel-card");
 };
}
async function animateSpellToTarget(from,to,card){
 const a=centerOf($(fighterFor(from))),b=centerOf($(fighterFor(to))),orb=document.createElement("div");
 orb.className="spell-orb "+card.art;orb.style.left=(a.x-30)+"px";orb.style.top=(a.y-30)+"px";orb.style.setProperty("--spell",card.glow);
 orb.innerHTML='<span>'+card.icon+'</span>';document.body.append(orb);
 const dx=b.x-a.x,dy=b.y-a.y;
 const anim=orb.animate([
 {transform:"translate3d(0,0,0) scale(.35)",opacity:0},
 {offset:.18,transform:"translate3d("+dx*.13+"px,"+(dy*.13-35)+"px,0) scale(1.1)",opacity:1},
 {offset:.68,transform:"translate3d("+dx*.7+"px,"+(dy*.7-25)+"px,0) scale(1.5)",opacity:1},
 {transform:"translate3d("+dx+"px,"+dy+"px,0) scale(1.9)",opacity:1}],
 {duration:reduced?90:760,easing:"ease-in",fill:"forwards"});
 await anim.finished.catch(()=>{});
 anim.cancel();orb.remove();
}
function impactSequence(to,card,outcome){
 if(outcome.blocked){shieldBubble(to);actor(to,"parry",600);poseFighter(fighterFor(to),"defend",750);hitFlash(to,"block");burst(to,"ice",22);float(to,"🛡 −"+outcome.blocked,true)}
 if(outcome.amount){actor(to,"recoil",650);poseFighter(fighterFor(to),"hit",750);hitFlash(to);burst(to,card.art==="fire"?"fire":card.art==="lightning"?"electric":"gold",36);float(to,"−"+outcome.amount);screenPulse(card.art==="fire"?"fire":"strike")}
 if(navigator.vibrate&&!reduced)navigator.vibrate([40,30,65]);
}
async function dashStrike(from,to,card,resolveHit){
 stage("INVESTIDA • "+card.name.toUpperCase(),"attack");aura(from,card.glow,card.icon);sound(330);
 await wait(180);
 const returnHome=await moveActorToTarget(from,to);
 const outcome=resolveHit();impactSequence(to,card,outcome);sound(180);
 await wait(400);await returnHome();return outcome;
}
async function magicStrike(from,to,card,resolveHit){
 stage("INVOCANDO • "+card.name.toUpperCase(),"attack");
 poseFighter(fighterFor(from),"cast",1000);aura(fighterFor(from),card.glow,card.icon);burst(fighterFor(from),card.art==="fire"?"fire":"electric",18);
 await wait(250);
 stage(from==="heroArt"?"ELYRA AVANÇA!":"O CHEFE AVANÇA!","attack");
 const returnHome=await moveActorToTarget(from,to,"magic");
 stage("MAGIA EM COMBATE","attack");
 await animateSpellToTarget(from,to,card);
 const outcome=resolveHit();impactSequence(to,card,outcome);sound(card.art==="fire"?145:580);
 await wait(280);await returnHome();return outcome;
}
function updateShieldAuras(){
 $("heroArt").classList.toggle("shield-active",s.heroShield>0);
 $("enemyArt").classList.toggle("shield-active",s.enemyShield>0);
}
async function play(i){
 if(s.done||s.busy)return;
 const id=s.hand[i],c=C[id];if(!c||c.cost>s.energy)return;
 s.busy=true;
 const cardElement=$("cards").children[i];
 await fuseCard(cardElement,c);
 s.energy-=c.cost;s.hand.splice(i,1);s.discard.push(id);s.combo++;const element=elementFor(c);const elementalCombo=s.lastElement===element&&s.combo>1;s.lastElement=element;elementScene(element);elementalSound(element);
 render();
 let out=[];
 if(c.damage){
  const bonus=(s.combo>=3?Math.min(6,(s.combo-2)*2):0)+(elementalCombo?4:0);
  const resolveHit=()=>{const before=s.enemyShield;const amount=damage("enemy",c.damage+bonus);const blocked=before-s.enemyShield;render();return{amount,blocked}};
  const result=c.art==="sword"?await dashStrike("heroArt","enemyArt",c,resolveHit):await magicStrike("heroArt","enemyArt",c,resolveHit);
  out.push(result.amount+" dano"+(bonus?" • COMBO +"+bonus:""));
 }
 if(c.block){
  stage("ESCUDO INCORPORADO","defense");poseFighter("elyraFighter","defend",900);actor("heroArt","cast-guard",750);shieldBubble("heroArt");burst("heroArt","ice",24);screenPulse("shield");
  await wait(450);s.heroShield+=c.block;updateShieldAuras();float("heroArt","+"+c.block+" 🛡",true);sound(540);out.push("+"+c.block+" escudo");await wait(330);
 }
 if(c.heal){
  stage("ENERGIA VITAL","heal");poseFighter("elyraFighter","heal",950);actor("heroArt","cast-heal",850);burst("heroArt","heal",30);screenPulse("heal");
  const n=Math.min(c.heal,100-s.hero);await wait(420);s.hero+=n;float("heroArt","+"+n+" ♥",true);sound(720);out.push("+"+n+" HP");await wait(260);
 }
 if(c.burn){s.burn=Math.max(s.burn,c.burn);out.push("🔥 Queimadura");burst("enemyArt","fire",10)}if(c.freeze){s.freeze=Math.max(s.freeze,c.freeze);out.push("❄️ Malgruk congelado");burst("enemyArt","ice",18)}
 if(s.enemy<=0){render();finish("win");return}
 s.busy=false;stage("SUA VEZ","ready");log(c.icon+" "+c.name+": "+out.join(" • "));render();
}
async function endTurn(){
 if(s.done||s.busy)return;s.busy=true;stage("TURNO DE "+currentStage().name,"danger");log("👹 "+currentStage().name+" está preparando a reação...");render();
 await wait(500);
 let out=[];
 if(s.burn){const n=damage("enemy",3);s.burn--;poseFighter("malgrukFighter","hit",600);actor("enemyArt","recoil",550);burst("enemyArt","fire",12);float("enemyArt","🔥 −"+n);out.push("Queimadura: "+n);await wait(520)}
 if(s.enemy<=0){finish("win");return}
 const frozen=s.freeze>0;if(frozen){s.freeze--;stage("MALGRUK CONGELADO","defense");elementScene("ice");poseFighter("malgrukFighter","defend",850);actor("enemyArt","parry",700);burst("enemyArt","ice",26);out.push("❄️ Malgruk perdeu a ação");await wait(600)}const defend=!frozen&&s.enemy<Math.ceil(currentStage().hp*.3)&&s.round%2===0;
 if(defend){
  stage("DEFESA DO GUARDIÃO","defense");poseFighter("malgrukFighter","defend",900);actor("enemyArt","cast-guard",700);shieldBubble("enemyArt");burst("enemyArt","ice",14);
  await wait(520);s.enemyShield+=currentStage().guard;updateShieldAuras();float("enemyArt","+"+currentStage().guard+" 🛡",true);out.push("Malgruk ergueu escudo");await wait(280);
 }else if(!frozen){
  const attack=bossDamage();
  const result=await dashStrike("enemyArt","heroArt",{name:"GOLPE DE "+currentStage().name,art:"sword",icon:"🪓",glow:"#f6a55d"},()=>{const before=s.heroShield;const amount=damage("hero",attack);const blocked=before-s.heroShield;render();return{amount,blocked}});
  out.push("Malgruk atacou: "+result.amount+" dano"+(result.blocked?" ("+result.blocked+" bloqueado)":""));
 }
 s.heroShield=0;updateShieldAuras();s.discard.push(...s.hand);s.hand=[];s.round++;s.energy=3;s.combo=0;s.lastElement="";draw();
 if(s.hero<=0){finish("lose");return}
 if(s.round>10){finish(s.hero>s.enemy?"win":s.hero<s.enemy?"lose":"draw");return}
 s.busy=false;stage("SUA VEZ","ready");log(out.join(" • ")+" • Sua vez!");render();
}
function finish(k){if(!s.done){const coins=k==="win"?50:k==="draw"?10:5;const xp=k==="win"?35:k==="draw"?12:8;profile.coins+=coins;profile.xp+=xp;if(k==="win")profile.wins++;if(k==="win"&&profile.stage<STAGES.length-1)profile.stage++;if(k==="lose")profile.losses++;saveProfile();refreshProfile()}s.done=true;s.busy=false;document.body.classList.remove("danger-health");render();$("resultIcon").textContent=k==="win"?"🏆":k==="draw"?"⚖️":"💀";$("resultTitle").textContent=k==="win"?"VITÓRIA!":k==="draw"?"EMPATE":"DERROTA";$("resultText").textContent=k==="win"?"Chefe derrotado! Uma nova fase da Torre foi desbloqueada.":k==="draw"?"Os heróis terminaram empatados.":"Ajuste seu deck e tente novamente.";$("reward").textContent=k==="win"?"+50 MOEDAS · +35 XP":k==="draw"?"+10 MOEDAS · +12 XP":"+5 MOEDAS · +8 XP";$("result").classList.remove("hidden");sound(k==="win"?740:190)}
function render(){alertCheck();$("enemyHP").textContent=s.enemy+" / "+currentStage().hp;$("heroHP").textContent=s.hero+" / 100";$("enemyBar").style.width=(100*s.enemy/currentStage().hp)+"%";$("heroBar").style.width=s.hero+"%";$("round").textContent=Math.min(10,s.round)+" / 10";$("enemyStatus").textContent=[s.enemyShield?"🛡 Escudo "+s.enemyShield:"",s.burn?"🔥 Queimadura "+s.burn:"",s.freeze?"❄️ Congelado":" "].filter(Boolean).join(" • ")||"✦ Sem efeitos";$("heroStatus").textContent=s.heroShield?"🛡 Escudo "+s.heroShield:"✦ Sem efeitos";$("intent").textContent=s.freeze?"❄️ Próximo: perde a ação":s.enemy<Math.ceil(currentStage().hp*.3)&&s.round%2===0?"🛡 Próximo: defender":"⚔ Próximo: "+bossDamage()+" dano";$("energyText").textContent=s.energy+" / 3";$("combo").textContent="×"+Math.max(1,s.combo);$("deckCount").textContent=s.deck.length;$("hint").textContent=s.busy?"Aguarde...":s.energy?"Toque para jogar":"Sem mana • encerre o turno";$("gems").replaceChildren();for(let i=0;i<3;i++){let g=document.createElement("span");g.className="gem"+(i>=s.energy?" off":"");g.textContent="💎";$("gems").append(g)}$("cards").replaceChildren();s.hand.forEach((id,i)=>{let c=C[id],b=document.createElement("button");b.className="card card-"+c.art;b.dataset.element=c.art;b.disabled=s.done||s.busy||c.cost>s.energy;b.style.setProperty("--glow",c.glow+"66");b.style.setProperty("--delay",i*45+"ms");b.setAttribute("aria-label",c.name+", "+c.cost+" mana, "+cardInfo(c));let cost=document.createElement("span");cost.className="cost";cost.textContent=c.cost;let art=document.createElement("div");art.className="art";let img=document.createElement("img");img.src="assets/card-"+c.art+".svg";img.alt="";art.append(img);let name=document.createElement("strong");name.textContent=c.name;let desc=document.createElement("small");desc.textContent=cardInfo(c);let rarity=document.createElement("span");rarity.className="rarity";let type=document.createElement("span");type.className="card-type";type.textContent=c.block?"DEFESA":c.heal?"CURA":c.art==="sword"?"ATAQUE":"MAGIA";b.append(cost,art,name,desc,type,rarity);b.addEventListener("click",()=>play(i));let pressTimer;b.addEventListener("pointerdown",()=>{pressTimer=setTimeout(()=>showCardDetails(id),550)});["pointerup","pointercancel","pointerleave"].forEach(ev=>b.addEventListener(ev,()=>clearTimeout(pressTimer)));$("cards").append(b)});$("end").disabled=s.done||s.busy;updateShieldAuras()}
["hero","enemy"].forEach(which=>{const e=$(which==="hero"?"heroArt":"enemyArt");e.addEventListener("click",()=>{if(!s.busy)showHeroDetails(which)});e.addEventListener("keydown",ev=>{if(ev.key==="Enter"||ev.key===" "){ev.preventDefault();if(!s.busy)showHeroDetails(which)}})});$("closeHeroDetails").addEventListener("click",hideHeroDetails);$("heroDetailBack").addEventListener("click",hideHeroDetails);$("heroDetails").addEventListener("click",ev=>{if(ev.target.id==="heroDetails")hideHeroDetails()});$("end").addEventListener("click",endTurn);$("cardDetails")?.addEventListener("click",hideCardDetails);$("collectionBtn").addEventListener("click",showCollection);$("closeCollection").addEventListener("click",hideCollection);$("collectionPanel").addEventListener("click",e=>{if(e.target.id==="collectionPanel")hideCollection()});$("again").addEventListener("click",start);start();refreshProfile();