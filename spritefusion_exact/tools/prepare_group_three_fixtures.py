import json, pathlib, struct, sys
root = pathlib.Path(sys.argv[1])
def encode(v):
    if isinstance(v, bool): return v
    if isinstance(v, (int, float)): return {'__f64': struct.pack('<d', v).hex()}
    if isinstance(v, list): return [encode(x) for x in v]
    if isinstance(v, dict): return {k: encode(x) for k,x in v.items()}
    return v
for suite in ['oracle','oracle-stress']:
    base=root/suite
    (base/'cases-f64.json').write_text(json.dumps(encode(json.loads((base/'cases.json').read_text()))))
