#!/usr/bin/env python3
"""Focused math/config/generated-adapter checks; engine checks are separate."""
import json
import re
from pathlib import Path
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
subprocess.run(['python3', str(ROOT/'build_shaders.py'), '--check'], check=True)
with tempfile.TemporaryDirectory(prefix='ragecat-slash-check-') as out:
    binary = str(Path(out)/'kernel_checks')
    subprocess.run(['g++','-std=c++17','-O2','-Wall','-Wextra','-Werror',str(ROOT/'tests/kernel_checks.cpp'),'-o',binary],check=True)
    subprocess.run([binary],check=True)
data=json.loads((ROOT/'config/presets.json').read_text())
default=data['defaults']
assert abs(sum(default[k] for k in ['start_seconds','burst_seconds','decay_seconds'])-.18)<1e-6
assert 'seed' not in default
for preset in data['presets']:
    p=default|preset['overrides']
    assert 16<=p['reach_px']<=80
    assert 2<=p['thickness_px']<=min(28,p['reach_px']*.65)
    assert 30<=p['sweep_degrees']<=220 and .35<=p['curvature']<=1
    assert .005<=p['start_seconds']<=.08 and .015<=p['burst_seconds']<=.16 and .025<=p['decay_seconds']<=.25
print('Preset and generated-adapter checks passed.')

preview=(ROOT.parents[2]/'preview/godot/preview.gd').read_text()
ui_defaults=preview.split('const DEFAULTS := {',1)[1].split('}',1)[0]
for key,value in default.items():
    if key == 'pixels_per_unit': continue  # integration metadata, not a preview knob
    if isinstance(value,bool): pattern=r'"'+key+r'"\s*:\s*'+str(value).lower()
    elif isinstance(value,(int,float)):
        match=re.search(r'"'+key+r'"\s*:\s*([0-9.]+)',ui_defaults)
        assert match and abs(float(match.group(1))-value)<1e-7, key
        continue
    else: pattern=r'"'+key+r'"\s*:\s*Color\("'+value.lstrip('#')+r'"\)'
    assert re.search(pattern,ui_defaults), key
print('Preview defaults match the canonical parameter contract.')
