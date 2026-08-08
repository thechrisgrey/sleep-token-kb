<div align="center">

# Sleep Token KB

**A custom iOS system keyboard that puts the ritual alphabet on your keys — and a composer that writes real vertical runes.**

[![Platform](https://img.shields.io/badge/platform-iOS%2026.5%2B-C8A968?style=for-the-badge&logo=apple&logoColor=white&labelColor=0E0D0F)](https://developer.apple.com/ios/)
[![Swift](https://img.shields.io/badge/Swift-5.0-DE9BA9?style=for-the-badge&logo=swift&logoColor=white&labelColor=0E0D0F)](https://swift.org)
[![SwiftUI](https://img.shields.io/badge/SwiftUI-native-C8A968?style=for-the-badge&logo=swift&logoColor=white&labelColor=0E0D0F)](https://developer.apple.com/xcode/swiftui/)
[![Tests](https://img.shields.io/badge/tests-252%20passing-4F7A5C?style=for-the-badge&logo=checkmarx&logoColor=white&labelColor=0E0D0F)](#testing)
[![License](https://img.shields.io/badge/license-MIT-C8A968?style=for-the-badge&labelColor=0E0D0F)](LICENSE)

[![Targets](https://img.shields.io/badge/targets-3-DE9BA9?style=flat-square&labelColor=1A1820)](#project-structure)
[![Glyphs](https://img.shields.io/badge/glyphs-26-DE9BA9?style=flat-square&labelColor=1A1820)](#the-ritual-alphabet)
[![Themes](https://img.shields.io/badge/themes-2-DE9BA9?style=flat-square&labelColor=1A1820)](#two-themes)
[![Key faces](https://img.shields.io/badge/key%20faces-3-DE9BA9?style=flat-square&labelColor=1A1820)](#the-keyboard)
[![Export formats](https://img.shields.io/badge/export%20formats-5-DE9BA9?style=flat-square&labelColor=1A1820)](#rune-pad)
[![Full Access](https://img.shields.io/badge/Full%20Access-optional%2C%20haptics%20only-4F7A5C?style=flat-square&labelColor=1A1820)](#privacy--full-access)
[![Build](https://img.shields.io/badge/build-xcodegen-C8A968?style=flat-square&labelColor=1A1820)](#getting-started)
[![Status](https://img.shields.io/badge/status-unofficial%20fan%20project-8A8580?style=flat-square&labelColor=1A1820)](#legal)

<br>

<img src="docs/og-image.png" width="880" alt="Sleep Token KB — the ritual alphabet, on every key">

</div>

---

## Contents

- [What this is](#what-this-is)
- [Features](#features)
- [The keyboard](#the-keyboard)
- [The host app](#the-host-app)
- [Rune Pad](#rune-pad)
- [The ritual alphabet](#the-ritual-alphabet)
- [Two themes](#two-themes)
- [Jerry](#jerry)
- [Architecture](#architecture)
- [How state flows](#how-state-flows)
- [Getting started](#getting-started)
- [Testing](#testing)
- [Releasing](#releasing)
- [Project structure](#project-structure)
- [Accessibility](#accessibility)
- [Privacy & Full Access](#privacy--full-access)
- [Regenerating the glyph assets](#regenerating-the-glyph-assets)
- [Social preview](#social-preview)
- [Legal](#legal)

---

## What this is

Two things that work together, wrapped in one app:

| | |
|---|---|
| **A system keyboard** | Ritual glyphs on the keycaps, but every keystroke inserts ordinary English. It works in Messages, Notes, Safari, anywhere — because the text you send is plain `a`–`z`. The runes are the *interface*, not the payload. |
| **Rune Pad** | When you want the runes themselves, compose them here: vertical columns of real glyphs, read back in Latin as you type, exported as transparent PNGs, a plaque image, or plain text. |

The split exists because iOS keyboards can only insert text, and rune text would arrive as tofu in every app that lacks the font. So the keyboard stays honest and universal, and Rune Pad carries the runes out as pictures.

---

## Features

| Feature | Notes |
|---------|-------|
| **QWERTY layout** | Muscle-memory typing with glyph keycaps |
| **A–Z grid layout** | The learning layout; every letter in alphabetical order |
| **Glide typing** | Slide a finger across the letters and lift; alternates wait in the suggestion bar. QWERTY only, toggleable, on by default |
| **Suggestion bar** | Spelling candidates over the keys as you type, with what you actually typed always kept; space commits the correction |
| **Three key faces** | `Rune`, `Rune·A`, `Aa` — pure glyphs, glyphs with a Latin hint beneath, or plain letters; pick one by long-pressing the emoji key |
| **Always-English insert** | Tapping any key inserts `a`–`z` / `A`–`Z`; the key face is cosmetic |
| **Shift & caps lock** | Tap for one letter, tap again for sticky caps lock, third tap releases |
| **123 page** | Digits and punctuation with its own backspace; once you have typed one, space brings the letters back |
| **Emoji page** | Nine categories behind a recents tab; recents persist the same way every other preference does |
| **Entrance hall** | The app opens as a welcome that routes — hero, a card that shows only until the keyboard is enabled, three doors |
| **Rune Pad** | Vertical composition, live Latin read-back, spell check, five export formats |
| **Two themes** | Ritual (obsidian and gold) or EIA (pink on black stone) |
| **Haptics** | Per-keystroke feedback, toggleable |
| **Jerry** | He is in the app. Ten times. [Find him](#jerry) |
| **Full Access** | **Optional, off by default.** Needed only for haptics. `RequestsOpenAccess = true` |

---

## The keyboard

<div align="center">
<img src="docs/screenshots/keyboard-safari.png" width="520" alt="The Sleep Token keyboard running inside Safari, showing rune keycaps with Latin hints">
<br>
<sub><i>Running inside Safari, in the Rune·A face — glyph above, Latin letter below</i></sub>
</div>

<br>

The bottom bar carries five keys: the `123`/`ABC` page key, the globe (next keyboard, shown only when the system asks for it), the emoji key, space, and return. Layout and key face used to sit here as two more permanent keys, and now live behind a long press on the emoji key — which is what buys the space bar its stock width. Every switch key names its **destination**, never its current state: the page key names the alphabet it takes you to, and the emoji key turns into a `keyboard` glyph once the emoji page is open.

The text behaviour is stock throughout: shift arms itself from the field's own autocapitalization and the words already before the cursor, two quick spaces become a period, a held delete repeats and then accelerates, and the return key wears whatever the field asks for — `Search`, `Send`, `Go`, `Done`.

### Glide typing

Slide a finger across the letters and lift; the word lands. It rides QWERTY muscle memory, so QWERTY is the only layout that has it — nobody has a trained path through an alphabetical grid, and the A–Z layout stays tap-only. All three key faces keep it: a glide works without reading the caps.

The commit behaviour is stock. The best match inserts on lift, its alternates fill the suggestion bar over the keys, one backspace immediately after a glide removes the whole word instead of one letter, and consecutive glides space themselves. Shift and caps lock case a glided word exactly as they case a tapped one.

The engine is path-template matching — the SHARK² lineage every production glide keyboard descends from. The trace is resampled to sixty-four points and scored against each candidate word's ideal polyline through the key centres, blended with word frequency and weighted at the endpoints, where a finger is at its most deliberate. The dictionary is 50,042 words, bundled as `glide_lexicon.txt`, merged at run time with the host's supplementary lexicon (contact names, text replacements) and pruned by the neighbourhood of the first and last key, so scoring touches a fraction of it.

Two deliberate details:

- **The geometry is the rendered geometry.** `KeyCenters` re-derives every key centre from the same `KeyboardMetrics` arithmetic the page lays itself out with, and a parity test holds the two together. A decoder scoring against a keyboard that is not on screen is the one glide failure a user could never diagnose.
- **You always get what you drew.** If pruning finds nothing, it widens once; if it still finds nothing, the keyboard inserts the letters nearest the path. Never silence.

The toggle lives in the host app's keyboard defaults and is on by default. VoiceOver never sees the gesture — stock does not mix slide-to-type with touch typing either — and Reduce Motion draws the trail as a plain line.

### The three key faces

A long press on the emoji key opens a panel over the keyboard with two rows of choices — **Layout** (`QWERTY`, `A–Z`) and **Key face** — the current one filled in the active colour and marked selected to VoiceOver. Both also live in the host app's Settings; the panel is the in-keyboard shortcut for them.

| Cap | Keycaps |
|:---:|---|
| **Rune** | Pure glyph keycaps |
| **Rune·A** | Glyph with a small Latin letter beneath |
| **Aa** | Plain English keycaps |

The hinted face uses taller keys (44pt vs 40pt), so the container reserves the **tallest** face for the current page — switching mid-session can never clip a visible row.

### Shift

```mermaid
stateDiagram-v2
    direction LR
    off: off — shift
    shifted: shifted — shift.fill
    capsLocked: caps locked — capslock.fill

    [*] --> off
    off --> shifted: tap
    shifted --> capsLocked: tap
    capsLocked --> off: tap
    shifted --> off: after one letter
    capsLocked --> capsLocked: after one letter
```

Each state has its own SF Symbol and its own VoiceOver value, so caps lock is never mistaken for a one-shot shift.

---

## The host app

The app around the keyboard opens as an entrance hall, not a settings menu. The hero owns the first third of the screen, then one card that may or may not be there, then three doors.

**The threshold card** — "Enable the keyboard" — takes the first position while the keyboard is not enabled yet, and disappears entirely once it is. `EnableThreshold` reads the system's enabled-keyboards preference for the extension's bundle ID, and deliberately degrades toward showing: an unreadable or empty answer keeps the card, because showing setup to someone who has finished it is a shrug while hiding it from someone who has not is a dead end. For the case where the read lies, the foot of the enable guide carries a manual out: **Already enabled? Hide the setup card on the welcome screen.**

**The three doors** — Rune Pad, the alphabet, Settings — share one card form: glyph, title, one line, chevron.

Everything the front page used to spill now lives behind the Settings door: the theme picker, the keyboard defaults (layout, key look, haptics, glide typing), and the "Two ways to write" explainer, which is reference material rather than front-door reading. Settings also carries the one thing the welcome must never carry — see [Jerry](#jerry).

---

## Rune Pad

<div align="center">
<img src="docs/screenshots/runepad-arcadia.png" width="260" alt="Rune Pad in the EIA theme">
<img src="docs/screenshots/runepad-ritual.png" width="260" alt="Rune Pad in the Ritual theme">
<br>
<sub><i>The same composition in both themes — EIA (left) and Ritual (right)</i></sub>
</div>

<br>

Each space starts a new **column**; runes stack top to bottom. The canvas binary-searches the largest glyph size that still fits, so long messages shrink instead of overflowing. The letter pad is anchored to the bottom like a real keyboard, and the canvas takes every remaining point of height.

### Live Latin read-back

A `READS` strip translates the composed runes back to Latin on every keystroke and spell-checks each finished word with `UITextChecker`. Words outside the dictionary are underlined in amber.

Two deliberate details:

- **Proper nouns pass.** A word is accepted if either its lowercase *or* capitalized form is known — so `EUCLID` and `ARCADIA` are not flagged as mistakes.
- **The word you're still typing is left alone.** Only completed columns are judged, so nothing flickers amber mid-word.

### Export

```mermaid
flowchart LR
    A["Composed runes"] --> B["CanvasMetrics.forExport"]
    B --> C["ImageRenderer at display scale"]
    C --> D{"Format"}
    D --> E["Transparent PNG, light ink"]
    D --> F["Transparent PNG, dark ink"]
    D --> G["Plaque PNG, self-backed"]
    E --> H["Pasteboard: public.png"]
    F --> H
    G --> H
    G --> I["Share sheet: sleep-token-runes.png"]
    A --> J["Latin text"] --> K["Pasteboard: plain string"]
```

| Format | Use it for |
|--------|-----------|
| **Copy image · for dark backgrounds** | Transparent PNG, light ink — Messages dark mode, dark Stories |
| **Copy image · for light backgrounds** | Transparent PNG, dark ink — Notes, light chats, documents |
| **Copy image · on plaque** | Obsidian card that brings its own background; legible anywhere |
| **Share as image** | System share sheet — AirDrop, Photos, Save to Files |
| **Copy as Latin text** | The plain-English reading, for search or spell check elsewhere |

Copies write an explicit `public.png` pasteboard item so alpha survives into apps that would otherwise flatten it to JPEG.

---

## The ritual alphabet

Twenty-six glyphs, one per letter, mapped into the Unicode **Private Use Area** at `U+E900`–`U+E919`. The keyboard draws them from vector assets; Rune Pad can also render them from the bundled `SleepTokenRunes.ttf`.

<div align="center">
<img src="docs/screenshots/alphabet-arcadia.png" width="260" alt="Alphabet chart in EIA">
<img src="docs/screenshots/alphabet-ritual.png" width="260" alt="Alphabet chart in Ritual">
</div>

| Letter | Codepoint | Glyph construction | | Letter | Codepoint | Glyph construction |
|:---:|:---:|---|---|:---:|:---:|---|
| **A** | `U+E900` | Circle with center dot and X base | | **N** | `U+E90D` | V with X and apex dot |
| **B** | `U+E901` | Diamond with horizontal midline | | **O** | `U+E90E` | Double vertical arches |
| **C** | `U+E902` | Diamond, bottom half filled | | **P** | `U+E90F` | Triple vertical arches |
| **D** | `U+E903` | Diamond, top half filled | | **Q** | `U+E910` | Open square with center dot |
| **E** | `U+E904` | Horizontal bar with inverted chevron | | **R** | `U+E911` | Closed square with center dot |
| **F** | `U+E905` | Diamond, left half filled | | **S** | `U+E912` | Diamond, bottom filled, X on top |
| **G** | `U+E906` | Diamond with center dot | | **T** | `U+E913` | Diamond, top filled, X below |
| **H** | `U+E907` | Diamond with X and center dot | | **U** | `U+E914` | Concentric circles with center |
| **I** | `U+E908` | Left chevron with center dot | | **V** | `U+E915` | Circle with center and X above |
| **J** | `U+E909` | Right arrow with leading dot | | **W** | `U+E916` | Open diamond |
| **K** | `U+E90A` | Right arrow with X and leading dot | | **X** | `U+E917` | Horizontal bar |
| **L** | `U+E90B` | X with lower-right arm and trailing dot | | **Y** | `U+E918` | Diamond, right half filled |
| **M** | `U+E90C` | Peak with X and base center dot | | **Z** | `U+E919` | Horizontal bar with Y below |

Every glyph has a hand-coded geometric fallback drawn with `Canvas`, so a missing asset degrades to a readable key instead of a blank one.

---

## Two themes

The host app wears one of two aesthetics. Switching is purely cosmetic — no screen, control, or behaviour changes. The keyboard extension is deliberately excluded: it lives inside other apps and mirrors the system keyboard in both light and dark.

<div align="center">

<img src="docs/screenshots/home-ritual.png" width="260" alt="Home in the Ritual theme">
<img src="docs/screenshots/home-arcadia.png" width="260" alt="Home in the EIA theme">

<sub><i>Ritual (left) and EIA (right)</i></sub>

</div>

| | **Ritual** | **EIA** |
|---|---|---|
| Field | Obsidian, near-black | Black stone with a breath of green |
| Cards | Neutral raised surface | Deep arcadian green — the flag |
| Accent | Antique gold | Dusty rose |
| Ink | Bone | Champagne |
| Ornament | The word `worship` in runes | Jerry, the black flamingo |
| Atmosphere | A single candlelit bloom | Two blooms and drifting pink petals |

Choosing **EIA** plays a one-time ceremony: a black curtain rises, petals begin to fall, the `SLEEP TOKEN` wordmark breathes in from the dark in champagne serif — letterspacing settling, blur burning off — then dissolves into the re-themed app. The theme flip happens *behind* the opaque curtain, so the recolour is never seen raw. Reduce Motion gets a clean crossfade instead.

---

## Jerry

> [!NOTE]
> Spoilers below. If you'd rather find him yourself, skip this section.

<details>
<summary><b>What is the Jerry hunt?</b></summary>

<br>

Jerry — black body, white beak, pink legs — is hidden **ten times** across the host app at about 13% opacity. He is drawn entirely in code; no album artwork ships in this repository.

Each find pops a rose `N of 10` counter, permanently brightens that Jerry so you can track progress, persists across relaunch, and announces itself to VoiceOver.

Settings keeps a running tally once the first one is found — the count written out, "Four of ten", serif, nothing tappable. It names no screen and points at no corner, and it does not exist at all before that first find, so nobody learns from the UI that there is a hunt. At ten it offers the reward again, so Damocles stops being a missable one-time event.

Find all ten and the app plays a ceremony — petal storm, Jerry at full height, `DAMOCLES` in champagne serif — then opens the song on Apple Music.

**The song is linked, never bundled.** The audio is not ours to ship.

</details>

<details>
<summary><b>Where are they?</b> (full spoilers)</summary>

<br>

| # | Screen | Where |
|---|--------|-------|
| 1 | Home | Perched at the end of the `SLEEP TOKEN` rune wordmark |
| 2 | Settings | Corner of the "Two ways to write" card |
| 3 | Settings | Corner of the Appearance card |
| 4 | Home | Beside the footer |
| 5 | Enable keyboard | Corner of the Setup card |
| 6 | Enable keyboard | Corner of the Troubleshooting card |
| 7 | Alphabet | End of the intro line |
| 8 | Alphabet | Below the grid — a twenty-seventh resident |
| 9 | Rune Pad | Wading in the canvas shallows |
| 10 | Rune Pad | Roosting in the navigation bar |

</details>

---

## Architecture

```mermaid
graph TD
    subgraph Host["Host app · SleepTokenKB"]
        CV["ContentView — the welcome: hero, threshold, doors"]
        SV["SettingsView — appearance, keyboard defaults, the tally"]
        ET["EnableThreshold — does the threshold card show"]
        JT["JerryTally — the spoiler-free count"]
        RP["RunePadView — compose and translate"]
        RC["RuneCanvas — fit math and renderer"]
        RE["RuneExport — styles, share sheet"]
        AC["AlphabetChartView"]
        EK["EnableKeyboardView"]
        TH["Theme + ThemeStore — palette, petals, flamingo"]
        JH["JerryHunt — the ten"]
    end

    subgraph Shared["Shared"]
        AL["Alphabet — letters, PUA mapping, translation"]
        LM["LayoutMode — layouts, key faces, preferences"]
        KM["KeyboardMetrics — one source of keyboard geometry"]
        KC["KeyCenters — where every QWERTY key sits"]
        GD["GlideLexicon + GlideDecoder — 50k words, path templates"]
        GS["GlideSession + GlideCommit — trace capture, commit rules"]
        PS["PageAfterSpace — where space leaves the keyboard"]
        SS["ShiftState"]
        SG["SymbolGlyphView — asset plus fallback"]
        RF["RuneFont"]
    end

    subgraph Ext["Extension · SleepTokenKeyboard"]
        KVC["KeyboardViewController — UIInputViewController"]
        KRV["KeyboardRootView — pages, chrome, keys"]
        KP["KeyPalette"]
    end

    Host -->|embeds| Ext
    CV --> SV
    CV --> RP --> RC & RE
    CV --> AC & EK
    CV & SV --> TH & JH
    CV --> ET
    SV --> JT
    RP --> AL
    AC --> SG
    KVC --> KRV --> KP
    KRV --> SS & KM & LM & AL & SG
    KRV --> GS & GD & PS
    KRV --> KC --> KM
    KVC --> KM
    RC --> SG & RF
    LM -.->|App Group<br/>UserDefaults| KRV
```

**Design rules the code holds to:**

- `KeyboardMetrics` is the only place keyboard geometry lives. The SwiftUI content lays itself out from it *and* the view controller reserves height from it, so the container can never promise less space than the rows occupy.
- `KeyCenters` re-derives the QWERTY key centres from that same arithmetic rather than measuring the views, and a parity test locks the two files together — the decoder must score against the keyboard that is actually on screen.
- `CanvasMetrics` plays the same role for Rune Pad, and both the fit math and the renderer consume the same derived constants.
- The extension never links `RuneFont` — it renders asset art only, and a keyboard extension has a tight memory budget.

---

## How state flows

Host-app settings reach the extension through an App Group, with a local fallback for the case where the extension's sandbox denies the shared container.

```mermaid
sequenceDiagram
    participant U as User
    participant H as Host app
    participant G as App Group<br/>UserDefaults
    participant L as Local<br/>UserDefaults
    participant K as Keyboard extension

    U->>H: Change layout / key face / haptics
    H->>G: write (shared, authoritative)
    H->>L: write (survives relaunch)
    Note over K: next appearance
    K->>G: read
    alt App Group readable
        G-->>K: value wins
    else sandbox denies
        L-->>K: local fallback
    end
    U->>K: Pick layout / key face in the keyboard
    K->>L: write locally
    K->>G: write (no-op if denied)
    Note over H: returning to foreground
    H->>G: re-read, refresh the pickers
```

---

## Getting started

### Requirements

- macOS with **Xcode 15+**
- **iOS 26.5+** deployment target
- An Apple Developer team (free is fine) for device installs
- Optional: [`xcodegen`](https://github.com/yonaskolb/XcodeGen) if you edit `project.yml`
- Not needed to build, but expected before you commit: [`swiftlint`](https://github.com/realm/SwiftLint) — `.swiftlint.yml` sits at the repo root and the tree is clean against it

### Build and run

```bash
git clone https://github.com/thechrisgrey/sleep-token-kb.git
cd sleep-token-kb
open SleepTokenKB.xcodeproj
```

1. Select the **SleepTokenKB** scheme (not the extension alone).
2. Set your **Team** on all three targets. `project.yml` hardcodes one — change it *there*, not in Xcode, then re-run `xcodegen generate`.
3. Build and run. A physical iPhone is recommended; the Simulator supports keyboard extensions but you may need <kbd>⌘</kbd><kbd>K</kbd> to reveal the software keyboard.

> Both `Info.plist` files and both `.entitlements` files are **generated** from `project.yml`. Edit the YAML, not the XML — `xcodegen generate` overwrites them.

```bash
xcodegen generate   # after any project.yml change
```

### Identifiers

| Thing | Value |
|---|---|
| App bundle ID | `ai.altivum.SleepTokenKB` |
| Keyboard bundle ID | `ai.altivum.SleepTokenKB.SleepTokenKeyboard` |
| App Group | `group.ai.altivum.SleepTokenKB` |

The keyboard's ID must stay a suffix of the app's, and both targets need the App Group or host settings will never reach the keyboard.

### Enable the keyboard

iOS never auto-enables a third-party keyboard. Once, after installing:

1. Open **Settings** (the app has a button that deep-links straight there)
2. Tap **Keyboards** on the Sleep Token KB page — or go the long way: **General → Keyboard → Keyboards**
3. Turn on **Sleep Token KB**
4. In any text field, long-press the **globe** key and pick it

Missing from the list? Force-quit Settings, reinstall the app, try again. Extensions only appear after the host app has been installed at least once.

---

## Testing

```bash
./scripts/test.sh          # builds both targets and runs the suite
DEVICE="iPhone 16" ./scripts/test.sh
```

Two hundred and fifty-two tests across thirty-three suites cover the pure-logic layer — the parts where a silent regression would be invisible in the UI until a user hit it.

| Suite | Tests | What it pins |
|---|:---:|---|
| `SuggestionsTests` | 19 | The candidate bar and the correction on space: what is offered, what is replaced, what is left alone |
| `AutocapitalizationTests` | 19 | The host field's intent — sentence, word, all-caps, none — read as a pure rule over the text before the cursor |
| `KeyboardMetricsTests` | 12 | Reserved height always covers content, for every page × layout × face × size class |
| `SpellCheckerTests` | 11 | Which words count as finished, and which finished words get flagged |
| `AutoShiftTests` | 10 | The ratchet, the impossible cancel, and the caps-lock latch, as plain sequences |
| `PageAfterSpaceTests` | 10 | Space returns to the letters — armed by the first keystroke of a visit, not by arrival |
| `PeriodShortcutTests` | 10 | Double-space-for-period, and every guard that stops it firing on a pause |
| `RuneFontTests` | 10 | The real bundle: the face registers, and all 26 letters map to distinct glyphs |
| `AlphabetTests` | 9 | PUA round-tripping, Latin translation, pass-through of non-rune characters |
| `KeyboardPreferencesTests` | 9 | Defaults, round-trips, and migration of the legacy Latin-hints flag |
| `PageParityTests` | 9 | Every page is the same height, and delete stays inline instead of buying a row |
| `ReturnKeyTitleTests` | 9 | Every `UIReturnKeyType` has a cap and a spoken label — Search and Send included |
| `EmojiCatalogTests` | 8 | Stable category order, no emoji in two places, a recents list that behaves like stock |
| `GlideCommitTests` | 8 | Auto-space between consecutive glides, casing under shift, the whole-word backspace |
| `KeyRepeatTests` | 8 | The delete acceleration curve, as arithmetic rather than a live timer |

Those are the fifteen largest; eighteen more sit beside them in `SleepTokenKBTests/` — the shift machine, Rune Pad's fit math, the themes and their contrast floor, the Jerry hunt, and the welcome's two pure rules. Four of them are glide's: the geometry parity that keeps `KeyCenters` equal to the rendered page, the lexicon's pruning and merge, the tap-versus-glide session, and the decoder's accuracy floor. That floor is measured rather than asserted — ideal traces for the top two hundred words decode top-three, and jittered ones clear a ninety-percent hit rate. `pit`, `pot` and `put` share one straight line, so the decoder is only asked to surface all three among the alternates.

> Tests passing is not the same as shipped-and-working. Every feature here was also exercised by hand in the Simulator — the keyboard typing into Safari, the pasteboard inspected after each export, the ceremonies watched frame by frame.

---

## Releasing

Archiving, signing, validating, uploading and distributing are scripted. Signing authenticates with an App Store Connect API key rather than a checked-in certificate, so no `.p12` and no certificate password lives in this repo.

```bash
./scripts/release.sh preflight    # inspect the environment; builds nothing
./scripts/release.sh status       # ask App Store Connect where the app stands
./scripts/release.sh archive      # archive + export a signed .ipa (default)
./scripts/release.sh validate     # ...then run Apple's validation
./scripts/release.sh upload       # ...then upload to App Store Connect
./scripts/release.sh distribute   # put an already-uploaded build in front of testers
```

`archive`, `validate` and `upload` are cumulative, and the default never uploads. `preflight`, `status` and `distribute` build nothing — `distribute` is deliberately *not* cumulative and never archives, validates or uploads, because Apple rejects a second upload of a build number outright, so the build it works on is always one that is already there.

**Uploading is not distributing.** A build that has finished processing has reached Apple and reached nobody. `distribute` adds it to the beta group (`ASC_BETA_GROUP`, default `Fan Community`), submits it for Beta App Review, waits for `buildBetaDetail.externalBuildState` to read `IN_BETA_TESTING`, and expires every other live build only after that — never one second before. `DRY_RUN=1` prints every write and sends none; `NO_EXPIRE=1` leaves the superseded builds live; `BUILD_NUMBER` picks the build.

The same script runs in CI through the manually-dispatched [Release workflow](.github/workflows/release.yml), which offers `archive`, `validate` and `upload` — `archive` is its default too, so a mis-click is a no-op. `status` and `distribute` need only the API key, not Xcode, so they run from anywhere.

Build numbers come from the commit count, so they only ever increase and never collide between a laptop and a runner.

**[docs/RELEASE.md](docs/RELEASE.md)** is the full runbook: the one-time account setup that has no API and has to be done by hand, the review notes specific to shipping a custom keyboard, and a troubleshooting table.

---

## Project structure

```
sleep-token-kb/
├── SleepTokenKB/              # Host app
│   ├── SleepTokenKBApp.swift      # @main — the app entry point
│   ├── ContentView.swift          # The welcome: hero, threshold, three doors
│   ├── SettingsView.swift         # Appearance, keyboard defaults, the tally
│   ├── EnableThreshold.swift      # Does the threshold card show
│   ├── JerryTally.swift           # The spoiler-free count
│   ├── RunePadView.swift          # Composer + live translation
│   ├── RuneCanvas.swift           # Fit math + shared renderer
│   ├── RuneExport.swift           # Export styles, share sheet
│   ├── SpellChecker.swift         # Finished words, flagged words
│   ├── AlphabetChartView.swift    # 26-glyph reference
│   ├── EnableKeyboardView.swift   # Setup walkthrough
│   ├── Theme.swift                # Palette, petals, Jerry, cards
│   ├── ArcadiaRevealView.swift    # Theme-switch ceremony
│   ├── JerryHunt.swift            # The hunt + Damocles reward
│   └── SleepTokenRunes.ttf        # PUA-mapped rune font
├── SleepTokenKeyboard/        # Keyboard extension
│   ├── KeyboardViewController.swift
│   ├── KeyboardRootView.swift
│   ├── HostField.swift            # Live reads of the field being edited
│   └── KeyPalette.swift
├── Shared/                    # Linked into both targets
│   ├── Alphabet.swift
│   ├── LayoutMode.swift
│   ├── KeyboardMetrics.swift
│   ├── KeyCenters.swift           # QWERTY key centres, for glide
│   ├── GlideLexicon.swift
│   ├── GlideDecoder.swift
│   ├── GlideSession.swift
│   ├── GlideCommit.swift
│   ├── Suggestions.swift
│   ├── Autocapitalization.swift
│   ├── AutoShift.swift
│   ├── ShiftState.swift
│   ├── CapsLockTap.swift
│   ├── KeyRepeat.swift
│   ├── PeriodShortcut.swift
│   ├── PageAfterSpace.swift
│   ├── ReturnKeyTitle.swift
│   ├── SpaceTracker.swift
│   ├── EmojiCatalog.swift
│   ├── SymbolGlyphView.swift
│   ├── RuneFont.swift
│   └── Resources/
│       └── glide_lexicon.txt      # 50,042 words with frequencies
├── SleepTokenKBTests/         # 252 tests, 33 suites
├── scripts/
│   ├── test.sh                    # Build + test
│   ├── release.sh                 # Archive, validate, upload, distribute
│   ├── build_rune_font.py         # SVG → TTF pipeline
│   ├── build_glide_lexicon.py     # Word list → bundled lexicon
│   └── og/                        # Social cards: editorial, devices, glyph
├── docs/
│   ├── RELEASE.md                 # The release runbook
│   ├── feature-optimization.md    # Living refinement record
│   └── superpowers/specs/         # Design specs for recent features
├── .swiftlint.yml             # Lint rules
└── project.yml                # Source of truth (xcodegen)
```

---

## Accessibility

Not an afterthought — the hunt included.

- **Keyboard keys** carry `.isKeyboardKey`, so VoiceOver users can touch-type. Chrome keys deliberately don't, keeping confirm-before-acting.
- **Shift** announces its three states distinctly (`off`, `on for one letter`, `caps lock on`).
- **The rune canvas** is one element that speaks the words you composed, not a stream of letters and shape hints.
- **Flagged words** are announced, not just underlined — the spell-check signal reaches non-sighted users.
- **Both ceremonies** hide the covered UI from the accessibility tree while the curtain is up, and announce themselves.
- **Every Jerry** is a labeled element, so the hunt is fully playable with VoiceOver.
- **Reduce Motion** is honoured everywhere: petals freeze, key presses stop scaling, ceremonies become crossfades.
- **Dynamic Type** scales the alphabet chart, which drops to two columns at accessibility sizes rather than truncating.

---

## Privacy & Full Access

**The keyboard requests Full Access** (`RequestsOpenAccess = true`) for exactly one feature: key press haptics. iOS does not deliver haptic feedback from a keyboard extension unless Full Access has been granted, and there is no supported way around that.

- **It is opt-in and off by default.** Everything except haptics works without it: both layouts, all three key faces, both themes, Rune Pad, and the alphabet chart. The keyboard checks `hasFullAccess` before firing feedback rather than assuming.
- **Be precise about what this costs.** Earlier versions declared `RequestsOpenAccess = false`, which let this project claim the OS itself made exfiltration impossible. That enforced guarantee is gone. What replaces it is weaker but checkable: there is no networking code anywhere in either target — no `URLSession`, no sockets, no third-party SDK — and this repository is public, so you can verify it instead of trusting it.
- Nothing you type is stored, logged, buffered, or transmitted, with or without Full Access.
- Preferences are shared between the app and the keyboard through a local App Group container. Without Full Access the extension cannot reach it and falls back to its own `UserDefaults`, so settings changed in the app reach the keyboard only once Full Access is on.
- Rune Pad's exports go to the system pasteboard or the share sheet — both user-initiated, both local.

---

## Regenerating the glyph assets

Real traced art ships for all 26 letters. To change it:

1. Edit the source SVGs in `stkb-runes-svg/`.
2. Re-run the PDF import loop and the font build — both commands are in `Assets/Symbols/README.md`.

```bash
pip install -r requirements.txt
python3 scripts/build_rune_font.py
```

The script expands every stroked centerline into a filled outline (TrueType has no strokes), centers each glyph like a keycap icon, and maps it into the PUA block.

---

## Social preview

Three 1280×640 social cards ship with the repo, each generated from source by a script in
`scripts/og/` — no design tool, no external assets. They composite real app captures, real
rune glyphs set from `SleepTokenRunes.ttf`, and Jerry drawn from the same geometry the app
uses, over the EIA palette.

| Card | File | Direction |
|---|---|---|
| **Editorial hero** (in use) | [`docs/og-image.png`](docs/og-image.png) | Serif wordmark and rune row over two tilted devices; Jerry in the lower gap |
| Device showcase | [`docs/og-devices.png`](docs/og-devices.png) | Three fanned screens showing the gold/pink theme duality |
| Glyph-forward | [`docs/og-glyph.png`](docs/og-glyph.png) | One enormous inscription band of runes; maximum restraint |

```bash
python3 scripts/og/editorial.py   # or devices.py / glyph.py
```

To change which one GitHub serves in link unfurls: **Settings → General → Social preview →
Upload an image**. GitHub exposes no API for this, so it is the one step that must be done
in the web UI.

---

## Legal

**Unofficial fan project. Not affiliated with, endorsed by, or connected to Sleep Token or their rights holders.**

Sleep Token's names, iconography, and the ritual alphabet are almost certainly protected. This is fine for personal and TestFlight use; public App Store distribution would need rights clearance and clear "not affiliated" labeling.

No album artwork, photography, or audio is included in this repository. The Damocles reward opens the official Apple Music listing — it does not bundle, stream, or reproduce the recording.

The code is [MIT licensed](LICENSE).

---

<div align="center">

<br>

### Dedicated to the beautiful Erikka Rose - the ultimate Sleep Token fan.

<br>

<sub>Worship.</sub>

</div>
