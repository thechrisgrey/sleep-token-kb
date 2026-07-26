# Symbol assets

Source SVGs live in `../../stkb-runes-svg/` (`symbol_a.svg` … `symbol_z.svg`).
They are the single source of truth for both the keycap art (PDF, imported
into the asset catalogs) and the Rune Pad font (TTF).

## PDF glyph art (keycaps + alphabet chart)

Converted to PDF and installed in:

- `SleepTokenKeyboard/Assets.xcassets/symbol_*.imageset` (keyboard)
- `SleepTokenKB/Assets.xcassets/symbol_*.imageset` (host app / alphabet chart)

| Asset name | Letter |
|------------|--------|
| `symbol_a` … `symbol_z` | A–Z |

Each imageset uses:
- **Template Image** rendering
- **Preserve Vector Data**

`SymbolGlyphView` loads `symbol_x` from the asset catalog; if missing, it
falls back to geometric drawings.

To re-import after editing SVGs:

```bash
# from sleep-token-kb/
for l in a b c d e f g h i j k l m n o p q r s t u v w x y z; do
  rsvg-convert -f pdf -o "Assets/Symbols/pdf/symbol_${l}.pdf" "stkb-runes-svg/symbol_${l}.svg"
  cp "Assets/Symbols/pdf/symbol_${l}.pdf" "SleepTokenKeyboard/Assets.xcassets/symbol_${l}.imageset/"
  cp "Assets/Symbols/pdf/symbol_${l}.pdf" "SleepTokenKB/Assets.xcassets/symbol_${l}.imageset/"
done
```

## Rune font (Rune Pad + system-wide install)

`SleepTokenRunes.ttf` maps U+E900…U+E919 to the same 26 traced glyphs, built
directly from the SVGs by `scripts/build_rune_font.py` (fontTools +
svgelements + shapely: each stroked path/circle/ellipse is expanded to a
filled outline, since TrueType glyphs are filled regions, not centerlines).
This font is a secondary representation of the alphabet — today's primary
in-app rendering path (Rune Pad's on-screen canvas and its "Copy Image"
export) uses the PDF/imageset art above via `SymbolGlyphView`, not this font.
The font exists so the raw rune text is still readable if it's ever pasted
as plain text elsewhere, or if installed system-wide via
`RuneFont.registerPersistentWithMessage()`.

To rebuild after editing SVGs:

```bash
# from sleep-token-kb/
python3 -m venv .venv        # first time only
source .venv/bin/activate
pip install -r requirements.txt
python3 scripts/build_rune_font.py SleepTokenKB/SleepTokenRunes.ttf
cp SleepTokenKB/SleepTokenRunes.ttf SleepTokenKeyboard/SleepTokenRunes.ttf
```

Both copies must stay identical — each target (host app and keyboard
extension) needs its own copy of the font file in its own bundle, since
`RuneFont.swift`'s `CTFontManagerRegisterFontsForURL` registration is
per-process and reads from `Bundle.main`.
