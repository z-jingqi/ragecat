#!/usr/bin/env python3
from pathlib import Path
import json,os,subprocess,tempfile
root=Path(__file__).resolve().parents[4]
assert json.loads((root/'effects/pixel/particle_reveals/presets.json').read_text())==json.loads((root/'preview/godot/effects/particle_reveals/presets.json').read_text())
with tempfile.TemporaryDirectory(prefix='reveals-check-') as tmp:
 env=os.environ.copy();env.update(XDG_DATA_HOME=tmp,XDG_CACHE_HOME=tmp)
 subprocess.run(['godot','--headless','--path',str(root/'preview/godot'),'--script','res://effects/particle_reveals/test_reveals.gd'],env=env,check=True)
 subprocess.run(['godot','--headless','--path',str(root/'preview/godot'),'res://effects/particle_reveals/particle_reveals.tscn','--quit-after','5'],env=env,check=True)
print('Preset parity and scene load passed')
