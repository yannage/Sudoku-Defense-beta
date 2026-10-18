import test from 'node:test';
import assert from 'node:assert/strict';
import {Game} from '../dist/game/simulation.js';
const module=(id,kind='power')=>({id,type:'attachment',kind,name:kind,power:1,rarity:'common',color:'#abc',description:kind});
function kit(){
 const g=new Game('gear-transfers');for(let cell=0;cell<81&&g.towers.length<3;cell++)if(!g.board[cell])g.place(cell,g.solution[cell]);g.endSolve();
 const [a,b,c]=g.towers;g.items=[module('m1'),module('m2','rapid'),module('m3','frost'),module('m4'),module('m5'),module('m6'),module('m7')];
 g.equipItem(a.cell,'m1');g.equipItem(a.cell,'m2');return {g,a,b,c};
}
const ownership=g=>[...g.items,...g.towers.flatMap(t=>t.attachments)].map(i=>i.id).sort();
test('moving equipment transfers the exact item and preserves bag, credits, and all ownership',()=>{
 const {g,a,b}=kit(),item=a.attachments[0],before=ownership(g),bag=[...g.items],credits=g.credits;
 assert.ok(g.moveAttachment(a.cell,0,b.cell,item.id).ok);
 assert.equal(b.attachments[0],item);assert.equal(a.attachments.includes(item),false);assert.deepEqual(g.items,bag);assert.equal(g.credits,credits);assert.deepEqual(ownership(g),before);
 const restored=Game.fromSave(g.exportSave());assert.deepEqual(ownership(restored),before);assert.equal(restored.towers.find(t=>t.cell===b.cell).attachments[0].id,item.id);
});
test('occupied slot swap keeps five modules and returns the previous item exactly once',()=>{
 const {g,a}=kit();for(const id of ['m3','m4','m5'])g.equipItem(a.cell,id);
 const old=a.attachments[2],next=g.items[0],before=ownership(g),money=g.credits,bagSize=g.items.length;
 const result=g.swapAttachment(a.cell,2,next.id,old.id);assert.ok(result.ok);assert.equal(result.returned,old);assert.equal(a.attachments[2],next);assert.ok(g.items.includes(old));
 assert.equal(a.attachments.length,5);assert.equal(g.items.length,bagSize);assert.equal(g.credits,money);assert.deepEqual(ownership(g),before);
 assert.equal(g.swapAttachment(a.cell,2,next.id,old.id).ok,false);assert.deepEqual(ownership(g),before);
});
test('stale slots, invalid cells, full targets, wrong phase and consumables never partially move gear',()=>{
 const {g,a,b}=kit();for(const id of ['m3','m4','m5','m6','m7'])g.equipItem(b.cell,id);
 g.items.push(module('spare'),{...module('boost'),type:'consumable',kind:'overclock'});
 const attempts=[()=>g.moveAttachment(a.cell,0,b.cell,'m1'),()=>g.moveAttachment(a.cell,0,a.cell,'m1'),()=>g.moveAttachment(a.cell,0,999,'m1'),()=>g.moveAttachment(a.cell,0,g.towers[2].cell,'wrong'),()=>g.moveAttachment(a.cell,-1,g.towers[2].cell,'m1'),()=>g.swapAttachment(a.cell,0,'spare','stale'),()=>g.swapAttachment(a.cell,4,'spare'),()=>g.swapAttachment(a.cell,0,'boost'),()=>g.swapAttachment(a.cell,0,'missing')];
 for(const attempt of attempts){const before=g.exportSave();assert.equal(attempt().ok,false);assert.deepEqual(g.exportSave(),before);}
 for(const phase of ['solve','battle','lost']){g.phase=phase;const before=g.exportSave();assert.equal(g.moveAttachment(a.cell,0,g.towers[2].cell,'m1').ok,false);assert.equal(g.swapAttachment(a.cell,0,'spare','m1').ok,false);assert.deepEqual(g.exportSave(),before);}
});
