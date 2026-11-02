#!/usr/bin/env python3
from pathlib import Path
import os,json,subprocess
root=Path(__file__).resolve().parents[4]
effect=root/'effects/pixel/VFX-03_physical_projectile'
runtime=root/'preview/godot/effects/VFX-03_physical_projectile'
data=json.loads((effect/'config/presets.json').read_text())
assert len({p['id'] for p in data['presets']})==len(data['presets'])
assert all(set(p['overrides'])<=set(data['defaults']) for p in data['presets'])
for p in runtime.glob('*.gd'):
    s=p.read_text();assert 'VFX-03_projectile/' not in s and 'VFX-02_weapon_trail/' not in s,p
subprocess.run(['python3',str(effect/'sync_config.py'),'--check'],check=True)
env=dict(os.environ)
for key,sub in [('XDG_CONFIG_HOME','config'),('XDG_DATA_HOME','data'),('XDG_CACHE_HOME','cache')]:
    p=Path('/tmp/physical-godot')/sub;p.mkdir(parents=True,exist_ok=True);env[key]=str(p)
subprocess.run(['godot','--headless','--path',str(root/'preview/godot'),'--script','res://effects/VFX-03_physical_projectile/test_physical.gd'],env=env,check=True)
print('Physical projectile contract: PASS; no energy/weapon runtime dependency')
