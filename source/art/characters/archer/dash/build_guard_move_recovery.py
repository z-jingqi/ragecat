"""Three real-IK guarded moving-recovery samples, driven by 18.4 game pixels.
This is not a crossfade, root-motion bake, or modification to gameplay timing.
The approved six-pose dash remains unchanged. The camera selects the actual orthographic view; travel remains aim-forward.
"""
import os

import sys
sys.dont_write_bytecode=True
import argparse,json,math,runpy,time
from pathlib import Path
import bpy,numpy as np
from mathutils import Matrix,Vector
ROOT=Path(os.environ.get('ARCHER_DASH_OUTPUT', str(Path(__file__).resolve().parent/'generated'))).resolve()
argv=sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else []
ap=argparse.ArgumentParser();ap.add_argument('--render',action='store_true');ap.add_argument('--samples',type=int,default=16);ap.add_argument('--camera',choices=['east','southeast','south','southwest','west','northwest','north','northeast'],default='east');ap.add_argument('--skip-existing',action='store_true');ap.add_argument('--job-label',default='');MOVE_OPTIONS=ap.parse_args(argv)
# Load the same approved solver and model, authoring only its existing absorb pose.
# Its normal renderer is disabled. All files remain in the candidate directory.
sys.argv=[str(Path(__file__).resolve().parent/'build_dash_sample.py'),'--','--variant','follow','--shoot-mode','guard','--frame','5','--camera',MOVE_OPTIONS.camera,'--job-label',('move_prepare_'+MOVE_OPTIONS.job_label if MOVE_OPTIONS.job_label else 'move_prepare')]
core=runpy.run_path(str(Path(__file__).resolve().parent/'build_dash_sample.py'),run_name='__main__')
ctx=core['ctx'];R=core['R'];B=core['B'];L=core['L'];rig=core['rig'];sc=core['sc'];C=core['C'];D=core['D'];axis=core['axis'];absorb=core['row'];ABS_M={n:m.copy() for n,m in absorb['bones'].items()};ABS_BOB=absorb['bob'].copy();ABS_FEET={s:Vector(absorb['feet'][s]['ankle']) for s in ['l','r']}
solve_motion=core['solve_motion'];solve_two_bone=core['solve_two_bone'];transport_segment=core['transport_segment'];matrix_at=core['matrix_at'];apply_pose=core['apply_pose'];upper_state=core['upper_state'];layers=core['layers'];fixed=core['fixed']
body_manifest=json.load(open(core['SRC']/'body_manifest.json'));movement=body_manifest['clips'][MOVE_OPTIONS.camera+'/run_forward'];stride_game=movement['projected_stride_game_px'];stride_world=movement['stride_m'];start_phase=1/16;total_distance=230*.08;camera=Matrix(C['directions'][MOVE_OPTIONS.camera]['camera_matrix_world']);pixel_scale=192/C['ortho_scale'];game_scale=C['texture_to_game_scale'];tag='follow_guard_move_full'+('' if MOVE_OPTIONS.camera=='east' else '__'+MOVE_OPTIONS.camera+'_dash_0')+('__job_'+MOVE_OPTIONS.job_label if MOVE_OPTIONS.job_label else '');frame_prefix=MOVE_OPTIONS.camera+'_guard_move';out=ROOT/'renders'/tag;out.mkdir(parents=True,exist_ok=True)
sc.cycles.device='CPU';sc.cycles.samples=MOVE_OPTIONS.samples;core['dep'].base_path=str(out)
records=[];start_clock=time.monotonic()
for ri,i in enumerate([6,7,8]):
 progress=(ri+1)/3;w=progress*progress*(3-2*progress);distance=total_distance*progress;root_travel=D*(distance/stride_game*stride_world);phase=start_phase+distance/stride_game
 target=solve_motion(ctx,D,phase);M={n:m.copy() for n,m in target['bones'].items()};TARGET={n:m.copy() for n,m in M.items()};target_bob=target['bob'].copy();pivot=M['chest'].translation.copy();lean=[3,1,0][ri];Q=Matrix.Translation(pivot)@Matrix.Rotation(math.radians(lean),4,axis)@Matrix.Translation(-pivot);CQ=Matrix.Translation(pivot)@Matrix.Rotation(math.radians(lean*.545),4,axis)@Matrix.Translation(-pivot)
 for n in ['hips','spine','upper_spine']+[n for n in M if n.startswith('cloth_')]:M[n]=Q@M[n]
 for n in fixed:M[n]=CQ@M[n]
 bob=ABS_BOB.lerp(target_bob,w);hip=M['hips'];feet={};footbase=ctx['R0']@Matrix.Rotation(math.radians(target['foot_yaw_deg']),3,'Z');lane=footbase@Vector((1,0,0));facing=footbase@Vector((0,-1,0))
 for side,sg in [('l',1),('r',-1)]:
  foot='foot.'+side;start_ankle=ABS_FEET[side]-root_travel;target_ankle=Vector(target['feet'][side]['ankle']);actual=start_ankle.lerp(target_ankle,w)
  foot_q=ABS_M[foot].to_quaternion().slerp(TARGET[foot].to_quaternion(),w)
  # mathutils near-collinear slerp can lose unit magnitude by ~1e-5.
  # Repair only that numerical defect; already valid accepted poses stay exact.
  if abs(foot_q.magnitude-1.0)>1e-6:foot_q.normalize()
  foot_bone_R=foot_q.to_matrix();sole_R=foot_bone_R@R[foot].to_3x3().inverted();desired_sole_z=target['feet'][side]['lowest_sole'][2]*w;actual.z=desired_sole_z-min((sole_R@v).z for v in ctx['sole'][side])
  S=hip@R['hips'].inverted()@B['thigh.'+side][0];A=actual-bob;pole=S+facing*.8+lane*(sg*.05);knee,ankle,error=solve_two_bone(S,A,L['thigh.'+side],L['shin.'+side],pole,bend_gap=.004)
  M['thigh.'+side]=transport_segment(R['thigh.'+side],*B['thigh.'+side],S,knee);M['shin.'+side]=transport_segment(R['shin.'+side],*B['shin.'+side],knee,ankle);M[foot]=matrix_at(foot_bone_R,ankle)
  knee_forward=(knee-(S+ankle)*.5).dot(facing);assert knee_forward>0;assert error<1e-5
  lowest=min((ankle+bob+sole_R@v for v in ctx['sole'][side]),key=lambda v:v.z);support_delta=ankle+bob+root_travel-ABS_FEET[side];screen_delta=camera.inverted().to_3x3()@support_delta
  toe=min(ctx['sole'][side],key=lambda v:v.y);start_sole_R=ABS_M[foot].to_3x3()@R[foot].to_3x3().inverted();start_toe=ABS_FEET[side]+start_sole_R@toe;virtual_toe=ankle+bob+sole_R@toe+root_travel;toe_delta=camera.inverted().to_3x3()@(virtual_toe-start_toe)
  feet[side]={'virtual_toe_world':list(virtual_toe),'toe_contact_drift_game_px':math.hypot(toe_delta.x,toe_delta.y)*pixel_scale*game_scale,'hip':list(S+bob),'knee':list(knee+bob),'ankle':list(ankle+bob),'lowest_sole_z':lowest.z,'reach_error_m':error,'knee_forward_bend_m':knee_forward,'virtual_root_motion_world_m':list(root_travel),'virtual_ankle_world':list(ankle+bob+root_travel),'support_drift_game_px':math.hypot(screen_delta.x,screen_delta.y)*pixel_scale*game_scale}
 row={**target,'bones':M,'bob':bob,'pelvis_rotation':Q.to_3x3()@target['pelvis_rotation'],'feet':feet,'reach':{s:feet[s]['reach_error_m'] for s in feet},'upper_transform':CQ}
 cloth_stats=apply_pose(ctx,row,correct=True);u=upper_state(i,M,CQ);bpy.context.view_layer.update();length_error=max(abs((M[n]@Vector((0,L[n],0))-M[n].translation).length-L[n]) for n in M);connection_error=max((M[a]@Vector((0,L[a],0))-M[b].translation).length for a,b in [('hips','spine'),('spine','upper_spine'),('upper_spine','chest'),('thigh.l','shin.l'),('shin.l','foot.l'),('thigh.r','shin.r'),('shin.r','foot.r')]);assert length_error<1e-6,('bone_length',MOVE_OPTIONS.camera,ri,length_error,sorted([(n,abs((M[n]@Vector((0,L[n],0))-M[n].translation).length-L[n])) for n in M],key=lambda v:v[1],reverse=True)[:3]);assert connection_error<3e-6,('connection',MOVE_OPTIONS.camera,ri,connection_error)
 compare_names=['root','hips','spine','upper_spine','chest','neck','head','clavicle.l','clavicle.r','thigh.l','shin.l','foot.l','thigh.r','shin.r','foot.r']+[n for n in M if n.startswith('cloth_')];endpoint_error=max(abs(M[n][a][b]-TARGET[n][a][b]) for n in compare_names for a in range(4) for b in range(4))
 if ri==2:assert endpoint_error<2e-6,endpoint_error
 cv=camera.inverted().to_3x3()@bob
 rec={'index':ri,'source_recovery_key':i,'distance_game_px':distance,'distance_fraction':progress,'nominal_time_after_dash_s':distance/230,'nominal_total_time_s':.2+distance/230,'gait_phase':phase,'gait_phase_start':start_phase,'gait_phase_end':start_phase+total_distance/stride_game,'shared_bob_world_m':list(bob),'shared_screen_shift_px':[cv.x*pixel_scale,-cv.y*pixel_scale],'shared_bob_game_px':[cv.x*pixel_scale*game_scale,-cv.y*pixel_scale*game_scale],'shared_depth_shift_m':-cv.z,'lower_spine_pitch_degrees':lean,'chest_pitch_degrees':lean*.545,'bones':{n:list(map(list,m)) for n,m in M.items()},'upper_transform':list(map(list,CQ)),'feet':feet,'cloth':cloth_stats,'bone_length_error_m':length_error,'connection_error_m':connection_error,'difference_from_continuous_target_matrices':endpoint_error,'arrow_visible':u['visible']};records.append(rec)
 png=out/f'{frame_prefix}_{ri:03}.png';exr=out/f'{frame_prefix}_{ri:03}_depth_0000.exr'
 if MOVE_OPTIONS.render and not (MOVE_OPTIONS.skip_existing and core['cached_validation_valid'](tag,frame_prefix,ri,requested_pose=rec,role='guard_move',camera=MOVE_OPTIONS.camera,relative=0,clip=MOVE_OPTIONS.camera+'/dash_0_move_recover')):
  visible=set(layers['body_core'])|set(layers['shoot_limbs_props'])
  if not u['visible']:visible.discard('Cosmetic_arrow_shaft');visible.discard('Cosmetic_arrow_tip')
  for o in sc.objects:
   if o.type in ['MESH','CURVE']:o.hide_render=o.name not in visible
  bpy.data.objects['Lower_anatomical_legs_feet_CC0'].hide_render=True;sc.render.filepath=str(out/f'{frame_prefix}_{ri:03}.png');core['dep'].file_slots[0].path=f'{frame_prefix}_{ri:03}_depth_';bpy.context.view_layer.update();bpy.ops.render.render(write_still=True)
 if MOVE_OPTIONS.render:
  rec['artifact_validation']=core['save_validation'](tag,frame_prefix,ri,role='guard_move',camera=MOVE_OPTIONS.camera,relative=0,clip=MOVE_OPTIONS.camera+'/dash_0_move_recover');checkpoint_dir=ROOT/'pose_checkpoints'/tag;checkpoint_dir.mkdir(parents=True,exist_ok=True);checkpoint=checkpoint_dir/f'{frame_prefix}_{ri:03}.json';checkpoint.write_text(json.dumps({'version':2,'source_identity':core['source_identity'](),'clip':MOVE_OPTIONS.camera+'/dash_0_move_recover','sample_count':1,'frames':[rec]},indent=2));core['bind_pose_metadata'](tag,frame_prefix,[ri],checkpoint)
 print('MOVE_RECOVERY',json.dumps({k:v for k,v in rec.items() if k not in ['bones','upper_transform']}),flush=True)
result={'version':2,'source_identity':core['source_identity'](),'role':'guard_move','clip':MOVE_OPTIONS.camera+'/dash_0_move_recover','camera_direction':MOVE_OPTIONS.camera,'output_tag':tag,'rendered':MOVE_OPTIONS.render,'scope':'three '+MOVE_OPTIONS.camera+'/forward full guarded recovery frames; candidate','driver':'accumulated actual movement distance / 18.4 game pixels; not a required fixed 0.08 seconds','distance_total_game_px':total_distance,'nominal_speed_for_authoring':230,'nominal_duration_s':.08,'starting_dash_frame':5,'starting_gait_phase':start_phase,'ending_gait_phase':start_phase+total_distance/stride_game,'recommended_exit_walk_frame':int(math.floor((start_phase+total_distance/stride_game)*16+.5))%16,'recommended_exit_gait_phase':(int(math.floor((start_phase+total_distance/stride_game)*16+.5))%16)/16,'stride_game_px':stride_game,'stride_world_m':stride_world,'canonical_pivot_px':C['pivot_px'],'display_scale':game_scale,'sample_count':3,'frames':records,'cpu_elapsed_s':time.monotonic()-start_clock}
manifest_path=ROOT/('guard_move_recovery.json' if MOVE_OPTIONS.camera=='east' and not MOVE_OPTIONS.job_label else 'guard_move_recovery_'+MOVE_OPTIONS.camera+('__job_'+MOVE_OPTIONS.job_label if MOVE_OPTIONS.job_label else '')+'.json');manifest_path.write_text(json.dumps(result,indent=2))
if MOVE_OPTIONS.render:core['bind_pose_metadata'](tag,frame_prefix,range(3),manifest_path)
print('VALIDATED_MOVING_GUARD',str(manifest_path))
