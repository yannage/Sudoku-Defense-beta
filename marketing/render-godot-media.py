#!/usr/bin/env python3
"""Edit real native Godot capture into the Steam trailer and description loops.

Input: capture_store_gameplay.gd's AVI/timeline and the original synthesized
32-second score. No reconstructed gameplay, AI video, outside music or samples.
All game footage stays intact; only trailer captions and closing branding are
composited. Store screenshots and embedded page loops carry no extra claims.
"""
from pathlib import Path
import argparse, json, subprocess
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
FONT = '/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf'
BOLD = '/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf'

def run(*args):
    subprocess.run([str(x) for x in args], check=True)

def caption(path, title, stage):
    image = Image.new('RGBA',(1920,1080),(0,0,0,0))
    d = ImageDraw.Draw(image)
    # Replace only the lower input strip. The actual board and menus remain
    # visible in their original geometry, lighting, colors and animation.
    d.rectangle((0,936,1920,1080), fill=(6,18,26,246))
    d.rectangle((54,965,59,1042),fill=(132,231,195,255))
    d.text((82,959),stage.upper(),font=ImageFont.truetype(BOLD,18),fill=(132,231,195,255))
    d.text((80,991),title,font=ImageFont.truetype(BOLD,39),fill=(239,246,236,255))
    d.text((1628,1006),'ALPHA GAMEPLAY',font=ImageFont.truetype(FONT,18),fill=(152,177,182,255))
    image.save(path)

def encode_video(source, destination, start, duration, overlay=None):
    cmd=['ffmpeg','-hide_banner','-loglevel','warning','-y','-ss',str(start),'-i',str(source)]
    if overlay:
        cmd+=['-loop','1','-i',str(overlay),'-filter_complex','[0:v]setsar=1[v];[v][1:v]overlay=0:0:shortest=1,format=yuv420p[out]','-map','[out]']
    else: cmd+=['-vf','setsar=1,format=yuv420p']
    cmd+=['-t',str(duration),'-an','-r','30','-c:v','libx264','-preset','fast','-crf','18','-pix_fmt','yuv420p','-color_primaries','bt709','-color_trc','bt709','-colorspace','bt709','-movflags','+faststart',str(destination)]
    run(*cmd)

def loop(source, dest, start, duration, crop=None):
    framing=("crop="+crop+",") if crop else ""
    run('ffmpeg','-hide_banner','-loglevel','warning','-y','-ss',start,'-i',source,'-t',duration,'-an','-vf',framing+'scale=1170:-2:flags=lanczos,setsar=1,format=yuv420p','-r','30','-c:v','libx264','-preset','fast','-crf','23','-color_primaries','bt709','-color_trc','bt709','-colorspace','bt709','-movflags','+faststart',dest.with_suffix('.mp4'))
    run('ffmpeg','-hide_banner','-loglevel','warning','-y','-i',dest.with_suffix('.mp4'),'-filter_complex','fps=12,scale=780:-2:flags=lanczos,split[a][b];[a]palettegen=max_colors=112:stats_mode=diff[p];[b][p]paletteuse=dither=bayer:bayer_scale=3:diff_mode=rectangle','-loop','0',dest.with_suffix('.gif'))

def main():
    parser=argparse.ArgumentParser();parser.add_argument('--out',type=Path,default=ROOT/'release/marketing');args=parser.parse_args()
    out=args.out;out.mkdir(parents=True,exist_ok=True)
    source=out/'capture.avi'
    manifest=json.loads((out/'capture-manifest.json').read_text())
    times={row['name']:row['seconds'] for row in manifest['timeline']}
    solve_source=out/'solve-capture.avi'
    solve_manifest=json.loads((out/'solve-capture-manifest.json').read_text()) if (out/'solve-capture-manifest.json').exists() else manifest
    solve_times={row['name']:row['seconds'] for row in solve_manifest['timeline']}
    if not solve_source.exists():solve_source=source
    assert solve_manifest['version']==manifest['version'],'Do not combine captures from different game versions'
    edit=out/'edit';edit.mkdir(exist_ok=True)
    beats=[
        ('hook',times['battle']+6,3,'Sudoku meets tower defense.','Plan • Build • Defend'),
        ('solve',solve_times['solve'],6,'Every answer is a tower.','01 / Solve'),
        ('transform',solve_times['transform'],2,'Solve first. Fight next.','02 / Prepare'),
        ('gear',times['gear'],5,'Build the tower you need.','Mix and stack modules'),
        ('battle',times['battle']+7,8,'Your moves shape the battlefield.','03 / Defend'),
        ('loot',times['loot'],4,'Open chests. Keep building.','04 / Loot'),
    ]
    clips=[]
    for name,start,duration,title,stage in beats:
        overlay=edit/(name+'.png');caption(overlay,title,stage)
        clip=edit/(name+'.mp4');encode_video(solve_source if name in ['solve','transform'] else source,clip,start,duration,overlay);clips.append(clip)
    # Closing card uses the game's real rendered voxel composition and logo.
    background=Image.open(out/'capsules/library-hero.png').convert('RGBA')
    target=(1920,1080)
    factor=max(target[0]/background.width,target[1]/background.height)
    background=background.resize((round(background.width*factor),round(background.height*factor)),Image.Resampling.LANCZOS)
    left=(background.width-1920)//2;top=(background.height-1080)//2
    background=background.crop((left,top,left+1920,top+1080))
    background=Image.alpha_composite(background,Image.new('RGBA',target,(4,14,22,172)))
    logo=Image.open(out/'capsules/library-logo.png').convert('RGBA')
    logo.thumbnail((1420,555),Image.Resampling.LANCZOS)
    background.alpha_composite(logo,((1920-logo.width)//2,205))
    d=ImageDraw.Draw(background)
    for text,y,size,color in [('Solve first. Fight next.',775,40,(237,247,240,255)),('COMING TO STEAM',881,22,(132,231,195,255)),('Alpha gameplay • Development in progress',983,18,(148,172,177,255))]:
        font=ImageFont.truetype(BOLD if size>30 else FONT,size)
        width=d.textlength(text,font=font);d.text(((1920-width)/2,y),text,font=font,fill=color)
    card=edit/'end-card.png';background.convert('RGB').save(card)
    endclip=edit/'end.mp4'
    run('ffmpeg','-hide_banner','-loglevel','warning','-y','-loop','1','-i',card,'-t','4','-vf','fade=t=in:st=0:d=0.25,fade=t=out:st=3.6:d=0.4,format=yuv420p','-r','30','-an','-c:v','libx264','-preset','fast','-crf','18',endclip)
    clips.append(endclip)
    listing=edit/'trailer-concat.txt';listing.write_text(''.join("file '"+str(p.resolve())+"'\n" for p in clips))
    run('ffmpeg','-hide_banner','-loglevel','warning','-y','-f','concat','-safe','0','-i',listing,'-i',out/'soundtrack.wav','-map','0:v:0','-map','1:a:0','-t','32','-c:v','libx264','-preset','fast','-b:v','8M','-minrate','8M','-maxrate','8M','-bufsize','16M','-x264-params','nal-hrd=cbr:filler=1:force-cfr=1','-pix_fmt','yuv420p','-color_primaries','bt709','-color_trc','bt709','-colorspace','bt709','-c:a','aac','-b:a','192k','-ar','48000','-ac','2','-movflags','+faststart',out/'sudoku-defense-steam-trailer.mp4')
    loop(solve_source,out/'01-solve-loop',solve_times['solve'],9,'1160:820:400:110')
    loop(source,out/'02-build-loop',times['gear'],6,'1560:860:360:100')
    # Battle/chest montage from two actual clips, under Valve's12-second cap.
    first=edit/'loop-battle.mp4';second=edit/'loop-loot.mp4'
    encode_video(source,first,times['battle']+8,5)
    encode_video(source,second,times['loot']+0.6,4)
    listing=edit/'loop-concat.txt'
    listing.write_text("file '"+str(first.resolve())+"'\nfile '"+str(second.resolve())+"'\n")
    combined=edit/'loop-combined.mp4'
    run('ffmpeg','-hide_banner','-loglevel','warning','-y','-f','concat','-safe','0','-i',listing,'-c','copy',combined)
    loop(combined,out/'03-defend-loot-loop',0,9)
    run('ffmpeg','-hide_banner','-loglevel','warning','-y','-ss','19','-i',out/'sudoku-defense-steam-trailer.mp4','-frames:v','1',out/'trailer-poster.jpg')
    details={
      'trailer':{'path':'sudoku-defense-steam-trailer.mp4','duration':32,'resolution':[1920,1080],'fps':30,'video':'H.264 CBR 8 Mbps target, YUV420, BT.709','audio':'original synthesized score,AAC192kbpsstereo48kHz'},
      'loops':[{'name':'01-solve-loop','duration':9,'framing':'board crop'},{'name':'02-build-loop','duration':6,'framing':'board and gear crop'},{'name':'03-defend-loot-loop','duration':9}],
      'capture':manifest,
      'solve_capture':solve_manifest,
      'description':'All footage from the current Godot scene. Captions/end card are marketing overlays. Page loops and screenshots show the game UI with no marketing text added. No release date, price, Deck verification or unshipped feature claims.'}
    probe=json.loads(subprocess.check_output(['ffprobe','-v','error','-select_streams','v:0','-show_entries','stream=bit_rate','-show_entries','format=bit_rate,size','-of','json',str(out/'sudoku-defense-steam-trailer.mp4')]))
    details['trailer']['measured_video_bps']=int(probe['streams'][0]['bit_rate'])
    details['trailer']['measured_total_bps']=int(probe['format']['bit_rate'])
    details['trailer']['bytes']=int(probe['format']['size'])
    (out/'media-manifest.json').write_text(json.dumps(details,indent=2))
    print('GODOT_MEDIA_READY',out)
if __name__=='__main__':main()
