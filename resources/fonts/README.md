# Rage Cat UI font

`ragecat-ui-subset.otf` is a renamed subset of Noto Sans CJK SC Regular, from the installed Debian `fonts-noto-cjk` package, licensed under the adjacent SIL Open Font License. Upstream: https://github.com/notofonts/noto-cjk

The subset includes every displayed character in both localization PO catalogs, language endonyms, Latin UI characters and punctuation. It is approximately 198 KiB, rather than shipping the full CJK collection. Tests disable system-font fallback and check every catalog glyph.

Rebuild locally with `python3 tools/rebuild_ui_font.py`. Requires fontTools (validated with 4.61.1), no download. The default licensed source is `/usr/share/fonts/opentype/noto/NotoSansCJK-Regular.ttc`, SC collection face 2; override with `--source` and `--face` if needed. Source SHA-256: `b76b0433203017ca80401b2ee0dd69350349871c4b19d504c34dbdd80541690a`.

The script collects catalog characters deterministically, includes U+0020–024F and U+2000–206F, preserves license metadata, and renames family/full/PostScript names to Rage Cat UI Subset. Rebuild after changing either catalog, then run the full localization test. The source timestamp is retained for reproducibility.
