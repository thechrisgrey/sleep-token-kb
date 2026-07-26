# Sleep Token KB

Custom **iOS system keyboard** that shows Sleep Token ritual alphabet glyphs on the keys and inserts standard Latin letters into any text field.

After you install the host app once, **Sleep Token KB** appears under:

**Settings → General → Keyboard → Keyboards → Add New Keyboard…**

## What’s included

| Target | Role |
|--------|------|
| **SleepTokenKB** | Host app — enable guide, alphabet chart, default prefs |
| **SleepTokenKeyboard** | Custom Keyboard extension (`UIInputViewController`) |

| Feature | Notes |
|---------|--------|
| QWERTY layout | Muscle-memory typing; symbol faces on keys |
| A–Z Grid layout | Learning / ritual layout; toggle in the keyboard top bar |
| Latin insert | Tapping a key inserts `a`–`z` / `A`–`Z` (usable everywhere) |
| 123 page | Numbers and punctuation |
| Latin hints | Optional small letter under each glyph |
| Haptics | Toggle in host app |
| Full Access | **Off** by default (`RequestsOpenAccess = false`) |

Shared code lives in `Shared/` (alphabet map, layout prefs, glyph renderer).

## Open & run

1. Open `SleepTokenKB.xcodeproj` in Xcode.
2. Select the **SleepTokenKB** scheme (not the extension alone).
3. Signing & Capabilities:
   - Choose your **Team** on **both** targets (`SleepTokenKB` and `SleepTokenKeyboard`).
   - Bundle IDs (change if you like, keep the `.keyboard` suffix relationship):
     - App: `com.altivum.SleepTokenKB`
     - Keyboard: `com.altivum.SleepTokenKB.keyboard`
   - **App Groups** (both targets): `group.com.altivum.SleepTokenKB`  
     Required so host-app prefs (default layout, haptics, hints) sync into the keyboard. Without it, the keyboard still works; prefs set *inside* the keyboard persist only in the extension process.
4. Run on a **physical iPhone** (recommended). Simulator support for keyboard extensions is limited.
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
6. In any app’s text field: long-press the **globe** key → **Sleep Token KB**

If it’s missing from the list: delete the app, reinstall, force-quit Settings, try again.

## Using the keyboard

- **Top bar:** toggle **QWERTY** ↔ **A–Z Grid**; toggle Latin letter hints
- **Keys:** Sleep Token glyphs (geometric stand-ins until you add PDFs)
- **Shift:** uppercase; double-tap for caps-lock style sticky shift
- **123 / ABC:** numbers and punctuation
- **Globe:** next system keyboard

## Replacing glyphs with real art

Geometric approximations are built-in so you can type immediately. For production art:

1. Trace `Assets/Symbols/sleep-token-alphabet-reference.png` into monochrome PDFs.
2. Name them `symbol_a.pdf` … `symbol_z.pdf`.
3. Add each to **both** asset catalogs (or a shared catalog):
   - Render As: **Template Image**
   - Preserve Vector Data: **Yes**
4. `SymbolGlyphView` prefers catalog images over geometry when present.

See `Assets/Symbols/README.md`.

## Architecture

```
Host app (SleepTokenKB)
  └── embeds → Keyboard extension (SleepTokenKeyboard)
                  └── KeyboardViewController : UIInputViewController
                        └── SwiftUI KeyboardRootView
                              ├── LetterPage (QWERTY | Grid)
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

That is what registers it with the system keyboard list.

## Legal

Unofficial fan project. Sleep Token names and iconography are almost certainly protected IP. Fine for personal/TestFlight use; public App Store distribution may require rights clearance and clear “not affiliated” labeling.

## Requirements

- Xcode 15+ (built against current iOS SDK)
- iOS 17.0+ deployment target
- Apple Developer team (free or paid) for device install
