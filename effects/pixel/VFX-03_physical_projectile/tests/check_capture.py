#!/usr/bin/env python3
"""Validate exact native frames and immutable render inputs, not synthetic images."""
from pathlib import Path
from PIL import Image
import numpy as np
import json,hashlib,argparse
p=argparse.ArgumentParser();p.add_argument('frames',type=Path);p.add_argument('manifest',type=Path);p.add_argument('--output',type=Path);a=p.parse_args()
m=json.loads(a.manifest.read_text())
for path,h in m['files'].items(): assert hashlib.sha256((a.manifest.parent/'project'/path).read_bytes()).hexdigest()==h,path
def frame(n): return np.array(Image.open(a.frames/f'physical{n:08d}.png').convert('RGB'))
def crop(n): return frame(n)[110:180,25:325]
def mask(im): return np.any(im!=[32,38,43],axis=2)
def bounds(n):
    yy,xx=np.where(mask(crop(n)));return [int(xx.min()),int(yy.min()),int(xx.max()),int(yy.max())]
f=frame(630)
assert np.array_equal(f[249:297,33:273],f[132:148,95:175].repeat(3,0).repeat(3,1)), '3x differs from exact nearest'
arrow,knife=bounds(48),bounds(168)
assert arrow[3]-arrow[1]==6 and knife[3]-knife[1]==6, 'straight bodies lack full silhouette'
assert not np.array_equal(crop(48),crop(168)), 'arrow and knife unexpectedly identical'
slow,fast=bounds(510),bounds(630)
assert fast[2]-fast[0]>slow[2]-slow[0]+10, 'velocity does not change trail length'
assert bounds(264)[3]-bounds(264)[1]>10 and bounds(384)[3]-bounds(384)[1]>10, 'turning not rendered'
fade=[int(mask(crop(n)).sum()) for n in [720,723,726,732,762]]
assert fade[0]>fade[1]>fade[2]>fade[3]==fade[4]==0, 'stop does not visibly decay then clear'
result={'source_digest':m['source_digest'],'native_frames':len(list(a.frames.glob('*.png'))),'resolution':[640,360],'fps':60,'nearest_3x_exact':True,'arrow_frame':48,'knife_frame':168,'turn_frames':[264,384],'slow_bbox':slow,'fast_bbox':fast,'stop_frames':[720,723,726,732,762],'stop_pixel_counts':fade}
print(json.dumps(result,indent=2))
if a.output:a.output.write_text(json.dumps(result,indent=2)+'\n')
