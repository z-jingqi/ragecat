from pathlib import Path
import os, subprocess, tempfile
repo=Path(__file__).resolve().parents[4]
# tests -> VFX dir -> pixel -> effects -> repository
assert (repo/'preview/godot/project.godot').exists()
a=repo/'effects/pixel/VFX-18_status_effects/config/presets.json'
b=repo/'preview/godot/effects/VFX-18_status_effects/presets.json'
assert a.read_bytes()==b.read_bytes()
with tempfile.TemporaryDirectory() as home:
 env={**os.environ,'HOME':home,'XDG_DATA_HOME':home,'XDG_CACHE_HOME':home}
 for script in ['test_status.gd','test_demo.gd']:
  subprocess.run(['godot','--headless','--path',str(repo/'preview/godot'),'--script','res://effects/VFX-18_status_effects/'+script],env=env,check=True)
