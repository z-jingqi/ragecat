#!/usr/bin/env python3
"""Copy the neutral, canonical preset to Godot; --check verifies exact bytes."""
from pathlib import Path
import argparse
p = Path(__file__).resolve().parent
source = p / 'config/presets.json'
target = p.parents[2] / 'preview/godot/effects/VFX-03_projectile/presets.json'
a = argparse.ArgumentParser(); a.add_argument('--check', action='store_true'); args = a.parse_args()
if args.check:
    assert target.read_bytes() == source.read_bytes(), 'Godot presets out of sync'
    print('VFX-03 preset synchronization: PASS')
else:
    target.write_bytes(source.read_bytes())
