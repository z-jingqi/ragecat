from pathlib import Path
import os,subprocess
root=Path(__file__).resolve().parents[4]
env=dict(os.environ)
for key,name in [('XDG_CONFIG_HOME','config'),('XDG_CACHE_HOME','cache'),('XDG_DATA_HOME','data')]:
 p=Path('/tmp/chain-godot')/name;p.mkdir(parents=True,exist_ok=True);env[key]=str(p)
for script in ['test_chain.gd','test_demo.gd']:
 subprocess.run(['godot4','--headless','--path',str(root/'preview/godot'),'--script','res://effects/VFX-08_chain_lightning/'+script],env=env,check=True)
