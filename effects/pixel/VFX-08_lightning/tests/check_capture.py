#!/usr/bin/env python3
from pathlib import Path
from PIL import Image
import numpy as np,json,sys
frames=sorted(Path(sys.argv[1]).glob('frame_*.png'));assert frames
counts=[];colors=set();mismatch=0
for p in frames:
 a=np.asarray(Image.open(p).convert('RGB'));assert a.shape==(360,640,3)
 small=a[108:236,24:152];large=a[70:326,184:440]
 expected=np.repeat(np.repeat(small,2,axis=0),2,axis=1)
 mismatch+=int(not np.array_equal(large,expected))
 bg=a[250,24];mask=np.any(small!=bg,axis=2);counts.append(int(mask.sum()))
 colors.update(map(tuple,small[mask]))
assert mismatch==0,f'{mismatch} nearest-copy mismatches'
assert min(counts)==0 and max(counts)>100,(min(counts),max(counts))
assert len(set(counts))>=6,'Animation needs distinct development/peak/decay/clear states'
report={'frames':len(frames),'nearest_mismatches':mismatch,'minimum_effect_pixels':min(counts),'maximum_effect_pixels':max(counts),'distinct_coverage_counts':len(set(counts)),'effect_colors':len(colors),'first_24_counts':counts[:24]}
print(json.dumps(report,indent=2))
