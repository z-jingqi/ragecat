#!/usr/bin/env python3
"""Replay a saved native effect fixture and compare every frame to its TS oracle."""
import argparse,json,os,pathlib,subprocess,tempfile
p=argparse.ArgumentParser();p.add_argument('effect');p.add_argument('--suite',choices=['oracle','oracle-stress','all'],default='all');p.add_argument('--output');p.add_argument('--timeout',type=int,default=1800);args=p.parse_args()
root=pathlib.Path(__file__).resolve().parents[1]; project=root/'godot';fixtures=project/'tests/fixtures'/args.effect
out=pathlib.Path(args.output or tempfile.mkdtemp(prefix='spritefusion-'+args.effect+'-')).resolve()
if out.exists() and (not out.is_dir() or any(out.iterdir())):raise SystemExit('Output directory must be absent or empty; existing files were not changed: '+str(out))
env=os.environ.copy(); env['HOME']=str(out/'home');env['XDG_DATA_HOME']=str(out/'data');env['XDG_CACHE_HOME']=str(out/'cache');env['XDG_CONFIG_HOME']=str(out/'config');[pathlib.Path(env[k]).mkdir(parents=True,exist_ok=True) for k in ['HOME','XDG_DATA_HOME','XDG_CACHE_HOME','XDG_CONFIG_HOME']]
import_result=subprocess.run(['godot','--headless','--path',str(project),'--editor','--import','--quit'],env=env,capture_output=True,text=True,timeout=args.timeout)
import_log=out/'editor-import.log';import_log.write_text(import_result.stdout+import_result.stderr)
if import_result.returncode or 'ERROR:' in import_result.stdout or 'ERROR:' in import_result.stderr:raise SystemExit('Godot editor import failed: '+str(import_log))
summary=[]
for suite in ['oracle','oracle-stress'] if args.suite=='all' else [args.suite]:
 for case in json.loads((fixtures/suite/'cases.json').read_text()):
  dest=out/suite/case['id'];dest.mkdir(parents=True,exist_ok=True)
  result=subprocess.run(['godot','--headless','--path',str(project),'--script','res://tests/common/run_oracle.gd','--',str(fixtures),suite,case['id'],str(dest)],env=env,capture_output=True,text=True,timeout=args.timeout)
  (dest/'engine.log').write_text(result.stdout+result.stderr)
  if result.returncode or 'ERROR:' in result.stdout or 'ERROR:' in result.stderr:raise SystemExit('Native run failed: '+str(dest/'engine.log'))
  actual=json.loads((dest/'frames.json').read_text());expected=json.loads((fixtures/suite/case['id']/'expected.json').read_text())
  assert actual['frames']==expected['frames'],case['id']+' frame count'
  assert actual['doneFrame']==expected['doneFrame'],case['id']+' done timing'
  assert actual['hooks']==expected['hooks'],case['id']+' host hooks'
  for a,b in zip(actual['hashes'],expected['hashes']):
   for field in ['buffers','nonzero','actor','done']:assert a[field]==b[field],f"{case['id']} frame {a['frame']} {field}"
  summary.append({'id':case['id'],'frames':actual['frames'],'buffer_comparisons':actual['frames']*4,'mismatches':0})
  print('PASS',case['id'],actual['frames'],'frames')
(out/'summary.json').write_text(json.dumps(summary,indent=2)+'\n')
print('PASS',args.effect,sum(x['buffer_comparisons'] for x in summary),'buffer hashes; output',out)
