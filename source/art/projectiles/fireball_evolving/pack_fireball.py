"""Pack 32 final-quality, 64-sample straight-alpha PNG poses; never launch a renderer or encoder.

Usage: python pack_fireball.py /tmp/ragecat-evolving-fire-frames [output.png]
Add --check to compare the assembled pixel bytes with an existing atlas, without
writing an image. Do not composite onto a background or paste through alpha:
either would multiply the source alpha twice.
"""
import argparse
import hashlib
import json
from pathlib import Path
from PIL import Image

HERE = Path(__file__).resolve().parent
GRID = (8, 4)
CELL_SIZE = (192, 128)
FRAME_COUNT = 32
DEFAULT_OUTPUT = HERE.parents[3] / 'assets/projectiles/fireball/evolving_fire_atlas.png'


def validate_render_manifest(frame_directory):
    """Refuse incomplete/proof-quality renders when packing the release atlas."""
    manifest = json.loads((frame_directory / 'render_manifest.json').read_text())
    required = {'quality_mode': 'final', 'samples': 64, 'unique_frames': 32,
                'width': 192, 'height': 128, 'view_width': 4.8,
                'camera_center_x': -0.7, 'seed': 24026, 'burn_strength': 0.0}
    for key, expected in required.items():
        if manifest.get(key) != expected:
            raise ValueError(f'Release render requires {key}={expected!r}; got {manifest.get(key)!r}')
    wanted = list(range(FRAME_COUNT))
    rendered = [entry['frame'] for entry in manifest.get('rendered_frames', [])]
    if (manifest.get('requested_frames') != wanted or sorted(rendered) != wanted
            or not manifest.get('complete_requested_frames') or manifest.get('stopped_reason') is not None):
        raise ValueError('Release render manifest must confirm all 32 requested poses completed.')
    source_hash = hashlib.sha256((HERE / 'source_gas/gas_straight_rgba.png').read_bytes()).hexdigest()
    if manifest.get('source_sha256') != source_hash:
        raise ValueError('Rendered color source differs from the curated straight-alpha source.')
    provenance = json.loads((HERE / 'asset_manifest.json').read_text())
    recorded = provenance['original_render_source_sha256']
    for filename, field in [('build_evolving_fire.py', 'builder_script_sha256'),
                            ('evolving_geometry.py', 'geometry_script_sha256'),
                            ('evolving_material.py', 'material_reference_sha256')]:
        curated_hash = hashlib.sha256((HERE / filename).read_bytes()).hexdigest()
        if manifest.get(field) not in (curated_hash, recorded[filename]):
            raise ValueError(f'Rendered {filename} does not match the release source lineage.')
    return manifest


def assemble(frame_directory):
    """Validate a complete frame set and copy the original RGBA pixels once."""
    validate_render_manifest(frame_directory)
    expected = {f'frame_{i:03d}.png' for i in range(FRAME_COUNT)}
    found = {path.name for path in frame_directory.glob('frame_*.png')}
    if found != expected:
        raise ValueError(f'Expected exactly 32 poses; missing={sorted(expected-found)}, extra={sorted(found-expected)}')
    atlas = Image.new('RGBA', (CELL_SIZE[0] * GRID[0], CELL_SIZE[1] * GRID[1]))
    unique_poses = set()
    for frame in range(FRAME_COUNT):
        path = frame_directory / f'frame_{frame:03d}.png'
        with Image.open(path) as source:
            if source.size != CELL_SIZE or source.mode != 'RGBA':
                raise ValueError(f'{path.name}: expected 192x128 RGBA, got {source.size} {source.mode}')
            unique_poses.add(source.tobytes())
            atlas.paste(source, ((frame % GRID[0]) * CELL_SIZE[0], (frame // GRID[0]) * CELL_SIZE[1]))
    if len(unique_poses) != FRAME_COUNT:
        raise ValueError('The atlas must contain 32 distinct rendered poses, not repeated frames.')
    return atlas


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('frames', type=Path)
    parser.add_argument('output', nargs='?', type=Path, default=DEFAULT_OUTPUT)
    parser.add_argument('--check', action='store_true')
    args = parser.parse_args()
    atlas = assemble(args.frames)
    if args.check:
        with Image.open(args.output) as existing:
            if existing.mode != 'RGBA' or existing.size != atlas.size or existing.tobytes() != atlas.tobytes():
                raise ValueError('Existing atlas differs from the 32 source poses.')
        print(f'PASS: 32 distinct poses exactly match {args.output}; no image written.')
    else:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        atlas.save(args.output)
        print(f'Packed {FRAME_COUNT} distinct poses as {GRID[0]}x{GRID[1]} cells: {args.output}')


if __name__ == '__main__':
    main()
