#!/usr/bin/env python3
"""Capture shipping Godot gameplay at1080p without editing the game project.

MovieWriter locks its resolution before SceneTree scripts run. A temporary
project copy changes only the initial viewport/window dimensions (the same
layout used by resizing the shipping app) and the capture output path. Assets,
UI, render settings, gameplay, stats and input code remain byte-identical.
"""
from pathlib import Path
import argparse,json,os,re,shutil,subprocess
ROOT=Path(__file__).resolve().parents[1]

def main():
    parser=argparse.ArgumentParser()
    parser.add_argument('--godot',required=True,type=Path)
    parser.add_argument('--display',type=int,default=231)
    parser.add_argument('--stills-only',action='store_true')
    parser.add_argument('--solve-only',action='store_true',help='Refresh solve/transition footage after a placement visual change')
    args=parser.parse_args()
    out=ROOT/'release/marketing';out.mkdir(parents=True,exist_ok=True)
    # A new full take supersedes any earlier solve-only pickup.
    if not args.solve_only and not args.stills_only:
        for stale in [out/'solve-capture.avi',out/'solve-capture-manifest.json']:
            if stale.exists():stale.unlink()
    target=out/('capture-project-solve' if args.solve_only else 'capture-project')
    shutil.copytree(ROOT/'godot',target,ignore=shutil.ignore_patterns('.godot','build','__pycache__'),dirs_exist_ok=True)
    project=target/'project.godot';text=project.read_text()
    expected=re.search(r'config/version="([^"]+)"',text).group(1)
    for name,value in [('viewport_width',1920),('viewport_height',1080),('window_width_override',1920),('window_height_override',1080)]:
        text=re.sub(r'(window/size/'+name+r'=)\d+',lambda m:m[1]+str(value),text)
    project.write_text(text)
    capture=target/'tests/capture_store_gameplay.gd'
    capture_text=capture.read_text().replace('res://../release/marketing',str(out))
    manifest_name='solve-capture-manifest.json' if args.solve_only else 'capture-manifest.json'
    if args.solve_only:
        end=capture_text[capture_text.index('\tvar manifest :='): ]
        capture_text=capture_text[:capture_text.index('\t# Put legitimately earned varied modules')]+ '\tmark("end")\n'+end
        capture_text=capture_text.replace('capture-manifest.json',manifest_name)
    capture.write_text(capture_text)
    subprocess.run([str(args.godot),'--headless','--path',str(target),'--editor','--import','--quit'],check=True)
    manifest=out/manifest_name
    if manifest.exists():manifest.unlink()
    env=os.environ.copy();env['DISPLAY']=f'127.0.0.1:{args.display}';env['XDG_DATA_HOME']=str(out/'capture-profile')
    command=['xvfb-run','-n',str(args.display),'-l','-s','-screen 0 1920x1080x24 -nolisten local -nolisten unix -listen tcp','env',f'DISPLAY=127.0.0.1:{args.display}',str(args.godot),'--path',str(target),'--resolution','1920x1080','--audio-driver','Dummy','--rendering-method','gl_compatibility','--rendering-driver','opengl3_es','--fixed-fps','30','--disable-vsync']
    if not args.stills_only:
        movie=out/('solve-capture.avi' if args.solve_only else 'capture.avi')
        if movie.exists():movie.unlink()
        command+=['--write-movie',str(movie)]
    command+=['--script','res://tests/capture_store_gameplay.gd']
    if args.stills_only:command+=['--','--stills-only']
    subprocess.run(command,check=True,env=env,timeout=1800)
    assert json.loads(manifest.read_text())['version']==expected,'Capture version must match source'
    print('CAPTURE_VERIFIED_VERSION',expected)
if __name__=='__main__':main()
