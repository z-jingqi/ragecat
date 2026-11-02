#!/usr/bin/env python3
from pathlib import Path
import os,subprocess,json
root=Path(__file__).resolve().parents[4]
effect=root/'effects/pixel/VFX-08_lightning'
data=json.loads((effect/'config/presets.json').read_text())
assert all(set(p['overrides'])<=set(data['defaults']) for p in data['presets'])
subprocess.run(['python3',str(effect/'sync_config.py'),'--check'],check=True)
env=dict(os.environ)
for key,name in [('XDG_CONFIG_HOME','config'),('XDG_CACHE_HOME','cache'),('XDG_DATA_HOME','data')]:
 p=Path('/tmp/lightning-godot')/name;p.mkdir(parents=True,exist_ok=True);env[key]=str(p)
subprocess.run(['godot4','--headless','--path',str(root/'preview/godot'),'--script','res://effects/VFX-08_lightning/test_lightning.gd'],env=env,check=True)
subprocess.run(['godot4','--headless','--path',str(root/'preview/godot'),'--script','res://effects/VFX-08_lightning/test_demo.gd'],env=env,check=True)
