import test from 'node:test';
import assert from 'node:assert/strict';
import {Game,TOWERS,makePuzzle,countSolutions,sudokuLegal,buildRoute} from '../dist/game/simulation.js';

const tickUntil=(game,predicate,limit=300)=>{for(let i=0;i<limit&&!predicate();i++)game.update(1);assert.ok(predicate(),`Expected state before ${limit}s; got ${game.phase}, ${game.enemies.length} enemies`);};
const blank=game=>game.board.findIndex(n=>!n);

test('seeded puzzles are deterministic, valid and have exactly one solution',()=>{
  for(const seed of ['gridfall-01','deck','controller','sudoku-7',921]){
    const a=makePuzzle(seed),b=makePuzzle(seed);assert.deepEqual(a,b);assert.equal(a.solution.length,81);assert.ok(a.board.filter(n=>!n).length>=40);assert.equal(countSolutions(a.board),1);
    for(let cell=0;cell<81;cell++){assert.ok(sudokuLegal(a.solution,cell,a.solution[cell]));assert.equal(a.givens[cell],Boolean(a.board[cell]));}
  }
  assert.notDeepEqual(makePuzzle('a').board,makePuzzle('b').board);
});

test('free solves earn currency once, lock towers, and reject incorrect attempts',()=>{
  const g=new Game('economy'),cell=blank(g),n=g.solution[cell],money=g.credits;
  assert.equal(g.place(cell,n%9+1).ok,false);assert.equal(g.credits,money);assert.equal(g.towers.length,0);
  assert.equal(g.place(cell,n).ok,true);assert.equal(g.credits,money+3);assert.equal(g.inventory[n],1);assert.equal(g.solvedCount,1);assert.equal(g.towers[0].illegal,false);
  const earned=g.credits;assert.equal(g.place(cell,n).ok,false);assert.equal(g.credits,earned);assert.equal(g.solvedCount,1);
  assert.equal(g.place(g.givens.findIndex(Boolean),1).ok,false);assert.equal(g.towers.length,1);
});

test('purchase inventory and emergency placements charge corruption without solve rewards',()=>{
  const g=new Game('emergency'),cell=blank(g),wrong=g.solution[cell]%9+1,money=g.credits,def=TOWERS[wrong-1];
  assert.equal(g.buy(wrong).ok,true);assert.equal(g.credits,money-def.cost);assert.equal(g.inventory[wrong],2);
  g.startBattle();const balance=g.credits;
  assert.equal(g.place(cell,wrong).ok,true);assert.equal(g.inventory[wrong],1);assert.equal(g.corruption,1);assert.equal(g.credits,balance);assert.equal(g.solvedCount,0);assert.equal(g.towers[0].illegal,true);
  g._finishWave();assert.equal(g.board[cell],0);assert.equal(g.towers.length,0);assert.equal(g.phase,'reward');
  g.nextWave();assert.equal(g.phase,'solve');assert.equal(g.wave,2);assert.equal(g.timer,60);assert.equal(g.corruption,0);
});

test('correct combat pieces persist and combat routes lock until the next solve phase',()=>{
  const g=new Game('persistence'),cell=blank(g),n=g.solution[cell];g.startBattle();const route=JSON.stringify(g.route);assert.ok(g.place(cell,n).ok);assert.equal(g.inventory[n],0);assert.equal(g.solvedCount,1);assert.equal(JSON.stringify(g.route),route);
  g._finishWave();assert.equal(g.board[cell],n);assert.equal(g.towers.length,1);g.nextWave();assert.deepEqual(g.route,buildRoute([cell]));
});

test('recent moves produce connected, nonzero roads that cannot intersect any tower square',()=>{
  assert.notDeepEqual(buildRoute([2,40,74]),buildRoute([8,29,57]));
  for(const history of [[],[0],[80],[2,40,74],[74,40,2],Array.from({length:81},(_,i)=>i)]){
    const road=buildRoute(history);assert.equal(road[0].y,-.5);assert.equal(road.at(-1).y,8.5);
    for(let i=1;i<road.length;i++){
      const a=road[i-1],b=road[i];assert.ok(a.x===b.x||a.y===b.y);assert.notDeepEqual(a,b);
      // Every straight segment has one fixed half-integer coordinate. It cannot
      // hit an integer cell center even after all 81 cells become occupied.
      const fixed=a.x===b.x?a.x:a.y;assert.equal(Math.abs(fixed%1),.5);
      for(let c=0;c<81;c++){const x=c%9,y=c/9|0;assert.ok(!(a.x===b.x&&x===a.x&&y>=Math.min(a.y,b.y)&&y<=Math.max(a.y,b.y)));assert.ok(!(a.y===b.y&&y===a.y&&x>=Math.min(a.x,b.x)&&x<=Math.max(a.x,b.x)));}
    }
  }
});

function scenario(number){
  const g=new Game('effects');g.phase='battle';g._waveCount=100;g._spawnClock=100;g.towers=[{id:100,cell:40,number,illegal:false,cooldown:0}];
  g.enemies=[{id:1,x:4.5,y:4,hp:100,maxHp:100,kind:'grunt',progress:5,slowTime:0,poisonTime:0,poisonDps:0,speed:0},{id:2,x:4.9,y:4,hp:100,maxHp:100,kind:'grunt',progress:4.5,slowTime:0,poisonTime:0,poisonDps:0,speed:0},{id:3,x:4.5,y:4.5,hp:100,maxHp:100,kind:'grunt',progress:4,slowTime:0,poisonTime:0,poisonDps:0,speed:0}];
  g.drainEvents();return g;
}

test('the nine tower types each have their advertised gameplay effect',()=>{
  assert.equal(TOWERS.length,9);assert.equal(new Set(TOWERS.map(t=>t.name)).size,9);
  const pulse=scenario(1);pulse._fire(pulse.towers[0],pulse.enemies[0]);assert.equal(pulse.enemies[0].hp,94);assert.equal(pulse.enemies[1].hp,100);assert.ok(TOWERS[0].cooldown<TOWERS[1].cooldown);
  const frost=scenario(2);frost._fire(frost.towers[0],frost.enemies[0]);assert.ok(frost.enemies[0].slowTime>2);
  const arc=scenario(3);arc._fire(arc.towers[0],arc.enemies[0]);assert.ok(arc.enemies.every(e=>e.hp<100));assert.ok(arc.drainEvents().filter(e=>e.type==='shot').length>=3);
  const mortar=scenario(4);mortar._fire(mortar.towers[0],mortar.enemies[0]);assert.ok(mortar.enemies.every(e=>e.hp===87));
  const prism=scenario(5);prism._fire(prism.towers[0],prism.enemies[0]);assert.equal(prism.enemies[0].hp,88);assert.equal(prism.enemies[1].hp,88);assert.equal(prism.enemies[2].hp,100);
  const venom=scenario(6);venom._fire(venom.towers[0],venom.enemies[0]);assert.equal(venom.enemies[0].poisonTime,4);assert.equal(venom.enemies[0].poisonDps,6);
  const beacon=scenario(7);beacon._fire(beacon.towers[0],beacon.enemies[0]);assert.equal(beacon.enemies[0].hp,92);beacon.towers.push({id:101,cell:41,number:1,cooldown:10,illegal:false});beacon._step(.1);assert.ok(Math.abs(beacon.towers[1].cooldown-9.87)<1e-6);
  const gravity=scenario(8);const before=gravity.enemies.map(e=>e.progress);gravity._fire(gravity.towers[0],gravity.enemies[0]);assert.ok(gravity.enemies.some((e,i)=>e.progress<before[i]));
  const nova=scenario(9);nova._fire(nova.towers[0],nova.enemies[0]);assert.ok(nova.enemies.every(e=>e.hp===78));
});

test('solve timer starts combat automatically and an undefended run can lose',()=>{
  const g=new Game('loss');for(let i=0;i<60;i++)g.update(1);assert.equal(g.phase,'battle');
  tickUntil(g,()=>g.phase==='reward'||g.phase==='lost');assert.ok(g.health<20);
  if(g.phase==='reward'){g.nextWave();g.startBattle();tickUntil(g,()=>g.phase==='lost');}
  assert.equal(g.phase,'lost');assert.equal(g.health,0);assert.ok(g.drainEvents().some(e=>e.type==='lose'));
});

test('a fully solved board supports a complete five-wave win without route blockage',()=>{
  const g=new Game('victory');for(let cell=0;cell<81;cell++)if(!g.board[cell])assert.ok(g.place(cell,g.solution[cell]).ok);
  assert.equal(g.solvedCount,43);assert.equal(g.towers.length,43);
  for(let wave=1;wave<=5;wave++){assert.equal(g.wave,wave);g.startBattle();tickUntil(g,()=>g.phase!=='battle');assert.notEqual(g.phase,'lost');if(wave<5){assert.equal(g.phase,'reward');g.nextWave();}}
  assert.equal(g.phase,'won');assert.ok(g.health>0);assert.ok(g.kills>50);assert.ok(g.score>10000);assert.ok(g.drainEvents().some(e=>e.type==='win'));
});

test('hint builds a real persistent tower and reset removes all run state',()=>{
  const g=new Game('hint');const result=g.hint();assert.ok(result.ok);assert.equal(g.board[result.cell],result.number);assert.equal(g.solvedCount,1);assert.equal(g.credits,21);g.startBattle();g.update(5);g.reset('fresh');assert.equal(g.phase,'solve');assert.equal(g.health,20);assert.equal(g.enemies.length,0);assert.equal(g.towers.length,0);assert.equal(g.solvedCount,0);assert.equal(g.corruption,0);
});
