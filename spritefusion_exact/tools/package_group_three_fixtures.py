"""Preserve exact TS oracle fixtures, after validating native logs, for test_effect.py."""
import argparse,json,pathlib,shutil,struct
p=argparse.ArgumentParser();p.add_argument('slug');p.add_argument('--audit',required=True);p.add_argument('--baseline',required=True);p.add_argument('--stress',required=True);a=p.parse_args()
root=pathlib.Path(__file__).resolve().parents[1];audit=pathlib.Path(a.audit)
def encode(v):
 if isinstance(v,bool):return v
 if isinstance(v,(int,float)):return {'__f64':struct.pack('<d',v).hex()}
 if isinstance(v,list):return [encode(x) for x in v]
 if isinstance(v,dict):return {k:encode(x) for k,x in v.items()}
 return v
for suite,native in [('oracle',pathlib.Path(a.baseline)),('oracle-stress',pathlib.Path(a.stress))]:
 cases=[c for c in json.loads((audit/suite/'cases.json').read_text()) if c['slug']==a.slug]
 destination=root/'godot/tests/fixtures'/a.slug/suite;destination.mkdir(parents=True,exist_ok=True)
 for c in cases:
  got=json.loads((native/c['id']/'frames.json').read_text());expected=json.loads((audit/suite/c['id']/'frames.json').read_text())
  for key in ['frames','doneFrame','hooks']:assert got[key]==expected[key],(c['id'],key)
  for actual,wanted in zip(got['hashes'],expected['hashes']):
   for key in ['buffers','nonzero','actor','done']:assert actual[key]==wanted[key],(c['id'],actual['frame'],key)
  (destination/c['id']).mkdir(exist_ok=True);shutil.copy(audit/suite/c['id']/'frames.json',destination/c['id']/'expected.json')
 (destination/'cases.json').write_text(json.dumps(cases,indent=2)+'\n');(destination/'cases-f64.json').write_text(json.dumps(encode(cases))+'\n');shutil.copy(audit/suite/'actor.rgba',destination/'actor.rgba')
 print(a.slug,suite,'packaged',len(cases),'exact cases')
