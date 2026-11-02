from pathlib import Path
import subprocess,os,json
root=Path(__file__).resolve().parents[4]
e=root/'effects/pixel/VFX-21_xp_pickup'; p=root/'preview/godot/effects/VFX-21_xp_pickup'
assert json.loads((e/'config/default.json').read_text())==json.loads((p/'default.json').read_text())
env=dict(os.environ)
for name in ('CONFIG','DATA','CACHE'):
 d=Path('/tmp/xp-godot')/name.lower();d.mkdir(parents=True,exist_ok=True);env['XDG_'+name+'_HOME']=str(d)
result=subprocess.run(['godot','--headless','--path',str(root/'preview/godot'),'--script','res://effects/VFX-21_xp_pickup/test_xp.gd'],env=env,capture_output=True,text=True)
print(result.stdout);print(result.stderr)
assert result.returncode==0 and 'XP checks PASS:' in result.stdout and 'ERROR:' not in result.stderr

result=subprocess.run(['godot','--headless','--path',str(root/'preview/godot'),'--script','res://effects/VFX-21_xp_pickup/test_demo.gd'],env=env,capture_output=True,text=True)
print(result.stdout);print(result.stderr)
assert result.returncode==0 and 'XP demo checks PASS' in result.stdout and 'ERROR:' not in result.stderr
