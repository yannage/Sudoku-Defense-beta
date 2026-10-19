import {voxelArt} from './voxel-art.js';
import {RARITIES} from './game/items.js';
import {renderSlotMachine} from './slot-machine.js';
import {itemGuide, chestGuide, towerBuild} from './game/item-guide.js';

const esc = value => String(value ?? '').replace(/[&<>"']/g, char => ({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[char]));
const cap = value => String(value ?? '').replace(/^./, char => char.toUpperCase());
const number = value => Math.round(Number(value) || 0).toLocaleString();
const rarity = id => RARITIES.find(entry => entry.id === id) || RARITIES[0];
const icon = (kind, rarityId) => voxelArt(kind,{rarity:rarityId});
const phaseName = phase => ({solve:'Solve',prep:'War prep',battle:'Defense',loot:'Loot camp',won:'Run complete',lost:'Run ended'}[phase] || cap(phase));
const diffInfo = {
  sudoku: {easy:['More clues','A generous starting grid. Fewer blank squares to solve.'],medium:['Balanced grid','Less guidance. More room to grow your defense.'],hard:['Fewer clues','The most blank squares: harder logic, more potential towers and solving rewards.']},
  combat: {easy:['Room to learn','Lighter pressure while you explore your build.'],medium:['Tactical pressure','A balanced test of your route, gear and towers.'],hard:['High stakes','Stronger enemies and better combat rewards.']}
};
const descriptions = {
  campaign:'50 fresh Sudoku battlefields. Choose puzzle and combat difficulty before every new map.',
  freeplay:'One Sudoku board, one battle. A quick way to try a build or practice.',
  locked:'A 50-map expedition with your starting puzzle and combat difficulties fixed for the entire run.'
};

/** A DOM-only equipment, loot and expedition interface. Economy stays in Game. */
export class RogueUI {
  constructor({game, getSelectedCell = () => -1, onChange = () => {}, onNewRun = () => {}, onInspect = () => {}, onBoardEquip = () => {}, onSound = () => {}, isReducedMotion = () => false} = {}) {
    this.game=game; this.getSelectedCell=getSelectedCell; this.onChange=onChange; this.onNewRun=onNewRun;
    this.onInspect=onInspect; this.onBoardEquip=onBoardEquip; this.onSound=onSound; this.isReducedMotion=isReducedMotion;
    this.towerMapOpen=false;
    this.tab='inventory'; this.filter='all'; this.selectedItem=null; this.page=0; this.notice=''; this.lastKey=''; this.reveal=null; this.spin=null;
    this.options={mode:'campaign',sudokuDifficulty:'easy',combatDifficulty:'easy'};
    this.nextOptions={sudokuDifficulty:game.sudokuDifficulty||'easy',combatDifficulty:game.combatDifficulty||'easy'};
    this.dialog=document.createElement('dialog');
    this.dialog.id='rogueDialog'; this.dialog.className='rogue-dialog'; this.dialog.setAttribute('aria-labelledby','rogueTitle');
    document.body.append(this.dialog);
    this.dialog.addEventListener('click',event => this._click(event));
    this.dialog.addEventListener('change',event => this._change(event));
    this.dialog.addEventListener('cancel',event => {event.preventDefault();this.close();});
    this.dialog.addEventListener('close',()=>{this.reveal=null;this.spin=null;this.lastKey='';clearTimeout(this.revealTimer);clearTimeout(this.spinTimer);});
    document.addEventListener('keydown',event => this._keyboard(event),true);
  }

  isOpen(){return this.dialog.open;}
  open(tab='inventory'){
    if(tab==='chests'){tab='inventory';this.filter='chests';}
    if(tab!=='casino'){clearTimeout(this.spinTimer);this.spin=null;}
    this.tab=tab; this.notice=''; this.page=0;
    if(tab==='loot')this.nextOptions={sudokuDifficulty:this.game.sudokuDifficulty||'easy',combatDifficulty:this.game.combatDifficulty||'easy'};
    this.lastKey=''; this._render(); this._show();
  }
  openSetup(){
    this.options={mode:this.game.mode||'campaign',sudokuDifficulty:this.game.sudokuDifficulty||'easy',combatDifficulty:this.game.combatDifficulty||'easy'};
    this.open('setup');
  }
  close(){
    if(!this.dialog.open)return;
    this.dialog.close();
    if(this.returnFocus?.isConnected)this.returnFocus.focus({preventScroll:true});
  }
  _show(){
    if(!this.dialog.open){this.returnFocus=document.activeElement;this.dialog.showModal();}
    queueMicrotask(()=>this.dialog.querySelector('[data-initial-focus]')?.focus({preventScroll:true}));
  }
  refresh(){
    if(!this.isOpen()||this.reveal||(this.spin&&!this.spin.done))return;
    const g=this.game;
    const key=JSON.stringify([this.tab,this.filter,this.page,this.selectedItem,this.getSelectedCell(),g.phase,g.wave,g.credits,g.fragments,g.health,g.maxHealth,g.items,g.chests,g.towers?.map(t=>[t.cell,t.number,t.level,t.attachments]),g.familyLevels,g.passives,g.activeEffects?.map(e=>[e.id,Math.ceil(e.remaining)]),this.notice,this.options,this.nextOptions]);
    if(key===this.lastKey)return;
    this.lastKey=key; this._render();
  }
  tick(dt){
    // Timers run independently of the paused battlefield. Tick is available to the host.
    if(this.reveal)this.reveal.elapsed+=(Number(dt)||0);
    if(this.spin)this.spin.elapsed+=(Number(dt)||0);
  }
  _tower(){return this.game.towers?.find(tower=>tower.cell===Number(this.getSelectedCell()));}
  _call(method,...args){
    if(typeof this.game[method]!=='function')return {ok:false,message:'This action is not available yet.'};
    try{return this.game[method](...args)||{ok:false,message:'No result from this action.'};}
    catch(error){console.error(`Sudoku Defense ${method}`,error);return {ok:false,message:'That action could not be completed. Please try again.'};}
  }
  _result(result,{refresh=true}={}){
    this.notice=result?.message||''; this.noticeError=!result?.ok;
    this.onChange(result);
    if(refresh){this.lastKey='';this.refresh();}
    return result;
  }
  _wallet(){return `<div class="rg-wallet"><span title="Spend credits on seeds, upgrades and supplies"><i>${voxelArt('credit')}</i> ${number(this.game.credits)} <small>credits</small></span><span title="Enemy fragments unlock sealed chests"><i>${voxelArt('fragment')}</i> ${number(this.game.fragments)} <small>fragments</small></span></div>`;}
  _header(eyebrow,title,description=''){
    const emblem=this.reveal?'chest':({setup:'seed',inventory:'bag',tower:'tower',loot:'chest',casino:'credit'}[this.tab]||'bag');
    return `<header class="rg-header"><div class="rg-header-identity"><span class="rg-header-seal" aria-hidden="true">${voxelArt(emblem)}</span><div><div class="rg-eyebrow">${eyebrow}</div><h2 id="rogueTitle">${title}</h2>${description?`<p>${description}</p>`:''}</div></div><button type="button" class="rg-close" data-action="close" aria-label="Close menu" title="Close (Escape / B)">×</button></header>`;
  }
  _tabs(){
    return `<div class="rg-toolbar"><nav class="rg-tabs" aria-label="Run menus">${[['inventory','Inventory'],['tower','Workshop'],['loot','Loot camp'],['casino','Slots']].map(([id,label])=>`<button type="button" data-action="tab" data-tab="${id}" class="${this.tab===id?'active':''}" aria-current="${this.tab===id?'page':'false'}" data-focus="tab-${id}">${label}${id==='inventory'?` <span>${this.game.items?.length||0}</span>`:''}</button>`).join('')}</nav>${this._wallet()}</div>`;
  }
  _render(){
    const active=document.activeElement;
    const focusId=this.dialog.contains(active)?active.dataset.focus||active.id:null;
    const towerPicker=this.dialog.querySelector('.rg-tower-map-picker');
    if(towerPicker)this.towerMapOpen=towerPicker.open;
    const scroll=this.dialog.querySelector('.rg-body')?.scrollTop||0;
    const rewardScroll=this.dialog.querySelector('.rg-reward-grid')?.scrollLeft||0;
    const view=this.reveal?this._chestView():this.tab==='setup'?this._setupView():this._mainView();
    this.dialog.innerHTML=view;
    this.dialog.classList.toggle('rg-reveal-mode',Boolean(this.reveal));
    this.dialog.classList.toggle('rg-main-mode',!this.reveal&&this.tab!=='setup');
    this.dialog.classList.toggle('rg-setup-mode',!this.reveal&&this.tab==='setup');
    this.dialog.classList.toggle('rg-reduced-motion',Boolean(this.isReducedMotion()));
    if(focusId){const target=Array.from(this.dialog.querySelectorAll('[data-focus], [id]')).find(node=>node.dataset.focus===focusId||node.id===focusId);target?.focus({preventScroll:true});}
    const body=this.dialog.querySelector('.rg-body');if(body)body.scrollTop=scroll;
    const rewardGrid=this.dialog.querySelector('.rg-reward-grid');if(rewardGrid)rewardGrid.scrollLeft=rewardScroll;
  }
  _difficulty(type,value,prefix='setup',compact=false){
    return `<fieldset class="rg-difficulty ${compact?'rg-compact':''}"><legend>${type==='sudoku'?'Sudoku difficulty':'Combat difficulty'}</legend><div class="rg-choice-row">${['easy','medium','hard'].map(level=>`<button type="button" data-action="difficulty" data-prefix="${prefix}" data-type="${type}" data-value="${level}" data-focus="${prefix}-${type}-${level}" class="rg-choice ${value===level?'chosen':''}" aria-pressed="${value===level}"><strong>${cap(level)}</strong><span>${diffInfo[type][level][0]}</span></button>`).join('')}</div><p>${diffInfo[type][value]?.[1]||''}</p></fieldset>`;
  }
  _fieldScene(){
    return `<div class="rg-field-scene" aria-hidden="true"><div class="rg-scene-orbit"></div><div class="rg-scene-grid">${Array.from({length:25},(_,i)=>`<i class="${[2,7,8,13,18,17,22].includes(i)?'route':''}"></i>`).join('')}</div><span class="rg-scene-object rg-scene-seed">${voxelArt('seed')}</span><span class="rg-scene-object rg-scene-tower">${voxelArt('tower',{color:'#9fe7c0'})}</span><span class="rg-scene-object rg-scene-coil">${voxelArt('electric')}</span><span class="rg-scene-object rg-scene-cache">${voxelArt('chest',{rarity:'legendary'})}</span><span class="rg-scene-marker">SEED → SYSTEM</span><span class="rg-scene-cross rg-scene-cross-a">+</span><span class="rg-scene-cross rg-scene-cross-b">+</span></div>`;
  }
  _setupView(){
    const o=this.options;
    return `${this._header('SUDOKU DEFENSE / EXPEDITION CONTROL','Start a run','Choose a mode and your puzzle and combat difficulties.')}<div class="rg-body rg-setup-body"><section class="rg-expedition-hero"><div class="rg-hero-copy"><span class="rg-hero-stamp">THE GRID IS ALIVE</span><h3>A little logic.<br><em>A living defense.</em></h3><p>Plant your answers. Stack strange machinery. Make something worth defending.</p><span class="rg-hero-caption">SUDOKU × TOWER DEFENSE</span></div>${this._fieldScene()}</section><div class="rg-section-line rg-mode-heading"><h3>Choose your expedition</h3><span>01 / RUN TYPE</span></div><div class="rg-mode-grid">${[['campaign','01 → 50','Campaign'],['freeplay','ONE MAP','Free play'],['locked','01 → 50 · FIXED','Locked in']].map(([id,small,label])=>`<button type="button" class="rg-mode ${o.mode===id?'chosen':''}" data-action="mode" data-mode="${id}" data-focus="mode-${id}" aria-pressed="${o.mode===id}" ${id===o.mode?'data-initial-focus':''}><span class="rg-mode-icon" aria-hidden="true">${voxelArt(id==='campaign'?'tower':id==='freeplay'?'seed':'notes')}</span><small>${small}</small><strong>${label}</strong><p>${descriptions[id]}</p><span class="rg-select-dot" aria-hidden="true"></span></button>`).join('')}</div><div class="rg-setup-difficulties">${this._difficulty('sudoku',o.sudokuDifficulty)}${this._difficulty('combat',o.combatDifficulty)}</div><div class="rg-run-loop"><span><i>01</i> Solve &amp; grow</span><b>→</b><span><i>02</i> Equip your stack</span><b>→</b><span><i>03</i> Hold the line</span><b>→</b><span><i>04</i> Claim the loot</span></div><p class="rg-fineprint">Every tower starts as a seed and fires a basic bolt. Stack up to five attachments to build its identity. Your bag, number-family levels and passive upgrades carry between maps.</p></div><footer class="rg-footer"><span>${o.mode==='locked'?'Both difficulty choices stay fixed for all 50 maps.':o.mode==='freeplay'?'A complete expedition in one battlefield.':'Change either difficulty at the end of each map.'}</span><button class="rg-primary" type="button" data-action="start" data-focus="start">${o.mode==='freeplay'?'Start free play':'Begin expedition'} <b>→</b></button></footer>`;
  }
  _mainView(){
    const labels={inventory:['FIELD KIT','Inventory','Equipment stays with you. Boosts are used once.'],tower:['TOWER LAB','Tower workshop','Upgrade one tower, its entire number family, or its five attachments.'],loot:['BETWEEN BATTLES','Loot camp','Open chests, buy upgrades, and choose your next map.'],casino:['LUCKY CIRCUIT','Lucky circuit','Spin for credits, equipment, and bonus chests. Every spin has a reward.']};
    const [eyebrow,title,description]=labels[this.tab]||labels.inventory;
    return `${this._header(`${eyebrow} · MAP ${this.game.wave||1} / ${this.game.maxWaves||50}`,title,description)}${this._tabs()}<div class="rg-body">${this.notice?`<div class="rg-notice ${this.noticeError?'error':''}" role="status">${esc(this.notice)}</div>`:''}${this.tab==='tower'?this._towerView():this.tab==='loot'?this._lootView():this.tab==='casino'?this._casinoView():this._inventoryView()}</div><footer class="rg-footer"><span><b>${phaseName(this.game.phase)}</b><span class="rg-controller-hint"> · D-pad to navigate · A to choose · B to return</span></span><button class="rg-secondary" type="button" data-action="close" data-focus="return">Back to the grid <b>↗</b></button></footer>`;
  }
  _itemCard(item,{selected=false,compact=false}={}){
    const guide=itemGuide(item),boost=item.type==='consumable';
    return `<button type="button" class="rg-item-card ${selected?'selected':''} ${compact?'compact':''}" style="--loot:${guide.color}" data-action="select-item" data-item="${esc(item.id)}" data-focus="item-${esc(item.id)}" aria-pressed="${selected}"><span class="rg-item-art" aria-hidden="true">${icon(item.kind,item.rarity)}</span><span class="rg-item-copy"><small class="rg-rarity">${esc(guide.rarityName)} · ${boost?'BOOST':'EQUIPMENT'}</small><strong>${esc(guide.name)}</strong><span class="rg-card-effect">${esc(guide.effect)}</span><small class="rg-flavor">${esc(item.name)}</small></span><span class="rg-item-corner">${boost?'USE ONCE':'REUSABLE · 1 SLOT'}</span></button>`;
  }
  _inventoryView(){
    const items=this.game.items||[];
    const chests=this.game.chests||[];
    const counts={all:items.length,attachment:items.filter(i=>i.type==='attachment').length,consumable:items.filter(i=>i.type==='consumable').length,chests:chests.length};
    let list=items.filter(item=>this.filter==='all'||item.type===this.filter);
    list=[...list].sort((a,b)=>RARITIES.findIndex(r=>r.id===b.rarity)-RARITIES.findIndex(r=>r.id===a.rarity));
    const pages=Math.max(1,Math.ceil(list.length/18));this.page=Math.min(this.page,pages-1);
    const picked=list.find(item=>String(item.id)===String(this.selectedItem));
    return `<div class="rg-inventory-layout ${picked?'has-selection':''}"><section class="rg-bag"><div class="rg-section-line"><h3>Your field kit</h3><span>${items.length} items · ${chests.length} sealed</span></div><div class="rg-filters" aria-label="Filter inventory">${[['all','All items'],['attachment','Equipment'],['consumable','Boosts'],['chests','Chests']].map(([value,label])=>`<button type="button" class="${this.filter===value?'active':''}" data-action="filter" data-filter="${value}" data-focus="filter-${value}" aria-pressed="${this.filter===value}">${label} <b>${counts[value]}</b></button>`).join('')}</div>${this.filter==='chests'?this._chests():list.length?`<div class="rg-item-grid">${list.slice(this.page*18,this.page*18+18).map(item=>this._itemCard(item,{selected:String(item.id)===String(this.selectedItem)})).join('')}</div>${pages>1?`<div class="rg-pagination"><button type="button" data-action="page" data-delta="-1" ${this.page===0?'disabled':''}>← Previous</button><span>${this.page+1} / ${pages}</span><button type="button" data-action="page" data-delta="1" ${this.page===pages-1?'disabled':''}>Next →</button></div>`:''}`:`<div class="rg-empty"><span class="rg-empty-art">${voxelArt('bag')}</span><h4>Your next great find is out there.</h4><p>Defeat enemies for fragments and sealed chests. Open chests in War Prep or Loot Camp. Equipment upgrades one tower; boosts give you a one-time advantage.</p><button class="rg-secondary" type="button" data-action="filter" data-filter="chests">View sealed chests (${chests.length})</button></div>`}</section><aside class="rg-detail">${picked?`<button type="button" class="rg-text-button rg-back-items" data-action="clear-item" data-focus="clear-item">← Back to items</button>`:''}${picked?this._itemDetail(picked):this._inventoryTip()}${this._compactTower()}</aside></div>`;
  }
  _inventoryTip(){return `<section class="rg-detail-card rg-inventory-tip"><span class="rg-eyebrow">BUILD A TOWER THAT FITS THE JOB</span><h3>Pick an effect. Find its home.</h3><p><b>Equipment</b> fills one of five tower slots. Remove it freely; you keep it for the whole run.</p><div class="rg-stack-demo" aria-hidden="true"><i>${voxelArt('electric')}</i><i>${voxelArt('frost')}</i><i>${voxelArt('rapid')}</i><i>+</i><i>+</i></div><p><b>Boosts</b> are used once. Their card tells you who they affect and how long they last.</p><p class="rg-fineprint">Higher equipment rarity means more power per slot. Repeated effects combine; different effects work together. Gear returns to your bag on the next map.</p></section>`;}
  _itemDetail(item){
    const guide=itemGuide(item),tower=this._tower(),boost=item.type==='consumable';
    const canEdit=['prep','loot','won'].includes(this.game.phase);
    const canEquip=canEdit&&tower&&(tower.attachments?.length||0)<5;
    const canUse=item.kind==='repair'?['solve','prep','battle','loot'].includes(this.game.phase)&&this.game.health<this.game.maxHealth:this.game.phase==='battle';
    return `<section class="rg-detail-card" style="--loot:${guide.color}"><span class="rg-rarity">${esc(guide.rarityName)} · ${boost?'BOOST':'EQUIPMENT'}</span><div class="rg-big-glyph" aria-hidden="true">${icon(item.kind,item.rarity)}</div><h3>${esc(guide.name)}</h3><p class="rg-detail-effect">${esc(guide.effect)}</p><p class="rg-flavor">${esc(item.name)}</p><div class="rg-item-facts"><span><b>${boost?'Lasts':'Keep it'}</b>${esc(guide.lifetime)}</span><span><b>Good for</b>${esc(guide.purpose)}</span>${guide.pairWith?`<span><b>${boost?'When':'Pairing'}</b>${esc(guide.pairWith)}</span>`:''}${!boost?`<span><b>Stacking</b>${esc(guide.stack)}</span>`:''}</div>${!boost?`<div class="rg-preview-note"><strong>${tower?'On this tower':'Choose a tower to preview'}</strong>${this._preview(tower,item)}<span>Higher rarity means more effect power per slot. Remove equipment freely in War Prep or Loot Camp.</span></div><button class="rg-primary" type="button" data-action="board-equip" data-item="${esc(item.id)}" data-focus="board-equip" ${canEdit?'':'disabled'}>Equip on the board <b>↗</b></button><button class="rg-secondary" type="button" data-action="equip" data-item="${esc(item.id)}" data-focus="equip" ${canEquip?'':'disabled'}>${tower?`Equip on ${tower.number} · R${Math.floor(tower.cell/9)+1} C${tower.cell%9+1}`:'Select a tower first'} <b>+</b></button><p class="rg-fineprint">${!canEdit?'Equipment can be changed in War Prep and Loot Camp.':!tower?'Tap a tower on the board, or pick one below.':tower.attachments.length>=5?'This tower has 5 items. Remove one, or swap gear on the board.':'Your equipment stays with you for the entire run.'}</p>`:`<button class="rg-primary" type="button" data-action="use" data-item="${esc(item.id)}" data-focus="use" ${canUse?'':'disabled'}>${item.kind==='repair'?'Restore core health':'Use boost now'} <b>✦</b></button><p class="rg-fineprint">${item.kind==='repair'?(this.game.health>=this.game.maxHealth?'Your core is already at full health.':'One use. Restores up to 10 missing health.'):'One use. Activate during Defense; the timer pauses when the battle pauses.'}</p>`}</section>`;
  }
  _preview(tower,item){
    if(!tower||(tower.attachments?.length||0)>=5)return '';
    const before=this._stats(tower),after=this._stats({...tower,attachments:[...(tower.attachments||[]),item]});
    const fields=[['Bolt damage',before.damage,after.damage],['Shots / sec',before.cooldown?1/before.cooldown:0,after.cooldown?1/after.cooldown:0],['Range (cells)',before.range,after.range]];
    const effect=(stats,kind)=>Math.max(0,Number(stats.effects?.[kind])||0);
    const add=(label,read)=>fields.push([label,read(before),read(after)]);
    switch(item.kind){
      case 'frost':add('Slow (%)',s=>Math.min(70,18*effect(s,'frost')));break;
      case 'venom':add('Poison / sec',s=>s.damage*.30*effect(s,'venom'));break;
      case 'gravity':add('Pull (cells)',s=>Math.min(.8,.14*effect(s,'gravity')));break;
      case 'nova':add('Pulse damage',s=>s.damage*Math.min(2.5,.20*effect(s,'nova')));break;
      case 'blast':
        add('Splash damage',s=>s.damage*Math.min(3,.35*effect(s,'blast')));
        add('Splash radius',s=>effect(s,'blast')?Math.min(2.3,.65+.12*effect(s,'blast')):0);break;
      case 'electric':
        add('Extra targets',s=>effect(s,'electric')?Math.min(7,1+Math.floor(effect(s,'electric'))):0);
        add('First jump damage',s=>effect(s,'electric')?s.damage*Math.min(1,.30+.12*effect(s,'electric')):0);
        add('Jump reach',s=>effect(s,'electric')?1.5+.06*effect(s,'electric'):0);break;
    }
    const changed=fields.filter(([,a,b])=>Number(a).toFixed(2)!==Number(b).toFixed(2));
    if(!changed.length)return '<span class="rg-cap-note">This effect is already at its cap on this tower. Try another tower or effect.</span>';
    const format=value=>Number(Number(value).toFixed(2)).toString();
    return `<div class="rg-stat-preview">${changed.map(([label,a,b])=>`<span>${label}<b>${format(a)} <i>→</i> <strong>${format(b)}</strong></b></span>`).join('')}</div>`;
  }
  _towerSelect({compact=false}={}){
    const towers=this.game.towers||[],byCell=new Map(towers.map(tower=>[tower.cell,tower]));
    const selected=this._tower(),activeCell=selected?.cell??towers[0]?.cell;
    const label=selected?`Tower ${selected.number} · R${Math.floor(selected.cell/9)+1} C${selected.cell%9+1}`:'Choose a tower';
    const board=`<div class="rg-tower-map"><div class="rg-map-heading"><span>YOUR BATTLEFIELD</span><b>${towers.length} ${towers.length===1?'tower':'towers'}</b></div><div class="rg-map-columns" aria-hidden="true">${Array.from({length:9},(_,col)=>`<span>${col+1}</span>`).join('')}</div><div class="rg-mini-board" role="grid" aria-label="Tower map. Mint squares are your towers. Use arrow keys to select a tower, or Tab to leave the map.">${Array.from({length:9},(_,row)=>`<div role="row">${Array.from({length:9},(_,col)=>{
      const cell=row*9+col,tower=byCell.get(cell),value=this.game.board?.[cell]||0,chosen=selected?.cell===cell;
      const classes=['rg-map-cell',col===2||col===5?'block-right':'',row===2||row===5?'block-bottom':'',tower?'is-tower':value?'is-clue':'is-empty',chosen?'is-selected':'',tower?.illegal?'is-emergency':''].filter(Boolean).join(' ');
      if(!tower)return `<div role="gridcell" class="${classes}" aria-label="Row ${row+1}, column ${col+1}: ${value?`printed clue ${value}, not a tower`:'empty square'}"><span aria-hidden="true">${value||'·'}</span></div>`;
      const level=this._stats(tower).level||tower.level||1,slots=tower.attachments?.length||0;
      return `<div role="gridcell" class="${classes}" aria-selected="${chosen}"><button type="button" data-action="map-tower" data-cell="${cell}" data-focus="map-tower-${cell}" tabindex="${cell===activeCell?'0':'-1'}" aria-label="Tower ${tower.number}, row ${row+1}, column ${col+1}, level ${level}, ${slots} of 5 attachment slots filled${tower.illegal?', emergency tower':''}"><span class="rg-map-digit" aria-hidden="true">${tower.number}</span><small class="rg-map-level" aria-hidden="true">${level}</small><span class="rg-map-sockets" aria-hidden="true">${Array.from({length:5},(_,i)=>`<i class="${i<slots?'filled':''}"></i>`).join('')}</span></button></div>`;
    }).join('')}</div>`).join('')}</div><div class="rg-map-legend"><span><i class="tower"></i>Your towers</span><span><i class="clue"></i>Printed clue</span><span><b>•••••</b>Filled slots</span></div><p class="rg-map-help">${towers.length?'Tap a mint square to inspect it. The corner number is its level.':'Solve a Sudoku square to grow your first tower.'}</p></div>`;
    return compact?`<details class="rg-tower-map-picker" ${this.towerMapOpen?'open':''}><summary data-focus="tower-map-toggle"><span><small>EQUIP TARGET</small><strong>${label}</strong></span><b>Change <i aria-hidden="true">⌄</i></b></summary>${board}</details>`:board;
  }
  _selectMapTower(cell,{revealDetails=false}={}){
    if(!this.game.towers?.some(tower=>tower.cell===cell))return false;
    this.onInspect(cell);this.refresh();
    if(revealDetails&&this.tab==='tower'&&globalThis.matchMedia?.('(max-width:700px)').matches){
      const details=this.dialog.querySelector('[data-action="return-map"]');
      if(details){details.focus({preventScroll:true});details.scrollIntoView({block:'start',inline:'nearest'});return true;}
    }
    const button=this.dialog.querySelector(`[data-action="map-tower"][data-cell="${cell}"]`);
    button?.focus({preventScroll:true});button?.scrollIntoView({block:'nearest',inline:'nearest'});
    return true;
  }
  _moveMapTower(node,dx,dy){
    if(node?.dataset.action!=='map-tower')return false;
    const cell=Number(node.dataset.cell),row=Math.floor(cell/9),col=cell%9;
    const candidates=(this.game.towers||[]).map(tower=>({cell:tower.cell,x:tower.cell%9-col,y:Math.floor(tower.cell/9)-row})).filter(tower=>dx?tower.x*dx>0:tower.y*dy>0);
    if(!candidates.length)return false;
    candidates.sort((a,b)=>{
      const primaryA=dx?Math.abs(a.x):Math.abs(a.y),primaryB=dx?Math.abs(b.x):Math.abs(b.y);
      const crossA=dx?Math.abs(a.y):Math.abs(a.x),crossB=dx?Math.abs(b.y):Math.abs(b.x);
      // A tower in the same row or column is the most predictable next stop.
      return Number(crossA!==0)-Number(crossB!==0)||(primaryA+crossA*2)-(primaryB+crossB*2)||a.cell-b.cell;
    });
    return this._selectMapTower(candidates[0].cell);
  }
  _stats(tower){try{return this.game.towerStats?.(tower)||{};}catch{return {};}}
  _compactTower(){
    const tower=this._tower();
    return `<section class="rg-detail-card rg-mini-tower">${this._towerSelect({compact:true})}${tower?`<div class="rg-mini-slots">${Array.from({length:5},(_,i)=>`<span class="${tower.attachments?.[i]?'filled':''}" style="--loot:${rarity(tower.attachments?.[i]?.rarity).color}" title="${esc(tower.attachments?.[i]?.name||'Empty slot')}">${tower.attachments?.[i]?icon(tower.attachments[i].kind,tower.attachments[i].rarity):'+'}</span>`).join('')}</div><button class="rg-text-button" type="button" data-action="tab" data-tab="tower">Inspect and upgrade tower →</button>`:'<p class="rg-fineprint">Only player-grown towers can be equipped. Printed Sudoku clues are foundations.</p>'}</section>`;
  }
  _towerView(){
    const tower=this._tower();
    if(!tower)return `<div class="rg-workshop-pick">${this._towerSelect()}<div class="rg-empty rg-empty-tower"><div class="rg-seed-art" aria-hidden="true">${voxelArt('seed')}</div><h3>${this.game.towers?.length?'Pick your next project.':'First a seed. Then a stronghold.'}</h3><p>${this.game.towers?.length?'Choose a mint tower on the mini board to see its damage, upgrades, and five equipment slots.':'Each correct Sudoku answer grows a tower. Printed clues stay as foundations.'}</p><button type="button" class="rg-secondary" data-action="close">Return to the grid →</button></div></div>`;
    const stats=this._stats(tower),family=this.game.familyLevels?.[tower.number]||1,canEdit=['prep','loot','won'].includes(this.game.phase);
    const cost=this.game.upgradeCost?.(tower.cell)??0,familyCost=this.game.familyUpgradeCost?.(tower.number)??0;
    const attachments=tower.attachments||[];
    const picked=this.game.items?.find(item=>String(item.id)===String(this.selectedItem)&&item.type==='attachment');
    return `<div class="rg-lab-layout rg-visual-lab"><section class="rg-tower-summary">${this._towerSelect()}<div class="rg-selected-tower"><button type="button" class="rg-map-return" data-action="return-map" data-focus="return-map">← Choose another tower <span aria-hidden="true">▦</span></button><span class="rg-selected-tower-art" aria-hidden="true">${voxelArt('tower')}</span><div class="rg-selected-tower-label"><small>R${Math.floor(tower.cell/9)+1} · C${tower.cell%9+1}</small><h3>Tower ${tower.number}</h3><span>Level ${stats.level||tower.level||1} · ${attachments.length}/5 equipped</span></div></div><div class="rg-stat-grid"><div><strong>${(Number(stats.damage)||0).toFixed(1)}</strong><span>BOLT DAMAGE</span></div><div><strong>${stats.cooldown?(1/stats.cooldown).toFixed(2):'—'}</strong><span>SHOTS / SEC</span></div><div><strong>${(Number(stats.range)||0).toFixed(1)}</strong><span>RANGE</span></div><div><strong>${attachments.length}<small> / 5</small></strong><span>LAYERS</span></div></div><div class="rg-upgrade-card"><h4>Grow this tower</h4><p>Raise this tower's individual level for the current map.</p><button type="button" class="rg-primary" data-action="upgrade" data-focus="upgrade" ${this.game.credits>=cost?'':'disabled'}>Upgrade tower <b>ϟ ${number(cost)}</b></button></div><div class="rg-upgrade-card family"><h4>Grow every ${tower.number}</h4><p>Family level ${family} → ${family+1}. Every ${tower.number} gains a level, including future towers. Lasts the run.</p><button type="button" class="rg-secondary" data-action="upgrade-family" data-focus="upgrade-family" ${this.game.credits>=familyCost?'':'disabled'}>Upgrade all ${tower.number}s <b>ϟ ${number(familyCost)}</b></button></div>${tower.illegal?'<p class="rg-warning">Emergency tower: temporary for this map. Its attachments return to your bag after combat.</p>':''}</section><section class="rg-stack-editor"><div class="rg-section-line"><h3>${esc(towerBuild(tower).name)}</h3><span>${canEdit?'Click a filled slot to return its gear':'Editable in war prep / loot camp'}</span></div><div class="rg-equipment-slots">${Array.from({length:5},(_,i)=>{const item=attachments[i],r=rarity(item?.rarity);return `<button type="button" class="rg-equipment-slot ${item?'filled':''}" style="--loot:${r.color}" data-action="${item?'unequip':'browse-attachments'}" data-slot="${i}" data-focus="slot-${i}" ${item&&!canEdit?'disabled':''}><span class="rg-slot-index">0${i+1}</span><span class="rg-slot-glyph">${item?icon(item.kind,item.rarity):'+'}</span><span>${item?`<small class="rg-rarity">${r.name}</small><strong>${esc(itemGuide(item).name)}</strong><small>${esc(itemGuide(item).effect)}</small>`:'<strong>Open attachment slot</strong><small>Choose gear from your field kit</small>'}</span><b>${item?'↩':'→'}</b></button>`;}).join('')}</div><p class="rg-build-summary">${esc(towerBuild(tower).summary)}</p><p class="rg-fineprint">Each item fills one slot. Repeating an effect adds its power; mixing effects changes what the tower can do.</p>${picked?this._itemDetail(picked):`<button type="button" class="rg-primary" data-action="browse-attachments" data-focus="choose-attachments">Choose an attachment <b>+</b></button>`}<div class="rg-effect-list">${this._activeEffects()}</div></section></div>`;
  }
  _activeEffects(){return (this.game.activeEffects||[]).map(effect=>`<span class="rg-effect-pill">✦ ${esc(effect.name||cap(effect.kind))} <b>${Math.ceil(effect.remaining)}s</b></span>`).join('');}
  _chests(){
    const chests=this.game.chests||[];
    if(!chests.length)return `<div class="rg-empty small"><span class="rg-empty-art">${voxelArt('chest')}</span><h4>No sealed chests yet.</h4><p>Enemies drop fragments and sometimes chests. Keep both: fragments open your chests in War Prep or Loot Camp.</p></div>`;
    const allowed=['prep','loot','won'].includes(this.game.phase);
    return `<p class="rg-loot-rule">Every chest contains items of its own rarity. Equipment stays with you; boosts are used once.</p><div class="rg-chest-grid">${chests.map(chest=>{const r=rarity(chest.rarity),guide=chestGuide(chest.rarity),cost=chest.cost??guide.cost,shortage=Math.max(0,cost-this.game.fragments);return `<article class="rg-chest-card ${allowed&&!shortage?'is-ready':''}" style="--loot:${r.color}"><div class="rg-mini-chest" aria-hidden="true">${voxelArt('chest',{rarity:chest.rarity})}</div><small class="rg-rarity">${r.name} chest</small><h4>${guide.count} ${guide.count===1?'item':'items'} inside</h4><p>${esc(guide.contents)}</p><p class="rg-chest-explanation">${esc(guide.explanation)}</p><button type="button" class="rg-secondary" data-action="chest" data-chest="${esc(chest.id)}" data-focus="chest-${esc(chest.id)}" ${allowed&&!shortage?'':'disabled'}>Open <b>◈ ${cost}</b></button><small class="${allowed&&!shortage?'rg-ready':''}">${!allowed?'Open in War Prep or Loot Camp':shortage?`Need ${shortage} more fragments`:`Spend ${cost} of your ${number(this.game.fragments)} fragments`}</small></article>`;}).join('')}</div>`;
  }
  _lootView(){
    const g=this.game,inCamp=g.phase==='loot',isLocked=g.mode==='locked';
    return `${!inCamp?`<div class="rg-phase-notice"><b>${g.phase==='prep'?'War prep is open.':'The camp opens after a battle.'}</b><span>${g.phase==='prep'?'Open chests and equip your towers now. The shop and next-map choices arrive after you defend.':'You can inspect your supplies here. Defend the current map to shop and continue.'}</span></div>`:''}${inCamp?`<section class="rg-camp-banner"><div><span class="rg-eyebrow">DEFENSE COMPLETE · REFIT STATION</span><h3>Good soil. Better spoils.</h3><p>Unpack your finds. Tune your towers. Choose what comes next.</p></div><span aria-hidden="true">${voxelArt('chest',{rarity:'epic'})}${voxelArt('bag')}</span></section>`:''}<section class="rg-camp-section"><div class="rg-section-line"><h3>Your spoils</h3><span>Fragments come from defeated enemies</span></div>${this._chests()}</section><section class="rg-camp-section"><div class="rg-section-line"><h3>Sealed supplies</h3><span>Buy with credits · unlock with fragments</span></div><div class="rg-shop-grid">${RARITIES.map(r=>{const cost=g.chestPrice?.(r.id)??({common:30,uncommon:50,rare:90,epic:160,legendary:280}[r.id]);return `<article class="rg-shop-card" style="--loot:${r.color}"><span class="rg-shop-gem">${voxelArt('chest',{rarity:r.id})}</span><small class="rg-rarity">${r.name}</small><h4>Supply cache</h4><p>${chestGuide(r.id).count} ${chestGuide(r.id).count===1?'item':'items'} · ${r.fragmentCost} fragments to open</p><button type="button" class="rg-secondary" data-action="buy-chest" data-rarity="${r.id}" data-focus="buy-chest-${r.id}" ${inCamp&&g.credits>=cost?'':'disabled'}>Buy <b>ϟ ${cost}</b></button></article>`;}).join('')}</div></section><section class="rg-camp-section"><div class="rg-section-line"><h3>Run upgrades</h3><span>Carry through this entire run</span></div><div class="rg-passives">${[['power','◆','Amplifier','+9% tower damage per level'],['salvage','◈','Scavenger','+5% bonus fragment chance and +1% rarity luck per level'],['vitality','+','Reinforced core','+4 maximum integrity and repair 4 per level']].map(([id,glyph,name,description])=>{const level=g.passives?.[id]||0,cost=g.passiveCost?.(id)??999;return `<article class="rg-passive"><div class="rg-passive-glyph">${voxelArt(id==='salvage'?'fragment':id==='vitality'?'core':'power')}</div><div><small>RUN PASSIVE · LV ${level}</small><h4>${name}</h4><p>${description}</p></div><button type="button" class="rg-secondary" data-action="passive" data-kind="${id}" data-focus="passive-${id}" ${inCamp&&g.credits>=cost?'':'disabled'}>ϟ ${number(cost)} <b>+</b></button></article>`;}).join('')}</div></section><section class="rg-next-map"><div><span class="rg-eyebrow">${isLocked?'LOCKED IN · DIFFICULTIES FIXED':'YOUR NEXT BATTLEFIELD'}</span><h3>Map ${Math.min((g.wave||1)+1,g.maxWaves||50)} awaits.</h3><p>Your attachments return to your bag for the new grid. Your credits, gear, family levels and passives stay with you.</p></div>${isLocked?`<div class="rg-locked-info"><span>◈ ${cap(g.sudokuDifficulty)} Sudoku</span><span>ϟ ${cap(g.combatDifficulty)} combat</span><p>Chosen at the start. Fixed for the run.</p></div>`:`<div class="rg-next-difficulties">${this._difficulty('sudoku',this.nextOptions.sudokuDifficulty,'next',true)}${this._difficulty('combat',this.nextOptions.combatDifficulty,'next',true)}</div>`}<button type="button" class="rg-primary" data-action="next-wave" data-focus="next-wave" ${inCamp&&g.wave<g.maxWaves?'':'disabled'}>Enter the next map <b>→</b></button><p class="rg-fineprint">${inCamp?'Spend or save. You can leave with unopened chests.':g.mode==='freeplay'?'Free play ends after this one battlefield.':'Complete this battle before continuing.'}</p></section>`;
  }
  _casinoView(){
    return renderSlotMachine({game:this.game,spin:this.spin});
  }
  showChest(result){
    if(!result?.ok){this._result(result);return;}
    clearTimeout(this.revealTimer);
    this.reveal={result,returnTab:this.tab==='setup'?'inventory':this.tab,stage:0,flipped:[],elapsed:0};
    this.onSound('chestCharge',{rarity:result.rarity});
    this._render();this._show();
    if(this.isReducedMotion()){this._unsealRewards();return;}
    this.revealTimer=setTimeout(()=>this._unsealRewards(),520);
  }
  _unsealRewards(){
    if(!this.reveal||this.reveal.stage!==0)return;
    clearTimeout(this.revealTimer);
    this.reveal.stage=1;
    this.onSound('chestReveal',{rarity:this.reveal.result.rarity});
    const focusChest=document.activeElement?.dataset.action==='unseal-rewards';
    this._render();
    if(focusChest)this.dialog.querySelector('[data-action="flip-reward"]')?.focus({preventScroll:true});
  }
  _finishReveal(){
    if(!this.reveal)return;
    clearTimeout(this.revealTimer);
    if(this.reveal.stage===0)this.onSound('chestReveal',{rarity:this.reveal.result.rarity});
    this.reveal.stage=2;
    this.reveal.flipped=(this.reveal.result.rewards||[]).map((_,index)=>index);
    this._render();
    this.dialog.querySelector('[data-action="accept-loot"]')?.focus({preventScroll:true});
  }
  _flipReward(index){
    if(!this.reveal||this.reveal.stage===0||!Number.isInteger(index)||index<0||index>=(this.reveal.result.rewards||[]).length||this.reveal.flipped.includes(index))return;
    this.reveal.flipped.push(index);
    if(this.reveal.flipped.length===this.reveal.result.rewards.length)this.reveal.stage=2;
    const item=this.reveal.result.rewards[index];
    this.onSound('lootFlip',{rarity:item.rarity});
    this._render();
    const card=this.dialog.querySelector(`[data-focus="reward-${index}"]`);
    (card?.querySelector('button')||card)?.focus({preventScroll:true});
  }
  _chestView(){
    const {result,stage,flipped}=this.reveal,r=rarity(result.rarity),items=result.rewards||[],complete=flipped.length===items.length;
    const canEquip=['prep','loot','won'].includes(this.game.phase);
    return `${this._header(`${r.name.toUpperCase()} CHEST · ${items.length} ${items.length===1?'ITEM':'ITEMS'}`,stage===0?'Powering the lock…':complete?'Your next build starts here.':'What did you find?')}<div class="rg-body rg-reveal-body stage-${stage}" style="--loot:${r.color}"><div class="rg-reveal-stage"><div class="rg-reveal-halo"></div><div class="rg-reveal-rays" aria-hidden="true">${Array.from({length:8},(_,i)=>`<i style="--ray:${i}"></i>`).join('')}</div>${stage===0?`<button type="button" class="rg-hero-chest rg-chest-trigger" data-action="unseal-rewards" data-focus="chest-trigger" aria-label="Open chest now">${voxelArt('chest',{rarity:result.rarity})}</button>`:`<div class="rg-hero-chest" aria-hidden="true">${voxelArt('chest',{rarity:result.rarity})}</div>`}</div><div class="rg-reveal-copy" aria-live="polite"><strong>${stage===0?'Tap the chest to pop it open.':complete?'All yours. Equipment is reusable. Boosts are used once.':`Tap to reveal · ${flipped.length} of ${items.length} revealed${items.length>1?' · swipe for more':''}`}</strong><p>Already saved in your bag. Keep everything, even if you close.</p></div>${stage>0?`<div class="rg-reward-grid" aria-label="Chest rewards">${items.map((item,index)=>{const guide=itemGuide(item),shown=flipped.includes(index);return `<article class="rg-reward-card ${shown?'is-flipped':'is-mystery'}" style="--loot:${guide.color};--reward:${index}" ${shown?`tabindex="-1" data-focus="reward-${index}" aria-label="${esc(guide.name)}: ${esc(guide.effect)}"`:''}>${shown?`<div class="rg-reward-heading"><div class="rg-reward-glyph" aria-hidden="true">${icon(item.kind,item.rarity)}</div><span class="rg-rarity">${esc(guide.rarityName)}<br>${item.type==='consumable'?'BOOST · ONE USE':'EQUIPMENT · REUSABLE'}</span></div><h4>${esc(guide.name)}</h4><p class="rg-reward-effect">${esc(guide.effect)}</p><p class="rg-reward-purpose">${esc(guide.purpose)}</p><p class="rg-reward-pair">${item.type==='attachment'&&guide.pairWith?esc(guide.pairWith):esc(guide.lifetime)}</p>${item.type==='attachment'?`<button type="button" class="rg-secondary" data-action="reward-equip" data-item="${esc(item.id)}" data-reward="${index}" data-focus="reward-equip-${index}" ${canEquip?'':'disabled'} aria-label="Equip ${esc(guide.name)} on the board">Equip on board <b>↗</b></button>`:'<span class="rg-reward-saved">✓ Saved to Boosts</span>'}`:`<button type="button" class="rg-mystery-face" data-action="flip-reward" data-reward="${index}" data-focus="reward-flip-${index}" aria-label="Reveal ${r.name.toLowerCase()} reward ${index+1} of ${items.length}"><span class="rg-mystery-art" aria-hidden="true">${voxelArt('chest',{rarity:item.rarity})}</span><span class="rg-rarity">${esc(guide.rarityName)} FIND</span><strong>Tap to reveal</strong><small>Item ${index+1} / ${items.length}</small></button>`}</article>`;}).join('')}</div>`:''}</div><footer class="rg-footer rg-reveal-footer"><span>${complete?'✓ Everything saved':'No need to reveal to keep it'}</span><div>${!complete?'<button type="button" class="rg-secondary" data-action="skip-reveal" data-initial-focus data-focus="reveal-action">Reveal all</button>':''}<button type="button" class="rg-primary" data-action="accept-loot" ${complete?'data-initial-focus':''} data-focus="accept-loot">Done <b>✓</b></button></div></footer>`;
  }
  _click(event){
    const button=event.target.closest('button[data-action]');if(!button||button.disabled||!this.dialog.contains(button))return;
    const a=button.dataset.action;
    if(a==='close'){this.close();return;}
    if(a==='unseal-rewards'){this._unsealRewards();return;}
    if(a==='flip-reward'){this._flipReward(Number(button.dataset.reward));return;}
    if(a==='reward-equip'){
      const index=Number(button.dataset.reward),item=this.reveal?.result.rewards?.[index];
      if(!item||!this.reveal.flipped.includes(index)||item.type!=='attachment'||String(item.id)!==button.dataset.item)return;
      this.close();this.onBoardEquip(String(item.id));return;
    }
    if(a==='skip-reveal'){this._finishReveal();return;}
    if(a==='accept-loot'){const tab=this.reveal?.returnTab||'inventory';clearTimeout(this.revealTimer);this.reveal=null;this.open(tab);return;}
    if(a==='mode'){this.options.mode=button.dataset.mode;this.refresh();return;}
    if(a==='difficulty'){const target=button.dataset.prefix==='next'?this.nextOptions:this.options;target[`${button.dataset.type}Difficulty`]=button.dataset.value;this.refresh();return;}
    if(a==='start'){const options={...this.options};this.close();this.onNewRun(options);return;}
    if(a==='tab'){this.open(button.dataset.tab);return;}
    if(a==='filter'){this.filter=button.dataset.filter;this.page=0;this.refresh();return;}
    if(a==='page'){this.page+=Number(button.dataset.delta);this.refresh();return;}
    if(a==='select-item'){
      this.selectedItem=button.dataset.item;this.refresh();
      if(globalThis.matchMedia?.('(max-width:700px)').matches){
        const body=this.dialog.querySelector('.rg-body');if(body)body.scrollTop=0;
        this.dialog.querySelector('[data-action="clear-item"]')?.focus({preventScroll:true});
      }
      return;
    }
    if(a==='clear-item'){
      const item=this.selectedItem;this.selectedItem=null;this.refresh();
      const target=Array.from(this.dialog.querySelectorAll('[data-action="select-item"]')).find(node=>node.dataset.item===item);
      target?.focus({preventScroll:true});
      const body=this.dialog.querySelector('.rg-body');if(body)body.scrollTop=0;
      return;
    }
    if(a==='map-tower'){this._selectMapTower(Number(button.dataset.cell),{revealDetails:event.detail>0});return;}
    if(a==='return-map'){
      this.dialog.querySelector(`[data-action="map-tower"][data-cell="${Number(this.getSelectedCell())}"]`)?.focus({preventScroll:true});
      this.dialog.querySelector('.rg-tower-map')?.scrollIntoView({block:'start',inline:'nearest'});return;
    }
    if(a==='browse-attachments'){this.filter='attachment';this.open('inventory');return;}
    if(a==='board-equip'){const id=button.dataset.item;this.close();this.onBoardEquip(id);return;}
    if(a==='equip'){this._result(this._call('equipItem',Number(this.getSelectedCell()),button.dataset.item));return;}
    if(a==='unequip'){this._result(this._call('unequipItem',Number(this.getSelectedCell()),Number(button.dataset.slot)));return;}
    if(a==='use'){this._result(this._call('useItem',button.dataset.item));return;}
    if(a==='upgrade'){this._result(this._call('upgradeTower',Number(this.getSelectedCell())));return;}
    if(a==='upgrade-family'){const tower=this._tower();if(tower)this._result(this._call('upgradeFamily',tower.number));return;}
    if(a==='chest'){const result=this._call('openChest',button.dataset.chest);this._result(result,{refresh:false});if(result.ok)this.showChest(result);else this.refresh();return;}
    if(a==='buy-chest'){this._result(this._call('buyChest',button.dataset.rarity));return;}
    if(a==='passive'){this._result(this._call('buyPassive',button.dataset.kind));return;}
    if(a==='next-wave'){const result=this._call('nextWave',{...this.nextOptions});if(result.ok)this.close();this._result(result);return;}
    if(a==='spin'){
      if(this.spin&&!this.spin.done)return;
      const result=this._call('spinSlots');
      if(!result.ok){this._result(result);return;}
      this.spin={result,done:Boolean(this.isReducedMotion()),elapsed:0};this.onSound('slotSpin');this.notice='';this.onChange(result);this._render();
      clearTimeout(this.spinTimer);
      this.spinTimer=setTimeout(()=>{if(!this.spin)return;this.spin.done=true;this.onSound(result.reward?.credits||result.reward?.chestRarity||result.reward?.item?'slotWin':'slotLose');this._render();this.dialog.querySelector('[data-action="spin"]')?.focus({preventScroll:true});},this.isReducedMotion()?0:1700);
    }
  }
  _change(event){
    if(event.target.dataset.action==='select-tower'){
      const cell=Number(event.target.value);if(cell>=0){this.onInspect(cell);this.refresh();}
    }
  }
  _focusable(){return Array.from(this.dialog.querySelectorAll('button:not(:disabled),select:not(:disabled),summary,a[href],input:not(:disabled)')).filter(node=>node.tabIndex!==-1&&node.getClientRects().length&&!node.closest('[aria-hidden="true"]'));}
  _moveFocus(delta){const nodes=this._focusable();if(!nodes.length)return;const index=nodes.indexOf(document.activeElement);const node=nodes[(index+delta+nodes.length)%nodes.length];node.focus({preventScroll:true});node.scrollIntoView({block:'nearest',inline:'nearest'});}
  handleController(action,dx=0,dy=0){
    if(!this.isOpen())return false;
    if(action==='back'||action==='pause'){this.close();return true;}
    if(action==='number'||action==='tabs'){
      if(this.tab==='setup'||this.reveal){this._moveFocus(Math.sign(dx)||1);return true;}
      const tabs=['inventory','tower','loot','casino'];this.open(tabs[(tabs.indexOf(this.tab)+(Math.sign(dx)||1)+tabs.length)%tabs.length]);return true;
    }
    if(action==='move'){
      const node=document.activeElement;
      if(node?.dataset.action==='map-tower'){if(!this._moveMapTower(node,Math.sign(dx),Math.sign(dy)))this._moveFocus(Math.sign(dy||dx)||1);}
      else if(node?.tagName==='SELECT'&&dx){const next=Math.min(node.options.length-1,Math.max(0,node.selectedIndex+Math.sign(dx)));node.selectedIndex=next;node.dispatchEvent(new Event('change',{bubbles:true}));}
      else this._moveFocus(Math.sign(dy||dx)||1);
      return true;
    }
    if(action==='place'||action==='confirm'||action==='phase'){
      const node=document.activeElement;
      if(node?.tagName==='SELECT'){node.selectedIndex=(node.selectedIndex+1)%node.options.length;node.dispatchEvent(new Event('change',{bubbles:true}));}
      else if(this.dialog.contains(node))node.click();else this._focusable()[0]?.focus();
      return true;
    }
    return true;
  }
  _keyboard(event){
    if(!this.isOpen())return;
    // Keep host hotkeys from placing towers behind an open menu.
    event.stopImmediatePropagation();
    if(event.key==='Escape'){event.preventDefault();this.close();return;}
    if(event.key==='Tab')return;
    if(event.target?.dataset.action==='map-tower'){
      const arrows={ArrowUp:[0,-1],ArrowDown:[0,1],ArrowLeft:[-1,0],ArrowRight:[1,0]};
      if(arrows[event.key]){event.preventDefault();this._moveMapTower(event.target,...arrows[event.key]);return;}
      if(event.key==='Home'||event.key==='End'){event.preventDefault();const cells=(this.game.towers||[]).map(tower=>tower.cell).sort((a,b)=>a-b);this._selectMapTower(event.key==='Home'?cells[0]:cells.at(-1));return;}
    }
    const directions={ArrowUp:-1,ArrowDown:1,ArrowLeft:-1,ArrowRight:1};
    if(directions[event.key]&&event.target.tagName!=='SELECT'){event.preventDefault();this._moveFocus(directions[event.key]);}
  }
}
