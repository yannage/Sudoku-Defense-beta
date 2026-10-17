/** Tiny reusable voxel illustrations, built from a single isometric projection.
 * Decorative only; the surrounding control always carries its readable label.
 */
const COLORS = Object.freeze({common:'#b7c7d9',uncommon:'#91e8a6',rare:'#77caff',epic:'#c7a0ff',legendary:'#ffca69'});
const KINDS = Object.freeze({rapid:'#6de8ff',electric:'#c6a0ff',frost:'#a4c7ff',blast:'#ffae68',venom:'#9be878',range:'#ffe188',power:'#fb86c3',gravity:'#bb9bff',nova:'#ff7289',overclock:'#6de8ff',overcharge:'#ffe188',freeze:'#a4c7ff',repair:'#91e8a6',credit:'#ffbb7c',fragment:'#b8a0fa',core:'#fa9993'});
const safeColor = (value,fallback) => /^#[\da-f]{6}$/i.test(String(value)) ? String(value) : /^#[\da-f]{3}$/i.test(String(value)) ? '#'+String(value).slice(1).split('').map(c=>c+c).join('') : fallback;
const shade = (color,amount) => '#'+[1,3,5].map(i=>Math.round(Math.min(255,Math.max(0,parseInt(color.slice(i,i+2),16)*amount))).toString(16).padStart(2,'0')).join('');
const point = (x,y,z=0) => [64+(x-y)*4,82+(x+y)*2-z*4];
const coords = points => points.map(p=>p.map(n=>Number(n.toFixed(2))).join(',')).join(' ');
const poly = (points,fill,extra='') => `<polygon points="${coords(points)}" fill="${fill}"${extra}/>`;
function box(x,y,z,w,d,h,color,extra='') {
  return `<g${extra}>${poly([point(x,y+d,z),point(x+w,y+d,z),point(x+w,y+d,z+h),point(x,y+d,z+h)],shade(color,.76))}${poly([point(x+w,y,z),point(x+w,y+d,z),point(x+w,y+d,z+h),point(x+w,y,z+h)],shade(color,.51))}${poly([point(x,y,z+h),point(x+w,y,z+h),point(x+w,y+d,z+h),point(x,y+d,z+h)],color)}</g>`;
}
const shadow = () => poly([point(-8,-5,-.6),point(7,-5,-.6),point(8,5,-.6),point(-7,5,-.6)],'#030a11',' opacity=".55"');
const plate = () => box(-5,-4,0,10,8,.8,'#425665')+box(-4.4,-3.4,.8,8.8,6.8,.5,'#78949a');
const light = (x,y,z,color,size=1) => box(x,y,z,size,size,.65,color);
function chest(color) {
  let body=shadow();
  for(const x of [-5.7,3.9])for(const y of [-3.5,2.2])body+=box(x,y,0,1.8,1.8,1.5,'#677c81');
  body+=box(-6,-4,1,12,8,1,'#708b8c')+box(-5.8,-3.8,2,11.6,7.6,4.4,'#45616a');
  // Recessed interior, chunky corner rails and inset front face panels.
  body+=box(-5.15,-3.15,6.35,10.3,6.3,.12,'#0e242a');
  for(const x of [-5.9,4.85])body+=box(x,3.65,2,1.05,.55,4.5,color);
  for(const y of [-3.85,2.9])body+=box(5.55,y,2,.6,.95,4.5,color);
  for(const x of [-3.9,.55])body+=box(x,3.85,2.75,3.35,.3,2,'#607d80');
  body+=box(-1,3.95,4.6,2,1,2.3,'#243d4b')+box(-.5,4.93,5.25,1,.2,1,color,' class="vx-chest-lock"');
  body+=box(5.95,-1.5,3.3,.25,2.7,1.5,'#253d46')+box(6.22,-1.12,3.7,.18,1.9,.6,color);
  const glow=`<g class="vx-chest-glow">${poly([[31,67],[26,16],[58,4],[100,22],[98,68]],color,' opacity=".10"')}${poly([[40,68],[49,19],[71,13],[88,67]],color,' opacity=".18"')}${box(-4.8,-2.8,6.4,9.6,5.6,.3,shade(color,1.13))}</g>`;
  let lid=box(-6.25,-4.25,6.6,12.5,8.5,2.1,'#668a8c');
  lid+=box(-5.25,-3.3,8.7,10.5,6.6,.4,'#94b6af');
  for(const x of [-5.4,3.95])lid+=box(x,-4.3,6.6,1.45,8.6,2.35,color);
  lid+=box(-1.45,-1.4,9.1,2.9,2.8,.55,'#304a54')+box(-.8,-.75,9.65,1.6,1.5,.7,color);
  const rays=[[-37,-30],[-26,-54],[-5,-66],[23,-48],[43,-28],[31,-8],[-44,-9],[5,-37]];
  const particles=`<g class="vx-chest-particles">${rays.map(([dx,dy],i)=>`<g class="vx-chest-spark" style="--vx-dx:${dx}px;--vx-dy:${dy}px;--vx-delay:${i*25}ms">${box(-.7,-.7,7,1.4,1.4,1.4,i%2?color:'#daf2d9')}</g>`).join('')}</g>`;
  return body+glow+`<g class="vx-chest-lid">${lid}</g>`+particles;
}
function moduleArt(kind,color) {
  let art=shadow()+plate();
  const pedestal=()=>box(-2.6,-2.6,1.3,5.2,5.2,1.2,'#42606a');
  switch(kind) {
    case 'rapid':
      art+=pedestal();
      for(const y of [-2.5,.7])art+=box(-3,y,2.5,7,1.8,1.9,'#668b91')+box(3.5,y-.1,2.3,1.5,2,2.3,color)+box(-3,y,4.4,4,1.8,.6,color);
      break;
    case 'electric':
      art+=pedestal();
      for(const x of [-2.6,1.2]){art+=box(x,-.8,2.5,1.4,1.6,5,'#506b7a');for(const z of [3,4.7,6.4])art+=box(x-.5,-1.3,z,2.4,2.6,.7,color);}
      art+=box(-.1,-.6,6.5,1.2,1.2,1.2,'#e4dbff');break;
    case 'frost':
      art+=pedestal()+box(-1.2,-1.2,2.5,2.4,2.4,5.5,color)+box(-3.2,-.8,3.3,2,1.6,2,color)+box(1.2,-.8,4,2,1.6,1.7,color)+box(-.8,-3.1,4,1.6,2.1,2,shade(color,1.12))+box(-.8,1.2,3,1.6,2.2,1.8,color)+box(-.6,-.6,8,1.2,1.2,.8,'#e5faff');break;
    case 'blast':
      art+=pedestal()+box(-2.4,-2.4,2.5,4.8,4.8,3.1,'#72584e')+box(-1.7,-1.7,5.6,3.4,3.4,1.6,color)+box(-.6,-.6,7.2,1.2,1.2,1.5,'#ffe7b2');
      for(const x of [-2.6,1.7])art+=box(x,1.7,2.8,.9,.9,2.5,color);break;
    case 'venom':
      art+=pedestal()+box(-.8,-.8,2.5,1.6,1.6,2.7,'#7f9d6c')+box(-3,-2,5.2,6,4,1.3,color)+box(-2,-3,5.2,4,6,1.3,color)+box(-1.5,-1.5,6.5,3,3,1.3,shade(color,1.18))+box(-.65,2.8,5.5,1.3,.4,.8,'#d9ffa2');break;
    case 'range':
      art+=pedestal()+box(-.7,-.7,2.5,1.4,1.4,3,'#75959a')+box(-3,-1.7,5.5,6,3.4,1,'#617985');
      for(const x of [-3,2])art+=box(x,-1.7,6.5,1,3.4,2.2,color);
      art+=box(-2,-1.7,7.7,4,1,1,color)+box(-.5,-.2,6.5,1,1,1.7,'#fcf5c4');break;
    case 'gravity':
      art+=pedestal();
      for(const x of [-3,2])art+=box(x,-3,2.5,1,6,1,color)+box(x,-3,3.5,1,1,3,color)+box(x,2,3.5,1,1,3,color);
      art+=box(-2,-3,5.7,4,1,.8,color)+box(-2,2,5.7,4,1,.8,color)+box(-.9,-.9,4,1.8,1.8,1.8,'#dacbff');break;
    case 'nova':
      art+=pedestal()+box(-1.4,-1.4,2.5,2.8,2.8,4.5,color);
      for(const [x,y]of[[-3.5,-.8],[1.8,-.8],[-.8,-3.5],[-.8,1.8]])art+=box(x,y,4.3,1.6,1.6,1.6,color);
      art+=box(-.75,-.75,7,1.5,1.5,1,'#fff0c8');break;
    case 'core':
    case 'power':
    default:
      art+=pedestal()+box(-2,-2,2.5,4,4,3.5,'#57767b')+box(-1.3,-1.3,6,2.6,2.6,1.9,color)+box(-.65,-.65,7.9,1.3,1.3,.6,'#ffe8e5');
      for(const x of [-2.4,1.6])art+=box(x,1.6,2.9,.8,.8,3,color);
  }
  return art;
}
function consumable(kind,color) {
  let art=shadow()+box(-2.7,-2.7,0,5.4,5.4,1,'#536975')+box(-2.3,-2.3,1,4.6,4.6,4.8,'#7ea2a5')+box(-1.8,-1.8,1.3,3.6,3.6,3.4,color)+box(-1.4,-1.4,5.8,2.8,2.8,1.3,'#aec3b8')+box(-1.7,-1.7,7.1,3.4,3.4,1,'#495b6a');
  art+=box(-1.3,2.32,2.8,2.6,.2,1.5,'#dcebdc');
  if(kind==='repair')art+=box(-.35,2.52,2.7,.7,.1,1.7,color)+box(-1,2.53,3.25,2,.1,.6,color);
  else art+=box(-.9,2.52,3.1,1.8,.1,.6,color);
  return art;
}
function utility(kind,color) {
  switch(kind) {
    case 'seed':return shadow()+box(-2.3,-2.3,0,4.6,4.6,1.6,'#8d7661')+box(-1.8,-1.8,1.6,3.6,3.6,2.4,'#baa17b')+box(-.5,-.5,4,1,1,2.6,'#72ae87')+box(-2.3,-.4,5.3,2,1.4,1,color)+box(.5,-1.7,6,2,1.4,1,shade(color,1.12));
    case 'tower':return shadow()+plate()+box(-2.7,-2.7,1.3,5.4,5.4,2,'#527c78')+box(-2.2,-2.2,3.3,4.4,4.4,2.2,color)+box(-2,-2,5.5,4,4,2,'#88a9a2')+box(-.8,-.8,7.5,4.8,1.6,1.8,'#597582')+box(3.8,-1,7.3,1,2,2.2,color);
    case 'bag':return shadow()+box(-3.8,-2.5,0,7.6,5,6.5,'#6b9288')+box(-4.3,-2.7,5.7,8.6,5.4,1.5,color)+box(-1.9,-1,7.2,3.8,2,.7,'#9bb7a9')+box(-1.9,-1,7.9,.7,2,1.3,'#9bb7a9')+box(1.2,-1,7.9,.7,2,1.3,'#9bb7a9')+box(-1.2,-1,8.7,2.4,2,.5,'#9bb7a9')+box(-2.9,2.5,1.2,5.8,.7,2.8,'#385b59')+box(-.5,3.2,2.5,1,.3,1.2,color);
    case 'notes':return shadow()+box(-4,-3,0,8,6,1.4,'#547f82')+box(-3.5,-2.5,1.4,7,5,.6,'#d5e6cd')+box(-3.1,-2.1,2,6.2,4.2,.4,'#b8d6c3')+box(-4.2,-3.1,.2,1,6.2,2.6,color)+[0,1,2].map(i=>box(-2.6,-1.6+i*1.15,2.4,4.9,.35,.12,'#6e9692')).join('')+box(1.8,-3.4,2.5,.7,7,.6,'#ffbd7b');
    case 'settings':return shadow()+plate()+box(-2.8,-2.8,1.3,5.6,5.6,2.5,'#60788b')+box(-1.6,-1.6,3.8,3.2,3.2,1.2,color)+[[-4,-1],[-1,-4],[2.7,-1],[-1,2.7]].map(([x,y])=>box(x,y,2,2.3,2.3,1.7,'#8b9ea8')).join('')+box(-.8,-.8,5,1.6,1.6,.6,'#314350');
    case 'fragment':return shadow()+box(-2.2,-2.2,1,4.4,4.4,3.8,color)+box(-1.45,-1.45,4.8,2.9,2.9,2.2,shade(color,1.1))+box(-.7,-.7,7,1.4,1.4,1.7,shade(color,1.2))+box(2.5,-1.2,.4,1.4,1.4,2,color)+box(-2.3,2.1,.2,1.4,1.4,1.2,color);
    case 'credit':return shadow()+box(-3.5,-2.8,0,6,5.6,1.2,shade(color,.86))+box(-2.8,-3.5,1.2,6,5.6,1.2,color)+box(-3.2,-3,2.4,6,5.6,1.2,shade(color,1.08))+box(-1.8,-1.8,3.6,3.2,3.2,.35,'#fff0b1')+box(-.6,-.6,3.95,.8,.8,.4,'#c58c55');
    default:return moduleArt(kind,color);
  }
}
const CACHE = new Map();
/** `kind` is a utility, attachment or consumable ID; color is an optional hex.
 * `rarity` tints chassis highlights; className accepts ordinary CSS tokens only.
 */
export function voxelArt(kind='tower',{color,rarity,className=''}={}) {
  const resolved=typeof kind==='string'&&/^[a-z-]+$/.test(kind)?kind:'tower';
  const rarityColor=typeof rarity==='string'&&Object.hasOwn(COLORS,rarity)?COLORS[rarity]:null;
  const kindColor=Object.hasOwn(KINDS,resolved)?KINDS[resolved]:null;
  const accent=safeColor(color,rarityColor||kindColor||(resolved==='chest'?COLORS.common:'#8bdcc0'));
  const classes=String(className).split(/\s+/).filter(token=>/^[a-zA-Z_][\w-]*$/.test(token)).join(' ');
  const key=[resolved,accent,classes].join('|');if(CACHE.has(key))return CACHE.get(key);
  const art=resolved==='chest'?chest(accent):['overclock','overcharge','freeze','repair'].includes(resolved)?consumable(resolved,accent):utility(resolved,accent);
  const svg=`<svg class="vx-art vx-${resolved}${classes?' '+classes:''}" viewBox="0 0 128 112" xmlns="http://www.w3.org/2000/svg" aria-hidden="true" focusable="false" style="--vx-color:${accent}">${art}</svg>`;
  if(CACHE.size<200)CACHE.set(key,svg);return svg;
}
