import {RARITIES, ATTACHMENTS, itemDescription, SLOT_COST, SLOT_PAYTABLE} from './game/items.js';

const esc = value => String(value ?? '').replace(/[&<>"']/g, char => ({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[char]));
const cap = value => String(value ?? '').replace(/^./, char => char.toUpperCase());
const number = value => Math.round(Number(value) || 0).toLocaleString();
const rarity = id => RARITIES.find(entry => entry.id === id) || RARITIES[0];
const icon = kind => ({rapid:'»',electric:'ϟ',frost:'❄',blast:'✹',venom:'◈',range:'◎',power:'◆',gravity:'◉',nova:'✦',overclock:'»',overcharge:'ϟ',freeze:'❄',repair:'+'}[kind] || '◇');
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
  constructor({game, getSelectedCell = () => -1, onChange = () => {}, onNewRun = () => {}, onInspect = () => {}, onSound = () => {}, isReducedMotion = () => false} = {}) {
    this.game=game; this.getSelectedCell=getSelectedCell; this.onChange=onChange; this.onNewRun=onNewRun;
    this.onInspect=onInspect; this.onSound=onSound; this.isReducedMotion=isReducedMotion;
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
    catch(error){console.error(`Gridfall ${method}`,error);return {ok:false,message:'That action could not be completed. Please try again.'};}
  }
  _result(result,{refresh=true}={}){
    this.notice=result?.message||''; this.noticeError=!result?.ok;
    this.onChange(result);
    if(refresh){this.lastKey='';this.refresh();}
    return result;
  }
  _wallet(){return `<div class="rg-wallet"><span title="Spend credits on seeds, upgrades and supplies"><i>ϟ</i> ${number(this.game.credits)} <small>credits</small></span><span title="Enemy fragments unlock sealed chests"><i>◈</i> ${number(this.game.fragments)} <small>fragments</small></span></div>`;}
  _header(eyebrow,title,description=''){
    return `<header class="rg-header"><div><div class="rg-eyebrow">${eyebrow}</div><h2 id="rogueTitle">${title}</h2>${description?`<p>${description}</p>`:''}</div><button type="button" class="rg-close" data-action="close" aria-label="Close menu" title="Close (Escape / B)">×</button></header>`;
  }
  _tabs(){
    return `<div class="rg-toolbar"><nav class="rg-tabs" aria-label="Run menus">${[['inventory','Inventory'],['tower','Tower lab'],['loot','Loot camp'],['casino','Lucky circuit']].map(([id,label])=>`<button type="button" data-action="tab" data-tab="${id}" class="${this.tab===id?'active':''}" aria-current="${this.tab===id?'page':'false'}" data-focus="tab-${id}">${label}${id==='inventory'?` <span>${this.game.items?.length||0}</span>`:''}</button>`).join('')}</nav>${this._wallet()}</div>`;
  }
  _render(){
    const active=document.activeElement;
    const focusId=this.dialog.contains(active)?active.dataset.focus||active.id:null;
    const scroll=this.dialog.querySelector('.rg-body')?.scrollTop||0;
    const view=this.reveal?this._chestView():this.tab==='setup'?this._setupView():this._mainView();
    this.dialog.innerHTML=view;
    this.dialog.classList.toggle('rg-reveal-mode',Boolean(this.reveal));
    this.dialog.classList.toggle('rg-reduced-motion',Boolean(this.isReducedMotion()));
    if(focusId){const target=Array.from(this.dialog.querySelectorAll('[data-focus], [id]')).find(node=>node.dataset.focus===focusId||node.id===focusId);target?.focus({preventScroll:true});}
    const body=this.dialog.querySelector('.rg-body');if(body)body.scrollTop=scroll;
  }
  _difficulty(type,value,prefix='setup',compact=false){
    return `<fieldset class="rg-difficulty ${compact?'rg-compact':''}"><legend>${type==='sudoku'?'Sudoku difficulty':'Combat difficulty'}</legend><div class="rg-choice-row">${['easy','medium','hard'].map(level=>`<button type="button" data-action="difficulty" data-prefix="${prefix}" data-type="${type}" data-value="${level}" data-focus="${prefix}-${type}-${level}" class="rg-choice ${value===level?'chosen':''}" aria-pressed="${value===level}"><strong>${cap(level)}</strong><span>${diffInfo[type][level][0]}</span></button>`).join('')}</div><p>${diffInfo[type][value]?.[1]||''}</p></fieldset>`;
  }
  _setupView(){
    const o=this.options;
    return `${this._header('VOXEL FORGE · EXPEDITION 02','Build a beautiful disaster.','Solve a grid. Grow your towers. Find the gear that changes everything.')}<div class="rg-body rg-setup-body"><div class="rg-mode-grid">${[['campaign','01 → 50','Campaign'],['freeplay','ONE MAP','Free play'],['locked','01 → 50 · FIXED','Locked in']].map(([id,small,label])=>`<button type="button" class="rg-mode ${o.mode===id?'chosen':''}" data-action="mode" data-mode="${id}" data-focus="mode-${id}" aria-pressed="${o.mode===id}" ${id===o.mode?'data-initial-focus':''}><small>${small}</small><strong>${label}</strong><p>${descriptions[id]}</p><span class="rg-select-dot" aria-hidden="true"></span></button>`).join('')}</div><div class="rg-setup-difficulties">${this._difficulty('sudoku',o.sudokuDifficulty)}${this._difficulty('combat',o.combatDifficulty)}</div><div class="rg-run-loop"><span><i>01</i> Solve &amp; grow</span><b>→</b><span><i>02</i> Equip your stack</span><b>→</b><span><i>03</i> Hold the line</span><b>→</b><span><i>04</i> Claim the loot</span></div><p class="rg-fineprint">Every tower starts as a seed and fires a basic bolt. Stack up to five attachments to build its identity. Your bag, number-family levels and passive upgrades carry between maps.</p></div><footer class="rg-footer"><span>${o.mode==='locked'?'Both difficulty choices stay fixed for all 50 maps.':o.mode==='freeplay'?'A complete expedition in one battlefield.':'Change either difficulty at the end of each map.'}</span><button class="rg-primary" type="button" data-action="start" data-focus="start">${o.mode==='freeplay'?'Start free play':'Begin expedition'} <b>→</b></button></footer>`;
  }
  _mainView(){
    const labels={inventory:['FIELD KIT','A little room for possibility.','Attachments make the tower. Consumables change the moment.'],tower:['TOWER LAB','Small seed. Big potential.','Select an existing tower to upgrade its level or build its five-layer stack.'],loot:['BREACH CONTAINED','Make the next run unfair.','Unlock your finds, invest in your build, then choose the next battlefield.'],casino:['LUCKY CIRCUIT','One more spin?','An optional credit sink between battles. Sometimes the grid gives back.']};
    const [eyebrow,title,description]=labels[this.tab]||labels.inventory;
    return `${this._header(`${eyebrow} · MAP ${this.game.wave||1} / ${this.game.maxWaves||50}`,title,description)}${this._tabs()}<div class="rg-body">${this.notice?`<div class="rg-notice ${this.noticeError?'error':''}" role="status">${esc(this.notice)}</div>`:''}${this.tab==='tower'?this._towerView():this.tab==='loot'?this._lootView():this.tab==='casino'?this._casinoView():this._inventoryView()}</div><footer class="rg-footer"><span><b>${phaseName(this.game.phase)}</b> · D-pad to navigate · A to choose · B to return</span><button class="rg-secondary" type="button" data-action="close" data-focus="return">Back to the grid <b>↗</b></button></footer>`;
  }
  _itemCard(item,{selected=false,compact=false}={}){
    const r=rarity(item.rarity);
    return `<button type="button" class="rg-item-card ${selected?'selected':''} ${compact?'compact':''}" style="--loot:${r.color}" data-action="select-item" data-item="${esc(item.id)}" data-focus="item-${esc(item.id)}" aria-pressed="${selected}"><span class="rg-item-art" aria-hidden="true">${icon(item.kind)}</span><span class="rg-item-copy"><small class="rg-rarity">${r.name} ${item.type==='consumable'?'consumable':'attachment'}</small><strong>${esc(item.name)}</strong><span>${esc(item.description||itemDescription(item))}</span></span>${item.type==='consumable'?'<span class="rg-item-corner">1 USE</span>':'<span class="rg-item-corner">1 SLOT</span>'}</button>`;
  }
  _inventoryView(){
    const items=this.game.items||[];
    const chests=this.game.chests||[];
    const counts={all:items.length,attachment:items.filter(i=>i.type==='attachment').length,consumable:items.filter(i=>i.type==='consumable').length,chests:chests.length};
    let list=items.filter(item=>this.filter==='all'||item.type===this.filter);
    list=[...list].sort((a,b)=>RARITIES.findIndex(r=>r.id===b.rarity)-RARITIES.findIndex(r=>r.id===a.rarity));
    const pages=Math.max(1,Math.ceil(list.length/18));this.page=Math.min(this.page,pages-1);
    const picked=items.find(item=>String(item.id)===String(this.selectedItem));
    return `<div class="rg-inventory-layout"><section class="rg-bag"><div class="rg-section-line"><h3>Your field kit</h3><span>${items.length} items · ${chests.length} sealed</span></div><div class="rg-filters" aria-label="Filter inventory">${[['all','All items'],['attachment','Attachments'],['consumable','Consumables'],['chests','Chests']].map(([value,label])=>`<button type="button" class="${this.filter===value?'active':''}" data-action="filter" data-filter="${value}" data-focus="filter-${value}" aria-pressed="${this.filter===value}">${label} <b>${counts[value]}</b></button>`).join('')}</div>${this.filter==='chests'?this._chests():list.length?`<div class="rg-item-grid">${list.slice(this.page*18,this.page*18+18).map(item=>this._itemCard(item,{selected:String(item.id)===String(this.selectedItem)})).join('')}</div>${pages>1?`<div class="rg-pagination"><button type="button" data-action="page" data-delta="-1" ${this.page===0?'disabled':''}>← Previous</button><span>${this.page+1} / ${pages}</span><button type="button" data-action="page" data-delta="1" ${this.page===pages-1?'disabled':''}>Next →</button></div>`:''}`:`<div class="rg-empty"><span>◇</span><h4>Your next great find is out there.</h4><p>Defeat enemies for fragments and sealed chests. Open chests in war prep or loot camp to discover attachments and consumables.</p><button class="rg-secondary" type="button" data-action="filter" data-filter="chests">View sealed chests (${chests.length})</button></div>`}</section><aside class="rg-detail">${picked?this._itemDetail(picked):this._inventoryTip()}${this._compactTower()}</aside></div>`;
  }
  _inventoryTip(){return `<section class="rg-detail-card"><span class="rg-eyebrow">FIVE SLOTS. YOUR BUILD.</span><h3>Make the numbers your own.</h3><p>Select an item to see its effect, then attach it to the selected tower during war prep or loot camp.</p><div class="rg-stack-demo" aria-hidden="true"><i>ϟ</i><i>ϟ</i><i>»</i><i>◇</i><i>◇</i></div><p class="rg-fineprint">Repeat attachments to specialize. Mix them to combine effects. Your gear returns to your bag when you move to a new map.</p></section>`;}
  _itemDetail(item){
    const r=rarity(item.rarity), tower=this._tower();
    const canEquip=['prep','loot','won'].includes(this.game.phase)&&tower&&(tower.attachments?.length||0)<5;
    const canUse=this.game.phase==='battle'||item.kind==='repair'&&!['won','lost'].includes(this.game.phase);
    return `<section class="rg-detail-card" style="--loot:${r.color}"><span class="rg-rarity">${r.name} ${item.type==='consumable'?'consumable':'attachment'}</span><div class="rg-big-glyph" aria-hidden="true">${icon(item.kind)}</div><h3>${esc(item.name)}</h3><p>${esc(itemDescription(item)||item.description)}</p>${item.type==='attachment'?`<div class="rg-preview-note"><strong>Build preview</strong>${this._preview(tower,item)}<span>${ATTACHMENTS.find(a=>a.id===item.kind)?.description||'Adds another ability layer to this tower.'}</span><span>Uses 1 of 5 slots. Repeated kinds combine.</span></div><button class="rg-primary" type="button" data-action="equip" data-item="${esc(item.id)}" data-focus="equip" ${canEquip?'':'disabled'}>${tower?`Attach to ${tower.number} · R${Math.floor(tower.cell/9)+1} C${tower.cell%9+1}`:'Select a tower first'} <b>+</b></button><p class="rg-fineprint">${!['prep','loot','won'].includes(this.game.phase)?'Attachments can be changed in war prep and loot camp.':!tower?'Return to the grid and click one of your towers, or select one below.':tower.attachments.length>=5?'This tower is full. Remove a layer to make space.':'Gear is returned to your bag when removed.'}</p>`:`<button class="rg-primary" type="button" data-action="use" data-item="${esc(item.id)}" data-focus="use" ${canUse?'':'disabled'}>${item.kind==='repair'?'Repair the core':'Activate now'} <b>✦</b></button><p class="rg-fineprint">${item.kind==='repair'?'Consumed on use. Repairs core integrity.':'Consumed on use. Activate during a battle; effect timers pause with the battle.'}</p>`}</section>`;
  }
  _preview(tower,item){
    if(!tower||(tower.attachments?.length||0)>=5)return '';
    const before=this._stats(tower),after=this._stats({...tower,attachments:[...(tower.attachments||[]),item]});
    const fields=[['Damage',before.damage,after.damage],['Shots / sec',before.cooldown?1/before.cooldown:0,after.cooldown?1/after.cooldown:0],['Range',before.range,after.range]];
    const changed=fields.filter(([,a,b])=>Number(a).toFixed(2)!==Number(b).toFixed(2));
    if(!changed.length)changed.push([`${cap(item.kind)} strength`,before.effects?.[item.kind]||0,after.effects?.[item.kind]||0]);
    return `<div class="rg-stat-preview">${changed.map(([label,a,b])=>`<span>${label}<b>${Number(a).toFixed(2)} <i>→</i> <strong>${Number(b).toFixed(2)}</strong></b></span>`).join('')}</div>`;
  }
  _towerSelect(){
    const towers=this.game.towers||[];
    return `<label class="rg-select-label" for="rgTowerSelect">Selected tower</label><select id="rgTowerSelect" data-action="select-tower" data-focus="tower-select"><option value="-1" ${!this._tower()?'selected':''}>${towers.length?'Choose a tower…':'Solve a square to grow a tower'}</option>${towers.map(tower=>`<option value="${tower.cell}" ${tower.cell===Number(this.getSelectedCell())?'selected':''}>${tower.number} · R${Math.floor(tower.cell/9)+1} C${tower.cell%9+1} · Lv ${this._stats(tower).level||tower.level||1} · ${tower.attachments?.length||0}/5 slots</option>`).join('')}</select>`;
  }
  _stats(tower){try{return this.game.towerStats?.(tower)||{};}catch{return {};}}
  _compactTower(){
    const tower=this._tower();
    return `<section class="rg-detail-card rg-mini-tower">${this._towerSelect()}${tower?`<div class="rg-mini-slots">${Array.from({length:5},(_,i)=>`<span class="${tower.attachments?.[i]?'filled':''}" style="--loot:${rarity(tower.attachments?.[i]?.rarity).color}" title="${esc(tower.attachments?.[i]?.name||'Empty slot')}">${tower.attachments?.[i]?icon(tower.attachments[i].kind):'+'}</span>`).join('')}</div><button class="rg-text-button" type="button" data-action="tab" data-tab="tower">Inspect and upgrade tower →</button>`:'<p class="rg-fineprint">Only player-grown towers can be equipped. Printed Sudoku clues are foundations.</p>'}</section>`;
  }
  _towerView(){
    const tower=this._tower();
    if(!tower)return `<div class="rg-empty rg-empty-tower"><div class="rg-seed-art" aria-hidden="true">⬡</div><h3>First a seed. Then a stronghold.</h3><p>Each correct Sudoku answer grows a tower. Click an existing tower on the grid to inspect it, or select one below.</p>${this._towerSelect()}<button type="button" class="rg-secondary" data-action="close">Return to the grid →</button></div>`;
    const stats=this._stats(tower),family=this.game.familyLevels?.[tower.number]||1,canEdit=['prep','loot','won'].includes(this.game.phase);
    const cost=this.game.upgradeCost?.(tower.cell)??0,familyCost=this.game.familyUpgradeCost?.(tower.number)??0;
    const attachments=tower.attachments||[];
    const picked=this.game.items?.find(item=>String(item.id)===String(this.selectedItem)&&item.type==='attachment');
    return `<div class="rg-lab-layout"><section class="rg-tower-summary"><div class="rg-tower-number">${tower.number}<span>LV ${stats.level||tower.level||1}</span></div>${this._towerSelect()}<div class="rg-stat-grid"><div><strong>${(Number(stats.damage)||0).toFixed(1)}</strong><span>BOLT DAMAGE</span></div><div><strong>${stats.cooldown?(1/stats.cooldown).toFixed(2):'—'}</strong><span>SHOTS / SEC</span></div><div><strong>${(Number(stats.range)||0).toFixed(1)}</strong><span>RANGE</span></div><div><strong>${attachments.length}<small> / 5</small></strong><span>LAYERS</span></div></div><div class="rg-upgrade-card"><h4>Grow this tower</h4><p>Raise this tower's individual level for the current map.</p><button type="button" class="rg-primary" data-action="upgrade" data-focus="upgrade" ${this.game.credits>=cost?'':'disabled'}>Upgrade tower <b>ϟ ${number(cost)}</b></button></div><div class="rg-upgrade-card family"><h4>Grow every ${tower.number}</h4><p>Family level ${family} → ${family+1}. Every ${tower.number} gains a level, including future towers. Lasts the run.</p><button type="button" class="rg-secondary" data-action="upgrade-family" data-focus="upgrade-family" ${this.game.credits>=familyCost?'':'disabled'}>Upgrade all ${tower.number}s <b>ϟ ${number(familyCost)}</b></button></div>${tower.illegal?'<p class="rg-warning">Emergency tower: temporary for this map. Its attachments return to your bag after combat.</p>':''}</section><section class="rg-stack-editor"><div class="rg-section-line"><h3>The tower stack</h3><span>${canEdit?'Click a filled slot to return its gear':'Editable in war prep / loot camp'}</span></div><div class="rg-equipment-slots">${Array.from({length:5},(_,i)=>{const item=attachments[i],r=rarity(item?.rarity);return `<button type="button" class="rg-equipment-slot ${item?'filled':''}" style="--loot:${r.color}" data-action="${item?'unequip':'browse-attachments'}" data-slot="${i}" data-focus="slot-${i}" ${item&&!canEdit?'disabled':''}><span class="rg-slot-index">0${i+1}</span><span class="rg-slot-glyph">${item?icon(item.kind):'+'}</span><span>${item?`<small class="rg-rarity">${r.name}</small><strong>${esc(item.name)}</strong><small>${esc(itemDescription(item))}</small>`:'<strong>Open attachment slot</strong><small>Choose gear from your field kit</small>'}</span><b>${item?'↩':'→'}</b></button>`;}).join('')}</div><p class="rg-fineprint">Each attachment forms a visible layer. Five electric coils stack lightning power; mix rapid, frost and electric for a hybrid.</p>${picked?this._itemDetail(picked):`<button type="button" class="rg-primary" data-action="browse-attachments" data-focus="choose-attachments">Choose an attachment <b>+</b></button>`}<div class="rg-effect-list">${this._activeEffects()}</div></section></div>`;
  }
  _activeEffects(){return (this.game.activeEffects||[]).map(effect=>`<span class="rg-effect-pill">✦ ${esc(effect.name||cap(effect.kind))} <b>${Math.ceil(effect.remaining)}s</b></span>`).join('');}
  _chests(){
    const chests=this.game.chests||[];
    if(!chests.length)return `<div class="rg-empty small"><span>▣</span><h4>No sealed chests yet.</h4><p>Enemies sometimes drop chests. Their energy fragments power the locks. You can also buy sealed chests at loot camp.</p></div>`;
    const allowed=['prep','loot','won'].includes(this.game.phase);
    return `<div class="rg-chest-grid">${chests.map(chest=>{const r=rarity(chest.rarity),cost=chest.cost??r.fragmentCost;return `<article class="rg-chest-card" style="--loot:${r.color}"><div class="rg-mini-chest" aria-hidden="true"><i></i><b>◈</b></div><small class="rg-rarity">${r.name} supply chest</small><h4>${cap(chest.rarity)} cache</h4><p>Sealed. Spend enemy fragments to discover its loot.</p><button type="button" class="rg-secondary" data-action="chest" data-chest="${esc(chest.id)}" data-focus="chest-${esc(chest.id)}" ${allowed&&this.game.fragments>=cost?'':'disabled'}>Unlock <b>◈ ${cost}</b></button>${!allowed?'<small>Open in war prep or loot camp</small>':this.game.fragments<cost?`<small>${cost-this.game.fragments} more fragments needed</small>`:'<small class="rg-ready">Ready to crack open</small>'}</article>`;}).join('')}</div>`;
  }
  _lootView(){
    const g=this.game,inCamp=g.phase==='loot',isLocked=g.mode==='locked';
    return `${!inCamp?`<div class="rg-phase-notice"><b>${g.phase==='prep'?'War prep is open.':'The camp opens after a battle.'}</b><span>${g.phase==='prep'?'Open chests and equip your towers now. The shop and next-map choices arrive after you defend.':'You can inspect your supplies here. Defend the current map to shop and continue.'}</span></div>`:''}<section class="rg-camp-section"><div class="rg-section-line"><h3>Your spoils</h3><span>Fragments come from defeated enemies</span></div>${this._chests()}</section><section class="rg-camp-section"><div class="rg-section-line"><h3>Sealed supplies</h3><span>Buy with credits · unlock with fragments</span></div><div class="rg-shop-grid">${RARITIES.map(r=>{const cost=g.chestPrice?.(r.id)??({common:30,uncommon:50,rare:90,epic:160,legendary:280}[r.id]);return `<article class="rg-shop-card" style="--loot:${r.color}"><span class="rg-shop-gem">▣</span><small class="rg-rarity">${r.name}</small><h4>Supply cache</h4><p>Lock: ◈ ${r.fragmentCost}</p><button type="button" class="rg-secondary" data-action="buy-chest" data-rarity="${r.id}" data-focus="buy-chest-${r.id}" ${inCamp&&g.credits>=cost?'':'disabled'}>Buy <b>ϟ ${cost}</b></button></article>`;}).join('')}</div></section><section class="rg-camp-section"><div class="rg-section-line"><h3>Permanent advantages</h3><span>Carry through this entire run</span></div><div class="rg-passives">${[['power','◆','Amplifier','+9% tower damage per level'],['salvage','◈','Scavenger','+5% bonus fragment chance and +1% rarity luck per level'],['vitality','+','Reinforced core','+4 maximum integrity and repair 4 per level']].map(([id,glyph,name,description])=>{const level=g.passives?.[id]||0,cost=g.passiveCost?.(id)??999;return `<article class="rg-passive"><div class="rg-passive-glyph">${glyph}</div><div><small>RUN PASSIVE · LV ${level}</small><h4>${name}</h4><p>${description}</p></div><button type="button" class="rg-secondary" data-action="passive" data-kind="${id}" data-focus="passive-${id}" ${inCamp&&g.credits>=cost?'':'disabled'}>ϟ ${number(cost)} <b>+</b></button></article>`;}).join('')}</div></section><section class="rg-next-map"><div><span class="rg-eyebrow">${isLocked?'LOCKED IN · DIFFICULTIES FIXED':'YOUR NEXT BATTLEFIELD'}</span><h3>Map ${Math.min((g.wave||1)+1,g.maxWaves||50)} awaits.</h3><p>Your attachments return to your bag for the new grid. Your credits, gear, family levels and passives stay with you.</p></div>${isLocked?`<div class="rg-locked-info"><span>◈ ${cap(g.sudokuDifficulty)} Sudoku</span><span>ϟ ${cap(g.combatDifficulty)} combat</span><p>Chosen at the start. Fixed for the run.</p></div>`:`<div class="rg-next-difficulties">${this._difficulty('sudoku',this.nextOptions.sudokuDifficulty,'next',true)}${this._difficulty('combat',this.nextOptions.combatDifficulty,'next',true)}</div>`}<button type="button" class="rg-primary" data-action="next-wave" data-focus="next-wave" ${inCamp&&g.wave<g.maxWaves?'':'disabled'}>Enter the next map <b>→</b></button><p class="rg-fineprint">${inCamp?'Spend or save. You can leave with unopened chests.':g.mode==='freeplay'?'Free play ends after this one battlefield.':'Complete this battle before continuing.'}</p></section>`;
  }
  _casinoView(){
    const ready=this.game.phase==='loot';
    const spinning=Boolean(this.spin&&!this.spin.done);
    const result=this.spin?.done?this.spin.result:null;
    const symbols=result?.reels||['◇','ϟ','▣'];
    return `<section class="rg-casino"><div class="rg-casino-intro"><span class="rg-eyebrow">LUCKY CIRCUIT / THREE-REEL TERMINAL</span><h3>Fortune favors the curious.</h3><p>Stake earned credits for a chance at more credits or a sealed chest. Every chest still needs fragments to open.</p></div><div class="rg-slot-machine ${spinning?'spinning':''} ${result?.ok?'has-result':''}"><div class="rg-machine-top"><span>GRIDFALL</span><i>★</i><span>SUPPLY DIVISION</span></div><div class="rg-reels" aria-label="${spinning?'Reels spinning':result?`Result: ${result.reels.join(', ')}`:'Three slot machine reels'}">${symbols.map((symbol,i)=>`<div class="rg-reel" style="--reel:${i}">${spinning?'<span class="rg-spinning-symbols" aria-hidden="true">◇<br>ϟ<br>▣<br>✦<br>◇</span>':`<span>${esc(symbol)}</span>`}</div>`).join('')}</div><div class="rg-machine-label"><span>ONE SPIN</span><strong>ϟ ${SLOT_COST}</strong><span>THREE REELS</span></div></div><div class="rg-slot-result" role="status" aria-live="polite">${spinning?'Circuit engaged…':result?esc(result.message||'Spin complete.'):ready?'Your next upgrade could be one spin away.':'Available at loot camp after you survive a battle.'}</div><button type="button" class="rg-primary rg-spin-button" data-action="spin" data-focus="spin" ${ready&&this.game.credits>=SLOT_COST&&!spinning?'':'disabled'}>${spinning?'Spinning…':'Spin the circuit'} <b>ϟ ${SLOT_COST}</b></button><p class="rg-fineprint">Optional. Credits are earned in this run. No real money or cash out.</p><details class="rg-odds"><summary data-focus="odds">Know your odds · show exact payouts</summary><p>Each spin independently chooses one outcome. Three matching symbols identify a payout; losses show three distinct symbols.</p><div class="rg-odds-table"><div><b>Outcome</b><b>Chance</b></div>${SLOT_PAYTABLE.map(outcome=>`<div><span>${esc(outcome.label|| (outcome.chestRarity?`${cap(outcome.chestRarity)} sealed chest`:outcome.credits?`${outcome.credits} credits`:'No payout'))}</span><span>${Number((outcome.probability*100).toFixed(3))}%</span></div>`).join('')}</div><p>Credit payouts are the total returned, before your ${SLOT_COST}-credit stake. Chests are sealed and cost fragments to unlock.</p></details></section>`;
  }
  showChest(result){
    if(!result?.ok){this._result(result);return;}
    this.reveal={result,returnTab:this.tab==='setup'?'inventory':this.tab,stage:this.isReducedMotion()?2:0,elapsed:0};
    this.onSound('chestCharge',{rarity:result.rarity});
    this._render();this._show();
    clearTimeout(this.revealTimer);
    if(this.reveal.stage===2){this.onSound('chestReveal',{rarity:result.rarity});return;}
    this.revealTimer=setTimeout(()=>{if(!this.reveal)return;this.reveal.stage=1;this._render();this.onSound('chestReveal',{rarity:result.rarity});this.revealTimer=setTimeout(()=>this._finishReveal(),850);},750);
  }
  _finishReveal(){
    if(!this.reveal)return;
    clearTimeout(this.revealTimer);if(this.reveal.stage===0)this.onSound('chestReveal',{rarity:this.reveal.result.rarity});this.reveal.stage=2;this._render();
    this.dialog.querySelector('[data-action="accept-loot"]')?.focus({preventScroll:true});
  }
  _chestView(){
    const {result,stage}=this.reveal,r=rarity(result.rarity),items=result.rewards||[];
    return `${this._header('FRAGMENTS SPENT. POSSIBILITIES UNLOCKED.',stage<2?'Something good in there.':'Look what you found.')}<div class="rg-body rg-reveal-body stage-${stage}" style="--loot:${r.color}"><div class="rg-reveal-stage"><div class="rg-reveal-halo"></div><div class="rg-reveal-rays">${Array.from({length:12},(_,i)=>`<i style="--ray:${i}"></i>`).join('')}</div><div class="rg-hero-chest"><div class="rg-chest-lid"><i></i><b></b></div><div class="rg-chest-base"><i></i><b>◈</b></div></div><div class="rg-reveal-particles">${Array.from({length:18},(_,i)=>`<i style="--particle:${i}"></i>`).join('')}</div></div><div class="rg-reveal-copy" aria-live="polite"><span class="rg-rarity">${r.name} cache</span><h3>${stage===0?'Waking the lock…':stage===1?'There it is.':`${items.length} new ${items.length===1?'possibility':'possibilities'}.`}</h3><p>${stage<2?'A little energy. A lot of potential.':'Already packed in your inventory. Time to make something dangerous.'}</p></div><div class="rg-reward-grid ${stage<2?'concealed':''}" ${stage<2?'aria-hidden="true"':''}>${items.map(item=>{const ir=rarity(item.rarity);return `<article class="rg-reward-card" style="--loot:${ir.color}"><div class="rg-reward-glyph">${icon(item.kind)}</div><span class="rg-rarity">${ir.name} ${item.type}</span><h4>${esc(item.name)}</h4><p>${esc(itemDescription(item))}</p></article>`;}).join('')}</div></div><footer class="rg-footer"><span>Loot is added immediately. Nothing is lost if you skip.</span><button type="button" class="rg-primary" data-action="${stage<2?'skip-reveal':'accept-loot'}" data-initial-focus data-focus="reveal-action">${stage<2?'Reveal now':'Pack the loot'} <b>${stage<2?'»':'✓'}</b></button></footer>`;
  }
  _click(event){
    const button=event.target.closest('button[data-action]');if(!button||button.disabled)return;
    const a=button.dataset.action;
    if(a==='close'){this.close();return;}
    if(a==='skip-reveal'){this._finishReveal();return;}
    if(a==='accept-loot'){const tab=this.reveal?.returnTab||'inventory';this.reveal=null;this.open(tab);return;}
    if(a==='mode'){this.options.mode=button.dataset.mode;this.refresh();return;}
    if(a==='difficulty'){const target=button.dataset.prefix==='next'?this.nextOptions:this.options;target[`${button.dataset.type}Difficulty`]=button.dataset.value;this.refresh();return;}
    if(a==='start'){const options={...this.options};this.close();this.onNewRun(options);return;}
    if(a==='tab'){this.open(button.dataset.tab);return;}
    if(a==='filter'){this.filter=button.dataset.filter;this.page=0;this.refresh();return;}
    if(a==='page'){this.page+=Number(button.dataset.delta);this.refresh();return;}
    if(a==='select-item'){this.selectedItem=button.dataset.item;this.refresh();return;}
    if(a==='browse-attachments'){this.filter='attachment';this.open('inventory');return;}
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
      this.spinTimer=setTimeout(()=>{if(!this.spin)return;this.spin.done=true;this.onSound(result.reward?.credits||result.reward?.chestRarity?'slotWin':'slotLose');this._render();this.dialog.querySelector('[data-action="spin"]')?.focus({preventScroll:true});},this.isReducedMotion()?0:1700);
    }
  }
  _change(event){
    if(event.target.dataset.action==='select-tower'){
      const cell=Number(event.target.value);if(cell>=0){this.onInspect(cell);this.refresh();}
    }
  }
  _focusable(){return Array.from(this.dialog.querySelectorAll('button:not(:disabled),select:not(:disabled),summary,a[href],input:not(:disabled)')).filter(node=>node.getClientRects().length&&!node.closest('[aria-hidden="true"]'));}
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
      if(node?.tagName==='SELECT'&&dx){const next=Math.min(node.options.length-1,Math.max(0,node.selectedIndex+Math.sign(dx)));node.selectedIndex=next;node.dispatchEvent(new Event('change',{bubbles:true}));}
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
    const directions={ArrowUp:-1,ArrowDown:1,ArrowLeft:-1,ArrowRight:1};
    if(directions[event.key]&&event.target.tagName!=='SELECT'){event.preventDefault();this._moveFocus(directions[event.key]);}
  }
}
