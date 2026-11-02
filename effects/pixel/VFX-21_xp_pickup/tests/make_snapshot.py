from pathlib import Path
import sys,shutil,hashlib
root=Path(__file__).resolve().parents[4]
runtime=root/'preview/godot/effects/VFX-21_xp_pickup'
files=sorted(runtime.glob('*'))+[root/'preview/godot/project.godot']
digest=hashlib.sha256(b''.join(p.read_bytes() for p in files if p.is_file())).hexdigest()[:16]
out=Path(sys.argv[1]).resolve()/('source-'+digest);(out/'effects/VFX-21_xp_pickup').mkdir(parents=True,exist_ok=True)
for p in files:
 if p.is_file():shutil.copy2(p,out/p.name if p.name=='project.godot' else out/'effects/VFX-21_xp_pickup'/p.name)
print(out)
