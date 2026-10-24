"""Validate authored alpha, transition registration and loop closure.
Run after render_assets.py --loop-boundary and pack_assets.py.
Visual QA still requires inspection at actual game scale on the target renderer.
"""
import argparse
import json
from pathlib import Path
from PIL import Image, ImageChops

p = argparse.ArgumentParser()
p.add_argument('--frames', type=Path, required=True)
p.add_argument('--assets', type=Path, default=Path('assets/vfx/blender/ice_dark'))
a = p.parse_args()
manifest = json.loads((a.assets / 'manifest.json').read_text())
for entry in manifest:
    im = Image.open(a.assets / Path(entry['path']).name).convert('RGBA')
    cell = entry['cell_size']
    assert im.size == (entry['columns'] * cell, entry['rows'] * cell), entry['key']
    assert entry['alpha'] == 'straight' and entry['intended_mode'] == 'alpha_blend'
    for frame in range(entry['frames']):
        x, y = frame % entry['columns'] * cell, frame // entry['columns'] * cell
        tile = im.crop((x, y, x + cell, y + cell))
        box = tile.getchannel('A').getbbox()
        if box:
            assert box[0] >= 1 and box[1] >= 1 and box[2] <= cell - 1 and box[3] <= cell - 1, (entry['key'], frame, box)
        if entry['key'] in ['ice_shatter', 'ice_thaw'] and frame == entry['frames'] - 1:
            assert box is None, (entry['key'], 'final frame must be clear')
        if entry['key'] == 'ice_shell' and frame == 0:
            assert box is None, 'frozen shell starts empty'

def load(kind, frame):
    return Image.open(a.frames / kind / f'{frame:03}.png').convert('RGBA')

def equal(first, second):
    # RGBA getbbox alone can ignore RGB differences when alpha is identical.
    return not any(channel.getbbox() for channel in ImageChops.difference(first, second).split())

assert equal(load('ice_growth', 23), load('ice_shatter', 0)), 'shell/shatter registration or material mismatch'
assert equal(load('ice_growth', 23), load('ice_thaw', 0)), 'shell/thaw registration or material mismatch'
assert equal(load('dark_vortex', 0), load('dark_vortex', 24)), 'dark loop endpoint mismatch'
print('Ice/dark assets: atlas layout, padding, clear endpoints, exact ice transitions and dark loop endpoint passed.')
