/**
 * Gridfall's deterministic, renderer-independent simulation. Coordinates are board
 * columns/rows (0..8). Roads run in the gaps at half coordinates, so a completed
 * Sudoku can never sever the route. update() accepts elapsed seconds.
 *
 * Solve placements require no inventory: a correct blank becomes a permanent
 * tower and pays once. Buying pieces adds combat inventory. In battle any blank
 * can hold a purchased piece; incorrect/conflicting ones are temporary, add
 * corruption, and disappear after the wave. Correct battle entries persist.
 */
export const TOWERS = [
  {number:1,name:'Pulse',color:'#6de8ff',cost:5,description:'Rapid bolts · dependable single-target fire.',range:1.85,damage:6,cooldown:.38},
  {number:2,name:'Frost',color:'#a4c7ff',cost:6,description:'Chilling shots slow enemies by 48%.',range:2.1,damage:5,cooldown:.8},
  {number:3,name:'Arc',color:'#c6a0ff',cost:8,description:'Lightning jumps through three nearby enemies.',range:2.1,damage:8,cooldown:.9},
  {number:4,name:'Mortar',color:'#ffae68',cost:8,description:'Explosive shells strike an area.',range:2.7,damage:13,cooldown:1.35},
  {number:5,name:'Prism',color:'#fb86c3',cost:9,description:'A piercing beam burns enemies along its line.',range:2.8,damage:12,cooldown:1.1},
  {number:6,name:'Venom',color:'#9be878',cost:7,description:'Toxic bolts deal lingering damage.',range:2.05,damage:4,cooldown:.9},
  {number:7,name:'Beacon',color:'#ffe188',cost:9,description:'Fires radiant bolts; nearby towers attack 30% faster.',range:2.15,damage:8,cooldown:.9},
  {number:8,name:'Gravity',color:'#bb9bff',cost:10,description:'A gravity well pulls a cluster backward.',range:2.3,damage:7,cooldown:1.6},
  {number:9,name:'Nova',color:'#ff7289',cost:12,description:'A powerful burst hits every enemy in range.',range:2.15,damage:22,cooldown:2.4},
];
const clamp = (n,a,b)=>Math.max(a,Math.min(b,n));
const xy = cell=>({x:cell%9,y:Math.floor(cell/9)});
const distance = (a,b)=>Math.hypot(a.x-b.x,a.y-b.y);
const colorFor = number=>TOWERS[number-1].color;
function hashSeed(seed) {let h=2166136261;for(const c of String(seed)) {h^=c.charCodeAt(0);h=Math.imul(h,16777619);}return h>>>0;}
function randomGenerator(seed) {let a=hashSeed(seed);return ()=>{a|=0;a=a+0x6D2B79F5|0;let t=Math.imul(a^a>>>15,1|a);t=t+Math.imul(t^t>>>7,61|t)^t;return ((t^t>>>14)>>>0)/4294967296;};}
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
export function makePuzzle(seed='gridfall') {
  const rng=randomGenerator(seed),bands=shuffled([0,1,2],rng),stacks=shuffled([0,1,2],rng);
  const rows=bands.flatMap(b=>shuffled([0,1,2],rng).map(r=>3*b+r));
  const cols=stacks.flatMap(b=>shuffled([0,1,2],rng).map(c=>3*b+c));
  const digits=shuffled([1,2,3,4,5,6,7,8,9],rng);
  const solution=rows.flatMap(r=>cols.map(c=>digits[(r*3+Math.floor(r/3)+c)%9]));
  const board=[...solution];let removed=0;
  for(const i of shuffled(Array.from({length:81},(_,i)=>i),rng)){const n=board[i];board[i]=0;if(countSolutions(board)!==1)board[i]=n;else removed++;if(removed>=43)break;}
  return {solution,board,givens:board.map(Boolean)};
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
  constructor(seed='gridfall-01') {this.reset(seed);}
  reset(seed=this.seed||'gridfall-01') {
    this.seed=seed;this.rng=randomGenerator(seed);Object.assign(this,makePuzzle(seed));
    this.phase='solve';this.wave=1;this.timer=60;this.solveDuration=60;this.credits=24;this.health=20;this.score=0;this.combo=0;this.corruption=0;this.solvedCount=0;this.kills=0;
    this.inventory=Object.fromEntries(TOWERS.map(t=>[t.number,1]));this.towers=[];this.enemies=[];this.projectiles=[];this.recentMoves=[];this.route=buildRoute();this.events=[];
    this._nextId=1;this._clock=0;this._spawnClock=0;this._spawned=0;this._waveCount=0;this._battleTime=0;this._rewarded=new Set();this._unitsRewarded=new Set();this._routeDistances=[];this._cacheRoute();
    this._emit('phase',{phase:'solve',text:'Build your defense. Solve the grid.'});return this;
  }
  _emit(type,data={}) {this.events.push({type,...data});if(this.events.length>400)this.events.splice(0,this.events.length-400);}
  drainEvents() {const events=this.events;this.events=[];return events;}
  _invalid(message,cell) {this._emit('invalid',{cell,text:message,...(Number.isInteger(cell)?xy(cell):{}),color:'#ff7289'});return {ok:false,message};}
  candidates(cell) {if(this.board[cell])return [];return TOWERS.map(t=>t.number).filter(n=>sudokuLegal(this.board,cell,n));}
  place(cell,number) {
    cell=Number(cell);number=Number(number);
    if(!Number.isInteger(cell)||cell<0||cell>=81||!Number.isInteger(number)||number<1||number>9)return this._invalid('Choose a square and a number.');
    if(this.phase!=='solve'&&this.phase!=='battle')return this._invalid('Continue to the next wave first.',cell);
    if(this.board[cell])return this._invalid(this.givens[cell]?'Printed clues cannot be changed.':'That square already has a tower.',cell);
    const correct=this.solution[cell]===number,legal=sudokuLegal(this.board,cell,number),illegal=!correct||!legal;
    if(this.phase==='solve'&&!correct){this.combo=0;this._emit('invalid',{cell,...xy(cell),color:'#ff7289',text:'Not this square. Try another number.'});return {ok:false,message:'That number does not solve this square.'};}
    if(this.phase==='battle'&&!(this.inventory[number]>0))return this._invalid(`Buy a ${TOWERS[number-1].name} piece first.`,cell);
    if(this.phase==='battle')this.inventory[number]--;
    this.board[cell]=number;
    this.towers.push({id:this._nextId++,cell,number,illegal,cooldown:this.rng()*.2});
    if(illegal){this.corruption++;this._emit('place',{cell,...xy(cell),number,illegal:true,color:colorFor(number),text:'+1 corruption'});}
    else {
      this.solvedCount++;this.recentMoves.push(cell);if(this.recentMoves.length>12)this.recentMoves.shift();
      if(!this._rewarded.has(cell)){this._rewarded.add(cell);this.combo++;const earned=3+Math.min(3,Math.floor((this.combo-1)/3));this.credits+=earned;this.score+=100+Math.min(300,(this.combo-1)*25);this._emit('place',{cell,...xy(cell),number,illegal:false,color:colorFor(number),text:`+${earned} coins`,combo:this.combo});this._checkUnitRewards(cell);}
      // A combat route is locked for the whole wave so existing enemies never
      // teleport. A correct combat entry reshapes the following wave instead.
      if(this.phase==='solve'){this.route=buildRoute(this.recentMoves);this._cacheRoute();this._emit('path',{cell,...xy(cell)});}
    }
    return {ok:true,message:illegal?'Emergency tower deployed. Corruption strengthens new enemies.':'Tower built. Grid solved one step further.',illegal};
  }
  _checkUnitRewards(cell) {
    const r=cell/9|0,c=cell%9,b=(r/3|0)*3+(c/3|0);
    const units=[['r'+r,Array.from({length:9},(_,i)=>r*9+i)],['c'+c,Array.from({length:9},(_,i)=>i*9+c)],['b'+b,Array.from({length:9},(_,i)=>(Math.floor(b/3)*3+Math.floor(i/3))*9+(b%3*3+i%3))]];
    for(const [key,cells] of units)if(!this._unitsRewarded.has(key)&&cells.every(i=>this.board[i]===this.solution[i])){this._unitsRewarded.add(key);this.credits+=8;this.score+=300;this._emit('combo',{cell,...xy(cell),color:'#ffe188',text:'Unit complete · +8 coins'});}
  }
  buy(number) {
    const t=TOWERS[Number(number)-1];if(!t)return this._invalid('Choose a piece to buy.');
    if(!['solve','battle','reward'].includes(this.phase))return this._invalid('Start a new run to buy pieces.');
    if(this.credits<t.cost)return this._invalid(`Need ${t.cost} coins for ${t.name}.`);
    this.credits-=t.cost;this.inventory[t.number]++;this._emit('buy',{number:t.number,color:t.color,text:`${t.name} piece added`});return {ok:true,message:`Bought one ${t.name} piece.`};
  }
  hint() {
    if(this.phase!=='solve')return this._invalid('Hints are available during the solve phase.');
    if(this.credits<6)return this._invalid('A hint costs 6 coins.');
    const blanks=this.board.map((n,i)=>!n?i:-1).filter(i=>i>=0);if(!blanks.length)return this._invalid('The entire grid is already solved.');
    const cell=blanks.sort((a,b)=>this.candidates(a).length-this.candidates(b).length)[0];
    this.credits-=6;const result=this.place(cell,this.solution[cell]);return {...result,cell,number:this.solution[cell]};
  }
  startBattle() {
    if(this.phase!=='solve')return {ok:false,message:'A wave is already active.'};
    this.phase='battle';this.timer=0;this.route=buildRoute(this.recentMoves);this._cacheRoute();this._spawned=0;this._spawnClock=.7;this._battleTime=0;this._waveCount=9+this.wave*3;this.enemies=[];
    this._emit('wave',{wave:this.wave,text:`WAVE ${this.wave}`,color:'#ffae68'});this._emit('phase',{phase:'battle',text:'Defend the grid!'});return {ok:true,message:'Wave started.'};
  }
  nextWave() {
    if(this.phase!=='reward')return {ok:false,message:'Finish the current wave first.'};
    this.wave++;this.phase='solve';this.timer=60;this.combo=0;this.corruption=Math.max(0,this.corruption-1);this.route=buildRoute(this.recentMoves);this._cacheRoute();this._emit('phase',{phase:'solve',text:`Wave ${this.wave}: strengthen your grid.`});return {ok:true,message:'The next solve phase has begun.'};
  }
  _cacheRoute() {this._routeDistances=[0];for(let i=1;i<this.route.length;i++)this._routeDistances.push(this._routeDistances[i-1]+distance(this.route[i-1],this.route[i]));this.routeLength=this._routeDistances.at(-1)||1;}
  _position(enemy) {const p=clamp(enemy.progress,0,this.routeLength);let i=1;while(i<this._routeDistances.length-1&&this._routeDistances[i]<p)i++;const a=this.route[i-1],b=this.route[i],span=this._routeDistances[i]-this._routeDistances[i-1],t=span?(p-this._routeDistances[i-1])/span:0;enemy.x=a.x+(b.x-a.x)*t;enemy.y=a.y+(b.y-a.y)*t;}
  _spawn() {
    const n=this._spawned++,boss=this.wave===5&&n===this._waveCount-1;
    const kind=boss?'boss':n%7===5?'tank':n%4===2?'runner':n%5===3?'swarm':'grunt';
    const baseHp=21+this.wave*10, factor=kind==='boss'?9:kind==='tank'?2.5:kind==='swarm'?.58:kind==='runner'?.72:1;
    const waveScaling=[1,1.35,1.9,2.7,3.7][this.wave-1]||3.7;
    const hp=baseHp*factor*waveScaling*(1+this.corruption*.075);
    const enemy={id:this._nextId++,x:this.route[0].x,y:this.route[0].y,hp,maxHp:hp,kind,progress:0,speed:(kind==='runner'?1.5:kind==='tank'?.57:kind==='boss'?.49:.86)*(1+this.wave*.045),slowTime:0,poisonTime:0,poisonDps:0};
    this.enemies.push(enemy);this._emit('spawn',{x:enemy.x,y:enemy.y,kind,color:kind==='boss'?'#ff547d':'#f2a273'});
  }
  _damage(enemy,amount,color,quiet=false) {
    if(enemy.hp<=0)return;enemy.hp-=amount;
    if(!quiet)this._emit('hit',{x:enemy.x,y:enemy.y,color,amount});
    if(enemy.hp<=0){this.kills++;this.score+=Math.round(enemy.maxHp*2);this.credits+=enemy.kind==='boss'?15:enemy.kind==='tank'?2:1;this._emit('kill',{x:enemy.x,y:enemy.y,color,text:enemy.kind==='boss'?'+15':'+1',kind:enemy.kind});}
  }
  _fire(tower,target) {
    const def=TOWERS[tower.number-1],origin=xy(tower.cell),power=tower.illegal?.84:1;
    this._emit('shot',{...origin,cell:tower.cell,number:tower.number,targetX:target.x,targetY:target.y,color:def.color,illegal:tower.illegal});
    const damage=(e,n)=>this._damage(e,n*power,def.color);
    switch(tower.number){
      case 1:damage(target,def.damage);break;
      case 2:damage(target,def.damage);target.slowTime=Math.max(target.slowTime,2.1);break;
      case 3:{let current=target;const used=new Set();for(let i=0;i<3&&current;i++){used.add(current.id);damage(current,def.damage*(1-i*.17));const last=current;current=this.enemies.filter(e=>e.hp>0&&!used.has(e.id)&&distance(e,last)<1.55).sort((a,b)=>distance(a,last)-distance(b,last))[0];if(current)this._emit('shot',{x:last.x,y:last.y,targetX:current.x,targetY:current.y,color:def.color,number:3});}break;}
      case 4:for(const e of this.enemies)if(e.hp>0&&distance(e,target)<1.05)damage(e,def.damage);this._emit('explosion',{x:target.x,y:target.y,color:def.color,radius:1.05,number:4});break;
      case 5:{const dx=target.x-origin.x,dy=target.y-origin.y,len=Math.hypot(dx,dy)||1;for(const e of this.enemies){const ex=e.x-origin.x,ey=e.y-origin.y,along=(ex*dx+ey*dy)/len,across=Math.abs(ex*dy-ey*dx)/len;if(e.hp>0&&along>-.1&&along<=def.range+.3&&across<.36)damage(e,def.damage);}break;}
      case 6:damage(target,def.damage);target.poisonTime=4;target.poisonDps=Math.max(target.poisonDps,6*power);break;
      case 7:damage(target,def.damage);break;
      case 8:for(const e of this.enemies)if(e.hp>0&&distance(e,target)<1.25){damage(e,def.damage);e.progress=Math.max(0,e.progress-(e.kind==='boss'?.14:.56));e.slowTime=Math.max(e.slowTime,.65);this._position(e);}this._emit('explosion',{x:target.x,y:target.y,color:def.color,radius:1.25,number:8});break;
      case 9:for(const e of this.enemies)if(e.hp>0&&distance(e,origin)<=def.range)damage(e,def.damage);this._emit('explosion',{...origin,color:def.color,radius:def.range,number:9});break;
    }
  }
  update(dt) {
    if(!Number.isFinite(dt)||dt<=0)return;
    // Substeps keep targeting and status damage stable at low display frame rates.
    let remaining=Math.min(dt,10);while(remaining>1e-8){const step=Math.min(remaining,.05);this._step(step);remaining-=step;}
  }
  _step(dt) {
    this._clock+=dt;
    if(this.phase==='solve'){this.timer=Math.max(0,this.timer-dt);if(this.timer<=1e-7)this.startBattle();return;}
    if(this.phase!=='battle')return;
    this._battleTime+=dt;this._spawnClock-=dt;
    if(this._spawned<this._waveCount&&this._spawnClock<=0){this._spawn();this._spawnClock=Math.max(.38,1.0-this.wave*.075);}
    for(const e of this.enemies){if(e.hp<=0)continue;if(e.poisonTime>0){e.poisonTime=Math.max(0,e.poisonTime-dt);this._damage(e,e.poisonDps*dt,'#9be878',true);}if(e.hp<=0)continue;const slow=e.slowTime>0?.52:1;e.slowTime=Math.max(0,e.slowTime-dt);e.progress+=e.speed*slow*dt;this._position(e);if(e.progress>=this.routeLength){e.hp=0;this.health-=e.kind==='boss'?5:e.kind==='tank'?2:1;this._emit('leak',{x:e.x,y:e.y,text:'CORE HIT',color:'#ff7289'});}}
    if(this.health<=0){this.health=0;this.phase='lost';this._emit('lose',{text:'The core fell.',color:'#ff7289'});this._emit('phase',{phase:'lost'});return;}
    for(const tower of this.towers){const origin=xy(tower.cell),def=TOWERS[tower.number-1];const buff=this.towers.some(other=>other.number===7&&other.id!==tower.id&&distance(xy(other.cell),origin)<=2.2)?1.3:1;tower.cooldown-=dt*buff;if(tower.cooldown>0)continue;const target=this.enemies.filter(e=>e.hp>0&&distance(e,origin)<=def.range).sort((a,b)=>b.progress-a.progress)[0];if(target){this._fire(tower,target);tower.cooldown=def.cooldown;}else tower.cooldown=0;}
    this.enemies=this.enemies.filter(e=>e.hp>0);
    if(this._spawned>=this._waveCount&&!this.enemies.length)this._finishWave();
  }
  _finishWave() {
    for(const tower of this.towers)if(tower.illegal)this.board[tower.cell]=0;
    this.towers=this.towers.filter(t=>!t.illegal);const bonus=12+this.wave*3;this.credits+=bonus;this.score+=500+this.health*10;this.lastWaveBonus=bonus;
    this.phase=this.wave>=5?'won':'reward';this._emit(this.phase==='won'?'win':'waveComplete',{wave:this.wave,color:'#ffe188',text:this.phase==='won'?'GRID SECURED':`Wave clear · +${bonus} coins`});this._emit('phase',{phase:this.phase});
  }
}
