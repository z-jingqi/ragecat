"""Author and validate a six-pose real skeletal dash; render only with --render.
The source package is read-only. No gameplay or projectile mechanics are changed.
"""
import os

import sys
sys.dont_write_bytecode = True
import bpy, json, gzip, math, argparse
from pathlib import Path
from mathutils import Matrix, Vector
import numpy as np
ROOT=Path(os.environ.get('ARCHER_DASH_OUTPUT', str(Path(__file__).resolve().parent/'generated'))).resolve()
SRC=Path(os.environ.get('ARCHER_SOURCE_ROOT', str(Path(__file__).resolve().parent.parent))).resolve()
sys.path.insert(0,str(SRC))
sys.path.insert(0,str(Path(__file__).resolve().parent))
from dash_artifact_validation import save_validation,source_identity,cached_validation_valid,bind_pose_metadata
from locomotion_solver import make_context, solve_motion, solve_two_bone, transport_segment, matrix_at, apply_pose
args=sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else []
ap=argparse.ArgumentParser();ap.add_argument('--render',action='store_true');ap.add_argument('--cpu',action='store_true');ap.add_argument('--write-anchor-contract',action='store_true');ap.add_argument('--samples',type=int,default=16);ap.add_argument('--frame',type=int);ap.add_argument('--frames',default='');ap.add_argument('--job-label',default='');ap.add_argument('--skip-existing',action='store_true');ap.add_argument('--layer',choices=['full','body'],default='full');ap.add_argument('--variant',choices=['braced','follow'],default='braced');ap.add_argument('--shoot-mode',choices=['shoot','carry','guard'],default='shoot');ap.add_argument('--camera',choices=['east','southeast','south','southwest','west','northwest','north','northeast'],default='east');ap.add_argument('--relative-travel',type=int,choices=range(8),default=0);opt=ap.parse_args(args);clip_id=f'{opt.camera}/dash_{opt.relative_travel}';clip_token=f'{opt.camera}_dash_{opt.relative_travel}';legacy=opt.camera=='east' and opt.relative_travel==0;tag=f'{opt.variant}_{opt.shoot_mode}_{opt.layer}'+('' if legacy else '__'+clip_token);frame_prefix='east_dash' if legacy else clip_token;tag+=('__job_'+opt.job_label) if opt.job_label else '';cloth_dir=ROOT/'cloth'/tag;selected_frames={int(v) for v in opt.frames.split(',') if v.strip()} if opt.frames else None
assert not opt.job_label or all(ch.isalnum() or ch in '_-' for ch in opt.job_label),'Unsafe job label'
bpy.ops.wm.open_mainfile(filepath=str(SRC/'archer.blend'));sc=bpy.context.scene;rig=bpy.data.objects['Approved_archer_rig']
for o in sc.objects:
 if o.animation_data:o.animation_data_clear()
P=json.load(gzip.open(SRC/'body_poses.json.gz','rt'));U=json.load(gzip.open(SRC/'upper_poses.json.gz','rt'));C=json.load(open(SRC/'camera_contract.json'));layers=json.load(open(SRC/'layer_objects.json'))
ctx=make_context(rig,P['idle'][0]);R,B,L=ctx['R'],ctx['B'],ctx['L'];camera_contract=C['directions'][opt.camera];D=Vector((0,-1,0)) if legacy else Vector(camera_contract['screen_relative_movements'][opt.relative_travel]['world_ground_direction']);D.normalize();up=Vector((0,0,1));axis=up.cross(D).normalized();lead_side='l' if D.dot(ctx['R0']@Vector((1,0,0)))>=0 else 'r';movement_names=['run_forward','run_forward_right','run_right','run_back_right','run_back','run_back_left','run_left','run_forward_left'];movement_clip=f'{opt.camera}/{movement_names[opt.relative_travel]}'
# t, lumbar/pelvis pitch, common downshift, lead reach/lift/pitch, trail reach/lift/pitch
# Both legs are independently solved in 3D. The common translation is never baked
# into bones, keeping the existing upper texture and all bow/arrow anchors exact.
KEYS=[
(0.00,10,-.115, .16,0,-3, -.18,0,7,'compress'),
(0.17,20,-.165, .18,.11,7, -.38,0,23,'push_off'),
(0.36,22,-.125, .24,.16,8, -.26,.075,20,'low_tuck'),
(0.56,18,-.100, .42,.04,-8, -.18,.13,10,'reach'),
(0.78,13,-.175, .36,0,-5, -.12,.09,5,'land'),
(1.00,6,-.100, .18,0,0, -.14,0,0,'absorb'),
(1.1333333,3,-.060, .12,0,0, -.09,0,0,'settle_1'),
(1.2666667,1,-.025, .055,0,0, -.04,0,0,'settle_2'),
(1.4,0,0, 0,0,0, 0,0,0,'ready')]

SHOOT=[('short_draw',0),('short_draw',2),('short_draw',4),('short_release',0),('short_release',2),('short_recover',2),('short_recover',3),('short_draw',0),('short_draw',1)]
fixed=['chest','neck','head','clavicle.l','clavicle.r'];records=[]
def solve(i):
 t,lean,down,lp,ll,lr,rp,rl,rr,label=KEYS[i]
 recovery=max(0,(i-5)/3);row=solve_motion(ctx,D,.12+min(t,1)*.68,idle=i==8)
 if recovery>0 and i<8:
  hy=math.radians(row['pelvis_yaw_deg'])*(1-recovery);top=ctx['H']@Vector((0,L['hips'],0));Y=Matrix.Translation(top)@Matrix.Rotation(hy,4,'Z')@Matrix.Translation(-top);row['bones']['hips']=Y@ctx['H'];row['pelvis_rotation']=Y.to_3x3()@ctx['R0'];row['foot_yaw_deg']*=1-recovery
 M=row['bones'];base={n:m.copy() for n,m in M.items()};pivot=base['chest'].translation.copy();Q=Matrix.Translation(pivot)@Matrix.Rotation(math.radians(lean),4,axis)@Matrix.Translation(-pivot)
 for n in ['hips','spine','upper_spine']:
  M[n]=Q@base[n]
 chest_lean=(lean*(.545 if opt.shoot_mode!='shoot' else .273)) if opt.variant=='follow' else 0
 CQ=Matrix.Translation(pivot)@Matrix.Rotation(math.radians(chest_lean),4,axis)@Matrix.Translation(-pivot)
 for n in fixed:M[n]=CQ@base[n]
 row['upper_transform']=CQ
 hip=M['hips'];bob=Vector((0,0,down))+D*[.015,.05,.065,.03,-.015,0,0,0,0][i];pelvisR=Q.to_3x3()@row['pelvis_rotation'];row['pelvis_rotation']=pelvisR;row['bob']=bob;row['phase']=t
 # Real direction-specific pelvis/foot axes come from the source continuous solver.
 # Backward legs retain the anatomical forward knee pole, never a 180-degree flip.
 footbase=ctx['R0']@Matrix.Rotation(math.radians(row['foot_yaw_deg']),3,'Z');lane=footbase@Vector((1,0,0));facingforward=footbase@Vector((0,-1,0));angles={};feet={}
 backward=D.dot(facingforward)<-.4
 lead_pitch=-lr if backward else lr
 leg_targets=[('l',1,lp,ll,lead_pitch),('r',-1,rp,rl,rr)] if lead_side=='l' else [('l',1,rp,rl,rr),('r',-1,lp,ll,lead_pitch)]
 for s,sg,p,lift,pitch in leg_targets:
  pR=Matrix.Rotation(math.radians(pitch),3,'X');footR=footbase@pR
  height=-min((pR@v).z for v in ctx['sole'][s])+lift
  actual=ctx['R0']@Vector((.0111724,0,0))+lane*(sg*(.145-.02*recovery))+D*p+Vector((0,0,height))
  S=hip@R['hips'].inverted()@B['thigh.'+s][0];A=actual-bob;pole=S+facingforward*.8+D*(.22*(1-recovery))+lane*(sg*(.06-.01*recovery))
  knee,ankle,error=solve_two_bone(S,A,L['thigh.'+s],L['shin.'+s],pole,bend_gap=.004)
  M['thigh.'+s]=transport_segment(R['thigh.'+s],*B['thigh.'+s],S,knee);M['shin.'+s]=transport_segment(R['shin.'+s],*B['shin.'+s],knee,ankle);M['foot.'+s]=matrix_at(footR@R['foot.'+s].to_3x3(),ankle)
  angles[s]=math.atan2((knee-S).dot(pelvisR@Vector((0,-1,0))),S.z-knee.z)
  knee_forward=(knee-(S+ankle)*.5).dot(facingforward)
  assert knee_forward>0,('reversed knee',clip_id,i,s,knee_forward)
  feet[s]={'knee_forward_bend_m':knee_forward,'hip':list(S+bob),'knee':list(knee+bob),'ankle':list(ankle+bob),'lowest_sole_z':min((ankle+bob+footR@v).z for v in ctx['sole'][s]),'reach_error_m':error,'lift_m':lift,'pitch_deg':pitch}
 # Real garment bone follow-through plus the existing local mesh clearance solver.
 for q in ctx['chains']:
  hM=hip@R['hips'].inverted();sg=q['side'];s='l' if sg>0 else 'r';direction=-1 if q['front'] else 1
  push=max(0,angles[s] if q['front'] else -angles[s]);ribbon=q['name'].startswith('Scarlet');amp=min(.72,(.25 if ribbon else .16)+push*(.9 if ribbon else 1.1))*(1-recovery);flutter=.04*math.sin(math.pi*min(t,1)+(0 if sg>0 else .5))*(1-recovery)
  local=Matrix.Rotation(direction*amp+flutter,3,'X')@Matrix.Rotation(sg*.06*(1-recovery),3,'Y');wr=pelvisR@local@pelvisR.transposed();a=hM@q['a'];b=a+wr@(hM.to_3x3()@(q['b']-q['a']));tip=Matrix.Rotation(direction*amp*.32,3,'X');wt=pelvisR@tip@pelvisR.transposed();c=b+wt@wr@(hM.to_3x3()@(q['c']-q['b']))
  M[q['names'][0]]=transport_segment(R[q['names'][0]],q['a'],q['b'],a,b);M[q['names'][1]]=transport_segment(R[q['names'][1]],q['b'],q['c'],b,c)
 fixed_error=max(max(abs(M[n][a][b]-(CQ@base[n])[a][b]) for a in range(4) for b in range(4)) for n in fixed)
 length_error=max(abs((M[n]@Vector((0,L[n],0))-M[n].translation).length-L[n]) for n in M)
 connection_error=max((M[a]@Vector((0,L[a],0))-M[b].translation).length for a,b in [('hips','spine'),('spine','upper_spine'),('upper_spine','chest'),('thigh.l','shin.l'),('shin.l','foot.l'),('thigh.r','shin.r'),('shin.r','foot.r')])
 assert fixed_error<1e-7,(i,fixed_error)
 assert length_error<1e-6,(i,length_error)
 assert connection_error<3e-6,(i,connection_error)
 assert max(v['reach_error_m'] for v in feet.values())<1e-5,(i,feet)
 row['feet']=feet;row['reach']={s:v['reach_error_m'] for s,v in feet.items()}
 stats=apply_pose(ctx,row,correct=True)
 coat_coords={o.name:np.array([v.co[:] for v in ctx['keys'][o.name].data],dtype=np.float32) for o in ctx['coats']}
 # A real chest-hinge lumbar lean, not an image rotation. Chest remains fixed to
 # preserve independently sampled firing animation. Do not claim a full chest tilt.
 camM=Matrix(camera_contract['camera_matrix_world']);cv=camM.inverted().to_3x3()@bob;scale=192/C['ortho_scale']
 rec={'index':i,'clip':clip_id,'matching_locomotion_clip':movement_clip,'leading_leg':lead_side,'travel_direction_world':list(D),'travel_direction_screen':camera_contract['screen_relative_movements'][opt.relative_travel]['screen_direction'],'pelvis_yaw_deg':row['pelvis_yaw_deg'],'foot_yaw_deg':row['foot_yaw_deg'],'foot_lane_separation_m':(Vector(feet['l']['ankle'])-Vector(feet['r']['ankle'])).dot(lane),'normalized_dash_time':t,'duration_s':.2,'time_seconds':round(t*.2,8),'recovery_only':i>5,'stage':label,'lower_spine_pitch_degrees':lean,'chest_pitch_delta_degrees':chest_lean,'shared_bob_world_m':list(bob),'shared_screen_shift_px':[cv.x*scale,-cv.y*scale],'shared_depth_shift_m':-cv.z,'bones':{n:list(map(list,m)) for n,m in M.items()},'feet':feet,'fixed_anchor_error':fixed_error,'bone_length_error_m':length_error,'connection_error_m':connection_error,'cloth':stats,'demo_shoot_clip':SHOOT[i][0] if opt.shoot_mode=='shoot' else ('authored_guard' if opt.shoot_mode=='guard' else 'carry'),'demo_shoot_frame':SHOOT[i][1] if opt.shoot_mode=='shoot' else 0,'upper_transform':list(map(list,CQ))}
 return row,rec,coat_coords

def blend_matrix(a,b,t):
 at,ar,asc=a.decompose();bt,br,bsc=b.decompose();return Matrix.LocRotScale(at.lerp(bt,t),ar.slerp(br,t),asc.lerp(bsc,t))
def upper_state(i,M,Q):
 clip,frame=SHOOT[i] if opt.shoot_mode=='shoot' else ('hold_relaxed' if opt.shoot_mode=='guard' and i<8 else 'carry',0)
 u=U['clips'][clip]['frames'][frame]
 UM={n:Matrix(m) for n,m in u['bones'].items()};propT=Matrix.Identity(4)
 if opt.shoot_mode=='guard' and i<8:
  # Compact two-hand guard with a real 18-degree bow slant, not a picture tilt.
  # Shoulders/elbows solve to the shifted wrists; both hands keep their grip.
  delta=Vector((.025,.035,-.145));bp=Matrix(u['bow_matrix']).translation
  propT=Matrix.Translation(delta)@Matrix.Translation(bp)@Matrix.Rotation(math.radians(18),4,axis)@Matrix.Translation(-bp)
  recovery=max(0,(i-5)/3);carry=U['clips']['carry']['frames'][0]
  if recovery>0:
   guardbow=propT@Matrix(u['bow_matrix']);newbow=blend_matrix(guardbow,Matrix(carry['bow_matrix']),recovery);propT=newbow@Matrix(u['bow_matrix']).inverted()
  for side in ['l','r']:
   ua,fa,ha='upperarm.'+side,'forearm.'+side,'hand.'+side
   oldhand=UM[ha].copy();newhand=propT@oldhand
   if side=='r' and recovery>0:newhand=blend_matrix(newhand,Matrix(carry['bones'][ha]),recovery)
   hand_delta=newhand@oldhand.inverted();shoulder=UM[ua].translation.copy();wrist=newhand.translation
   pole=UM[fa].translation+Vector((.06 if side=='l' else -.06,.03,-.07))
   elbow,achieved,err=solve_two_bone(shoulder,wrist,L[ua],L[fa],pole,bend_gap=.002)
   assert err<1e-5,('guard wrist unreachable',side,err)
   UM[ua]=transport_segment(R[ua],*B[ua],shoulder,elbow);UM[fa]=transport_segment(R[fa],*B[fa],elbow,achieved)
   for n in UM:
    if n==ha or (n.startswith('finger') and n.endswith('.'+side)):UM[n]=hand_delta@UM[n]
 for n,m in UM.items():
  if n.startswith(('upperarm.','forearm.','hand.','finger')):M[n]=Q@m
 for n,m in M.items():
  pb=rig.pose.bones[n];par=pb.parent.name if pb.parent else None;pb.rotation_mode='QUATERNION';pb.matrix_basis=R[n].inverted()@R[par]@M[par].inverted()@m if par else R[n].inverted()@m
 propQ=Q@propT
 bpy.data.objects['Bow_Prop_Root'].matrix_world=propQ@Matrix(u['bow_matrix']);bpy.data.objects['Bow_Recurve_Body'].data.shape_keys.key_blocks['DrawFlex'].value=u['flex'];bpy.data.objects['Cosmetic_arrow_tip'].matrix_world=propQ@Matrix(u['tip_matrix'])
 for n,key in [('Fixed_tip_bowstring','string'),('Cosmetic_arrow_shaft','arrow')]:
  for p,v in zip(bpy.data.objects[n].data.splines[0].points,u[key]):p.co=(*(propQ@Vector(v)),1)
 return u

if opt.write_anchor_contract:
 camera_inverse=Matrix(C['directions']['east']['camera_matrix_world']).inverted();pixel_scale=192/C['ortho_scale'];game_scale=C['texture_to_game_scale'];pivot=Vector(C['pivot_px'])
 def project(v,bob):
  q=camera_inverse@(Vector(v)+bob);px=Vector((96+q.x*pixel_scale,96-q.y*pixel_scale));return {'source_px':list(px),'game_px_relative_pivot':list((px-pivot)*game_scale),'camera_depth_m':-q.z}
 result={'version':1,'scope':'single east aim/east travel sample; full images only, not installed','dash_duration_s':.2,'visual_recovery_s':.08,'gameplay_speed':760,'cooldown_s':2,'canvas_px':192,'display_scale':game_scale,'pivot_px':list(pivot),'variants':{}}
 for variant,mode in [('braced','shoot'),('follow','shoot'),('follow','guard')]:
  tag0=f'{variant}_{mode}_full';opt.variant=variant;opt.shoot_mode=mode;manifest=json.load(open(ROOT/f'dash_sample_{tag0}.json'));out=[]
  for rec in manifest['frames']:
   M={n:Matrix(m) for n,m in rec['bones'].items()};Q=Matrix(rec['upper_transform']);u=upper_state(rec['index'],M,Q);bpy.context.view_layer.update();bob=Vector(rec['shared_bob_world_m']);anchors={};errors={}
   for side in ['l','r']:
    n='clavicle.'+side;body_shoulder=M[n]@Vector((0,L[n],0));upper_shoulder=M['upperarm.'+side].translation;errors[side]=(body_shoulder-upper_shoulder).length
    anchors['body_shoulder_'+side]=project(body_shoulder,bob);anchors['upper_shoulder_'+side]=project(upper_shoulder,bob);anchors['hand_'+side]=project(M['hand.'+side].translation,bob)
   anchors['chest']=project(M['chest'].translation,bob)
   for name,label in [('Bow_Grip','bow_grip'),('Bow_Arrow_Rest','bow_arrow_rest')]:anchors[label]=project(bpy.data.objects[name].matrix_world.translation,bob)
   out.append({'index':rec['index'],'time_seconds':rec['time_seconds'],'dash_phase':min(1,rec['normalized_dash_time']),'recovery_phase':max(0,min(1,(rec['time_seconds']-.2)/.08)),'stage':rec['stage'],'shared_bob_game_px':[x*game_scale for x in rec['shared_screen_shift_px']],'shared_depth_bob_m':rec['shared_depth_shift_m'],'chest_pitch_degrees':rec['chest_pitch_delta_degrees'],'anchors_after_shared_bob':anchors,'body_upper_shoulder_error_m':errors,'arrow_visible':u['visible'],'shot_demo':{'clip':rec['demo_shoot_clip'],'frame':rec['demo_shoot_frame']}})
  result['variants'][tag0]=out
 (ROOT/'dash_runtime_contract.json').write_text(json.dumps(result,indent=2));print('ANCHOR_CONTRACT',str(ROOT/'dash_runtime_contract.json'));sys.exit(0)

cam=sc.camera;cam.parent=None
for c in list(cam.constraints):cam.constraints.remove(c)
cam.matrix_world=Matrix(camera_contract['camera_matrix_world']);cam.data.type='ORTHO';cam.data.ortho_scale=C['ortho_scale'];cam.data.clip_start=.1;cam.data.clip_end=20
sc.render.engine='CYCLES';sc.cycles.samples=opt.samples;sc.cycles.use_denoising=False;sc.render.resolution_x=sc.render.resolution_y=192;sc.render.resolution_percentage=100;sc.render.film_transparent=True;sc.render.image_settings.file_format='PNG';sc.render.image_settings.color_mode='RGBA';sc.render.image_settings.color_depth='8';sc.view_layers[0].use_pass_z=True;sc.view_layers[0].pass_alpha_threshold=.001
# Only touch Cycles compute devices when actually authorized to render.
if opt.render and not opt.cpu:
 prefs=bpy.context.preferences.addons['cycles'].preferences
 try:
  prefs.compute_device_type='CUDA';prefs.get_devices()
  for device in prefs.devices:device.use=device.type=='CUDA'
  if any(d.use for d in prefs.devices):sc.cycles.device='GPU'
 except Exception:pass
if opt.render and opt.cpu:sc.cycles.device='CPU'
sc.use_nodes=True;nt=sc.node_tree;nt.nodes.clear();rl=nt.nodes.new('CompositorNodeRLayers');com=nt.nodes.new('CompositorNodeComposite');nt.links.new(rl.outputs['Image'],com.inputs[0]);dep=nt.nodes.new('CompositorNodeOutputFile');dep.base_path=str(ROOT/'renders'/tag);dep.format.file_format='OPEN_EXR';dep.format.color_mode='RGB';dep.format.color_depth='32';dep.format.exr_codec='ZIP';nt.links.new(rl.outputs['Depth'],dep.inputs[0])
(ROOT/'renders'/tag).mkdir(parents=True,exist_ok=True);cloth_dir.mkdir(parents=True,exist_ok=True)
for i in range(len(KEYS)):
 if opt.frame is not None and i!=opt.frame:continue
 if selected_frames is not None and i not in selected_frames:continue
 row,rec,cloth=solve(i);u=upper_state(i,row['bones'],row['upper_transform']);rec['bones']={n:list(map(list,m)) for n,m in row['bones'].items()};records.append(rec);np.savez_compressed(cloth_dir/f'{frame_prefix}_{i:03}.npz',**cloth)
 render_png=ROOT/'renders'/tag/f'{frame_prefix}_{i:03}.png';render_exr=ROOT/'renders'/tag/f'{frame_prefix}_{i:03}_depth_0000.exr'
 if opt.render and not (opt.skip_existing and cached_validation_valid(tag,frame_prefix,i,requested_pose=rec,role='body' if opt.layer=='body' else 'guard' if opt.shoot_mode=='guard' else 'review_full',camera=opt.camera,relative=opt.relative_travel,clip=clip_id)):
  u=upper_state(i,row['bones'],row['upper_transform']);visible=set(layers['body_core'])
  if opt.layer=='full':visible.update(layers['shoot_limbs_props'])
  if not u['visible']:visible.discard('Cosmetic_arrow_shaft');visible.discard('Cosmetic_arrow_tip')
  for o in sc.objects:
   if o.type in ['MESH','CURVE']:o.hide_render=o.name not in visible
  bpy.data.objects['Lower_anatomical_legs_feet_CC0'].hide_render=True
  sc.render.filepath=str(ROOT/'renders'/tag/f'{frame_prefix}_{i:03}.png');dep.file_slots[0].path=f'{frame_prefix}_{i:03}_depth_';bpy.context.view_layer.update();bpy.ops.render.render(write_still=True)
 if opt.render:
  rec['artifact_validation']=save_validation(tag,frame_prefix,i,role='body' if opt.layer=='body' else 'guard' if opt.shoot_mode=='guard' else 'review_full',camera=opt.camera,relative=opt.relative_travel,clip=clip_id)
  checkpoint_dir=ROOT/'pose_checkpoints'/tag;checkpoint_dir.mkdir(parents=True,exist_ok=True);checkpoint=checkpoint_dir/f'{frame_prefix}_{i:03}.json';checkpoint.write_text(json.dumps({'version':2,'source_identity':source_identity(),'source':str(SRC),'clip':clip_id,'sample_count':1,'frames':[rec]},indent=2));bind_pose_metadata(tag,frame_prefix,[i],checkpoint)
 print('DASH_FRAME',json.dumps({k:v for k,v in rec.items() if k!='bones'}),flush=True)
manifest={'version':2,'source_identity':source_identity(),'role':'body' if opt.layer=='body' else 'guard' if opt.shoot_mode=='guard' else 'review_full','scope':'single '+clip_id+' real skeletal candidate; not published','clip':clip_id,'camera_direction':opt.camera,'relative_travel_index':opt.relative_travel,'matching_locomotion_clip':movement_clip,'frame_prefix':frame_prefix,'variant':opt.variant,'shoot_mode':opt.shoot_mode,'source':str(SRC),'canvas_px':192,'pivot_px':C['pivot_px'],'texture_to_game_scale':C['texture_to_game_scale'],'sample_count':len(records),'rendered':opt.render,'cycles_samples':opt.samples,'job_label':opt.job_label,'output_tag':tag,'cloth_directory':str(cloth_dir),'dash_duration_s':.2,'visual_recovery_s':.08,'upper_policy':'braced reuses existing upper; follow requires matched new upper render assets. Shooting cycle and projectile emission stay authoritative; no static guard overlay','root_motion':'none; runtime dash 0.2 s, speed 760, cooldown 2 s remain unchanged','frames':records}
output=ROOT/(f'dash_sample_{tag}_{opt.frame:03}.json' if opt.frame is not None else (f'dash_sample_{tag}_frames_{opt.frames.replace(chr(44),chr(95))}.json' if opt.frames else f'dash_sample_{tag}.json'));output.write_text(json.dumps(manifest,indent=2))
if opt.render:bind_pose_metadata(tag,frame_prefix,[r['index'] for r in records],output)
print('VALIDATED',str(output),flush=True)
