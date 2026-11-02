#!/usr/bin/env python3
"""Freeze exact native-capture inputs outside the repository, with content hashes."""
from pathlib import Path
import hashlib, json, shutil, sys
root = Path(__file__).resolve().parents[4]
output = Path(sys.argv[1]).resolve()
assert root not in output.parents and output != root, 'Capture artifacts must stay outside the repository'
preview = root / 'preview/godot'
files = [preview/'project.godot'] + sorted((preview/'effects/VFX-03_projectile').glob('*'))
files = [p for p in files if p.is_file()]
manifest = {str(p.relative_to(preview)): hashlib.sha256(p.read_bytes()).hexdigest() for p in files}
digest = hashlib.sha256(json.dumps(manifest, sort_keys=True).encode()).hexdigest()
snapshot = output / ('source-' + digest[:16])
project = snapshot/'project'
for source in files:
    target = project/source.relative_to(preview)
    target.parent.mkdir(parents=True, exist_ok=True)
    if target.exists():
        assert target.read_bytes() == source.read_bytes(), 'Existing immutable snapshot differs'
    else:
        shutil.copyfile(source, target)
(snapshot/'source-manifest.json').write_text(json.dumps({'source_digest': digest, 'files': manifest}, indent=2)+'\n')
print(project)
