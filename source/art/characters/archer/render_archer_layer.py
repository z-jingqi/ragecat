"""Portable deterministic renderer for the final editable Archer model.
Usage: blender -b --disable-autoexec -t 4 -P render_archer_layer.py -- --layer body --clip east/run_right --frame 0 --output ./preview
All input paths are relative to this script, or override --assets.
"""
import bpy,json,sys,argparse,gzip
from pathlib import Path
from mathutils import Matrix,Vector
import numpy as np
args=sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else []
ap=argparse.ArgumentParser();ap.add_argument('--assets',type=Path,default=Path(__file__).resolve().parent);ap.add_argument('--model',default='archer.blend');ap.add_argument('--layer',choices=['body','upper'],default='body');ap.add_argument('--clip',default='east/idle');ap.add_argument('--frame',type=int,default=0);ap.add_argument('--phase',type=float,default=None);ap.add_argument('--output',type=Path,default=Path('preview'));ap.add_argument('--samples',type=int,default=12);opt=ap.parse_args(args);A=opt.assets.resolve();opt.output=opt.output.resolve();opt.output.mkdir(parents=True,exist_ok=True)
contract=json.load(open(A/'camera_contract.json'));layers=json.load(open(A/'layer_objects.json'));direction,name=opt.clip.split('/',1);camera=contract['directions'][direction]
bpy.ops.wm.open_mainfile(filepath=str(A/opt.model));sc=bpy.context.scene;rig=bpy.data.objects['Approved_archer_rig'];rest={b.name:b.matrix_local.copy() for b in rig.data.bones}
def apply_bones(M):
 for n,m in M.items():
  pb=rig.pose.bones[n];par=pb.parent.name if pb.parent else None
  pb.matrix_basis=rest[n].inverted()@rest[par]@M[par].inverted()@m if par else rest[n].inverted()@m
  pb.rotation_mode='QUATERNION'
if opt.layer=='body':
 meta=json.load(open(A/'body_manifest.json'));clip=meta['clips'][opt.clip];key=clip.get('world_pose_key','idle');poses=json.load(gzip.open(A/'body_poses.json.gz','rt'))
 if opt.phase is not None and key!='idle':
  sys.path.insert(0,str(A));from locomotion_solver import make_context,solve_motion,apply_pose
  ctx=make_context(rig,poses['idle'][0]);continuous=solve_motion(ctx,Vector(clip['travel_direction_world']),opt.phase%1);apply_pose(ctx,continuous);row={'shared_bob_world_m':list(continuous['bob'])}
 else:
  row=poses[key][opt.frame];apply_bones({n:Matrix(m) for n,m in row['bones'].items()});coords=np.load(A/'cloth'/f'{key}.npz')
  for n in coords.files:
   o=bpy.data.objects[n];sk=o.data.shape_keys.key_blocks['Runtime_leg_clearance'];sk.data.foreach_set('co',coords[n][opt.frame].reshape(-1));sk.value=1
 visible=set(layers['body_core']);bob=row['shared_bob_world_m']
else:
 data=json.load(gzip.open(A/'upper_poses.json.gz','rt'));row=data['clips'][name]['frames'][opt.frame];apply_bones({n:Matrix(m) for n,m in row['bones'].items()});bpy.data.objects['Bow_Prop_Root'].matrix_world=Matrix(row['bow_matrix']);bpy.data.objects['Bow_Recurve_Body'].data.shape_keys.key_blocks['DrawFlex'].value=row['flex'];bpy.data.objects['Cosmetic_arrow_tip'].matrix_world=Matrix(row['tip_matrix'])
 for n,key in [('Fixed_tip_bowstring','string'),('Cosmetic_arrow_shaft','arrow')]:
  for p,v in zip(bpy.data.objects[n].data.splines[0].points,row[key]):p.co=(*v,1)
 visible=set(layers['shoot_limbs_props']);bob=[0,0,0]
 if not row['visible']:visible.discard('Cosmetic_arrow_shaft');visible.discard('Cosmetic_arrow_tip')
for o in sc.objects:
 if o.animation_data:o.animation_data_clear()
 if o.type in ['MESH','CURVE']:o.hide_render=o.name not in visible
bpy.data.objects['Lower_anatomical_legs_feet_CC0'].hide_render=True
cam=sc.camera;cam.animation_data_clear();cam.parent=None
for c in list(cam.constraints):cam.constraints.remove(c)
cam.matrix_world=Matrix(camera['camera_matrix_world']);cam.data.type='ORTHO';cam.data.ortho_scale=contract['ortho_scale'];cam.data.clip_start=.1;cam.data.clip_end=20
sc.render.engine='CYCLES';sc.cycles.samples=opt.samples;sc.cycles.use_denoising=False;sc.render.resolution_x=sc.render.resolution_y=192;sc.render.resolution_percentage=100;sc.render.film_transparent=True;sc.render.image_settings.file_format='PNG';sc.render.image_settings.color_mode='RGBA';sc.render.image_settings.color_depth='8';sc.view_layers[0].use_pass_z=True;sc.view_layers[0].pass_alpha_threshold=.001;sc.use_nodes=True;nt=sc.node_tree;nt.nodes.clear();rl=nt.nodes.new('CompositorNodeRLayers');com=nt.nodes.new('CompositorNodeComposite');nt.links.new(rl.outputs['Image'],com.inputs[0]);dep=nt.nodes.new('CompositorNodeOutputFile');dep.base_path=str(opt.output);dep.format.file_format='OPEN_EXR';dep.format.color_mode='RGB';dep.format.color_depth='32';dep.format.exr_codec='ZIP';nt.links.new(rl.outputs['Depth'],dep.inputs[0]);dep.file_slots[0].path=f'{direction}_{name}_{opt.frame:03}_depth_';sc.render.filepath=str(opt.output/f'{direction}_{name}_{opt.frame:03}.png');bpy.context.view_layer.update();bpy.ops.render.render(write_still=True)
print(json.dumps({'clip':opt.clip,'frame':opt.frame,'layer':opt.layer,'pivot_px':contract['pivot_px'],'texture_to_game_scale':contract['texture_to_game_scale'],'shared_bob_world_m':bob,'depth':'camera-space metres; smaller nearer; ignore transparent pixels'}))
