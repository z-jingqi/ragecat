#!/usr/bin/env python3
from pathlib import Path
import hashlib,json,shutil,sys
root=Path(__file__).resolve().parents[4];out=Path(sys.argv[1]).resolve()
assert root not in out.parents and out!=root
preview=root/'preview/godot';files=[preview/'project.godot']+sorted((preview/'effects/VFX-08_lightning').glob('*'))
files=[f for f in files if f.is_file() and not f.name.endswith('.uid')]
manifest={str(f.relative_to(preview)):hashlib.sha256(f.read_bytes()).hexdigest() for f in files}
digest=hashlib.sha256(json.dumps(manifest,sort_keys=True).encode()).hexdigest();target=out/('source-'+digest[:16])/'project'
for f in files:
 p=target/f.relative_to(preview);p.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(f,p)
(target.parent/'source-manifest.json').write_text(json.dumps(manifest,indent=2)+'\n');print(target)
