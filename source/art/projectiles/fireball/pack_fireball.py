"""Pack the 24 original Blender renders. Run with Python and Pillow."""
from pathlib import Path
import argparse
from PIL import Image
p=argparse.ArgumentParser();p.add_argument('frames',type=Path);p.add_argument('output',type=Path);a=p.parse_args()
frames=[Image.open(a.frames/f'frame_{i:03d}.png').convert('RGBA') for i in range(24)]
w,h=frames[0].size
assert all(im.size==(w,h) for im in frames)
atlas=Image.new('RGBA',(w*6,h*4))
for i,im in enumerate(frames):
 im.putdata([(r,g,b,alpha) if alpha else (0,0,0,0) for r,g,b,alpha in im.getdata()])
 atlas.paste(im,((i%6)*w,(i//6)*h))
a.output.parent.mkdir(parents=True,exist_ok=True);atlas.save(a.output)
