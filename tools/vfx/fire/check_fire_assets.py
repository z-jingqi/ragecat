"""Verify atlas data contracts. Pixel review remains mandatory for release."""
from pathlib import Path
import json
import numpy as np
from PIL import Image
root=Path(__file__).resolve().parents[3]
folder=root/'assets/vfx/blender/fire'
manifest=json.loads((folder/'manifest.json').read_text())
for entry in manifest['effects']:
    image=np.asarray(Image.open(root/entry['path'][6:]).convert('RGBA'))
    w,h=entry['frame_size']
    assert image.shape[:2] == (h*entry['rows'],w*entry['columns']),entry['key']
    frames=[image[i//entry['columns']*h:(i//entry['columns']+1)*h,i%entry['columns']*w:(i%entry['columns']+1)*w] for i in range(entry['frames'])]
    if entry['key']=='fire_burst':
        assert frames[0][:,:,3].max()==0 and frames[-1][:,:,3].max()==0,'burst endpoints must be transparent'
        for frame in frames:
            # A brief local hot core is allowed, not a full sprite white flash.
            white=(frame[:,:,:3].min(axis=2)>230)&(frame[:,:,3]>127)
            assert white.mean()<.015,'unbounded white core'
    if entry['key']=='fire_ring':
        for frame in frames:
            # Every horizontal slice of mapped circumference has ember coverage.
            assert (frame[h//3:2*h//3,:,3].max(axis=0)>40).all(),'ring has a gap'
            assert (frame[h//2,:,3]>30).all(),'continuous density floor missing'
            assert frame[[0,-1],:,3].max()==0,'ring fringe must stay inside the authored band'
            first=np.argmax(frame[:,:,3]>12,axis=0)
            last=h-1-np.argmax(frame[::-1,:,3]>12,axis=0)
            assert np.ptp(first)>=2 and np.ptp(last)>=2,'ring fringe alpha is mechanically uniform'
    print(entry['key'],len(frames),'RGBA frames validated')
print('Fire atlas contracts passed; not a visual release certification.')
