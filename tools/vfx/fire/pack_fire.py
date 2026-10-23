"""Pack Blender straight-alpha PNG frames without resampling or baked background."""
import argparse,json,pathlib,math
from PIL import Image
p=argparse.ArgumentParser();p.add_argument('frames');p.add_argument('out');p.add_argument('--columns',type=int,default=6);p.add_argument('--crop-y',type=int,nargs=2);a=p.parse_args()
files=sorted(pathlib.Path(a.frames).glob('*.png'));assert files
first=Image.open(files[0]).convert('RGBA');
if a.crop_y:first=first.crop((0,a.crop_y[0],first.width,a.crop_y[1]))
w,h=first.size;rows=math.ceil(len(files)/a.columns)
atlas=Image.new('RGBA',(w*a.columns,h*rows))
for i,f in enumerate(files):
 im=Image.open(f).convert('RGBA');
 if a.crop_y:im=im.crop((0,a.crop_y[0],im.width,a.crop_y[1]))
 assert im.size==(w,h)
 # No alpha-mask paste: multiplying alpha here creates dark antialiased edges.
 atlas.paste(im,(i%a.columns*w,i//a.columns*h))
pathlib.Path(a.out).parent.mkdir(parents=True,exist_ok=True);atlas.save(a.out,optimize=True)
print(json.dumps(dict(path=a.out,columns=a.columns,rows=rows,frames=len(files),cell_size=w)))
