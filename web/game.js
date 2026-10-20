"use strict";
const C={sword:{name:"Espada Rúnica",cost:1,damage:10,art:"sword",icon:"⚔️",glow:"#c4a079"},fire:{name:"Bola de Fogo",cost:2,damage:14,burn:2,art:"fire",icon:"🔥",glow:"#d86945"},shield:{name:"Escudo Arcano",cost:1,block:12,art:"shield",icon:"🛡️",glow:"#5ab9ee"},lightning:{name:"Raio Celeste",cost:2,damage:16,art:"lightning",icon:"⚡",glow:"#a99aff"},heal:{name:"Cura Divina",cost:2,heal:12,art:"heal",icon:"💚",glow:"#65dca4"},spark:{name:"Faísca",cost:0,damage:4,art:"spark",icon:"✨",glow:"#f6c965"}};
const BASE=["sword","sword","fire","fire","shield","shield","lightning","heal","spark","spark","sword","shield"];const $=id=>document.getElementById(id);const reduced=matchMedia("(prefers-reduced-motion: reduce)").matches;let s,audio;
function sound(freq=320){try{audio??=new(window.AudioContext||window.webkitAudioContext)();const o=audio.createOscillator(),g=audio.createGain();o.type="triangle";o.frequency.setValueAtTime(freq,audio.currentTime);o.frequency.exponentialRampToValueAtTime(freq*.65,audio.currentTime+.16);g.gain.setValueAtTime(.045,audio.currentTime);g.gain.exponentialRampToValueAtTime(.001,audio.currentTime+.16);o.connect(g);g.connect(audio.destination);o.start();o.stop(audio.currentTime+.16)}catch{}}
function shuffle(a){a=[...a];for(let i=a.length-1;i>0;i--){let j=Math.floor(Math.random()*(i+1));[a[i],a[j]]=[a[j],a[i]]}return a}
function draw(){while(s.hand.length<5){if(!s.deck.length){if(!s.discard.length)break;s.deck=shuffle(s.discard);s.discard=[]}s.hand.push(s.deck.pop())}}
function start(){s={hero:100,enemy:100,heroShield:0,enemyShield:0,energy:3,burn:0,round:1,combo:0,deck:shuffle(BASE),discard:[],hand:[],done:false,busy:false};draw();$("result").classList.add("hidden");stage("SUA VEZ","ready");log("⚔ Prepare seu primeiro ataque!");render()}
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
async function play(i){
 if(s.done||s.busy)return;
 const id=s.hand[i],c=C[id];if(!c||c.cost>s.energy)return;
 s.busy=true;s.energy-=c.cost;s.hand.splice(i,1);s.discard.push(id);s.combo++;
 render();let out=[];
 if(c.damage){
  const bonus=s.combo>=3?Math.min(6,(s.combo-2)*2):0;
  const before=s.enemyShield,n=damage("enemy",c.damage+bonus),blocked=before-s.enemyShield;
  await animateAttack("heroArt","enemyArt",c,n,blocked);
  out.push(n+" de dano"+(bonus?" • COMBO +"+bonus:""));
 }
 if(c.block){
  stage("BARREIRA ARCANA","defense");actor("heroArt","cast-guard",750);shieldBubble("heroArt");burst("heroArt","ice",20);screenPulse("shield");
  await wait(430);s.heroShield+=c.block;float("heroArt","+12 🛡",true);sound(540);out.push("+"+c.block+" escudo");
  await wait(260);
 }
 if(c.heal){
  stage("LUZ RESTAURADORA","heal");actor("heroArt","cast-heal",850);burst("heroArt","heal",24);screenPulse("heal");
  const n=Math.min(c.heal,100-s.hero);await wait(420);s.hero+=n;float("heroArt","+"+n+" ♥",true);sound(720);out.push("+"+n+" HP");await wait(260);
 }
 if(c.burn){s.burn=Math.max(s.burn,c.burn);out.push("🔥 Queimadura");burst("enemyArt","fire",8)}
 if(s.enemy<=0){render();finish("win");return}
 s.busy=false;stage("SUA VEZ","ready");log(c.icon+" "+c.name+": "+out.join(" • "));render();
}
async function endTurn(){
 if(s.done||s.busy)return;s.busy=true;stage("TURNO DE MALGRUK","danger");log("👹 Malgruk está preparando a reação...");render();
 await wait(500);
 let out=[];
 if(s.burn){const n=damage("enemy",3);s.burn--;actor("enemyArt","recoil",550);burst("enemyArt","fire",12);float("enemyArt","🔥 −"+n);out.push("Queimadura: "+n);await wait(520)}
 if(s.enemy<=0){finish("win");return}
 const defend=s.enemy<30&&s.round%2===0;
 if(defend){
  stage("DEFESA DO GUARDIÃO","defense");actor("enemyArt","cast-guard",700);shieldBubble("enemyArt");burst("enemyArt","ice",14);
  await wait(520);s.enemyShield+=10;float("enemyArt","+10 🛡",true);out.push("Malgruk ergueu escudo");await wait(280);
 }else{
  const attack=12+(s.round%3===0?4:0),blocked=Math.min(s.heroShield,attack),n=damage("hero",attack);
  await animateAttack("enemyArt","heroArt",{name:"GOLPE DE MALGRUK",art:"sword",icon:"🪓",glow:"#f6a55d"},n,blocked);
  out.push("Malgruk atacou: "+n+" dano"+(blocked?" ("+blocked+" bloqueado)":""));
 }
 s.heroShield=0;s.discard.push(...s.hand);s.hand=[];s.round++;s.energy=3;s.combo=0;draw();
 if(s.hero<=0){finish("lose");return}
 if(s.round>10){finish(s.hero>s.enemy?"win":s.hero<s.enemy?"lose":"draw");return}
 s.busy=false;stage("SUA VEZ","ready");log(out.join(" • ")+" • Sua vez!");render();
}
function finish(k){s.done=true;s.busy=false;render();$("resultIcon").textContent=k==="win"?"🏆":k==="draw"?"⚖️":"💀";$("resultTitle").textContent=k==="win"?"VITÓRIA!":k==="draw"?"EMPATE":"DERROTA";$("resultText").textContent=k==="win"?"Malgruk foi derrotado. A Torre espera por você!":k==="draw"?"Os heróis terminaram empatados.":"Ajuste seu deck e tente novamente.";$("reward").textContent=k==="win"?"+50 MOEDAS (SIMULAÇÃO)":k==="draw"?"+10 MOEDAS (SIMULAÇÃO)":"+5 MOEDAS (SIMULAÇÃO)";$("result").classList.remove("hidden");sound(k==="win"?740:190)}
function render(){$("enemyHP").textContent=s.enemy+" / 100";$("heroHP").textContent=s.hero+" / 100";$("enemyBar").style.width=s.enemy+"%";$("heroBar").style.width=s.hero+"%";$("round").textContent=Math.min(10,s.round)+" / 10";$("enemyStatus").textContent=[s.enemyShield?"🛡 Escudo "+s.enemyShield:"",s.burn?"🔥 Queimadura "+s.burn:""].filter(Boolean).join(" • ")||"✦ Sem efeitos";$("heroStatus").textContent=s.heroShield?"🛡 Escudo "+s.heroShield:"✦ Sem efeitos";$("intent").textContent=s.enemy<30&&s.round%2===0?"🛡 Próximo: defender":"⚔ Próximo: "+(12+(s.round%3===0?4:0))+" dano";$("energyText").textContent=s.energy+" / 3";$("combo").textContent="×"+Math.max(1,s.combo);$("deckCount").textContent=s.deck.length;$("hint").textContent=s.busy?"Aguarde...":s.energy?"Toque para jogar":"Sem mana • encerre o turno";$("gems").replaceChildren();for(let i=0;i<3;i++){let g=document.createElement("span");g.className="gem"+(i>=s.energy?" off":"");g.textContent="💎";$("gems").append(g)}$("cards").replaceChildren();s.hand.forEach((id,i)=>{let c=C[id],b=document.createElement("button");b.className="card";b.disabled=s.done||s.busy||c.cost>s.energy;b.style.setProperty("--glow",c.glow+"66");b.style.setProperty("--delay",i*45+"ms");b.setAttribute("aria-label",c.name+", "+c.cost+" mana");let cost=document.createElement("span");cost.className="cost";cost.textContent=c.cost;let art=document.createElement("div");art.className="art";let img=document.createElement("img");img.src="assets/"+c.art+".svg";img.alt="";art.append(img);let name=document.createElement("strong");name.textContent=c.name;let desc=document.createElement("small");desc.textContent=c.damage?c.damage+" dano":c.block?c.block+" escudo":c.heal+" cura";let rarity=document.createElement("span");rarity.className="rarity";b.append(cost,art,name,desc,rarity);b.addEventListener("click",()=>play(i));$("cards").append(b)});$("end").disabled=s.done||s.busy}
$("end").addEventListener("click",endTurn);$("restart").addEventListener("click",start);$("again").addEventListener("click",start);start();