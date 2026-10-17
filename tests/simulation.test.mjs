import test from 'node:test';
import assert from 'node:assert/strict';
import {Game,TOWERS,DIFFICULTIES,makePuzzle,countSolutions,sudokuLegal,buildRoute} from '../dist/game/simulation.js';
import {RARITIES,generateItem} from '../dist/game/items.js';

const blank=game=>game.board.findIndex(n=>!n);
const solve=(g,limit=81)=>{let count=0;for(let cell=0;cell<81&&count<limit;cell++)if(!g.board[cell]){assert.ok(g.place(cell,g.solution[cell]).ok);count++;}return count;};
const enterBattle=g=>{assert.ok(g.endSolve().ok);assert.ok(g.startBattle().ok);};
const tickUntil=(g,predicate,limit=300)=>{for(let i=0;i<limit&&!predicate();i++)g.update(1);assert.ok(predicate(),`Expected state within ${limit}s; got ${g.phase}, ${g.enemies.length} enemies`);};
const settle=g=>{g.enemies=[];g._spawned=g._waveCount;return g._finishWave();};
const attachment=(kind,id=1000,power=1)=>({id,type:'attachment',kind,name:kind,rarity:'common',color:'#fff',power,description:kind});
const consumable=(kind,id=2000)=>({id,type:'consumable',kind,name:kind,rarity:'common',color:'#fff',power:1,description:kind});

// Clue densities are guaranteed unique; this does not claim a particular human
// solving technique or difficulty rating beyond the chosen density.
test('all Sudoku difficulties are deterministic, unique and have distinct clue counts',()=>{
  for(const difficulty of ['easy','medium','hard'])for(const seed of ['gridfall-01','deck','controller','sudoku-7',921]){
    const a=makePuzzle(seed,difficulty),b=makePuzzle(seed,difficulty);assert.deepEqual(a,b);assert.equal(a.board.filter(Boolean).length,DIFFICULTIES[difficulty].clues);assert.equal(countSolutions(a.board),1);
    for(let cell=0;cell<81;cell++){assert.ok(sudokuLegal(a.solution,cell,a.solution[cell]));assert.equal(a.givens[cell],Boolean(a.board[cell]));}
  }
  assert.notDeepEqual(makePuzzle('a').board,makePuzzle('b').board);
});

test('free solves earn credits once, plant growing towers, reject wrong answers',()=>{
  const g=new Game('economy'),cell=blank(g),n=g.solution[cell],money=g.credits;
  assert.equal(g.place(cell,n%9+1).ok,false);assert.equal(g.credits,money);assert.equal(g.towers.length,0);
  assert.equal(g.place(cell,n).ok,true);assert.equal(g.credits,money+3);assert.equal(g.inventory[n],1);assert.equal(g.solvedCount,1);assert.equal(g.towers[0].illegal,false);assert.equal(g.towers[0].growth,0);
  g.update(.8);assert.ok(g.towers[0].growth> .999);
  const earned=g.credits;assert.equal(g.place(cell,n).ok,false);assert.equal(g.credits,earned);assert.equal(g.solvedCount,1);assert.ok(g.drainEvents().some(e=>e.type==='seed'));
});

test('solve -> prep -> battle -> loot -> new puzzle is gated; prep has no timer',()=>{
  const g=new Game('phases');assert.equal(g.startBattle().ok,false);assert.equal(g.nextWave().ok,false);
  for(let i=0;i<10;i++)g.update(10);assert.equal(g.phase,'prep');g.update(10);assert.equal(g.phase,'prep');
  assert.equal(g.place(blank(g),g.solution[blank(g)]).ok,false);assert.ok(g.startBattle().ok);assert.equal(g.startBattle().ok,false);
  assert.equal(g._finishWave().ok,false);assert.ok(settle(g).ok);assert.equal(g.phase,'loot');const old=[...g.board];assert.ok(g.nextWave({sudokuDifficulty:'hard',combatDifficulty:'easy'}).ok);
  assert.equal(g.phase,'solve');assert.equal(g.wave,2);assert.equal(g.timer,90);assert.equal(g.towers.length,0);assert.notDeepEqual(g.board,old);assert.equal(g.board.filter(Boolean).length,27);assert.equal(g.combatDifficulty,'easy');assert.equal(countSolutions(g.board),1);
});

test('emergency seeds require reserves, add corruption, cannot move a live route, and return gear',()=>{
  const g=new Game('emergency'),cell=blank(g),wrong=g.solution[cell]%9+1,money=g.credits;
  assert.ok(g.buy(wrong).ok);assert.equal(g.credits,money-TOWERS[wrong-1].cost);assert.equal(g.inventory[wrong],2);
  enterBattle(g);const route=JSON.stringify(g.route),balance=g.credits;
  assert.ok(g.place(cell,wrong).ok);assert.equal(g.inventory[wrong],1);assert.equal(g.corruption,1);assert.equal(g.credits,balance);assert.equal(g.solvedCount,0);assert.equal(g.towers[0].illegal,true);assert.equal(JSON.stringify(g.route),route);
  // Recovery also protects legacy/equipped illegal towers from losing equipment.
  const gear=attachment('electric');g.towers[0].attachments.push(gear);settle(g);assert.equal(g.board[cell],0);assert.equal(g.towers.length,0);assert.deepEqual(g.items,[gear]);
  g.nextWave();assert.equal(g.corruption,0);assert.deepEqual(g.items,[gear]);
});

test('correct emergency seeds award a solve once and survive through current map loot',()=>{
  const g=new Game('combat-correct'),cell=blank(g),n=g.solution[cell];enterBattle(g);const route=JSON.stringify(g.route);
  assert.ok(g.place(cell,n).ok);assert.equal(g.inventory[n],0);assert.equal(g.solvedCount,1);assert.equal(JSON.stringify(g.route),route);
  settle(g);assert.equal(g.board[cell],n);assert.equal(g.towers.length,1);g.nextWave();assert.equal(g.towers.length,0);
});

test('move-built routes are orthogonal and never intersect a tower center',()=>{
  assert.notDeepEqual(buildRoute([2,40,74]),buildRoute([8,29,57]));
  for(const history of [[],[0],[80],[2,40,74],[74,40,2],Array.from({length:81},(_,i)=>i)]){
    const road=buildRoute(history);assert.equal(road[0].y,-.5);assert.equal(road.at(-1).y,8.5);
    for(let i=1;i<road.length;i++){const a=road[i-1],b=road[i];assert.ok(a.x===b.x||a.y===b.y);assert.notDeepEqual(a,b);const fixed=a.x===b.x?a.x:a.y;assert.equal(Math.abs(fixed%1),.5);
      for(let c=0;c<81;c++){const x=c%9,y=c/9|0;assert.ok(!(a.x===b.x&&x===a.x&&y>=Math.min(a.y,b.y)&&y<=Math.max(a.y,b.y)));assert.ok(!(a.y===b.y&&y===a.y&&x>=Math.min(a.x,b.x)&&x<=Math.max(a.x,b.x)));}
    }
  }
});

function scenario(number=1){
  const g=new Game('effects');g.phase='battle';g._waveCount=100;g._spawnClock=100;g.towers=[{id:100,cell:40,number,illegal:false,cooldown:0,level:1,attachments:[],growth:1}];
  g.enemies=[{id:1,x:4.5,y:4,hp:100,maxHp:100,kind:'grunt',progress:5,slowTime:0,poisonTime:0,poisonDps:0,speed:0},{id:2,x:4.9,y:4,hp:100,maxHp:100,kind:'grunt',progress:4.5,slowTime:0,poisonTime:0,poisonDps:0,speed:0},{id:3,x:4.5,y:4.5,hp:100,maxHp:100,kind:'grunt',progress:4,slowTime:0,poisonTime:0,poisonDps:0,speed:0}];g.drainEvents();return g;
}

test('all nine numbers fire the same base bolt and attachments add elemental effects',()=>{
  assert.equal(TOWERS.length,9);
  for(let n=1;n<=9;n++){const g=scenario(n);g._fire(g.towers[0],g.enemies[0]);assert.equal(g.enemies[0].hp,92);assert.equal(g.enemies[1].hp,100);assert.equal(g.enemies[0].slowTime,0);assert.equal(g.drainEvents().find(e=>e.type==='shot').effect,'basic');}
  const frost=scenario();frost.towers[0].attachments=[attachment('frost')];frost._fire(frost.towers[0],frost.enemies[0]);assert.equal(frost.enemies[0].slowTime,2);assert.ok(frost.enemies[0].slowFactor<1);
  const arc=scenario();arc.towers[0].attachments=[attachment('electric')];arc._fire(arc.towers[0],arc.enemies[0]);assert.ok(arc.enemies.every(e=>e.hp<100));assert.ok(arc.drainEvents().filter(e=>e.type==='shot').length>=3);
  const blast=scenario();blast.towers[0].attachments=[attachment('blast')];blast._fire(blast.towers[0],blast.enemies[0]);assert.ok(blast.enemies.every(e=>e.hp<100));
  const venom=scenario();venom.towers[0].attachments=[attachment('venom')];venom._fire(venom.towers[0],venom.enemies[0]);assert.equal(venom.enemies[0].poisonTime,3);assert.ok(venom.enemies[0].poisonDps>0);
  const gravity=scenario();gravity.towers[0].attachments=[attachment('gravity')];const before=gravity.enemies.map(e=>e.progress);gravity._fire(gravity.towers[0],gravity.enemies[0]);assert.ok(gravity.enemies.some((e,i)=>e.progress<before[i]));
  const nova=scenario();nova.towers[0].attachments=[attachment('nova')];nova._fire(nova.towers[0],nova.enemies[0]);assert.ok(nova.enemies.every(e=>e.hp<100));
});

test('individual and family levels improve current towers; family level persists across maps',()=>{
  const g=new Game('upgrades');solve(g,2);g.credits=500;const t=g.towers[0],damage=g.towerStats(t).damage;
  assert.ok(g.upgradeTower(t.cell).ok);assert.equal(g.towerStats(t).level,2);assert.ok(g.towerStats(t).damage>damage);
  assert.ok(g.upgradeFamily(t.number).ok);assert.equal(g.towerStats(t).level,3);assert.equal(g.familyLevels[t.number],2);
  const balance=g.credits;assert.equal(g.upgradeTower(100).ok,false);assert.equal(g.upgradeFamily(0).ok,false);assert.equal(g.credits,balance);
  enterBattle(g);settle(g);g.nextWave();const cell=g.board.findIndex((n,i)=>!n&&g.solution[i]===t.number);g.place(cell,t.number);assert.equal(g.towers[0].level,1);assert.equal(g.towerStats(g.towers[0]).level,2);
});

test('five attachment slots permit stacking and gear returns exactly once next map',()=>{
  const g=new Game('equipment');solve(g,1);const cell=g.towers[0].cell;g.items=Array.from({length:6},(_,i)=>attachment('rapid',i));
  assert.equal(g.equipItem(cell,0).ok,false);g.endSolve();
  for(let i=0;i<5;i++)assert.ok(g.equipItem(cell,i).ok);assert.equal(g.equipItem(cell,5).ok,false);assert.equal(g.towers[0].attachments.length,5);assert.equal(g.items.length,1);assert.equal(g.towerStats(cell).cooldown,.375);
  assert.ok(g.unequipItem(cell,2).ok);assert.equal(g.items.length,2);assert.ok(g.equipItem(cell,2).ok);
  g.startBattle();assert.equal(g.unequipItem(cell,0).ok,false);settle(g);g.nextWave();assert.equal(g.items.length,6);assert.equal(new Set(g.items.map(i=>i.id)).size,6);
  assert.equal(g.nextWave().ok,false);assert.equal(g.items.length,6);
});

test('chests require earned fragments, consume once, and produce rarity rewards',()=>{
  const g=new Game('chests');g.endSolve();const cost=RARITIES.find(r=>r.id==='rare').fragmentCost;const chest=g._addChest('rare');
  assert.equal(g.openChest(chest.id).ok,false);assert.equal(g.chests.length,1);g.fragments=cost;
  const result=g.openChest(chest.id);assert.ok(result.ok);assert.equal(result.rewards.length,2);assert.ok(result.rewards.every(i=>i.rarity==='rare'));assert.equal(g.fragments,0);assert.equal(g.chests.length,0);assert.equal(g.items.length,2);
  assert.equal(g.openChest(chest.id).ok,false);assert.equal(g.items.length,2);
  g.startBattle();const boss={id:999,x:0,y:0,hp:1,maxHp:1,kind:'boss'};g._damage(boss,2,'#fff');assert.equal(g.kills,1);assert.ok(g.fragments>=8);assert.equal(g.chests.length,1);const fragments=g.fragments;g._damage(boss,2,'#fff');assert.equal(g.fragments,fragments);assert.equal(g.kills,1);
});

test('temporary consumables only tick in battle, refresh safely, and repair does not waste at full HP',()=>{
  const g=new Game('consumables');solve(g,1);const t=g.towers[0];g.items=[consumable('overclock'),consumable('repair',2001)];
  assert.equal(g.useItem(2000).ok,false);assert.equal(g.useItem(2001).ok,false);assert.equal(g.items.length,2);
  g.health=15;assert.ok(g.useItem(2001).ok);assert.equal(g.health,25);enterBattle(g);const cooldown=g.towerStats(t).cooldown;assert.ok(g.useItem(2000).ok);assert.equal(g.towerStats(t).cooldown,cooldown/2);
  g.update(3);const time=g.activeEffects[0].remaining;assert.ok(time<18);settle(g);g.update(10);assert.equal(g.activeEffects[0].remaining,time);g.nextWave();g.update(10);assert.equal(g.activeEffects[0].remaining,time);
  enterBattle(g);g.update(10);g.update(10);assert.equal(g.activeEffects.length,0);
});

test('shops and slots are gated, debit correctly and cannot use insufficient credits',()=>{
  const g=new Game('shop');g.credits=1000;assert.equal(g.buyChest().ok,false);assert.equal(g.buyPassive('power').ok,false);assert.equal(g.spinSlots().ok,false);enterBattle(g);settle(g);
  let balance=g.credits;assert.ok(g.buyChest('common').ok);assert.equal(g.credits,balance-g.chestPrice('common'));
  balance=g.credits;const cost=g.passiveCost('power');assert.ok(g.buyPassive('power').ok);assert.equal(g.passives.power,1);assert.equal(g.credits,balance-cost);assert.ok(g.passiveCost('power')>cost);
  const max=g.maxHealth;assert.ok(g.buyPassive('vitality').ok);assert.equal(g.maxHealth,max+4);
  balance=g.credits;const spin=g.spinSlots();assert.ok(spin.ok);assert.equal(spin.reels.length,3);assert.equal(g.credits,balance-20+spin.reward.credits);
  g.credits=0;assert.equal(g.spinSlots().ok,false);assert.equal(g.buyChest('legendary').ok,false);assert.equal(g.buyPassive('power').ok,false);assert.equal(g.credits,0);
});

test('settlement cannot mint repeat clear rewards and freeplay ends after one round',()=>{
  const g=new Game('freeplay',{mode:'freeplay'});assert.equal(g.maxWaves,1);solve(g);enterBattle(g);tickUntil(g,()=>g.phase!=='battle');assert.equal(g.phase,'won');
  const balance=g.credits,score=g.score,chests=g.chests.length;assert.equal(g._finishWave().ok,false);assert.equal(g.credits,balance);assert.equal(g.score,score);assert.equal(g.chests.length,chests);assert.equal(g.nextWave().ok,false);
  if(g.chests[0]){g.fragments=999;assert.ok(g.openChest(g.chests[0].id).ok);}
});

test('Locked In rejects difficulty changes; campaign can choose each next round',()=>{
  const g=new Game('locked',{mode:'locked',sudokuDifficulty:'easy',combatDifficulty:'hard'});assert.equal(g.maxWaves,50);enterBattle(g);settle(g);
  assert.equal(g.nextWave({sudokuDifficulty:'hard'}).ok,false);assert.equal(g.wave,1);assert.equal(g.phase,'loot');assert.ok(g.nextWave().ok);assert.equal(g.sudokuDifficulty,'easy');assert.equal(g.combatDifficulty,'hard');
  const c=new Game('campaign');enterBattle(c);settle(c);assert.ok(c.nextWave({sudokuDifficulty:'hard',combatDifficulty:'easy'}).ok);assert.equal(c.combatDifficulty,'easy');
});

test('late-round combat scales beyond round five, difficulties separate health and counts',()=>{
  const g=new Game('scaling');const checkpoints=[];for(const wave of [1,5,10,25,50]){g.wave=wave;checkpoints.push(g.waveStats());}
  for(let i=1;i<checkpoints.length;i++){assert.ok(checkpoints[i].health>checkpoints[i-1].health);assert.ok(checkpoints[i].count>checkpoints[i-1].count);assert.ok(checkpoints[i].speed>checkpoints[i-1].speed);}
  assert.ok(checkpoints.at(-1).health>650);assert.equal(checkpoints.at(-1).boss,true);g.combatDifficulty='easy';const easy=g.waveStats();g.combatDifficulty='hard';const hard=g.waveStats();assert.ok(hard.health>easy.health*1.7);assert.ok(hard.count>easy.count);assert.ok(hard.speed>easy.speed);
});

test('an undefended campaign loses through normal combat',()=>{
  const g=new Game('loss');enterBattle(g);tickUntil(g,()=>g.phase!=='battle');assert.ok(g.health<g.maxHealth);
  while(g.phase==='loot'){g.nextWave();enterBattle(g);tickUntil(g,()=>g.phase!=='battle');}
  assert.equal(g.phase,'lost');assert.equal(g.health,0);assert.ok(g.drainEvents().some(e=>e.type==='lose'));
});

test('mid-battle save restores RNG, cooldowns, effects and exact future rewards',()=>{
  const g=new Game('resume');solve(g,20);g.endSolve();g.items=[attachment('electric')];g.equipItem(g.towers[0].cell,1000);g.startBattle();g.update(4.123);g.drainEvents();
  const restored=Game.fromSave(JSON.stringify(g.exportSave()));assert.deepEqual(restored.exportSave(),g.exportSave());
  for(let i=0;i<50&&g.phase==='battle';i++){g.update(.413);restored.update(.413);}
  assert.deepEqual(restored.exportSave(),g.exportSave());assert.deepEqual(restored.drainEvents(),g.drainEvents());
  g.enemies=[];g._spawned=g._waveCount;g._finishWave();const settled=Game.fromSave(g.exportSave()),balance=settled.credits;assert.equal(settled._finishWave().ok,false);assert.equal(settled.credits,balance);
});

test('saved unopened chest and slot RNG do not reroll on reload',()=>{
  const g=new Game('loot-save');enterBattle(g);settle(g);g.fragments=999;g.credits=999;const chest=g._addChest('legendary');const copy=Game.fromSave(g.exportSave());
  assert.deepEqual(g.openChest(chest.id),copy.openChest(chest.id));assert.deepEqual(g.spinSlots(),copy.spinSlots());
  const opened=Game.fromSave(g.exportSave());assert.equal(opened.openChest(chest.id).ok,false);
});

test('malformed saves are rejected and resetting clears all persistent run upgrades',()=>{
  assert.throws(()=>Game.fromSave({}));const g=new Game('reset');const bad=g.exportSave();bad.state.wave=NaN;assert.throws(()=>Game.fromSave(bad));
  solve(g,1);g.familyLevels[1]=5;g.passives.power=3;g.items=[generateItem(()=>.5,'rare',10,77)];g.fragments=99;g.reset('fresh',{mode:'freeplay',sudokuDifficulty:'easy'});
  assert.equal(g.phase,'solve');assert.equal(g.familyLevels[1],1);assert.equal(g.passives.power,0);assert.equal(g.items.length,0);assert.equal(g.fragments,0);assert.equal(g.maxWaves,1);assert.equal(g.health,30);
});

test('hints cost exactly six credits without solve rewards, combo farming or paid unit payouts',()=>{
  const g=new Game('hint-economy',{sudokuDifficulty:'hard'});solve(g,12);g.credits=1000;const before=g.credits,score=g.score;const result=g.hint();
  assert.ok(result.ok);assert.equal(g.credits,before-6);assert.equal(g.score,score);assert.equal(g.combo,0);assert.equal(g.board[result.cell],result.number);assert.equal(g.place(result.cell,result.number).ok,false);
  const blanks=g.board.filter(n=>!n).length;for(let i=0;i<blanks;i++)assert.ok(g.hint().ok);assert.equal(g.credits,before-6*(blanks+1));assert.equal(g.score,score);assert.equal(g.board.filter(n=>!n).length,0);
});
