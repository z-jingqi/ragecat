#!/usr/bin/env python3
"""Rebuild the portable licensed UI subset from the installed Noto CJK SC face.
Requires fontTools; no network/downloads. Pass an alternative licensed source via --source.
"""
import argparse
import ast
from pathlib import Path
from fontTools.ttLib import TTFont
from fontTools import subset
ROOT = Path(__file__).resolve().parents[1]
def characters():
    result = set(chr(i) for i in range(0x20, 0x250))
    result.update(chr(i) for i in range(0x2000, 0x2070))
    result.update('简体中文→×爆燃箭闪电寒冰暗影火雷附魔灼伤感冻引力冻结')
    for path in sorted((ROOT / 'resources/localization').glob('*.po')):
        for line in path.read_text().splitlines():
            if line.startswith('msgstr '):
                result.update(ast.literal_eval(line[7:]))
    return result - {'\n', '\r', '\t'}
def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source', default='/usr/share/fonts/opentype/noto/NotoSansCJK-Regular.ttc')
    parser.add_argument('--face', type=int, default=2)
    args = parser.parse_args()
    font = TTFont(args.source, fontNumber=args.face, recalcTimestamp=False)
    options = subset.Options()
    options.name_IDs = ['*']
    options.name_legacy = True
    options.name_languages = ['*']
    worker = subset.Subsetter(options=options)
    worker.populate(text=''.join(sorted(characters())))
    worker.subset(font)
    for record in font['name'].names:
        if record.nameID in (1, 4, 6, 16):
            name = 'RageCatUISubset' if record.nameID == 6 else 'Rage Cat UI Subset'
            record.string = name.encode(record.getEncoding())
    output = ROOT / 'resources/fonts/ragecat-ui-subset.otf'
    font.save(output)
    cmap = font.getBestCmap()
    missing = [char for char in characters() if ord(char) not in cmap]
    # Some Unicode Latin range slots are deliberately unassigned. Verify actual copy instead.
    for path in (ROOT / 'resources/localization').glob('*.po'):
        for line in path.read_text().splitlines():
            if line.startswith('msgstr '):
                assert all(ord(c) in cmap for c in ast.literal_eval(line[7:]) if not c.isspace()), path
    print(f'{output.name}: {output.stat().st_size} bytes, {len(cmap)} mapped glyphs')
if __name__ == '__main__': main()
