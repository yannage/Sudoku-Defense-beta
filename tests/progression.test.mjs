import test from 'node:test';
import assert from 'node:assert/strict';
import {Game,countSolutions} from '../dist/game/simulation.js';

/** A deterministic approximation for tuning, not a claim of human play balance.
 * Only ten correct answers per map. Prefer cells with fewest candidates, spend
 * available credits on balanced families, fit the strongest collected gear,
 * use one available buff per kind, and buy affordable run passives. */
function tenSolvePolicy(seed,difficulty){
  let game=new Game(seed,{mode:'campaign',sudokuDifficulty:difficulty,combatDifficulty:difficulty});
  const checkpoints=[];
  while(game.phase==='solve'){
    assert.equal(countSolutions(game.board),1);
    for(let i=0;i<10;i++){
      const cell=game.board.map((n,c)=>!n?c:-1).filter(c=>c>=0).sort((a,b)=>game.candidates(a).length-game.candidates(b).length)[0];
      assert.ok(game.place(cell,game.solution[cell]).ok);
    }
    for(let i=0;i<60;i++){
      const n=Object.keys(game.familyLevels).sort((a,b)=>game.familyLevels[a]-game.familyLevels[b])[0];
      if(game.familyUpgradeCost(n)>game.credits-30)break;
      assert.ok(game.upgradeFamily(n).ok);
    }
    assert.ok(game.endSolve().ok);
    let towerIndex=0;
    for(const item of [...game.items].filter(i=>i.type==='attachment').sort((a,b)=>b.power-a.power)){
      let attempts=0;while(game.towers[towerIndex%game.towers.length].attachments.length>=5&&attempts++<game.towers.length)towerIndex++;
      if(attempts>=game.towers.length)break;
      assert.ok(game.equipItem(game.towers[towerIndex++%game.towers.length].cell,item.id).ok);
    }
    assert.ok(game.startBattle().ok);
    for(const kind of ['overclock','overcharge','freeze']){const item=game.items.find(i=>i.kind===kind);if(item)assert.ok(game.useItem(item.id).ok);}
    // Reload in the middle of every fifth battle: progression and loot must
    // remain playable beyond one map and beyond one browser session.
    game.update(2.3);if(game.wave%5===0)game=Game.fromSave(JSON.stringify(game.exportSave()));
    let time=0;while(game.phase==='battle'&&time++<300)game.update(1);
    assert.notEqual(game.phase,'battle','A battle should settle without deadlock');
    if([1,10,25,50].includes(game.wave))checkpoints.push({wave:game.wave,hp:game.health,phase:game.phase});
    if(game.phase==='loot'){
      for(const chest of [...game.chests].sort((a,b)=>a.cost-b.cost))game.openChest(chest.id);
      for(const item of [...game.items].filter(i=>i.kind==='repair'))if(game.health<game.maxHealth)game.useItem(item.id);
      for(const passive of ['power','vitality','salvage'])if(game.passives[passive]<3&&game.credits>=game.passiveCost(passive))assert.ok(game.buyPassive(passive).ok);
      assert.ok(game.nextWave().ok);
    }
  }
  return {game,checkpoints};
}

for(const difficulty of ['easy','medium'])test(`50-round ${difficulty} expedition is winnable with ten solves, earned gear, family upgrades and save/resume`,()=>{
  const {game,checkpoints}=tenSolvePolicy(`ten-${difficulty}-a`,difficulty);
  assert.equal(game.phase,'won');assert.equal(game.wave,50);assert.equal(game.solvedCount,500);assert.ok(game.health>0);assert.ok(game.kills>1000);assert.equal(checkpoints.length,4);
  assert.ok(Object.values(game.familyLevels).some(n=>n>5));assert.ok(game.items.length>0);
  assert.ok(game.credits>=0);assert.ok(game.fragments>=0);assert.ok(game.towers.every(t=>t.attachments.length<=5));
  const allGear=[...game.items,...game.towers.flatMap(t=>t.attachments)];assert.equal(new Set(allGear.map(i=>i.id)).size,allGear.length);
});

test('ten solves without investing or equipping eventually loses, so progression has mechanical value',()=>{
  const game=new Game('no-invest-10');
  while(game.phase==='solve'){
    for(let i=0;i<10;i++){const cell=game.board.findIndex(n=>!n);game.place(cell,game.solution[cell]);}
    game.endSolve();game.startBattle();for(let i=0;i<300&&game.phase==='battle';i++)game.update(1);
    if(game.phase==='loot')game.nextWave();
  }
  assert.equal(game.phase,'lost');assert.ok(game.wave>5&&game.wave<30);assert.equal(game.health,0);
});
