"""Derive a straight-alpha runtime texture from an original black-background emission source.
Linear-light premultiplied recomposition recovers the black-background RGB.
Original master remains unmodified; output is an editable graphics import artifact.
"""
from pathlib import Path
from PIL import Image
import numpy as np,json,hashlib
p=Path(__file__).parent; src=p/'gas_black_master.png'
rgb=np.asarray(Image.open(src).convert('RGB'),dtype=np.float64)/255
lin=np.where(rgb<=.04045,rgb/12.92,((rgb+.055)/1.055)**2.4)
a=np.sqrt(lin.max(axis=2)); straight=np.divide(lin,a[:,:,None],out=np.zeros_like(lin),where=a[:,:,None]>1e-8)
srgb=np.where(straight<=.0031308,straight*12.92,1.055*np.power(straight,1/2.4)-.055)
out=np.dstack((np.clip(srgb,0,1),a));u=np.round(out*255).astype('uint8')
Image.fromarray(u,'RGBA').save(p/'gas_straight_rgba.png')
ql=u[:,:,:3]/255;ql=np.where(ql<=.04045,ql/12.92,((ql+.055)/1.055)**2.4)
rec=ql*(u[:,:,3:4]/255);err=np.abs(rec-lin)
report={'source_sha256':hashlib.sha256(src.read_bytes()).hexdigest(),'output_sha256':hashlib.sha256((p/'gas_straight_rgba.png').read_bytes()).hexdigest(),'source':'original generated RGB black-background gas flame','alpha':'sqrt(max(linear RGB))','rgb':'sRGB encode(linear RGB / alpha), zero RGB where alpha=0','max_linear_recomposition_error_8bit':float(err.max()),'mean_linear_recomposition_error_8bit':float(err.mean()),'transparent_fraction':float((u[:,:,3]==0).mean()),'opaque_fraction':float((u[:,:,3]==255).mean()),'cropped_master_right_edge':'Do not sample outside internal safe UV region; source right edge is truncated.'}
(p/'gas_alpha_provenance.json').write_text(json.dumps(report,indent=2));print(json.dumps(report))
