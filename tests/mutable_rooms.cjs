const WebSocket=require('ws');const assert=require('node:assert/strict');
const url=process.env.ROOM_URL||'ws://127.0.0.1:9080';
const sleep=ms=>new Promise(r=>setTimeout(r,ms));
async function connect(){const socket=new WebSocket(url);const messages=[];socket.on('message',b=>messages.push(JSON.parse(b)));await new Promise((resolve,reject)=>{socket.once('open',resolve);socket.once('error',reject)});return{socket,messages,send:m=>socket.send(JSON.stringify(m))};}
async function until(test,label){for(let i=0;i<100;i++){const v=test();if(v)return v;await sleep(50)}throw Error('Timeout: '+label)}
(async()=>{let a,b,c;try{
 a=await connect();b=await connect();c=await connect();
 a.send({type:'create'});const joined=await until(()=>a.messages.find(m=>m.type==='joined'),'create');assert.match(joined.code,/^[0-9A-F]{6}$/);assert.equal(joined.side,0);
 b.send({type:'join',code:'ZZZZZZ'});await until(()=>b.messages.find(m=>m.type==='error'),'invalid room');
 b.send({type:'join',code:joined.code});await until(()=>a.messages.find(m=>m.type==='start')&&b.messages.find(m=>m.type==='start'),'two players');assert.equal(b.messages.find(m=>m.type==='joined').side,1);
 c.send({type:'join',code:joined.code});await until(()=>c.messages.find(m=>m.type==='error'),'full room');
 a.send({type:'play',index:0,x:250,y:550});
 await until(()=>a.messages.some(m=>m.type==='state'&&m.state.units.length===1)&&b.messages.some(m=>m.type==='state'&&m.state.units.length===1),'synchronized summon');
 let s=a.messages.filter(m=>m.type==='state').at(-1).state;assert.equal(s.units[0].side,0);assert.equal(s.hands[0][0],'skeleton');
 b.send({type:'play',index:0,x:450,y:350});await until(()=>a.messages.some(m=>m.type==='state'&&m.state.units.length===2),'second client summon');
 const before=b.messages.length;b.send({type:'play',index:1,x:250,y:550,side:0});await until(()=>b.messages.slice(before).find(m=>m.type==='error'),'spoofed side cannot deploy on opponent half');
 a.send({type:'play',index:'bad',x:250,y:550});a.send({type:'play',index:999,x:250,y:550});a.send({type:'ability',x:null,y:550});
 await sleep(250);const states=a.messages.filter(m=>m.type==='state');const shared=states.find(m=>b.messages.some(n=>n.type==='state'&&JSON.stringify(n.state)===JSON.stringify(m.state)));assert(shared,'clients receive identical authoritative snapshots');
 b.socket.close();const ended=await until(()=>a.messages.find(m=>m.type==='ended'),'disconnect');assert.equal(ended.state.winner,0);
 c.send({type:'join',code:joined.code});await until(()=>c.messages.filter(m=>m.type==='error').length>=2,'expired room removed');
 console.log('MUTABLE_ROOMS_OK create, invalid/full room, two clients, authoritative play, side spoof, malformed commands, synchronized snapshots, disconnect, cleanup');
 }finally{for(const client of [a,b,c])if(client)client.socket.close()}})().catch(e=>{console.error(e);process.exitCode=1});
