"""Pack Blender-rendered RGBA frames without resampling or lossy compression.
Requires Pillow. Source renders stay outside the game repository.
"""
import argparse,json,math
from pathlib import Path
from PIL import Image, ImageChops
p=argparse.ArgumentParser();p.add_argument('--input',type=Path,required=True);p.add_argument('--output',type=Path,required=True);p.add_argument('--preview',type=Path);a=p.parse_args()
a.output.mkdir(parents=True,exist_ok=True)
manifest=[]
for effect,key,loop,fps in [('ice_growth','ice_shell',False,48),('ice_shatter','ice_shatter',False,40),('ice_thaw','ice_thaw',False,32),('dark_vortex','dark_vortex',True,24)]:
 frames=[]
 for index in range(24):
  im=Image.open(a.input/effect/f'{index:03}.png').convert('RGBA')
  strength=1.0  # Blender faces are translucent; slim luminous edges intentionally retain higher alpha.
  if strength<1: im.putalpha(im.getchannel('A').point(lambda v:round(v*strength)))
  # No fully-transparent RGB fringe is carried into the atlas.
  raw=bytearray(im.tobytes())
  for offset in range(0,len(raw),4):
   if raw[offset+3]==0: raw[offset:offset+3]=b'\x00\x00\x00'
  im=Image.frombytes('RGBA',im.size,bytes(raw))
  assert im.size==(256,256),im.size
  border=im.getchannel('A'); box=border.getbbox()
  if box: assert box[0]>=3 and box[1]>=3 and box[2]<=253 and box[3]<=253,(effect,index,box)
  cell=256 if effect=='dark_vortex' else 128
  if cell!=256:
   im=im.convert('RGBa').resize((cell,cell),Image.Resampling.LANCZOS).convert('RGBA')
  frames.append(im)
 atlas=Image.new('RGBA',(6*cell,4*cell))
 for i,im in enumerate(frames):atlas.paste(im,((i%6)*cell,(i//6)*cell))
 file=a.output/f'{key}.png';atlas.save(file,optimize=True)
 manifest.append(dict(key=key,path=f'res://assets/vfx/blender/ice_dark/{file.name}',columns=6,rows=4,frames=24,fps=fps,loop=loop,cell_size=cell,source_cell_size=256,alpha='straight',intended_mode='alpha_blend',notes=('Normalized freeze growth; hold last frame until thaw/shatter.' if key=='ice_shell' else 'Visual only. Runtime gameplay timers remain authoritative.')))
 if a.preview:
  a.preview.mkdir(parents=True,exist_ok=True)
  bgframes=[]
  for im in frames:
   bg=Image.new('RGBA',im.size,(20,28,43,255));bg.alpha_composite(im);bgframes.append(bg.convert('RGB').resize((256,256),Image.Resampling.LANCZOS))
  bgframes[0].save(a.preview/f'{key}.webp',save_all=True,append_images=bgframes[1:],duration=round(1000/fps),loop=0,lossless=True)
(a.output/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
print(json.dumps(manifest,indent=2))
