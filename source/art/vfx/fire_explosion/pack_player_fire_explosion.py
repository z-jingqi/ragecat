"""Pack the original Blender straight-alpha frames into the runtime atlas."""
import argparse
from pathlib import Path
from PIL import Image

parser = argparse.ArgumentParser()
parser.add_argument("frames", type=Path)
parser.add_argument("output", type=Path)
parser.add_argument("--frame-size", type=int, default=256)
args = parser.parse_args()
frames = sorted(args.frames.glob("[0-9][0-9][0-9].png"))
assert len(frames) == 24, "Expected 24 rendered frames"
cell = args.frame_size
atlas = Image.new("RGBA", (cell * 6, cell * 4))
for index, path in enumerate(frames):
    frame = Image.open(path).convert("RGBA")
    assert frame.size == (cell, cell), "Mismatched cell size"
    alpha = frame.getchannel("A")
    if index == 0:
        assert alpha.getbbox() is not None, "Ignition must be visible immediately"
    if index == 23:
        assert alpha.getbbox() is None, "Last frame must be transparent"
    for edge in [(0, 0, cell, 1), (0, cell - 1, cell, cell), (0, 0, 1, cell), (cell - 1, 0, cell, cell)]:
        assert alpha.crop(edge).getextrema()[1] == 0, "Clipped cell border"
    # Remove hidden RGB without premultiplying visible edge colors.
    frame.paste((0, 0, 0, 0), mask=alpha.point(lambda value: 255 if value == 0 else 0))
    atlas.paste(frame, (index % 6 * cell, index // 6 * cell))
args.output.parent.mkdir(parents=True, exist_ok=True)
atlas.save(args.output, optimize=True)
