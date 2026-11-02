#!/usr/bin/env python3
from pathlib import Path
import json, os, subprocess, tempfile
root=Path(__file__).resolve().parents[4]
source=root/'effects/pixel/VFX-15_monster_death/presets.json'
preview=root/'preview/godot/effects/VFX-15_monster_death/presets.json'
assert json.loads(source.read_text())==json.loads(preview.read_text()), 'Preset copies differ'
env=os.environ.copy()
with tempfile.TemporaryDirectory(prefix='death-checks-') as tmp:
    env.update(XDG_DATA_HOME=tmp, XDG_CACHE_HOME=tmp)
    subprocess.run(['godot','--headless','--path',str(root/'preview/godot'),'--script','res://effects/VFX-15_monster_death/test_death.gd'],env=env,check=True)
    subprocess.run(['godot','--headless','--path',str(root/'preview/godot'),'--script','res://effects/VFX-15_monster_death/test_demo.gd'],env=env,check=True)
    subprocess.run(['godot','--headless','--path',str(root/'preview/godot'),'res://effects/VFX-15_monster_death/death.tscn','--quit-after','8'],env=env,check=True)
print('Preset parity and scene load passed')
