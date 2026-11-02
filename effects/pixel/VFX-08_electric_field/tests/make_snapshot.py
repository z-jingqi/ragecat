from pathlib import Path
import hashlib, shutil, sys
root=Path(__file__).resolve().parents[4]
src=root/'preview/godot/effects/VFX-08_electric_field'
digest=hashlib.sha256(b''.join(p.read_bytes() for p in sorted(src.iterdir()) if p.is_file())).hexdigest()[:16]
out=Path(sys.argv[1])/('source-'+digest)
(out/'effects/VFX-08_electric_field').mkdir(parents=True,exist_ok=True)
shutil.copy2(root/'preview/godot/project.godot',out/'project.godot')
for p in src.iterdir():
 if p.is_file():shutil.copy2(p,out/'effects/VFX-08_electric_field'/p.name)
print(out)
