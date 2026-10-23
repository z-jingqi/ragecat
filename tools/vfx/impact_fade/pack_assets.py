"""Pack original Blender frames into straight-alpha atlases without multiplying alpha."""
from pathlib import Path
import argparse,json,math
from PIL import Image
p=argparse.ArgumentParser();p.add_argument('frames');p.add_argument('output');a=p.parse_args();dst=Path(a.output);dst.mkdir(parents=True,exist_ok=True)
manifest=[]
for name,count in [('death_smoke',12),('shield_break',8)]:
 files=sorted((Path(a.frames)/name).glob('*.png'))
 if len(files)!=count:raise ValueError(f'{name}: expected {count} frames, got {len(files)}')
 cols=4;rows=math.ceil(count/cols);cell=256;atlas=Image.new('RGBA',(cell*cols,cell*rows))
 for i,f in enumerate(files):
  im=Image.open(f).convert('RGBA')
  if im.size!=(cell,cell):raise ValueError(f'Unexpected frame size: {f}')
  atlas.paste(im,((i%cols)*cell,(i//cols)*cell))
 atlas.save(dst/(name+'.png'),optimize=True)
 manifest.append(dict(key=name,path=f'res://assets/vfx/blender/impact_fade/{name}.png',columns=cols,rows=rows,cell_size=cell,frames=count,fps=24,loop=False,alpha='straight'))
(dst/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
