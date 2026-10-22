# Rage Cat UI font

`ragecat-ui-subset.otf` is a small, renamed subset of Noto Sans CJK SC Regular
(from the installed Debian fonts-noto-cjk package), licensed under the adjacent
SIL Open Font License. Upstream: https://github.com/notofonts/noto-cjk

Includes Latin UI characters, punctuation, and the Chinese skill/passive labels.
Bundling avoids dependence on CJK fonts installed on a player's machine.
The project default font also applies to the practice panel's local theme.
When adding Chinese UI text, extend this subset and its glyph-coverage test.

Rebuild with fontTools subset, source collection face 2, Unicode ranges
U+0020-024F and U+2000-206F, plus `爆燃箭闪电寒冰暗影火雷附魔灼伤感冻引力冻结`.
Rename family/full/PostScript names to Rage Cat UI Subset after subsetting.
