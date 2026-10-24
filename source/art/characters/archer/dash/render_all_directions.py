"""Resumable approved 672-frame queue. No game files are written.
Each task has its own render, cloth, metadata and log paths. Verified existing
PNG/EXR pairs are reused, including the accepted east prototypes.
"""
import os

import argparse,json,subprocess,time,threading,concurrent.futures,hashlib
from pathlib import Path
R=Path(os.environ.get('ARCHER_DASH_OUTPUT', str(Path(__file__).resolve().parent/'generated'))).resolve();CAMERAS=['east','southeast','south','southwest','west','northwest','north','northeast'];B=os.environ.get('BLENDER_BIN','/usr/bin/blender')
ap=argparse.ArgumentParser();ap.add_argument('--workers',type=int,choices=[1],default=1);ap.add_argument('--only',default='');ap.add_argument('--prepare-only',action='store_true');opt=ap.parse_args();jobs=[]
for camera in CAMERAS:
 for rel in range(8):
  legacy=camera=='east' and rel==0;token=f'{camera}_dash_{rel}';tag='braced_shoot_body'+('' if legacy else '__'+token);prefix='east_dash' if legacy else token
  jobs.append({'id':f'body:{camera}:{rel}','kind':'body','camera':camera,'relative':rel,'count':9,'tag':tag,'prefix':prefix,'metadata':f'dash_sample_{tag}.json'})
for camera in CAMERAS:
 legacy=camera=='east';token=f'{camera}_dash_0';tag='follow_guard_full'+('' if legacy else '__'+token);prefix='east_dash' if legacy else token;jobs.append({'id':f'guard:{camera}:0','kind':'guard','camera':camera,'relative':0,'count':9,'tag':tag,'prefix':prefix,'metadata':f'dash_sample_{tag}.json'})
 tag='follow_guard_move_full'+('' if legacy else '__'+token);jobs.append({'id':f'guard_move:{camera}:0','kind':'guard_move','camera':camera,'relative':0,'count':3,'tag':tag,'prefix':camera+'_guard_move','metadata':'guard_move_recovery.json' if legacy else 'guard_move_recovery_'+camera+'.json'})
if opt.only:
 chosen=set(opt.only.split(','));jobs=[j for j in jobs if j['id'] in chosen]
# Deliver useful diagonals, reverse-camera proof and guard branches early.
def priority(j):
 if j['kind']=='body' and j['camera']=='east':return (0,j['relative'])
 if j['id']=='body:west:4':return (1,0)
 if j['kind']=='guard':return (2,CAMERAS.index(j['camera']))
 if j['kind']=='guard_move':return (3,CAMERAS.index(j['camera']))
 return (4,CAMERAS.index(j['camera'])*8+j['relative'])
jobs.sort(key=priority);manifest_path=R/'all_direction_completion.json';lock=threading.Lock();began=time.monotonic();R.mkdir(parents=True,exist_ok=True);report={'version':1,'scope':'approved 64 body x9 +8 guard x9 +8 guard_move x3; no publication','workers':opt.workers,'cpu_threads_per_job':2,'expected_frames':sum(j['count'] for j in jobs),'jobs':[]}
SRC=Path(os.environ.get('ARCHER_SOURCE_ROOT', str(Path(__file__).resolve().parent.parent))).resolve();source_id={'source_directory':str(SRC),'sha256':{n:hashlib.sha256((SRC/n).read_bytes()).hexdigest() for n in ['archer.blend','camera_contract.json','body_poses.json.gz','upper_poses.json.gz','locomotion_solver.py','layer_objects.json']}};report['source_identity']=source_id;report['pause_file']=str(R/'PAUSE_RENDER')

def pair_paths(j,i):
 folder=R/'renders'/j['tag'];return folder/f"{j['prefix']}_{i:03}.png",folder/f"{j['prefix']}_{i:03}_depth_0000.exr"
def verified(j):
 result=[]
 for i in range(j['count']):
  png,exr=pair_paths(j,i);vp=R/'validation'/j['tag']/f"{j['prefix']}_{i:03}.json"
  try:
   v=json.load(open(vp));expected_clip=j['camera']+('/dash_0_move_recover' if j['kind']=='guard_move' else '/dash_'+str(j['relative']))
   assert v['source_identity']==source_id and v['role']==j['kind'] and v['camera']==j['camera'] and v['relative']==j['relative'] and v['clip']==expected_clip and v['frame']==i
   assert v['pose_metadata_sha256']==hashlib.sha256(Path(v['pose_metadata_path']).read_bytes()).hexdigest()
   assert v['canvas_px']==[192,192] and v['alpha_nonzero_pixels']>0 and v['safe_surface_depth_range'] is True
   assert v['color_sha256']==hashlib.sha256(png.read_bytes()).hexdigest() and v['depth_sha256']==hashlib.sha256(exr.read_bytes()).hexdigest()
   result.append(i)
  except (OSError,ValueError,KeyError,AssertionError):pass
 return result

def save():
 report['elapsed_s']=time.monotonic()-began;report['verified_frames']=sum(len(j.get('verified_frames',[])) for j in report['jobs']);report['complete_jobs']=sum(j['status'] in ['complete','reused'] for j in report['jobs']);report['failed_jobs']=sum(j['status']=='failed' for j in report['jobs']);temp=manifest_path.with_suffix('.tmp');temp.write_text(json.dumps(report,indent=2));temp.replace(manifest_path)
for j in jobs:
 done=verified(j);j['verified_frames']=done;j['initial_verified_frames']=len(done);j['status']='pending';meta=R/j['metadata']
 try:valid_meta=json.load(open(meta)).get('sample_count')==j['count']
 except (OSError,ValueError):valid_meta=False
 if len(done)==j['count'] and valid_meta:j['status']='reused'
 report['jobs'].append(j)
with lock:save()
if opt.prepare_only:
 print('PREPARED',str(manifest_path),'expected',report['expected_frames'],'verified',report['verified_frames']);raise SystemExit(0)
def execute(j):
 if j['status']=='reused':return
 cmd=[B,'-b','--disable-autoexec','--python-exit-code','1','-t','2','-P',str(Path(__file__).resolve().parent/('build_guard_move_recovery.py' if j['kind']=='guard_move' else 'build_dash_sample.py')),'--','--render','--camera',j['camera'],'--samples','16','--skip-existing']
 if j['kind']!='guard_move':cmd+=['--cpu','--relative-travel',str(j['relative']),'--variant','braced' if j['kind']=='body' else 'follow','--shoot-mode','shoot' if j['kind']=='body' else 'guard','--layer','body' if j['kind']=='body' else 'full']
 log=R/'batch_logs'/f"{j['kind']}_{j['camera']}_{j['relative']}.log";log.parent.mkdir(exist_ok=True);start=time.monotonic();peak=0
 with log.open('w') as f:
  p=subprocess.Popen(cmd,stdout=f,stderr=subprocess.STDOUT)
  with lock:j.update(status='running',pid=p.pid,log=str(log),command=cmd);save()
  while p.poll() is None:
   try:
    values=[x for x in Path(f'/proc/{p.pid}/status').read_text().splitlines() if x.startswith('VmHWM:')];peak=max(peak,int(values[0].split()[1]) if values else 0)
   except OSError:pass
   done=verified(j)
   with lock:
    if done!=j['verified_frames']:j['verified_frames']=done;save()
   time.sleep(.5)
 done=verified(j)
 try:meta=json.load(open(R/j['metadata']));valid_meta=meta.get('sample_count')==j['count']
 except (OSError,ValueError):valid_meta=False
 with lock:
  j.update(returncode=p.returncode,elapsed_s=time.monotonic()-start,max_rss_KiB_observed=peak,verified_frames=done,status='complete' if p.returncode==0 and len(done)==j['count'] and valid_meta else 'failed')
  if j['status']=='failed':j['error_tail']='\n'.join(log.read_text(errors='replace').splitlines()[-20:])
  save()
 print('JOB_DONE',j['id'],j['status'],len(done),round(j['elapsed_s'],2),flush=True)
for j in jobs:
 while (R/'PAUSE_RENDER').exists():
  with lock:report['queue_status']='paused';save()
  time.sleep(1)
 if (R/'STOP_RENDER').exists():
  with lock:report['queue_status']='stopped_at_group_boundary';save()
  break
 with lock:report['queue_status']='running';save()
 execute(j)
 if j['status']=='failed':
  with lock:report['queue_status']='blocked_on_failed_job';save()
  break
with lock:
 if report.get('queue_status')=='running':report['queue_status']='complete'
 save()
print('QUEUE_RESULT',json.dumps({k:v for k,v in report.items() if k!='jobs'}),flush=True)
if report['failed_jobs']:raise SystemExit(1)
