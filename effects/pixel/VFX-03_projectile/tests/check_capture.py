#!/usr/bin/env python3
"""Check lossless native MovieWriter frames, never synthetic renders or a sprite sheet."""
from pathlib import Path
from PIL import Image
import numpy as np
import argparse, hashlib, json
p = argparse.ArgumentParser()
p.add_argument('frames', type=Path)
p.add_argument('manifest', type=Path)
p.add_argument('--output', type=Path)
a = p.parse_args()
manifest = json.loads(a.manifest.read_text())
for relative, digest in manifest['files'].items():
    source = a.manifest.parent/'project'/relative
    assert hashlib.sha256(source.read_bytes()).hexdigest() == digest, relative

def frame(n):
    return np.asarray(Image.open(a.frames/f'projectile{n:08d}.png').convert('RGB'))
def crop(n):
    return frame(n)[110:175,40:310]
def mask(c):
    return np.any(c != [32,38,43], axis=2)
def bounds(c):
    ys,xs = np.where(mask(c))
    return [int(xs.min()),int(ys.min()),int(xs.max()),int(ys.max())]
x,y = crop(144), crop(150)
mx,my = mask(x), mask(y)
assert np.array_equal(mx,my), 'tracked silhouette moved/changed unexpectedly'
changed = int((np.any(x!=y,axis=2)&mx&my).sum())
assert changed > 10, 'not enough real internal energy movement'
colors = np.unique(x[mx], axis=0).tolist()
assert sorted(colors) == sorted([[35,139,144],[122,231,197],[236,255,244]])
f = frame(150)
assert np.array_equal(f[238:302,45:245], f[132:148,130:180].repeat(4,axis=0).repeat(4,axis=1)), '4x detail differs from exact nearest enlargement'
slow,fast,turn = bounds(crop(270)),bounds(crop(390)),bounds(crop(504))
assert slow[2]-slow[0] < fast[2]-fast[0], 'speed does not change visible tail'
assert turn[3]-turn[1] > 7, 'turning frame remains horizontal'
assert not mask(crop(635)).any(), 'stop left residual pixels'
report = {'source_digest':manifest['source_digest'], 'native_frames':len(list(a.frames.glob('*.png'))), 'resolution':[640,360], 'fps':60, 'tracked_frames':[144,150], 'silhouette_identical':True, 'silhouette_pixels':int(mx.sum()), 'internal_changed_pixels':changed, 'palette_rgb':colors, 'nearest_4x_exact':True, 'slow_bbox':slow, 'fast_bbox':fast, 'turn_bbox':turn, 'stop_frame_clear':635}
print(json.dumps(report,indent=2))
if a.output: a.output.write_text(json.dumps(report,indent=2)+'\n')
