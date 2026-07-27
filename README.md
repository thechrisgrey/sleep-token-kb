# Sleep Token KB

Custom **iOS system keyboard** that shows Sleep Token ritual alphabet glyphs on the keys and inserts standard Latin letters into any text field. Also includes **Rune Pad**, a screen for composing vertical ritual text and exporting it as an image.

After you install the host app once, **Sleep Token KB** appears under:

**Settings → General → Keyboard → Keyboards → Add New Keyboard…**

## What's included

| Target | Role |
|--------|------|
| **SleepTokenKB** | Host app — enable guide, alphabet chart, Rune Pad, defaults |
| **SleepTokenKeyboard** | Custom Keyboard extension (`UIInputViewController`) |
| **SleepTokenKBTests** | Unit tests for the pure-logic layer (`Alphabet`, `LayoutMode`, `KeyboardPreferences`) |

| Feature | Notes |
|---------|--------|
| QWERTY layout | Muscle-memory typing; symbol faces on keys |
| A–Z Grid layout | Learning / ritual layout; toggle in the keyboard top bar |
| Key face cycle | One key cycles **Rune → Rune·A → Aa**: pure glyphs, glyphs with a small Latin letter beneath, plain ABC. Typed text is always English either way |
| Latin insert | Tapping a key inserts `a`–`z` / `A`–`Z` (usable everywhere) |
| Rune Pad | Compose vertical ritual text, read it back in Latin with live spell check, export as transparent PNG (light or dark ink), plaque PNG, share sheet, or plain Latin text |
| 123 page | Numbers and punctuation |
| Haptics | Toggle in host app |
| Full Access | **Off** by default (`RequestsOpenAccess = false`) |

Shared code lives in `Shared/` (alphabet map, layout prefs, glyph renderer, rune font loader).

## Open & run

1. Open `SleepTokenKB.xcodeproj` in Xcode.
2. Select the **SleepTokenKB** scheme (not the extension alone).
3. Signing & Capabilities:
   - Choose your **Team** on **all three** targets (`SleepTokenKB`, `SleepTokenKeyboard`, `SleepTokenKBTests`) — `project.yml` hardcodes `VMMDK66N53`; change it there (not in Xcode) if you use a different team, then re-run `xcodegen generate`.
   - Bundle IDs (change if you like, keep the `.SleepTokenKeyboard` suffix relationship):
     - App: `ai.altivum.SleepTokenFanKB`
     - Keyboard: `ai.altivum.SleepTokenFanKB.SleepTokenKeyboard`
   - **App Groups** (both app and keyboard targets): `group.ai.altivum.SleepTokenFanKB`
     Required so host-app prefs (default layout, key style, haptics, hints) sync into the keyboard. Declared in each target's `.entitlements` file — managed via `project.yml`'s `entitlements.properties`, so re-running `xcodegen generate` won't wipe it.
4. Run on a **physical iPhone** (recommended). Simulator support for keyboard extensions is limited (press Command-K if the software keyboard doesn't appear).
5. After install, enable the keyboard (next section).

Regenerate the project from `project.yml` if you edit it:

```bash
xcodegen generate
```

## Enable in Settings (required once)

iOS never auto-enables third-party keyboards. The host app includes these steps under **Enable the keyboard**:

1. Install **Sleep Token KB** (Run from Xcode).
2. **Settings → General → Keyboard → Keyboards**
3. **Add New Keyboard…**
4. Under **THIRD-PARTY KEYBOARDS**, choose **Sleep Token KB**
5. (Optional) Tap the keyboard name → **Allow Full Access** — **not needed** for this build
6. In any app's text field: long-press the **globe** key → **Sleep Token KB**

If it's missing from the list: delete the app, reinstall, force-quit Settings, try again.

## Using the keyboard

- **Bottom bar:** toggle **QWERTY** ↔ **A–Z Grid**; cycle the key face **Rune → Rune·A → Aa** (pure glyphs / glyphs with Latin hints / plain ABC); next-keyboard globe key
- **Keys:** Sleep Token glyphs (real traced art, with a geometric fallback if an asset is ever missing) or plain letters, depending on key face
- **Shift:** uppercase; double-tap for caps-lock style sticky shift
- **123 / ABC:** numbers and punctuation
- Typed text is **always** plain English — the key face is cosmetic only

## Rune Pad

Open **Rune Pad** from the host app to compose vertical ritual text: each space starts a new column and long text auto-shrinks to fit. A **READS** strip translates the runes back to Latin as you type, with live spell check (words missing from the dictionary are underlined). The **Export** menu offers:

- **Copy image · for dark backgrounds** — transparent PNG, light ink
- **Copy image · for light backgrounds** — transparent PNG, dark ink
- **Copy image · on plaque** — obsidian card PNG, legible on any background
- **Share as image** — system share sheet (Messages, Save to Files, AirDrop, Photos…)
- **Copy as Latin text** — the plain-English reading, for spell checking or search

## Replacing/updating glyph art

Real traced art is already imported for all 26 letters. To update it:

1. Edit the source SVGs in `stkb-runes-svg/`.
2. Re-run the PDF import loop and the font rebuild — see `Assets/Symbols/README.md` for both commands.

## Architecture

```
Host app (SleepTokenKB)
  └── embeds → Keyboard extension (SleepTokenKeyboard)
                  └── KeyboardViewController : UIInputViewController
                        └── SwiftUI KeyboardRootView
                              ├── LetterPage (QWERTY | Grid; rune art | ABC)
                              └── SymbolsPage (123)
```

Insert path:

```swift
textDocumentProxy.insertText("a")  // always Latin
```

`Info.plist` for the extension declares:

```
NSExtensionPointIdentifier = com.apple.keyboard-service
NSExtensionPrincipalClass  = $(PRODUCT_MODULE_NAME).KeyboardViewController
RequestsOpenAccess         = false
```

That is what registers it with the system keyboard list. Both `Info.plist` files (and both `.entitlements` files) are generated by `xcodegen` from `project.yml` — edit `project.yml`, not the plist/entitlements XML directly, since `xcodegen generate` overwrites them from there.

## Tests

`SleepTokenKBTests` covers the pure-logic layer: PUA rune-character round-tripping, `LayoutMode`/`KeyFaceStyle` cycling, and `KeyboardPreferences` defaults. Run via the `SleepTokenKB` scheme's Test action in Xcode.

## Legal

Unofficial fan project. Sleep Token names and iconography are almost certainly protected IP. Fine for personal/TestFlight use; public App Store distribution may require rights clearance and clear "not affiliated" labeling.

## Requirements

- Xcode 15+ (built against current iOS SDK)
- iOS 26.5+ deployment target
- Apple Developer team (free or paid) for device install
- Python 3 + the packages in `requirements.txt` (only needed if regenerating `SleepTokenRunes.ttf` from the source SVGs — see `Assets/Symbols/README.md`)
