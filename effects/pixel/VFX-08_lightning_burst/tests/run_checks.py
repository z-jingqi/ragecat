#!/usr/bin/env python3
from pathlib import Path
import os, subprocess
root=Path(__file__).resolve().parents[4]
env=dict(os.environ)
for key,sub in [('XDG_CONFIG_HOME','config'),('XDG_DATA_HOME','data'),('XDG_CACHE_HOME','cache')]:
 p=Path('/tmp/vfx08-burst-checks')/sub;p.mkdir(parents=True,exist_ok=True);env[key]=str(p)
subprocess.run(['godot','--headless','--path',str(root/'preview/godot'),'--script','res://effects/VFX-08_lightning_burst/test_burst.gd'],env=env,check=True)
