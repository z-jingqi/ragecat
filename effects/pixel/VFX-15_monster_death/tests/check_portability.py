#!/usr/bin/env python3
"""Copy only the two runtime files to an unrelated path and exercise standalone lifetime."""
from pathlib import Path
import os, shutil, subprocess, tempfile
root = Path(__file__).resolve().parents[4]
source = root / 'preview/godot/effects/VFX-15_monster_death'
with tempfile.TemporaryDirectory(prefix='death-portable-') as temp:
    target = Path(temp)
    runtime = target / 'scripts/vfx/death'
    runtime.mkdir(parents=True)
    for name in ('death.gd', 'death.gdshader'):
        shutil.copyfile(source / name, runtime / name)
    (target / 'project.godot').write_text('[application]\nconfig/name="Death portability"\n[rendering]\nrenderer/rendering_method="gl_compatibility"\n')
    test = (source / 'test_standalone.gd').read_text().replace('res://effects/VFX-15_monster_death/death.gd', 'res://scripts/vfx/death/death.gd')
    (target / 'test.gd').write_text(test)
    env = os.environ.copy()
    env.update(HOME=temp, XDG_DATA_HOME=temp, XDG_CACHE_HOME=temp, XDG_CONFIG_HOME=temp)
    result = subprocess.run(['godot', '--headless', '--path', temp, '--script', 'res://test.gd', '--quit-after', '10'], env=env, text=True, capture_output=True, timeout=20)
    print(result.stdout, result.stderr)
    if result.returncode or 'STANDALONE DEATH: 12 checks, 0 failed' not in result.stdout:
        raise SystemExit('Isolated two-file death runtime failed')
print('Isolated two-file death portability passed')
