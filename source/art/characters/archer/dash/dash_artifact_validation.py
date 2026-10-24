"""Read-only artifact validation for Blender PNG + linear Z EXR outputs."""
import os

import bpy,json,hashlib
from pathlib import Path
import numpy as np
ROOT=Path(os.environ.get('ARCHER_DASH_OUTPUT', str(Path(__file__).resolve().parent/'generated'))).resolve()
SRC=Path(os.environ.get('ARCHER_SOURCE_ROOT', str(Path(__file__).resolve().parent.parent))).resolve()
DEPTH_MIN=6.0551778793335;DEPTH_MAX=8.55949668884277
_ID=None
def source_identity():
 global _ID
 if _ID is None:
  files=['archer.blend','camera_contract.json','body_poses.json.gz','upper_poses.json.gz','locomotion_solver.py','layer_objects.json']
  _ID={'source_directory':str(SRC),'sha256':{n:hashlib.sha256((SRC/n).read_bytes()).hexdigest() for n in files}}
 return _ID

def validate_pair(png,exr,*,role,camera,relative,frame,clip):
 png=Path(png);exr=Path(exr);color=bpy.data.images.load(str(png),check_existing=False);depth=bpy.data.images.load(str(exr),check_existing=False)
 try:
  width,height=color.size[:];assert(width,height)==(192,192),(png,width,height);assert tuple(depth.size[:])==(192,192)
  depth.colorspace_settings.name='Non-Color';rgba=np.array(color.pixels[:],dtype=np.float32).reshape(192,192,4)[::-1];z=np.array(depth.pixels[:],dtype=np.float32).reshape(192,192,4)[::-1,:,0];alpha=rgba[:,:,3];active=alpha>0;assert active.any(),('empty',png);ys,xs=np.where(active);box=[int(xs.min()),int(ys.min()),int(xs.max()+1),int(ys.max()+1)];valid=active & np.isfinite(z) & (z>0) & (z<100);assert valid.any(),('no surface Z',exr);values=z[valid];lo=float(values.min());hi=float(values.max());safe=lo>=DEPTH_MIN-1e-5 and hi<=DEPTH_MAX+1e-5
  return {'role':role,'camera':camera,'relative':relative,'clip':clip,'frame':frame,'color':str(png),'depth':str(exr),'canvas_px':[width,height],'alpha_bbox_px':box,'alpha_nonzero_pixels':int(active.sum()),'touches_canvas_edge':box[0]==0 or box[1]==0 or box[2]==192 or box[3]==192,'valid_surface_depth_min_m':lo,'valid_surface_depth_max_m':hi,'depth_contract_m':[DEPTH_MIN,DEPTH_MAX],'safe_surface_depth_range':safe,'aa_background_depth_pixels':int((active & ~valid).sum()),'depth_units':'linear camera-space metres; background sentinel is not a surface','source_identity':source_identity(),'color_sha256':hashlib.sha256(png.read_bytes()).hexdigest(),'depth_sha256':hashlib.sha256(exr.read_bytes()).hexdigest()}
 finally:
  bpy.data.images.remove(color);bpy.data.images.remove(depth)

def save_validation(tag,prefix,index,**kwargs):
 directory=ROOT/'validation'/tag;directory.mkdir(parents=True,exist_ok=True);result=validate_pair(ROOT/'renders'/tag/f'{prefix}_{index:03}.png',ROOT/'renders'/tag/f'{prefix}_{index:03}_depth_0000.exr',frame=index,**kwargs);p=directory/f'{prefix}_{index:03}.json';p.write_text(json.dumps(result,indent=2));assert result['safe_surface_depth_range'],('surface outside fixed depth contract',p,result['valid_surface_depth_min_m'],result['valid_surface_depth_max_m']);return result

def pose_fingerprint(row):
 payload={k:row[k] for k in ['bones','shared_bob_world_m','upper_transform','demo_shoot_clip','demo_shoot_frame'] if k in row}
 return hashlib.sha256(json.dumps(payload,sort_keys=True,separators=(',',':')).encode()).hexdigest()

def cached_validation_valid(tag,prefix,index,requested_pose=None,**expected):
 try:
  p=ROOT/'validation'/tag/f'{prefix}_{index:03}.json';v=json.load(open(p));png=ROOT/'renders'/tag/f'{prefix}_{index:03}.png';exr=ROOT/'renders'/tag/f'{prefix}_{index:03}_depth_0000.exr';mp=Path(v['pose_metadata_path']);metadata_bytes=mp.read_bytes()
  if v.get('pose_metadata_sha256')!=hashlib.sha256(metadata_bytes).hexdigest():return False
  previous=next(r for r in json.loads(metadata_bytes)['frames'] if r['index']==index)
  if requested_pose is not None and pose_fingerprint(previous)!=pose_fingerprint(requested_pose):return False
  return v.get('frame')==index and all(v.get(k)==value for k,value in expected.items()) and v.get('source_identity')==source_identity() and v.get('canvas_px')==[192,192] and v.get('safe_surface_depth_range') is True and v.get('alpha_nonzero_pixels',0)>0 and v.get('color_sha256')==hashlib.sha256(png.read_bytes()).hexdigest() and v.get('depth_sha256')==hashlib.sha256(exr.read_bytes()).hexdigest()
 except (OSError,ValueError,KeyError,StopIteration):return False

def bind_pose_metadata(tag,prefix,indices,metadata_path):
 metadata_path=Path(metadata_path).resolve();metadata_bytes=metadata_path.read_bytes();digest=hashlib.sha256(metadata_bytes).hexdigest();rows={r['index']:r for r in json.loads(metadata_bytes)['frames']}
 for index in indices:
  p=ROOT/'validation'/tag/f'{prefix}_{index:03}.json';v=json.load(open(p));v['pose_metadata_path']=str(metadata_path);v['pose_metadata_sha256']=digest;v['render_pose_fingerprint']=pose_fingerprint(rows[index]);temporary=p.with_suffix('.tmp');temporary.write_text(json.dumps(v,indent=2));temporary.replace(p)
