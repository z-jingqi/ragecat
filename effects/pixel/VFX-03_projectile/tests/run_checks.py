#!/usr/bin/env python3
"""Focused executable Godot state tests + neutral preset contract, no fake engine tests."""
from pathlib import Path
import json, os, subprocess
root = Path(__file__).resolve().parents[4]
effect = root/'effects/pixel/VFX-03_projectile'
presets = json.loads((effect/'config/presets.json').read_text())
assert presets['variant'] == 'compact_energy_bolt'
assert len({p['id'] for p in presets['presets']}) == len(presets['presets'])
assert all(set(p['overrides']) <= set(presets['defaults']) for p in presets['presets'])
subprocess.run(['python3', str(effect/'sync_config.py'), '--check'], check=True)
env = dict(os.environ)
for key, sub in [('XDG_CONFIG_HOME','config'),('XDG_DATA_HOME','data'),('XDG_CACHE_HOME','cache')]:
    path = Path('/tmp/vfx03-godot')/sub
    path.mkdir(parents=True, exist_ok=True)
    env[key] = str(path)
subprocess.run(['godot', '--headless', '--path', str(root/'preview/godot'), '--script', 'res://effects/VFX-03_projectile/test_projectile.gd'], check=True, env=env)
subprocess.run(['godot', '--headless', '--path', str(root/'preview/godot'), '--script', 'res://effects/VFX-03_projectile/test_demo.gd'], check=True, env=env)
print('VFX-03 focused checks: PASS')
