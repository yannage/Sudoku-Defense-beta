import test from 'node:test';
import assert from 'node:assert/strict';
import {RARITIES,ATTACHMENTS,CONSUMABLES,SLOT_COST,SLOT_PAYTABLE,generateItem,generateAttachment,itemDescription,rollRarity,rollChest,rollSlot} from '../dist/game/items.js';

function seeded(seed=1337) {
  let state=seed>>>0;
  return ()=>{state=(Math.imul(state,1664525)+1013904223)>>>0;return state/4294967296;};
}
const sequence=(...values)=>{let index=0;return ()=>values[index++%values.length];};

test('the loot catalogue has five ordered rarities, nine modules, and four consumables',()=>{
  assert.deepEqual(RARITIES.map(r=>r.id),['common','uncommon','rare','epic','legendary']);
  assert.equal(ATTACHMENTS.length,9);assert.equal(CONSUMABLES.length,4);
  assert.equal(new Set([...ATTACHMENTS,...CONSUMABLES].map(def=>def.id)).size,13);
  for(let i=1;i<RARITIES.length;i++){
    assert.ok(RARITIES[i].multiplier>RARITIES[i-1].multiplier);
    assert.ok(RARITIES[i].fragmentCost>RARITIES[i-1].fragmentCost);
  }
});

test('all generated items have the contract shape and repeat exactly for a seed',()=>{
  const a=seeded(21),b=seeded(21),seen=new Set();
  for(let i=0;i<2000;i++){
    const rarity=RARITIES[i%5].id;
    const first=generateItem(a,rarity,i%50+1,`item-${i}`);
    assert.deepEqual(first,generateItem(b,rarity,i%50+1,`item-${i}`));
    assert.deepEqual(Object.keys(first).sort(),['color','description','id','kind','name','power','rarity','type']);
    const definitions=first.type==='attachment'?ATTACHMENTS:CONSUMABLES;
    assert.ok(definitions.some(def=>def.id===first.kind));
    assert.ok(first.power>0);assert.equal(first.description,itemDescription(first));
    assert.equal(first.rarity,rarity);assert.ok(first.name.length>8);
    if(['rare','epic','legendary'].includes(rarity))assert.equal(first.type,'attachment');
    seen.add(first.kind);
  }
  assert.equal(seen.size,13);
});

test('module stat rolls have useful rarity ranges and bounded round scaling',()=>{
  for(const rarity of RARITIES){
    const low=generateItem(sequence(.8,0,0,0,0),rarity.id,1,'low');
    const high=generateItem(sequence(.8,0,.99999,0,0),rarity.id,50,'high');
    assert.ok(Math.abs(low.power-rarity.multiplier*.9)<.006);
    assert.ok(Math.abs(high.power-rarity.multiplier*1.1*1.294)<.006);
    assert.ok(high.power>low.power);
  }
  assert.equal(generateItem(sequence(.8,0,.5), 'epic',10000).power,generateItem(sequence(.8,0,.5),'epic',50).power);
  assert.equal(generateItem(sequence(.8,0,.5), 'common',-10).power,generateItem(sequence(.8,0,.5),'common',1).power);
});

test('descriptions expose actual scalar effects and fixed consumable durations',()=>{
  assert.match(itemDescription({kind:'rapid',type:'attachment',power:2}),/\+40% attack speed/);
  assert.match(itemDescription({kind:'power',type:'attachment',power:2}),/\+50% bolt damage/);
  assert.match(itemDescription({kind:'range',type:'attachment',power:2}),/\+0.56 cells/);
  assert.match(itemDescription({kind:'electric',type:'attachment',power:2}),/3 extra targets/);
  assert.match(itemDescription({kind:'frost',type:'attachment',power:10}),/70% for 2 seconds/);
  assert.match(itemDescription({kind:'venom',type:'attachment',power:2}),/60% bolt damage per second for 3 seconds/);
  assert.match(itemDescription({kind:'overclock',type:'consumable'}),/2× as fast for 20 seconds/);
  assert.match(itemDescription({kind:'freeze',type:'consumable'}),/60% slower for 12 seconds/);
  assert.match(itemDescription({kind:'repair',type:'consumable'}),/10 core health/);
});

test('rarity rolls use the documented distribution and luck changes it monotonically',()=>{
  const rng=seeded(87212),counts=Object.fromEntries(RARITIES.map(r=>[r.id,0])),samples=100000;
  for(let i=0;i<samples;i++)counts[rollRarity(rng)]++;
  const expected=[.58,.27,.10,.04,.01];
  RARITIES.forEach((rarity,i)=>assert.ok(Math.abs(counts[rarity.id]/samples-expected[i])<.007));
  const ordered=RARITIES.map(r=>r.id);
  for(let i=0;i<1000;i++){
    const draw=i/1000;
    assert.ok(ordered.indexOf(rollRarity(()=>draw,1))>=ordered.indexOf(rollRarity(()=>draw,0)));
  }
  assert.equal(rollRarity(()=>0),'common');assert.equal(rollRarity(()=>.999999),'legendary');
});

test('chests preserve identity and charge the exact rarity fragment cost',()=>{
  const a=seeded(902),b=seeded(902);
  for(let i=0;i<100;i++){
    const chest=rollChest(a,35,`chest-${i}`,.4);
    assert.deepEqual(chest,rollChest(b,35,`chest-${i}`,.4));
    assert.equal(chest.id,`chest-${i}`);
    assert.equal(chest.cost,RARITIES.find(r=>r.id===chest.rarity).fragmentCost);
  }
});

test('slots have a 95% credit return, 55% stake recovery, and equipment for every shortfall',()=>{
  assert.equal(SLOT_COST,10);
  assert.ok(Math.abs(SLOT_PAYTABLE.reduce((sum,outcome)=>sum+outcome.probability,0)-1)<1e-9);
  assert.ok(Math.abs(SLOT_PAYTABLE.reduce((sum,outcome)=>sum+outcome.credits*outcome.probability,0)-9.5)<1e-9);
  const probability=predicate=>SLOT_PAYTABLE.filter(predicate).reduce((sum,p)=>sum+p.probability,0);
  assert.ok(Math.abs(probability(p=>p.credits>=SLOT_COST)-.55)<1e-9);
  assert.ok(Math.abs(probability(p=>p.credits>SLOT_COST)-.25)<1e-9);
  assert.ok(Math.abs(probability(p=>p.gearRarity)-.45)<1e-9);
  assert.ok(Math.abs(probability(p=>p.chestRarity)-.05)<1e-9);
  for(const prize of SLOT_PAYTABLE){
    assert.ok(prize.credits>=SLOT_COST||prize.gearRarity==='common');
    if(prize.chestRarity)assert.equal(prize.credits,SLOT_COST);
  }
});

test('every slot probability boundary and reel category matches the advertised prize',()=>{
  let cumulative=0;
  for(const prize of SLOT_PAYTABLE){
    const upper=cumulative+Math.round(prize.probability*1000);
    for(const draw of [cumulative/1000,(cumulative+upper)/2000,(upper-.00001)/1000]){
      let calls=0;const result=rollSlot(()=>{calls++;return draw;});
      assert.equal(result.outcomeId,prize.id);assert.equal(result.credits,prize.credits);
      assert.equal(result.chestRarity,prize.chestRarity);assert.equal(result.gearRarity,prize.gearRarity);
      assert.deepEqual(result.reels,[prize.symbol,prize.symbol,prize.symbol]);
      assert.equal(calls,1);assert.doesNotMatch(result.message,/no prize/i);
    }
    cumulative=upper;
  }
  assert.equal(cumulative,1000);
});

test('seeded slot outcomes follow advertised credit, equipment, and chest frequencies',()=>{
  const a=seeded(770),b=seeded(770),samples=100000;
  let credits=0,chests=0,gear=0,stakeBack=0,profits=0;
  for(let i=0;i<samples;i++){
    const result=rollSlot(a);
    if(i<100)assert.deepEqual(result,rollSlot(b));
    credits+=result.credits;if(result.chestRarity)chests++;
    if(result.gearRarity)gear++;
    if(result.credits>=SLOT_COST)stakeBack++;
    if(result.credits>SLOT_COST)profits++;
    assert.ok(result.credits||result.gearRarity||result.chestRarity);
  }
  assert.ok(Math.abs(credits/samples-9.5)<.15);
  for(const [count,expected] of [[chests,.05],[gear,.45],[stakeBack,.55],[profits,.25]])assert.ok(Math.abs(count/samples-expected)<.007);
});

test('consolation generation always produces reusable common gear with bounded round power',()=>{
  const a=seeded(65),b=seeded(65);
  for(const round of [1,50])for(let n=0;n<9;n++){
    let calls=0;const rng=sequence((n+.5)/9,.999999,.2,.7);
    const item=generateAttachment(()=>{calls++;return rng();},'common',round,`gear-${round}-${n}`);
    assert.equal(calls,4);assert.equal(item.type,'attachment');assert.equal(item.kind,ATTACHMENTS[n].id);
    assert.equal(item.rarity,'common');assert.equal(item.description,itemDescription(item));
    assert.ok(item.power>=.9&&item.power<=1.43);
    assert.equal(item.power,round===1?1.1:1.42);
    assert.deepEqual(generateAttachment(a,'common',round),generateAttachment(b,'common',round));
  }
  assert.equal(generateAttachment(()=>0).type,'attachment');
  assert.equal(generateAttachment(()=>.999999,'common',999).power,generateAttachment(()=>.999999,'common',50).power);
});

test('loot rejects invalid RNGs and unknown rarity instead of creating corrupt items',()=>{
  assert.throws(()=>generateItem(()=>.5,'mythical'),/Unknown rarity/);
  assert.throws(()=>rollRarity(()=>1),/Random values/);
  assert.throws(()=>rollSlot(()=>NaN),/Random values/);
});
