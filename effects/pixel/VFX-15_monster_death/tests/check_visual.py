#!/usr/bin/env python3
from pathlib import Path
import json,sys
from PIL import Image
import numpy as np
p=Path(sys.argv[1]);load=lambda name:np.asarray(Image.open(p/(name+'.png')).convert('RGBA'))
src=load('source');ready=load('ready');crop=ready[26:70,28:68]
assert np.array_equal(src[:,:,3],crop[:,:,3]), 'Ready source alpha changed'
assert np.array_equal(ready,load('reset')), 'Reset does not restore exact host'
assert np.array_equal(load('flipped')[26:70,28:68,3],src[:,::-1,3]), 'Flip alpha differs'
counts=[]
for name in ['ready','early','middle','body_gone','done']:
 a=load(name);count=int(np.count_nonzero(a[:,:,3]));counts.append(count)
 mask=ready[:,:,3]==0
 assert np.all(a[:,:,3][mask]==0), 'Pixels appeared outside source alpha'
 assert np.all((a[:,:,3]==0)|(a[:,:,3]==ready[:,:,3])), 'Alpha was faded or squared'
assert counts[0]>counts[1]>counts[2]>counts[3]==counts[4]==0, counts
result={'alpha_pixels':dict(zip(['ready','early','middle','body_gone','done'],counts)),'source_alpha_exact':True,'fractional_alpha_exact':True,'reset_exact':True,'flip_exact':True,'transparent_holes_preserved':True}
print(json.dumps(result,indent=2));(p/'proof.json').write_text(json.dumps(result,indent=2))
