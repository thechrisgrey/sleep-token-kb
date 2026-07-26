# Symbol assets

Source SVGs live in `../../stkb-runes-svg/` (`symbol_a.svg` … `symbol_z.svg`).

They are converted to PDF and installed in:

- `SleepTokenFanKB/SleepTokenKeyboard/Assets.xcassets/symbol_*.imageset` (keyboard)
- `SleepTokenFanKB/SleepTokenFanKB/Assets.xcassets/symbol_*.imageset` (host chart)

| Asset name | Letter |
|------------|--------|
| `symbol_a` … `symbol_z` | A–Z |

Each imageset uses:
- **Template Image** rendering
- **Preserve Vector Data**

`SymbolGlyphView` loads `symbol_x` from the asset catalog; if missing, it falls back to geometric drawings.

To re-import after editing SVGs:

```bash
# from sleep-token-kb/
for l in a b c d e f g h i j k l m n o p q r s t u v w x y z; do
  rsvg-convert -f pdf -o "Assets/Symbols/pdf/symbol_${l}.pdf" "stkb-runes-svg/symbol_${l}.svg"
  cp "Assets/Symbols/pdf/symbol_${l}.pdf" \
    "SleepTokenFanKB/SleepTokenKeyboard/Assets.xcassets/symbol_${l}.imageset/"
  cp "Assets/Symbols/pdf/symbol_${l}.pdf" \
    "SleepTokenFanKB/SleepTokenFanKB/Assets.xcassets/symbol_${l}.imageset/"
done
```
