import json, pathlib, sys, gzip, struct
ref=pathlib.Path(sys.argv[1]); actual=pathlib.Path(sys.argv[2])
a=json.loads((ref/'frames.json').read_text()); b=json.loads((actual/'frames.json').read_text())
errors=[]
for k in ['id','slug','frames','doneFrame','hooks']:
    if a[k]!=b[k]: errors.append({'field': k, 'expected': a[k], 'actual': b[k]})
mismatches=[]
for aa,bb in zip(a['hashes'],b['hashes']):
    for channel,sha in aa['buffers'].items():
        if sha!=bb['buffers'].get(channel):
            item={'frame':aa['frame'],'channel':channel,'expected':sha,'actual':bb['buffers'].get(channel)}
            name=f"{aa['frame']:04d}-{channel}.rgba"
            if (ref/(name+'.gz')).exists() and (actual/name).exists():
                x=gzip.decompress((ref/(name+'.gz')).read_bytes()); y=(actual/name).read_bytes()
                item['pixel_differences']=sum(x[i:i+4]!=y[i:i+4] for i in range(0,len(x),4))
                item['first_pixels']=[{'xy':[i//4%320,i//4//320],'expected':list(x[i:i+4]),'actual':list(y[i:i+4])} for i in range(0,len(x),4) if x[i:i+4]!=y[i:i+4]][:8]
            mismatches.append(item)
    if aa['actor']!=bb['actor']: errors.append({'frame':aa['frame'],'field':'actor','expected':aa['actor'],'actual':bb['actor']})
    if aa['done']!=bb['done']: errors.append({'frame':aa['frame'],'field':'done','expected':aa['done'],'actual':bb['done']})
report={'id':a['id'],'frames':b['frames'],'doneFrame':b['doneFrame'],'frame_buffers_compared':4*min(a['frames'],b['frames']),'mismatch_count':len(mismatches),'errors':errors,'first_mismatches':mismatches[:30]}
(actual/'comparison.json').write_text(json.dumps(report,indent=2))
print(json.dumps(report,indent=2))
sys.exit(1 if mismatches or errors else 0)
