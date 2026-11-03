"""Render verified shared-Frame Godot buffers. These are CPU diagnostics, not viewport captures."""
import json,pathlib,sys,hashlib
import numpy as np
from PIL import Image
raw=pathlib.Path(sys.argv[1]);dest=pathlib.Path(sys.argv[2]);oracle=pathlib.Path(sys.argv[3]);dest.mkdir(parents=True,exist_ok=True)
reference=json.loads(oracle.read_text());case_id=reference['id'];frames=[];w,h=320,200
base=np.empty((h,w,4),dtype=np.uint8);base[:]=[23,27,41,255]
# Original simple host background, not website art or a claimed actual viewport.
base[150:,:,:3]=[30,35,48];base[150,:,:3]=[52,61,77]
for row in reference['rows']:
 n=int(row['frame']);channels={}
 for key in ['color','light']:
  data=(raw/f'{n:04d}-{key}.rgba').read_bytes()
  assert hashlib.sha256(data).hexdigest()==row[key],(case_id,n,key,'Unverified combined buffer')
  channels[key]=np.frombuffer(data,dtype=np.uint8).reshape(h,w,4)
 target=base.copy()
 # The original host contract: add the combined light ONCE, then composite the
 # already-merged color, which contains back effects, the actor and front effects.
 target[:,:,:3]=np.minimum(255,target[:,:,:3].astype(np.uint16)+channels['light'][:,:,:3]).astype(np.uint8)
 color=channels['color'];alpha=color[:,:,3:4].astype(float)/255
 target[:,:,:3]=np.round(color[:,:,:3]*alpha+target[:,:,:3]*(1-alpha)).astype(np.uint8)
 frames.append(Image.fromarray(target).convert('RGB').resize((640,400),Image.Resampling.NEAREST))
assert frames
frames[0].save(dest/(case_id+'.webp'),save_all=True,append_images=frames[1:],duration=50,loop=0,lossless=True,method=4)
frames[min(len(frames)-1,20)].save(dest/(case_id+'.png'))
print(case_id,len(frames),'verified shared-Frame diagnostic frames',dest)
