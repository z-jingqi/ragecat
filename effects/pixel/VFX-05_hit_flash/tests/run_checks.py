from pathlib import Path
import os,subprocess
root=Path(__file__).resolve().parents[4]
a=root/'effects/pixel/VFX-05_hit_flash/config/presets.json'
b=root/'preview/godot/effects/VFX-05_hit_flash/presets.json'
assert a.read_bytes()==b.read_bytes()
env=dict(os.environ)
for k,v in [('XDG_DATA_HOME','data'),('XDG_CONFIG_HOME','config'),('XDG_CACHE_HOME','cache')]:
 p=Path('/tmp/vfx05-test')/v;p.mkdir(parents=True,exist_ok=True);env[k]=str(p)
subprocess.run(['godot','--headless','--path',str(root/'preview/godot'),'--script','res://effects/VFX-05_hit_flash/test_flash.gd'],env=env,check=True,timeout=30)
