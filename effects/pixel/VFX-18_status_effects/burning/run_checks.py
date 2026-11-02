from pathlib import Path
import os, subprocess, tempfile
root=Path(__file__).resolve().parents[4]
a=root/'effects/pixel/VFX-18_status_effects/burning/config.json'
b=root/'preview/godot/effects/VFX-18_status_effects/burning/config.json'
assert a.read_bytes()==b.read_bytes()
with tempfile.TemporaryDirectory() as home:
 env={**os.environ,'HOME':home,'XDG_DATA_HOME':home,'XDG_CACHE_HOME':home}
 subprocess.run(['godot','--headless','--path',str(root/'preview/godot'),'--script','res://effects/VFX-18_status_effects/burning/test_burning.gd'],env=env,check=True)
