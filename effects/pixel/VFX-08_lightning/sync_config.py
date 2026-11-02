#!/usr/bin/env python3
from pathlib import Path
import json,sys
root=Path(__file__).resolve().parents[3]
effect=Path(__file__).resolve().parent
runtime=root/'preview/godot/effects/VFX-08_lightning'
data=json.loads((effect/'config/presets.json').read_text())
outputs={runtime/'presets.json':json.dumps(data,indent=2)+'\n',runtime/'defaults.gd':'extends RefCounted\nconst DATA = '+json.dumps(data['defaults'])+'\n'}
for p,text in outputs.items():
 if '--check' in sys.argv:assert p.read_text()==text,p
 else:p.write_text(text)
print('Lightning config sync: PASS')
