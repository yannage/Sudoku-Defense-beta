/** Deterministic, renderer-independent Sudoku roguelite simulation.
 * Coordinates are board cells; routes use half-cell gutters and cannot be
 * blocked by towers. Gameplay state and the RNG are serializable mid-battle.
 */
import {RARITIES,generateItem,rollRarity,rollChest,rollSlot} from './items.js';
export const DIFFICULTIES={
  easy:{clues:48,solveDuration:120,hp:.75,speed:.9,count:.85,reward:.9},
  medium:{clues:36,solveDuration:100,hp:1,speed:1,count:1,reward:1},
  hard:{clues:27,solveDuration:90,hp:1.3,speed:1.1,count:1.18,reward:1.25},
};
const COLORS=['#6de8ff','#a4c7ff','#c6a0ff','#ffae68','#fb86c3','#9be878','#ffe188','#bb9bff','#ff7289'];
export const TOWERS=COLORS.map((color,i)=>({number:i+1,name:`Seed ${i+1}`,color,cost:6,description:'Basic bolt tower. Add up to five stackable attachments.',range:2.25,damage:8,cooldown:.75}));
const ACTIVE_PHASES=['solve','prep','battle','loot'];
const GEAR_PHASES=['prep','loot','won'];
const CHEST_PRICES={common:30,uncommon:50,rare:90,epic:160,legendary:280};
const EFFECT_KINDS=['nova','gravity','electric','blast','venom','frost','rapid','power','range'];
const clone=value=>JSON.parse(JSON.stringify(value));
const isDifficulty=value=>Object.hasOwn(DIFFICULTIES,value);
const clamp = (n,a,b)=>Math.max(a,Math.min(b,n));
const xy = cell=>({x:cell%9,y:Math.floor(cell/9)});
const distance = (a,b)=>Math.hypot(a.x-b.x,a.y-b.y);
const colorFor = number=>TOWERS[number-1].color;
function hashSeed(seed) {let h=2166136261;for(const c of String(seed)) {h^=c.charCodeAt(0);h=Math.imul(h,16777619);}return h>>>0;}
function randomGenerator(seed,state) {
  let a=state===undefined?hashSeed(seed):state>>>0;
  const rng=()=>{a=(a+0x6D2B79F5)>>>0;let t=Math.imul(a^a>>>15,1|a);t=t+Math.imul(t^t>>>7,61|t)^t;return ((t^t>>>14)>>>0)/4294967296;};
  rng.getState=()=>a>>>0;return rng;
}
function shuffled(a,rng) {a=[...a];for(let i=a.length-1;i>0;i--){const j=Math.floor(rng()*(i+1));[a[i],a[j]]=[a[j],a[i]];}return a;}
export function sudokuLegal(board,cell,number) {
  const r=Math.floor(cell/9),c=cell%9,br=Math.floor(r/3)*3,bc=Math.floor(c/3)*3;
  for(let i=0;i<9;i++) if(r*9+i!==cell&&board[r*9+i]===number||i*9+c!==cell&&board[i*9+c]===number)return false;
  for(let y=br;y<br+3;y++)for(let x=bc;x<bc+3;x++)if(y*9+x!==cell&&board[y*9+x]===number)return false;
  return true;
}
/** Count at most limit solutions using most-constrained-first search. */
export function countSolutions(input,limit=2) {
  const b=[...input],rows=new Uint16Array(9),cols=new Uint16Array(9),boxes=new Uint16Array(9);let count=0;
  for(let i=0;i<81;i++){const n=b[i];if(!n)continue;const r=i/9|0,c=i%9,k=(r/3|0)*3+(c/3|0),bit=1<<n;if((rows[r]|cols[c]|boxes[k])&bit)return 0;rows[r]|=bit;cols[c]|=bit;boxes[k]|=bit;}
  const search=()=>{if(count>=limit)return;let cell=-1,mask=0,best=10;
    for(let i=0;i<81;i++)if(!b[i]){const r=i/9|0,c=i%9,k=(r/3|0)*3+(c/3|0),m=1022&~(rows[r]|cols[c]|boxes[k]);let bits=m,n=0;while(bits){bits&=bits-1;n++;}if(!n)return;if(n<best){best=n;cell=i;mask=m;if(n===1)break;}}
    if(cell===-1){count++;return;}const r=cell/9|0,c=cell%9,k=(r/3|0)*3+(c/3|0);
    for(let n=1;n<=9;n++)if(mask&(1<<n)){const bit=1<<n;b[cell]=n;rows[r]|=bit;cols[c]|=bit;boxes[k]|=bit;search();rows[r]^=bit;cols[c]^=bit;boxes[k]^=bit;b[cell]=0;if(count>=limit)return;}
  };search();return count;
}
/** All three clue densities retain exactly one solution. Clue count describes
 * puzzle density rather than a human-technique difficulty rating. */
export function makePuzzle(seed='gridfall',difficulty='medium') {
  if(typeof difficulty==='object')difficulty=difficulty.sudokuDifficulty||'medium';
  const target=DIFFICULTIES[difficulty]?.clues||36;
  let best;
  // Hard removals can reach a locally minimal puzzle; deterministic retries
  // find the requested clue density without sacrificing uniqueness.
  for(let attempt=0;attempt<12;attempt++){
    const rng=randomGenerator(`${seed}:puzzle:${attempt}`),bands=shuffled([0,1,2],rng),stacks=shuffled([0,1,2],rng);
    const rows=bands.flatMap(b=>shuffled([0,1,2],rng).map(r=>3*b+r));
    const cols=stacks.flatMap(b=>shuffled([0,1,2],rng).map(c=>3*b+c));
    const digits=shuffled([1,2,3,4,5,6,7,8,9],rng);
    const solution=rows.flatMap(r=>cols.map(c=>digits[(r*3+Math.floor(r/3)+c)%9]));
    const board=[...solution];let clues=81;
    for(const i of shuffled(Array.from({length:81},(_,i)=>i),rng)){
      const n=board[i];board[i]=0;
      if(countSolutions(board)!==1)board[i]=n;else clues--;
      if(clues<=target)break;
    }
    const result={solution,board,givens:board.map(Boolean)};
    if(!best||clues<best.board.filter(Boolean).length)best=result;
    if(clues===target)return result;
  }
  return best;
}
/** Roads are orthogonal gaps. The newest move in each horizontal band steers
 * that band's turn, while move order also alters the entrance lane. */
export function buildRoute(recentMoves=[]) {
  const points=[];const add=(x,y)=>{const last=points.at(-1);if(!last||last.x!==x||last.y!==y)points.push({x,y});};
  const newest=recentMoves.at(-1),entry=newest===undefined?.5:clamp(newest%9-.5,.5,7.5);
  add(entry,-.5);let x=entry;
  for(let band=0;band<3;band++){
    const move=[...recentMoves].reverse().find(cell=>Math.floor(cell/27)===band);
    const y=move===undefined?band*3+1.5:Math.floor(move/9)+.5;
    // Place a turn on the side of this band opposite its previous turn. Move
    // columns change that side's depth; route vertices stay between squares.
    const base=move===undefined?(band%2?1:7):move%9;
    let nextX=base+.5;
    if(Math.abs(nextX-x)<2)nextX=x<4?7.5:.5;
    add(x,y);add(nextX,y);x=nextX;
  }
  add(x,8.5);add(8.5,8.5);
  return points;
}


export class Game {
  constructor(seed='gridfall-01',options={}){this.reset(seed,options);}
  reset(seed=this.seed||'gridfall-01',options={}){
    this.seed=String(seed);this.rng=randomGenerator(this.seed);
    this.mode=['campaign','freeplay','locked'].includes(options.mode)?options.mode:'campaign';
    this.sudokuDifficulty=isDifficulty(options.sudokuDifficulty)?options.sudokuDifficulty:'medium';
    this.combatDifficulty=isDifficulty(options.combatDifficulty)?options.combatDifficulty:'medium';
    this.lockedDifficulties={sudokuDifficulty:this.sudokuDifficulty,combatDifficulty:this.combatDifficulty};
    this.maxWaves=this.mode==='freeplay'?1:50;this.wave=1;this.credits=40;this.health=30;this.maxHealth=30;
    this.score=0;this.combo=0;this.corruption=0;this.solvedCount=0;this.kills=0;this.fragments=0;
    this.inventory=Object.fromEntries(TOWERS.map(t=>[t.number,1]));
    this.familyLevels=Object.fromEntries(TOWERS.map(t=>[t.number,1]));
    this.passives={power:0,salvage:0,vitality:0};this.chests=[];this.items=[];this.activeEffects=[];
    this.towers=[];this.enemies=[];this.projectiles=[];this.events=[];this._nextId=1;this._clock=0;
    this._newBoard();return this;
  }
  _newBoard(){
    Object.assign(this,makePuzzle(`${this.seed}:round:${this.wave}`,this.sudokuDifficulty));
    this.phase='solve';this.solveDuration=DIFFICULTIES[this.sudokuDifficulty].solveDuration;this.timer=this.solveDuration;
    this.towers=[];this.enemies=[];this.projectiles=[];this.recentMoves=[];this.route=buildRoute();
    this.combo=0;this.corruption=0;this.roundSolvedCount=0;this._spawnClock=0;this._spawned=0;this._waveCount=0;this._battleTime=0;
    this._waveSettled=false;this._rewarded=new Set();this._unitsRewarded=new Set();this._cacheRoute();
    this._emit('phase',{phase:'solve',text:`Round ${this.wave}/${this.maxWaves} · plant your defense.`});
  }
  _emit(type,data={}){this.events.push({type,...data});if(this.events.length>400)this.events.splice(0,this.events.length-400);}
  drainEvents(){const events=this.events;this.events=[];return events;}
  _invalid(message,cell){this._emit('invalid',{cell,text:message,...(Number.isInteger(cell)?xy(cell):{}),color:'#ff7289'});return {ok:false,message};}
  _getTower(cellOrTower){return typeof cellOrTower==='object'?this.towers.find(t=>t===cellOrTower||t.id===cellOrTower?.id):this.towers.find(t=>t.cell===Number(cellOrTower));}
  _luck(){return Math.min(.65,.01*this.passives.salvage+(this.sudokuDifficulty==='hard'?.1:this.sudokuDifficulty==='medium'?.03:0)+.003*(this.wave-1));}
  candidates(cell){if(!Number.isInteger(cell)||cell<0||cell>=81||this.board[cell])return [];return TOWERS.map(t=>t.number).filter(n=>sudokuLegal(this.board,cell,n));}
  place(cell,number){
    cell=Number(cell);number=Number(number);
    if(!Number.isInteger(cell)||cell<0||cell>=81||!Number.isInteger(number)||number<1||number>9)return this._invalid('Choose a square and a number.');
    if(!['solve','battle'].includes(this.phase))return this._invalid('Plant seeds during solve or battle.',cell);
    if(this.board[cell])return this._invalid(this.givens[cell]?'Printed clues cannot be changed.':'Select this tower to inspect or upgrade it.',cell);
    const correct=this.solution[cell]===number,legal=sudokuLegal(this.board,cell,number),illegal=!correct||!legal;
    if(this.phase==='solve'&&!correct){this.combo=0;return this._invalid('That number does not solve this square.',cell);}
    if(this.phase==='battle'&&!(this.inventory[number]>0))return this._invalid(`Buy a Seed ${number} reserve first.`,cell);
    if(this.phase==='battle')this.inventory[number]--;
    this.board[cell]=number;
    const tower={id:this._nextId++,cell,number,illegal,cooldown:this.rng()*.2,level:1,attachments:[],growth:0};this.towers.push(tower);
    this._emit('seed',{cell,...xy(cell),number,color:colorFor(number),illegal});
    if(illegal){this.corruption++;this._emit('place',{cell,...xy(cell),number,illegal:true,color:colorFor(number),text:'+1 corruption'});}
    else {
      this.solvedCount++;this.roundSolvedCount++;this.recentMoves.push(cell);if(this.recentMoves.length>12)this.recentMoves.shift();
      if(!this._rewarded.has(cell)){
        this._rewarded.add(cell);
        if(this._usingHint){this.combo=0;this._emit('place',{cell,...xy(cell),number,illegal:false,color:colorFor(number),text:'Hint seed · −6 credits',combo:0});}
        else {
          this.combo++;
          const earned=3+Math.min(3,Math.floor((this.combo-1)/3))+(this.sudokuDifficulty==='hard'?1:0);
          this.credits+=earned;this.score+=100+Math.min(300,(this.combo-1)*25);
          this._emit('place',{cell,...xy(cell),number,illegal:false,color:colorFor(number),text:`+${earned} credits`,combo:this.combo});
        }
        this._checkUnitRewards(cell,!this._usingHint);
      }
      // The combat route is locked: new battle placements cannot teleport mobs.
      if(this.phase==='solve'){this.route=buildRoute(this.recentMoves);this._cacheRoute();this._emit('path',{cell,...xy(cell)});}
    }
    return {ok:true,message:illegal?'Emergency seed planted. Corruption strengthens new enemies.':'Seed planted. Select the tower to upgrade it.',illegal,cell};
  }
  _checkUnitRewards(cell,award=true){
    const r=cell/9|0,c=cell%9,b=(r/3|0)*3+(c/3|0);
    const units=[['r'+r,Array.from({length:9},(_,i)=>r*9+i)],['c'+c,Array.from({length:9},(_,i)=>i*9+c)],['b'+b,Array.from({length:9},(_,i)=>(Math.floor(b/3)*3+Math.floor(i/3))*9+(b%3*3+i%3))]];
    for(const [key,cells] of units)if(!this._unitsRewarded.has(key)&&cells.every(i=>this.board[i]===this.solution[i])){
      this._unitsRewarded.add(key);if(award){this.credits+=8;this.score+=300;this._emit('combo',{cell,...xy(cell),color:'#ffe188',text:'Unit complete · +8 credits'});}
    }
  }
  buy(number){
    const def=TOWERS[Number(number)-1];if(!def)return this._invalid('Choose a reserve seed.');
    if(!ACTIVE_PHASES.includes(this.phase))return this._invalid('Start a new run to buy seeds.');
    if(this.credits<def.cost)return this._invalid(`Need ${def.cost} credits for ${def.name}.`);
    this.credits-=def.cost;this.inventory[def.number]++;
    this._emit('buy',{number:def.number,color:def.color,text:`${def.name} reserve added`});return {ok:true,message:`Bought one ${def.name} reserve.`};
  }
  hint(){
    if(this.phase!=='solve')return this._invalid('Hints are available during solve.');
    if(this.credits<6)return this._invalid('A hint costs 6 credits.');
    const blanks=this.board.map((n,i)=>!n?i:-1).filter(i=>i>=0);if(!blanks.length)return this._invalid('The entire grid is already solved.');
    const cell=blanks.sort((a,b)=>this.candidates(a).length-this.candidates(b).length)[0];
    this.credits-=6;this._usingHint=true;
    try {const result=this.place(cell,this.solution[cell]);return {...result,cell,number:this.solution[cell],message:'Hint seed planted for 6 credits. No solve rewards.'};}
    finally {delete this._usingHint;}
  }
  endSolve(){
    if(this.phase!=='solve')return this._invalid('War prep follows the solve phase.');
    this.phase='prep';this.timer=0;this.route=buildRoute(this.recentMoves);this._cacheRoute();
    this._emit('phase',{phase:'prep',text:'War prep · equip towers and open caches. No time limit.'});return {ok:true,message:'War prep started. Equip attachments, then launch the wave.'};
  }
  startBattle(){
    if(this.phase!=='prep')return this._invalid('Finish solving and enter war prep before launching.');
    this.phase='battle';this.timer=0;this._spawned=0;this._spawnClock=.7;this._battleTime=0;this.enemies=[];
    this._waveCount=Math.round((12+Math.floor(this.wave*.58))*DIFFICULTIES[this.combatDifficulty].count);
    this._emit('wave',{wave:this.wave,text:`ROUND ${this.wave}`,color:'#ffae68'});this._emit('phase',{phase:'battle',text:'Defend the grid!'});return {ok:true,message:'Wave started.'};
  }
  nextWave(options={}){
    if(this.phase!=='loot')return this._invalid('Clear the current round and collect loot first.');
    if(this.wave>=this.maxWaves)return this._invalid('This run is complete.');
    const nextSudoku=options.sudokuDifficulty||this.sudokuDifficulty,nextCombat=options.combatDifficulty||this.combatDifficulty;
    if(!isDifficulty(nextSudoku)||!isDifficulty(nextCombat))return this._invalid('Choose easy, medium, or hard.');
    if(this.mode==='locked'&&(nextSudoku!==this.lockedDifficulties.sudokuDifficulty||nextCombat!==this.lockedDifficulties.combatDifficulty))return this._invalid('Locked In keeps your starting difficulties for all 50 rounds.');
    for(const tower of this.towers)this.items.push(...tower.attachments);
    this.sudokuDifficulty=nextSudoku;this.combatDifficulty=nextCombat;this.wave++;this._newBoard();
    return {ok:true,message:`Round ${this.wave}: a fresh Sudoku. All attachments returned to your bag.`};
  }
  towerStats(cellOrTower){
    // Accept a read-only draft for equipment previews; mutations still resolve owned towers.
    const tower=cellOrTower&&typeof cellOrTower==='object'?cellOrTower:this._getTower(cellOrTower);if(!tower)return null;
    const effects={};for(const item of tower.attachments||[])effects[item.kind]=(effects[item.kind]||0)+(Number(item.power)||1);
    const level=(tower.level||1)+(this.familyLevels[tower.number]||1)-1;
    const overclock=this.activeEffects.some(e=>e.kind==='overclock'&&e.remaining>0)?2:1;
    const overcharge=this.activeEffects.some(e=>e.kind==='overcharge'&&e.remaining>0)?1.6:1;
    const damage=8*(1+.32*(level-1))*(1+.25*(effects.power||0))*(1+.09*this.passives.power)*overcharge*(tower.illegal?.84:1);
    const cooldown=.75/(1+.2*(effects.rapid||0))/overclock;
    return {level,damage,cooldown,range:Math.min(4.75,2.25+.28*(effects.range||0)),effects,attackSpeed:1/cooldown,slotsUsed:(tower.attachments||[]).length};
  }
  upgradeCost(cell){const tower=this._getTower(cell);return tower?Math.round(12+10*Math.pow(tower.level||1,1.25)):0;}
  familyUpgradeCost(number){return this.familyLevels[number]?Math.round(24+20*Math.pow(this.familyLevels[number],1.3)):0;}
  upgradeTower(cell){
    const tower=this._getTower(cell);if(!tower)return this._invalid('Select one of your planted towers.',Number(cell));
    if(!ACTIVE_PHASES.includes(this.phase))return this._invalid('Upgrades are available during an active run.');
    const cost=this.upgradeCost(tower);if(this.credits<cost)return this._invalid(`Need ${cost} credits to upgrade this tower.`,tower.cell);
    this.credits-=cost;tower.level++;this._emit('upgrade',{cell:tower.cell,...xy(tower.cell),number:tower.number,color:colorFor(tower.number),text:`Tower level ${this.towerStats(tower).level}`});
    return {ok:true,message:`Tower upgraded to level ${this.towerStats(tower).level}.`,cost};
  }
  upgradeFamily(number){
    number=Number(number);if(!this.familyLevels[number])return this._invalid('Choose a number family from 1 to 9.');
    if(!ACTIVE_PHASES.includes(this.phase))return this._invalid('Upgrades are available during an active run.');
    const cost=this.familyUpgradeCost(number);if(this.credits<cost)return this._invalid(`Need ${cost} credits to upgrade every ${number}.`);
    this.credits-=cost;this.familyLevels[number]++;
    this._emit('upgrade',{number,family:true,color:colorFor(number),text:`All ${number}s · family level ${this.familyLevels[number]}`});
    return {ok:true,message:`All current and future ${number} towers gain one level for this run.`,cost};
  }
  equipItem(cell,itemId){
    if(!GEAR_PHASES.includes(this.phase))return this._invalid('Equip attachments during war prep or loot.');
    const tower=this._getTower(cell),index=this.items.findIndex(i=>String(i.id)===String(itemId));
    if(!tower)return this._invalid('Select a planted tower to equip.',Number(cell));
    if(index<0||this.items[index].type!=='attachment')return this._invalid('Choose an attachment from your bag.');
    if(tower.attachments.length>=5)return this._invalid('All five slots are full. Remove an attachment first.',tower.cell);
    const item=this.items.splice(index,1)[0];tower.attachments.push(item);
    this._emit('equip',{cell:tower.cell,...xy(tower.cell),number:tower.number,color:item.color,text:item.name});return {ok:true,message:`${item.name} attached to Seed ${tower.number}.`,item};
  }
  unequipItem(cell,slotIndex){
    if(!GEAR_PHASES.includes(this.phase))return this._invalid('Remove attachments during war prep or loot.');
    const tower=this._getTower(cell);slotIndex=Number(slotIndex);
    if(!tower||!Number.isInteger(slotIndex)||slotIndex<0||slotIndex>=tower.attachments.length)return this._invalid('Choose an occupied attachment slot.');
    const item=tower.attachments.splice(slotIndex,1)[0];this.items.push(item);
    this._emit('equip',{cell:tower.cell,...xy(tower.cell),color:item.color,text:'Attachment returned'});return {ok:true,message:`${item.name} returned to your bag.`,item};
  }
  moveAttachment(sourceCell,slotIndex,targetCell,expectedItemId){
    if(!GEAR_PHASES.includes(this.phase))return this._invalid('Move equipment during war prep or loot camp.');
    const source=this._getTower(sourceCell),target=this._getTower(targetCell);slotIndex=Number(slotIndex);
    if(!source||!target)return this._invalid('Drop equipment on one of your planted towers.');
    if(source===target)return this._invalid('This module is already on that tower.');
    if(!Number.isInteger(slotIndex)||slotIndex<0||slotIndex>=source.attachments.length)return this._invalid('That module is no longer in this slot.');
    const item=source.attachments[slotIndex];
    if(expectedItemId!==undefined&&String(item.id)!==String(expectedItemId))return this._invalid('That slot changed. Pick up the module again.');
    if(target.attachments.length>=5)return this._invalid('Tower full. Return a module to your bag to make room.',target.cell);
    // Validate everything first: no intermediate bag state, duplication, or partial move.
    source.attachments.splice(slotIndex,1);target.attachments.push(item);
    this._emit('equip',{cell:target.cell,...xy(target.cell),sourceCell:source.cell,number:target.number,color:item.color,operation:'move',text:'MODULE TRANSFERRED'});
    return {ok:true,item,operation:'move',sourceCell:source.cell,cell:target.cell,message:`Module moved to Tower ${target.number}.`};
  }
  swapAttachment(cell,slotIndex,itemId,expectedSlotItemId){
    if(!GEAR_PHASES.includes(this.phase))return this._invalid('Swap equipment during war prep or loot camp.');
    const tower=this._getTower(cell),index=this.items.findIndex(i=>String(i.id)===String(itemId));slotIndex=Number(slotIndex);
    if(!tower||!Number.isInteger(slotIndex)||slotIndex<0||slotIndex>=tower.attachments.length)return this._invalid('Drop on an occupied module slot to replace it.');
    if(index<0||this.items[index].type!=='attachment')return this._invalid('Choose equipment from your bag.');
    const returned=tower.attachments[slotIndex],item=this.items[index];
    if(expectedSlotItemId!==undefined&&String(returned.id)!==String(expectedSlotItemId))return this._invalid('That slot changed. Pick up the module again.');
    // Replacing exchanges ownership in place, so even a full tower keeps exactly five slots.
    tower.attachments[slotIndex]=item;this.items[index]=returned;
    this._emit('equip',{cell:tower.cell,...xy(tower.cell),number:tower.number,color:item.color,operation:'swap',text:'MODULE SWAPPED'});
    return {ok:true,item,returned,operation:'swap',cell:tower.cell,message:`Module swapped. Previous equipment is back in your bag.`};
  }
  useItem(itemId){
    const index=this.items.findIndex(i=>String(i.id)===String(itemId)),item=this.items[index];
    if(!item||item.type!=='consumable')return this._invalid('Choose a consumable from your bag.');
    if(item.kind==='repair'){
      if(!ACTIVE_PHASES.includes(this.phase))return this._invalid('Repair kits are available during an active run.');
      if(this.health>=this.maxHealth)return this._invalid('The core is already at full health.');
      this.health=Math.min(this.maxHealth,this.health+10);
    }else{
      if(this.phase!=='battle')return this._invalid('Use temporary combat effects during a battle.');
      if(!['overclock','overcharge','freeze'].includes(item.kind))return this._invalid('Unknown consumable effect.');
      const duration=item.kind==='freeze'?12:20,existing=this.activeEffects.find(e=>e.kind===item.kind);
      // Re-use refreshes duration; it does not stack an unbounded multiplier.
      if(existing){existing.remaining=duration;existing.duration=duration;}
      else this.activeEffects.push({id:this._nextId++,kind:item.kind,name:item.name,remaining:duration,duration});
    }
    this.items.splice(index,1);this._emit('itemUsed',{kind:item.kind,color:item.color,text:item.name});return {ok:true,message:item.kind==='repair'?'Core repaired by up to 10 health.':`${item.name} activated.`,item};
  }
  chestPrice(rarity='common'){return Object.hasOwn(CHEST_PRICES,rarity)?CHEST_PRICES[rarity]:0;}
  _addChest(rarity,position={}){
    const spec=RARITIES.find(r=>r.id===rarity)||RARITIES[0];
    const chest={id:this._nextId++,rarity:spec.id,cost:spec.fragmentCost};this.chests.push(chest);
    this._emit('chestDrop',{...position,chestId:chest.id,rarity:chest.rarity,color:spec.color,text:`${spec.name} cache recovered`});return chest;
  }
  openChest(chestId){
    if(!GEAR_PHASES.includes(this.phase))return this._invalid('Open caches during war prep or loot.');
    const index=this.chests.findIndex(c=>String(c.id)===String(chestId)),chest=this.chests[index];
    if(!chest)return this._invalid('That cache has already been opened.');
    if(this.fragments<chest.cost)return this._invalid(`Need ${chest.cost} energy fragments to unlock this cache.`);
    this.fragments-=chest.cost;this.chests.splice(index,1);
    const count={common:1,uncommon:1,rare:2,epic:2,legendary:3}[chest.rarity]||1;
    const rewards=Array.from({length:count},()=>generateItem(this.rng,chest.rarity,this.wave,this._nextId++));this.items.push(...rewards);
    this._emit('chestOpen',{rarity:chest.rarity,color:RARITIES.find(r=>r.id===chest.rarity)?.color,text:rewards.map(i=>i.name).join(' + ')});
    return {ok:true,message:`${rewards.length} item${rewards.length===1?'':'s'} recovered.`,rewards,rarity:chest.rarity};
  }
  buyChest(rarity='common'){
    if(this.phase!=='loot')return this._invalid('Buy caches between rounds.');
    const cost=this.chestPrice(rarity);if(!cost)return this._invalid('Choose a known cache rarity.');
    if(this.credits<cost)return this._invalid(`Need ${cost} credits for this cache.`);
    this.credits-=cost;const chest=this._addChest(rarity);return {ok:true,message:'Cache purchased. Energy fragments are still required to unlock it.',chest};
  }
  passiveCost(kind){const base={power:60,salvage:50,vitality:55}[kind];return base?Math.round(base*Math.pow(1.55,this.passives[kind])):0;}
  buyPassive(kind){
    if(this.phase!=='loot')return this._invalid('Buy passive upgrades between rounds.');
    const cost=this.passiveCost(kind);if(!cost)return this._invalid('Choose power, salvage, or vitality.');
    if(this.credits<cost)return this._invalid(`Need ${cost} credits for this passive.`);
    this.credits-=cost;this.passives[kind]++;if(kind==='vitality'){this.maxHealth+=4;this.health=Math.min(this.maxHealth,this.health+4);}
    this._emit('upgrade',{color:'#ffe188',text:`${kind.toUpperCase()} ${this.passives[kind]}`});return {ok:true,message:`${kind} upgraded for this run.`,cost};
  }
  spinSlots(){
    if(this.phase!=='loot')return this._invalid('The slot machine opens between rounds.');
    if(this.credits<20)return this._invalid('A spin costs 20 credits.');
    this.credits-=20;const result=rollSlot(this.rng);this.credits+=result.credits||0;
    let chest=null;if(result.chestRarity)chest=this._addChest(result.chestRarity);
    const reward={credits:result.credits||0,chestRarity:result.chestRarity||null,chest};
    this._emit('slots',{reels:result.reels,reward,color:'#ffe188',text:result.message});return {ok:true,...result,reward};
  }
  _cacheRoute(){this._routeDistances=[0];for(let i=1;i<this.route.length;i++)this._routeDistances.push(this._routeDistances[i-1]+distance(this.route[i-1],this.route[i]));this.routeLength=this._routeDistances.at(-1)||1;}
  _position(enemy){const p=clamp(enemy.progress,0,this.routeLength);let i=1;while(i<this._routeDistances.length-1&&this._routeDistances[i]<p)i++;const a=this.route[i-1],b=this.route[i],span=this._routeDistances[i]-this._routeDistances[i-1],t=span?(p-this._routeDistances[i-1])/span:0;enemy.x=a.x+(b.x-a.x)*t;enemy.y=a.y+(b.y-a.y)*t;}
  /** Growth remains gradual across all 50 rounds; bosses appear every five. */
  waveStats(){
    const r=this.wave-1,d=DIFFICULTIES[this.combatDifficulty];
    return {health:30*(1+.12*r)*Math.pow(1.025,r)*d.hp,speed:(1+Math.min(.55,r*.011))*d.speed,count:Math.round((12+Math.floor(this.wave*.58))*d.count),spawnInterval:Math.max(.35,.94-r*.0105),boss:this.wave%5===0};
  }
  _spawn(){
    const n=this._spawned++,stats=this.waveStats(),boss=stats.boss&&n===this._waveCount-1;
    const kind=boss?'boss':n%7===5?'tank':n%4===2?'runner':n%5===3?'swarm':'grunt';
    const factor=kind==='boss'?5:kind==='tank'?2.3:kind==='swarm'?.58:kind==='runner'?.72:1;
    const hp=stats.health*factor*(1+this.corruption*.075);
    const enemy={id:this._nextId++,x:this.route[0].x,y:this.route[0].y,hp,maxHp:hp,kind,progress:0,speed:(kind==='runner'?1.4:kind==='tank'?.57:kind==='boss'?.47:.82)*stats.speed,slowTime:0,slowFactor:1,poisonTime:0,poisonDps:0};
    this.enemies.push(enemy);this._emit('spawn',{x:enemy.x,y:enemy.y,kind,color:kind==='boss'?'#ff547d':'#f2a273'});
  }
  _damage(enemy,amount,color,quiet=false){
    if(enemy.hp<=0||!Number.isFinite(amount)||amount<=0)return;enemy.hp-=amount;
    if(!quiet)this._emit('hit',{x:enemy.x,y:enemy.y,color,amount});
    if(enemy.hp<=0){
      this.kills++;this.score+=Math.round(enemy.maxHp*2);
      const credits=enemy.kind==='boss'?12:enemy.kind==='tank'?2:1;this.credits+=credits;
      const fragments=(enemy.kind==='boss'?8:enemy.kind==='tank'?2:1)+(this.rng()<Math.min(.75,.05*this.passives.salvage)?1:0);this.fragments+=fragments;
      this._emit('kill',{x:enemy.x,y:enemy.y,color,text:`+${credits}`,kind:enemy.kind});
      this._emit('fragment',{x:enemy.x,y:enemy.y,color:'#75eab8',amount:fragments,text:`+${fragments} fragments`});
      const chance=.09+(this.sudokuDifficulty==='hard'?.045:this.sudokuDifficulty==='medium'?.015:0);
      if(enemy.kind==='boss'||this.rng()<chance){
        const drop=rollChest(this.rng,this.wave,this._nextId++,this._luck());
        // rollChest owns the rarity lottery. Simulation owns inventory identity.
        this._addChest(drop.rarity,{x:enemy.x,y:enemy.y});
      }
    }
  }
  _fire(tower,target){
    const stats=this.towerStats(tower),origin=xy(tower.cell),effects=stats.effects,color=colorFor(tower.number);
    const effect=EFFECT_KINDS.find(kind=>effects[kind]>0)||'basic';
    // Presentation metadata is captured before damage can kill or displace the
    // target. It never participates in range, priority, cadence, or damage.
    tower.aimTargetId=target.id;tower.aimX=target.x;tower.aimY=target.y;
    const dx=target.x-origin.x,dy=target.y-origin.y;
    tower.aimAngle=dx*dx+dy*dy>1e-12?Math.atan2(dy,dx):(Number.isFinite(tower.aimAngle)?tower.aimAngle:0);
    this._emit('shot',{...origin,cell:tower.cell,towerId:tower.id,number:tower.number,targetId:target.id,targetX:target.x,targetY:target.y,aimAngle:tower.aimAngle,color,illegal:tower.illegal,effect,height:.4875+(tower.attachments?.length||0)*.18});
    const impact={x:target.x,y:target.y};this._damage(target,stats.damage,color);
    if(effects.frost&&target.hp>0){target.slowTime=Math.max(target.slowTime,2);target.slowFactor=Math.min(target.slowFactor||1,1-Math.min(.7,.18*effects.frost));}
    if(effects.venom&&target.hp>0){target.poisonTime=3;target.poisonDps=Math.max(target.poisonDps,.3*effects.venom*stats.damage);}
    if(effects.electric){
      let last=target;const used=new Set([target.id]);const jumps=Math.min(7,1+Math.floor(effects.electric));
      for(let i=0;i<jumps;i++){
        const next=this.enemies.filter(e=>e.hp>0&&!used.has(e.id)&&distance(e,last)<1.5+.06*effects.electric).sort((a,b)=>distance(a,last)-distance(b,last))[0];if(!next)break;
        this._emit('shot',{x:last.x,y:last.y,targetX:next.x,targetY:next.y,color:'#c6a0ff',number:tower.number,effect:'electric',height:.22});
        this._damage(next,stats.damage*Math.min(1,.3+.12*effects.electric)*Math.pow(.75,i),'#c6a0ff');used.add(next.id);last=next;
      }
    }
    if(effects.blast){
      const radius=Math.min(2.3,.65+.12*effects.blast);
      for(const enemy of this.enemies)if(enemy.id!==target.id&&enemy.hp>0&&distance(enemy,impact)<radius)this._damage(enemy,stats.damage*Math.min(3,.35*effects.blast),'#ffae68');
      this._emit('explosion',{...impact,color:'#ffae68',radius,number:tower.number,effect:'blast'});
    }
    if(effects.gravity){
      for(const enemy of this.enemies)if(enemy.hp>0&&distance(enemy,impact)<1.25){enemy.progress=Math.max(0,enemy.progress-Math.min(.8,.14*effects.gravity)*(enemy.kind==='boss'?.3:1));this._position(enemy);}
      this._emit('explosion',{...impact,color:'#bb9bff',radius:1.25,number:tower.number,effect:'gravity'});
    }
    if(effects.nova){
      for(const enemy of this.enemies)if(enemy.hp>0&&distance(enemy,origin)<=1.4)this._damage(enemy,stats.damage*Math.min(2.5,.2*effects.nova),'#ff7289');
      this._emit('explosion',{...origin,color:'#ff7289',radius:1.4,number:tower.number,effect:'nova'});
    }
  }
  update(dt){
    if(!Number.isFinite(dt)||dt<=0)return;
    let remaining=Math.min(dt,10);while(remaining>1e-8){const step=Math.min(remaining,.05);this._step(step);remaining-=step;}
  }
  _step(dt){
    this._clock+=dt;
    for(const tower of this.towers)tower.growth=Math.min(1,(tower.growth||0)+dt/ .8);
    if(this.phase==='solve'){this.timer=Math.max(0,this.timer-dt);if(this.timer<=1e-7)this.endSolve();return;}
    if(this.phase!=='battle')return;
    this._battleTime+=dt;
    for(const effect of this.activeEffects)effect.remaining=Math.max(0,effect.remaining-dt);
    this.activeEffects=this.activeEffects.filter(e=>e.remaining>0);
    this._spawnClock-=dt;
    if(this._spawned<this._waveCount&&this._spawnClock<=0){this._spawn();this._spawnClock=this.waveStats().spawnInterval;}
    const globalSlow=this.activeEffects.some(e=>e.kind==='freeze')?.4:1;
    for(const enemy of this.enemies){
      if(enemy.hp<=0)continue;
      if(enemy.poisonTime>0){enemy.poisonTime=Math.max(0,enemy.poisonTime-dt);this._damage(enemy,enemy.poisonDps*dt,'#9be878',true);}if(enemy.hp<=0)continue;
      const slow=Math.min(globalSlow,enemy.slowTime>0?(enemy.slowFactor||.52):1);enemy.slowTime=Math.max(0,enemy.slowTime-dt);if(enemy.slowTime<=0)enemy.slowFactor=1;
      enemy.progress+=enemy.speed*slow*dt;this._position(enemy);
      if(enemy.progress>=this.routeLength){enemy.hp=0;this.health-=enemy.kind==='boss'?6:enemy.kind==='tank'?2:1;this._emit('leak',{x:enemy.x,y:enemy.y,text:'CORE HIT',color:'#ff7289'});}
    }
    if(this.health<=0){this.health=0;this.phase='lost';this._emit('lose',{text:'The core fell.',color:'#ff7289'});this._emit('phase',{phase:'lost'});return;}
    for(const tower of this.towers){
      if(tower.growth<1)continue;const origin=xy(tower.cell),stats=this.towerStats(tower);tower.cooldown-=dt;if(tower.cooldown>0)continue;
      const target=this.enemies.filter(e=>e.hp>0&&distance(e,origin)<=stats.range).sort((a,b)=>b.progress-a.progress)[0];
      if(target){this._fire(tower,target);tower.cooldown=stats.cooldown;}else tower.cooldown=0;
    }
    this.enemies=this.enemies.filter(e=>e.hp>0);
    if(this._spawned>=this._waveCount&&!this.enemies.length)this._finishWave();
  }
  _finishWave(){
    // Single settlement is essential both for save/resume and overlapping ticks.
    if(this.phase!=='battle'||this._waveSettled||this._spawned<this._waveCount||this.enemies.some(e=>e.hp>0))return {ok:false,message:'The wave is not cleared.'};
    this._waveSettled=true;
    for(const tower of this.towers)if(tower.illegal){this.board[tower.cell]=0;this.items.push(...tower.attachments);}
    this.towers=this.towers.filter(t=>!t.illegal);
    const bonus=Math.round((22+this.wave*2)*DIFFICULTIES[this.combatDifficulty].reward);this.credits+=bonus;this.score+=500+this.health*10;this.lastWaveBonus=bonus;
    this.health=Math.min(this.maxHealth,this.health+3);
    // A clear always yields a locked cache; energy to open it must come from kills.
    this._addChest(rollRarity(this.rng,this._luck()));
    this.phase=this.wave>=this.maxWaves?'won':'loot';
    this._emit(this.phase==='won'?'win':'waveComplete',{wave:this.wave,color:'#ffe188',text:this.phase==='won'?'GRID SECURED':`Round clear · +${bonus} credits`});
    this._emit('phase',{phase:this.phase});return {ok:true,message:'Round cleared.',bonus};
  }
  exportSave(){
    const state={};for(const [key,value] of Object.entries(this))if(!['rng','events','_routeDistances','_rewarded','_unitsRewarded'].includes(key))state[key]=clone(value);
    return {version:2,state,rngState:this.rng.getState(),rewarded:[...this._rewarded],unitsRewarded:[...this._unitsRewarded]};
  }
  static fromSave(data){
    if(typeof data==='string')data=JSON.parse(data);
    const s=data?.state;
    if(data?.version!==2||!s||!Array.isArray(s.board)||s.board.length!==81||!Array.isArray(s.solution)||s.solution.length!==81||!Array.isArray(s.givens)||s.givens.length!==81)throw new Error('This save is incompatible. Start a new expedition.');
    if(!['solve','prep','battle','loot','won','lost'].includes(s.phase)||!['campaign','freeplay','locked'].includes(s.mode)||!isDifficulty(s.sudokuDifficulty)||!isDifficulty(s.combatDifficulty)||!Number.isInteger(s.wave)||s.wave<1||s.wave>50||!Number.isInteger(data.rngState))throw new Error('This save is incomplete.');
    for(const key of ['towers','enemies','items','chests','activeEffects','route'])if(!Array.isArray(s[key]))throw new Error('This save is missing run data.');
    if(!s.board.every(n=>Number.isInteger(n)&&n>=0&&n<=9)||!s.solution.every(n=>Number.isInteger(n)&&n>=1&&n<=9)||!s.route.every(p=>Number.isFinite(p.x)&&Number.isFinite(p.y))||s.route.length<2)throw new Error('Invalid board data.');
    for(const key of ['credits','health','maxHealth','fragments','_nextId','_clock','_spawned','_waveCount','_battleTime','timer'])if(!Number.isFinite(s[key])||s[key]<0)throw new Error('Invalid run counters.');
    if(!s.inventory||!s.familyLevels||!s.passives||!Array.isArray(data.rewarded)||!Array.isArray(data.unitsRewarded))throw new Error('Invalid inventory data.');
    const game=Object.create(Game.prototype);
    Object.assign(game,clone(s));game.rng=randomGenerator(s.seed,data.rngState);game.events=[];game._rewarded=new Set(data.rewarded);game._unitsRewarded=new Set(data.unitsRewarded);game._cacheRoute();
    return game;
  }
}
