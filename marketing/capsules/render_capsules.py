#!/usr/bin/env python3
"""Compose Steam art from the game's existing Canvas voxel diorama and SVG brand.
No gameplay screenshot is altered; these are explicitly store capsule artworks.
"""
from pathlib import Path
import base64, hashlib, json, math, subprocess, tempfile
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'release/marketing/capsules'
OUT.mkdir(parents=True, exist_ok=True)
ART = OUT / 'diorama-source.png'
if not ART.exists(): raise SystemExit('Run capture_diorama.gd first (see README).')
DATA = 'data:image/png;base64,'+base64.b64encode(ART.read_bytes()).decode()


def svg_start(w,h,transparent=False):
    return f'''<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" width="{w}" height="{h}" viewBox="0 0 {w} {h}">
<defs><radialGradient id="bg" cx="68%" cy="48%" r="90%"><stop offset="0" stop-color="#245157"/><stop offset=".47" stop-color="#102e38"/><stop offset="1" stop-color="#06131e"/></radialGradient>
<linearGradient id="ivory" x2="0" y2="1"><stop stop-color="#ffffee"/><stop offset="1" stop-color="#c9e9d6"/></linearGradient>
<linearGradient id="gold" x2="0" y2="1"><stop stop-color="#ffdc9d"/><stop offset="1" stop-color="#efad70"/></linearGradient>
<radialGradient id="glow"><stop stop-color="#8cf4ca" stop-opacity=".14"/><stop offset="1" stop-color="#8cf4ca" stop-opacity="0"/></radialGradient></defs>''' + ('' if transparent else background(w,h))


def background(w,h):
    s=f'<rect width="{w}" height="{h}" fill="url(#bg)"/><ellipse cx="{w*.72}" cy="{h*.55}" rx="{w*.6}" ry="{h*.7}" fill="url(#glow)"/>'
    # Fine stepped paths continue the board motif without resembling UI panels.
    for j in range(5):
        x=w*(.38+j*.16); y=h*(-.12+j*.03)
        s+=f'<path d="M{x} {y} l{w*.1} {h*.18} l{-w*.19} {h*.24} l{w*.12} {h*.2}" fill="none" stroke="#83e7c1" stroke-opacity=".055" stroke-width="{max(1,w/850)}"/>'
    for j in range(24):
        x=(j*193.1+71)%w; y=(j*127.8+41)%h
        r=max(1,min(w,h)*(.002 if j%4 else .0035))
        s+=f'<path d="M{x} {y-r} l{r} {r} l{-r} {r} l{-r} {-r} Z" fill="{("#f9bc7f" if j%3==0 else "#8fe9c8")}" opacity=".26"/>'
    return s


def art(x,y,w):
    return f'<image x="{x}" y="{y}" width="{w}" height="{w*.75}" xlink:href="{DATA}"/>'


def title(x,y,w):
    # Width is fixed for each line, deliberately large enough at Steam's small scale.
    fs=w/4.72
    lines=[('SUDOKU',0,'ivory'),('DEFENSE',fs*.99,'gold')]
    s=''
    for txt,offset,fill in lines:
        for dy,c in [(fs*.065,'#06161d'),(fs*.032,'#3c6059'),(0,f'url(#{fill})')]:
            s+=f'<text x="{x}" y="{y+offset+dy}" font-family="DejaVu Sans" font-weight="bold" font-size="{fs}" textLength="{w}" lengthAdjust="spacingAndGlyphs" fill="{c}" stroke="#06161d" stroke-width="{fs*.022}" paint-order="stroke fill">{txt}</text>'
    return s


def badge(x,y,size):
    # Reuse the actual app's cube, without the rounded tile background.
    b=(ROOT/'godot/assets/icon.svg').read_text()
    b=b.replace('<rect width="128" height="128" rx="26" fill="#0d1d29"/>','')
    return f'<g transform="translate({x} {y}) scale({size/128})">'+b.split('>',1)[1].rsplit('</svg>',1)[0]+'</g>'


def save(name,w,h,body,transparent=False):
    target=OUT/(name+'.svg')
    target.write_text(svg_start(w,h,transparent)+body+'</svg>')
    png=OUT/(name+'.png')
    with tempfile.TemporaryDirectory(prefix='capsule-export-') as temp:
        fresh=Path(temp)/(name+'.png')
        subprocess.run(['inkscape',str(target),'--export-type=png','--export-filename='+str(fresh)],check=True,stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)
        with Image.open(fresh) as check:
            check.load()
            assert check.size==(w,h), (name, check.size)
        png.write_bytes(fresh.read_bytes())
    return png

# Brand artwork is tailored for every aspect ratio rather than machine-cropped.
save('header-capsule',920,430,art(340,-10,720)+title(46,175,425))
save('small-capsule',462,174,art(235,-30,300)+title(20,76,245))
save('main-capsule',1232,706,art(415,38,930)+title(60,274,555))
save('vertical-capsule',748,896,art(-55,209,855)+title(68,158,610))
save('library-capsule',600,900,art(-133,260,870)+title(50,174,500))
save('library-header',920,430,art(340,-10,720)+title(46,175,425))
# Hero has no title, logo, copy, UI, or call to action. Art is in the center safe zone.
save('library-hero',3840,1240,art(940,-340,1960))
save('page-background',1438,810,art(650,-40,1050)+art(-490,270,1000))
save('library-logo',1280,500,title(40,218,1200),True)

# The icon is exactly the in-game cube; Steam can also derive its small app icon.
icon_svg=ROOT/'godot/assets/icon.svg'
subprocess.run(['inkscape',str(icon_svg),'--export-width=512','--export-height=512','--export-filename='+str(OUT/'shortcut-icon.png')],check=True,stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)
icon=Image.open(OUT/'shortcut-icon.png').convert('RGB')
icon.resize((184,184),Image.Resampling.LANCZOS).save(OUT/'app-icon.jpg',quality=97,subsampling=0)
from zipfile import ZipFile
with ZipFile(OUT/'linux-icons.zip','w') as z:
    for size in [16,24,32,48,64,96,128,256,512]:
        p=OUT/f'linux-icon-{size}.png'
        icon.resize((size,size),Image.Resampling.LANCZOS).save(p)
        z.write(p,p.name)

# Proof at Steam-like display sizes (not an upload asset).
proof=Image.new('RGB',(1440,1100),'#101a21')
d=ImageDraw.Draw(proof)
font=ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf',17)
positions=[('header-capsule',25,40,460,215),('small-capsule',25,320,231,87),('main-capsule',520,40,616,353),('vertical-capsule',25,480,299,358),('library-capsule',370,480,240,360),('library-logo',680,470,640,250),('library-hero',680,800,640,207)]
for name,x,y,w,h in positions:
    im=Image.open(OUT/(name+'.png')).convert('RGBA').resize((w,h),Image.Resampling.LANCZOS)
    proof.paste(im,(x,y),im)
    d.text((x,y-24),name,fill='#b6c9cc',font=font)
proof.save(OUT/'capsule-proof.jpg',quality=95)
manifest={}
for path in sorted(OUT.glob('*')):
    if path.suffix not in ['.png','.jpg','.zip'] or path.name.startswith('linux-icon-') or path.name=='diorama-source.png':continue
    item={'bytes':path.stat().st_size,'sha256':hashlib.sha256(path.read_bytes()).hexdigest()}
    if path.suffix in ['.png','.jpg']:
        with Image.open(path) as im:item.update(width=im.width,height=im.height,mode=im.mode)
    manifest[path.name]=item
(OUT/'asset-manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
print(json.dumps(manifest,indent=2))
