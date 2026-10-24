"""Numeric per-clip gait handoff recommendations, separate from formal import."""
import os

import json,gzip,time,math
from pathlib import Path
import numpy as np
R=Path(os.environ.get('ARCHER_DASH_OUTPUT', str(Path(__file__).resolve().parent/'generated'))).resolve();S=Path(os.environ.get('ARCHER_SOURCE_ROOT', str(Path(__file__).resolve().parent.parent))).resolve();C=json.load(open(S/'camera_contract.json'));P=json.load(gzip.open(S/'body_poses.json.gz','rt'));BM=json.load(open(S/'body_manifest.json'));moves=['run_forward','run_forward_right','run_right','run_back_right','run_back','run_back_left','run_left','run_forward_left'];names=['foot.l','foot.r','shin.l','shin.r','hips'];weights=[2,2,1,1,1];out={'scope':'numeric handoff recommendations only; not an asset importer or in-game proof','clips':{}};dest=R/'gait_entry_recommendations.json'
def recommend(job):
 meta=json.load(open(R/job['metadata']));camera=job['camera'];clip=camera+'/'+moves[job['relative']];old=BM['clips'][clip];poses=P[old['world_pose_key']];cam=np.linalg.inv(C['directions'][camera]['camera_matrix_world']);scale=192/C['ortho_scale']*C['texture_to_game_scale'];moving=job['kind']=='guard_move';row=meta['frames'][-1] if moving else meta['frames'][5];lead=meta['frames'][0].get('leading_leg','l');rank=[]
 for wi,target in enumerate(poses):
  errors=[]
  for bone in names:
   delta=np.array(target['bones'][bone])[:3,3]+np.array(target['shared_bob_world_m'])-np.array(row['bones'][bone])[:3,3]-np.array(row['shared_bob_world_m']);view=cam[:3,:3]@delta;errors.append(float(np.linalg.norm(view[:2])*scale))
  rank.append({'frame':wi,'phase':wi/16,'screen_rms_game_px':math.sqrt(sum(w*e*e for w,e in zip(weights,errors))/sum(weights)),'max_joint_error_game_px':max(errors),'joint_errors_game_px':dict(zip(names,errors)),'support_foot_lowest_sole_m':old['frames'][wi]['foot_contacts'][lead]['lowest_sole'][2]})
 if moving:
  end=meta['ending_gait_phase']%1;candidates=[v for v in rank if min(abs(v['phase']-end),1-abs(v['phase']-end))<=1/16+1e-6]
 else:candidates=[v for v in rank if v['support_foot_lowest_sole_m']<=.02]
 chosen=min(candidates,key=lambda v:v['screen_rms_game_px']);result={'role':job['kind'],'camera':camera,'relative':job['relative'],'motion_clip':clip,'pose_metadata':str(R/job['metadata']),'support_foot':lead,'chosen':chosen,'nearby_alternative':sorted(candidates,key=lambda v:v['screen_rms_game_px'])[1] if len(candidates)>1 else None,'review_required_over_6px':chosen['max_joint_error_game_px']>6}
 if moving:result.update(guard_move_distance_game_px=meta['distance_total_game_px'],continuous_exit_phase=meta['ending_gait_phase'],recommended_guard_move_exit_phase=chosen['phase'])
 elif job['kind']=='body':result['recommended_gait_entry_phase']=chosen['phase']
 else:result.update(guard_move_start_phase=1/16,direct_walk_candidate_phase=chosen['phase'],note='Guarded movement normally uses its separate distance recovery; do not skip guard relaxation.')
 return result
m=json.load(open(R/'all_direction_completion.json'))
assert m.get('queue_status')=='complete' and m.get('verified_frames')==672
for j in m['jobs']:
 assert j['status'] in ['complete','reused']
 out['clips'][j['id']]=recommend(j)
assert len(out['clips'])==80
dest.write_text(json.dumps(out,indent=2))
print('GAIT_RECOMMENDATIONS_COMPLETE',len(out['clips']),str(dest))
