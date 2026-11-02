#!/usr/bin/env python3
from pathlib import Path
import argparse
p=Path(__file__).resolve().parent
src=p/'config/presets.json'
dst=p.parents[2]/'preview/godot/effects/VFX-03_physical_projectile/presets.json'
a=argparse.ArgumentParser();a.add_argument('--check',action='store_true');args=a.parse_args()
if args.check:
    assert src.read_bytes()==dst.read_bytes(), 'Preset copy is stale'
    print('Physical projectile preset sync: PASS')
else: dst.write_bytes(src.read_bytes())
