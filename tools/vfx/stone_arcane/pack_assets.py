"""Pack rendered straight-alpha RGBA frames into runtime atlases (requires Pillow)."""
from pathlib import Path
import argparse,json
from PIL import Image
p=argparse.ArgumentParser();p.add_argument('frames');p.add_argument('output');a=p.parse_args();dst=Path(a.output);dst.mkdir(parents=True,exist_ok=True)
manifest=[]
for name in ['stone_impact','charge_dust','stone_fall','energy_orb','summon','lightning_impact']:
 files=sorted((Path(a.frames)/name).glob('*.png'))
 if len(files)!=24:raise ValueError(f'{name}: expected 24 frames, got {len(files)}')
 cell=256 if name in ['stone_impact','summon'] else 128
 atlas=Image.new('RGBA',(cell*6,cell*4))
 for n,f in enumerate(files):
  im=Image.open(f).convert('RGBA');assert im.size==(256,256);im=im.resize((cell,cell),Image.Resampling.LANCZOS);atlas.paste(im,((n%6)*cell,(n//6)*cell))
 atlas.save(dst/(name+'.png'),optimize=True)
 manifest.append(dict(key=name,path='res://assets/vfx/blender/stone_arcane/'+name+'.png',columns=6,rows=4,cell_size=cell,frames=24,fps=30 if name not in ['energy_orb','summon'] else 24,loop=name=='energy_orb',alpha='straight'))
(dst/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
