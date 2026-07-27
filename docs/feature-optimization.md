# Feature Optimization

> This file tracks ways to REFINE features that already exist in this project.
> It is NOT a roadmap of new features to add — nothing here introduces new
> functionality. Every item makes an existing feature cleaner, faster, safer,
> more accessible, or otherwise better.
>
> Maintained by the `/optimize-features` command. Last full inventory: 2026-07-26

## Feature Inventory

### A. Host app — onboarding & reference

| # | Feature | What it does | Where it lives | Last reviewed |
|---|---------|--------------|----------------|---------------|
| 1 | Enable-keyboard walkthrough | Numbered 5-step guide plus troubleshooting that walks the user through registering the extension in iOS Settings; includes a deep link that opens Settings | `SleepTokenKB/EnableKeyboardView.swift` | 2026-07-26 |
| 2 | Alphabet chart | Scrollable 4-column reference grid of all 26 ritual glyphs with letter and prose description of each glyph's shape | `SleepTokenKB/AlphabetChartView.swift` | 2026-07-26 |
| 3 | Home hub & keyboard defaults | Serif hero with rune wordmark, destination cards, and settings controls (layout picker, 3-way key-face picker, haptics toggle, theme picker) that write shared prefs consumed by the extension | `SleepTokenKB/ContentView.swift` | 2026-07-26 |
| 18 | Theme system: Ritual & Even in Arcadia | Switchable app-wide aesthetic via `@Observable ThemeStore` (persisted): obsidian/gold vs pink-on-black with arcadian-green panels, drifting petal field, black-flamingo ornament, and a full-screen SLEEP TOKEN wordmark ceremony on switch (Reduce Motion gets a crossfade). Host app only; strictly cosmetic | `SleepTokenKB/Theme.swift`, `SleepTokenKB/ArcadiaRevealView.swift` | 2026-07-26 |
| 20 | Jerry hunt Easter egg | Ten near-invisible Jerrys (black body, white beak, pink legs) hidden across all four screens; each find pops a counter and persists. Finding all ten plays a one-time Damocles ceremony (petal storm, champagne wordmark) and opens the song on Apple Music. VoiceOver users get labels, announcements, and the full hunt | `SleepTokenKB/JerryHunt.swift`, `SleepTokenKB/Theme.swift` | 2026-07-26 |

### B. Rune Pad (host-app composer)

| # | Feature | What it does | Where it lives | Last reviewed |
|---|---------|--------------|----------------|---------------|
| 4 | Vertical rune composer | Type letters into vertical columns (space starts a new column); binary-searches the largest rune size that still fits the canvas so long text auto-shrinks. Letter pad is bottom-anchored like a real keyboard; the canvas absorbs all free height | `SleepTokenKB/RunePadView.swift` | 2026-07-26 |
| 5 | Multi-format export | Export menu: transparent PNG in light or dark ink, plaque PNG (self-backed, legible anywhere), system share sheet with a named PNG file, and plain-Latin-text copy — all rendered off-screen at export resolution | `SleepTokenKB/RunePadView.swift` | 2026-07-26 |
| 19 | Latin read-back with live spell check | READS strip translates the composed PUA runes back to Latin per keystroke; each word is checked with `UITextChecker` and unknown words are underlined in amber | `SleepTokenKB/RunePadView.swift`, `Shared/Alphabet.swift` | 2026-07-26 |

### C. Custom keyboard extension

| # | Feature | What it does | Where it lives | Last reviewed |
|---|---------|--------------|----------------|---------------|
| 6 | Letter input with QWERTY / A–Z grid layouts | The core typing surface; two selectable key arrangements that always insert plain Latin text via `UITextDocumentProxy` | `SleepTokenKeyboard/KeyboardRootView.swift`, `Shared/Alphabet.swift` | 2026-07-26 |
| 7 | Key face cycle (Rune / Rune·A / Aa) | One chrome key cycles three keycap faces: pure glyphs, glyphs with a small Latin hint beneath, plain ABC — with legacy hints-bool migration on read | `SleepTokenKeyboard/KeyboardRootView.swift`, `Shared/LayoutMode.swift` | 2026-07-26 |
| 8 | Shift and caps lock | `ShiftState` enum: single tap shifts one letter, second tap engages sticky caps lock, third releases; distinct SF Symbols and VoiceOver values per state | `Shared/ShiftState.swift`, `SleepTokenKeyboard/KeyboardRootView.swift` | 2026-07-26 |
| 9 | Numbers and punctuation page | A 30-key `123` page of digits and punctuation with its own backspace | `SleepTokenKeyboard/KeyboardRootView.swift` | 2026-07-26 |
| 10 | Keyboard chrome and adaptive height | Globe/space/return/layout/style bar, plus per-orientation and per-mode keyboard height driven through an explicit height constraint | `SleepTokenKeyboard/KeyboardViewController.swift`, `SleepTokenKeyboard/KeyboardRootView.swift` | 2026-07-26 |

### D. Shared core

| # | Feature | What it does | Where it lives | Last reviewed |
|---|---------|--------------|----------------|---------------|
| 11 | Ritual alphabet model and PUA rune mapping | `SleepTokenLetter` enum: Latin value, asset name, prose glyph description, and bidirectional mapping to Private Use Area codepoints U+E900–U+E919 | `Shared/Alphabet.swift` | 2026-07-26 |
| 12 | Glyph renderer with geometric fallback | Draws a letter from the asset catalog when present, otherwise falls back to a hand-coded Canvas approximation so the keyboard is never blank | `Shared/SymbolGlyphView.swift` | 2026-07-26 |
| 13 | Rune font loading and registration | Locates `SleepTokenRunes.ttf` in the bundle, registers it once per process, and optionally installs it system-wide via CoreText | `Shared/RuneFont.swift` | 2026-07-26 |
| 14 | Cross-process preference sync | App Group `UserDefaults` bridge so host-app settings reach the keyboard extension, with typed accessors and defaults | `Shared/LayoutMode.swift` | 2026-07-26 |

### E. Build, assets and ops

| # | Feature | What it does | Where it lives | Last reviewed |
|---|---------|--------------|----------------|---------------|
| 15 | xcodegen project generation | Single `project.yml` generates both targets, the test bundle, Info.plists, entitlements and the shared scheme | `project.yml` | 2026-07-26 |
| 16 | SVG to PDF/TTF asset pipeline | 26 source SVGs converted to template PDFs for the asset catalogs and expanded stroke-to-fill into a PUA-mapped TrueType font | `scripts/build_rune_font.py`, `Assets/Symbols/README.md`, `stkb-runes-svg/` | 2026-07-26 |
| 17 | Unit test suite | 49 pure-logic tests: rune round-tripping and Latin translation, layout/key-face cycling and pref migration, shift-state machine, keyboard metrics arithmetic, theme persistence — with save/restore isolation | `SleepTokenKBTests/`, `scripts/test.sh` | 2026-07-26 |

## Optimization Opportunities

_Run 2026-07-26 (host app, categories A & B — features 1, 2, 3, 4, 5, 18, 19): 7 read-only lens reviewers + 7 adversarial verifiers via workflow. 36 findings, 0 refuted, 8 impact ratings revised downward on verification. All 36 retained below with verified impact, ranked by impact within each feature. Unchecked = not yet implemented._

_All 32 refinements for features 6-10 below were implemented on 2026-07-26 (see `Implementation notes` at the end for what was adapted and why). Analysis run 2026-07-26 — keyboard extension core (features 6-10), 8 lenses. 63 raw findings, 3 refuted by adversarial verification, 56 retained, then merged across lenses into the 32 distinct refinements below (several lenses independently flagged the same lines). Ranked by impact, never by effort._

_Compile-verified 2026-07-26: `./scripts/test.sh` builds both targets against the iOS Simulator 26.5 SDK and runs 33 tests, all passing, with zero source warnings. Behaviour on a physical device is still unverified._

### 1. Enable-keyboard walkthrough

_Current state: Visually cohesive with the ritual-card language; the five-step structure reads clearly, the copy is honest about Full Access, and the troubleshooting card plus Settings deep link cover the real first-run friction._

- [x] **[UX]** Deep link lands on a screen the steps never describe — the gold button opens the app's own Settings page (which has a direct Keyboards list), but steps II–III only describe the manual General → Keyboard route, and step II's detail repeats its own title. Copy-only fix. Impact: High. Effort: Low. (`SleepTokenKB/EnableKeyboardView.swift:120-122`) — added 2026-07-26, completed 2026-07-26
- [x] **[Accessibility]** Step rows are fragmented for VoiceOver — numeral/title/detail are three separate elements, so users hear a bare "IV" with no sequence context; combine + label per the AlphabetChartView convention. Impact: Medium. Effort: Low. (`SleepTokenKB/EnableKeyboardView.swift:82-105`) — added 2026-07-26, completed 2026-07-26
- [x] **[Cleaner code]** Manually numbered steps subscript a fixed numeral array — five hand-maintained indices into `numerals`; a miscount traps at runtime. Model steps as data and derive numerals from the loop index. Impact: Low. Effort: Low. (`SleepTokenKB/EnableKeyboardView.swift:7`) — added 2026-07-26, completed 2026-07-26
- [x] **[Consistency]** Steps card is the app's only unlabeled ritual card group — troubleshooting and every ContentView group get a SectionLabel; the steps card does not. Impact: Low. Effort: Low. (`SleepTokenKB/EnableKeyboardView.swift:17-63`) — added 2026-07-26, completed 2026-07-26
- [ ] **[UX]** Simulator-only Command-K bullet ships to end users — wrap in `#if targetEnvironment(simulator)`. Impact: Low. Effort: Low. (`SleepTokenKB/EnableKeyboardView.swift:70`) — added 2026-07-26

### 2. Alphabet chart

_Current state: Tidy 70-line file, closely on-theme, glyph rendering statically cached, every card a combined accessibility element with an explicit label._

- [x] **[Accessibility]** VoiceOver reads each glyph description twice per card — the combined element inherits SymbolGlyphView's hint (the same description as the explicit label); hide the decorative glyph like RunePadView does. Impact: Medium. Effort: Low. (`SleepTokenKB/AlphabetChartView.swift:59-60`, `Shared/SymbolGlyphView.swift:43`) — added 2026-07-26, completed 2026-07-26
- [x] **[UX]** Descriptions truncate at large Dynamic Type in the fixed 3-column grid — `.caption2` + `lineLimit(3)` in a ~100pt column ellipsizes at xxxLarge and widely at accessibility sizes; drop the line limit and fall to 2 columns at accessibility sizes. Impact: Medium (downgraded from High — truncation starts later than filed). Effort: Low. (`SleepTokenKB/AlphabetChartView.swift:4,41-46`) — added 2026-07-26, completed 2026-07-26
- [x] **[Consistency]** GlyphCard hand-rolls the card chrome at radius 14 — exact duplicate of RitualCard's body except the app-standard 16pt radius; replace with `.ritualCard(padding: 0)`. Impact: Low. Effort: Low. (`SleepTokenKB/AlphabetChartView.swift:51-58`) — added 2026-07-26, completed 2026-07-26

### 3. Home hub & keyboard defaults

_Current state: Ceremony wiring is sound (pendingMode/guard sequencing, reduce-motion fallback), DefaultsRow unifies the card, persistence is robust and tested._

- [x] **[Resilience & tests]** Defaults card goes stale when the keyboard extension changes preferences — pickers seed once and re-read only on `.onAppear`, which does not fire on foregrounding; refresh all three controls on `scenePhase == .active`. Impact: Medium. Effort: Low. (`SleepTokenKB/ContentView.swift:265,279,212-217`) — added 2026-07-26, completed 2026-07-26
- [x] **[Accessibility]** Segmented pickers voice chrome-key abbreviations ("Rune·A", "Aa") — the model's full accessibility labels exist and the keyboard itself uses them; the home screen does not. Impact: Medium. Effort: Low. (`SleepTokenKB/ContentView.swift:271,290`, `Shared/LayoutMode.swift:25-30`) — added 2026-07-26, completed 2026-07-26
- [x] **[Consistency]** Three controls, three preference-sync patterns — LayoutPicker/KeyFacePicker duplicate a seed/onChange/onAppear dance while haptics uses a raw computed Binding; extract one preference-backed control helper. Impact: Low. Effort: Low. (`SleepTokenKB/ContentView.swift:264-308,212-217`) — added 2026-07-26, completed 2026-07-26
- [x] **[UI]** Top scrim is a fixed 110pt ramp regardless of the device's safe-area inset — on small-inset devices it dims resting content; derive height from the actual inset. Impact: Low. Effort: Low. (`SleepTokenKB/ContentView.swift:98-107`) — added 2026-07-26, completed 2026-07-26

### 4. Vertical rune composer

_Current state: Binary-search fit keeps the plaque in view, one shared columns view renders screen and export so they cannot drift visually, the empty state teaches the interaction, pad keys carry correct accessibility labels._

- [x] **[Resilience & tests]** Fit algorithm omits the trailing caret's height — `fits()` never counts the caret child + gap (~0.77 × runeSize) the screen appends to the last column, so tight fits overflow the plaque; CanvasMetrics has zero tests. Impact: Medium. Effort: Low. (`SleepTokenKB/RunePadView.swift:532-535,569-572`) — added 2026-07-26, completed 2026-07-26
- [x] **[Accessibility]** VoiceOver reads the canvas letter-by-letter with shape-description hints — collapse it to one element whose value is the latin words already computed. Impact: Medium (downgraded from High — the translation strip already speaks the words). Effort: Low. (`SleepTokenKB/RunePadView.swift:62-72`, `Shared/SymbolGlyphView.swift:42-43`) — added 2026-07-26, completed 2026-07-26
- [x] **[Cleaner code]** Canvas geometry constants duplicated between fit math and rendering view — `cell`, column width, chrome padding each derived twice; the caret bug is the drift this enables. Single-source them in CanvasMetrics (the KeyboardMetrics precedent). Impact: Medium. Effort: Low. (`SleepTokenKB/RunePadView.swift:526,551,527-530,575-576`) — added 2026-07-26, completed 2026-07-26
- [x] **[UI]** When even the 8pt minimum cannot fit, content draws past the plaque card — nothing clips the canvas; add `.clipShape` on the card shape so overflow degrades inside the plaque. Impact: Medium. Effort: Low. (`SleepTokenKB/RunePadView.swift:488,62-75`) — added 2026-07-26, completed 2026-07-26
- [x] **[UX]** Clear destroys the whole composition in one unconfirmed tap beside the Export menu — add `role: .destructive` + confirmationDialog. Impact: Medium. Effort: Low. (`SleepTokenKB/RunePadView.swift:37-38`) — added 2026-07-26, completed 2026-07-26
- [x] **[Architecture]** RunePadView.swift hosts three features across 620 lines and locks the pure fit math behind private scope — split canvas types and export types into their own files at internal access so tests can reach them. Impact: Medium. Effort: Medium. (`SleepTokenKB/RunePadView.swift:10,454,543`) — added 2026-07-26, completed 2026-07-26
- [x] **[UX]** Delete has no press-and-hold auto-repeat — one tap per rune to trim long text; add long-press repeat per platform convention. Impact: Low (downgraded from Medium). Effort: Medium. (`SleepTokenKB/RunePadView.swift:237-251`) — added 2026-07-26, completed 2026-07-26

### 5. Multi-format export

_Current state: Three deliberate image styles centralized on RuneExportStyle with per-destination status copy, export-resolution metrics, displayScale-aware rendering, failure status on every path; security posture fine as-is._

- [x] **[Resilience & tests]** Redundant `UIPasteboard.image` assignment clobbers the PNG-first pasteboard item — line 330 replaces the `setItems` payload written at 326, discarding the explicit `public.png` representation that is the point of the transparent styles; delete the line (the else branch remains the fallback). Impact: High. Effort: Low. (`SleepTokenKB/RunePadView.swift:326,330`) — added 2026-07-26, completed 2026-07-26
- [x] **[UX]** Status capsule never fades, never expires, and is silent to VoiceOver — no `withAnimation` despite the declared transition, no expiry, no announcement; route status through one helper that animates, auto-clears, and announces. Impact: Medium. Effort: Low. (`SleepTokenKB/RunePadView.swift:82,316,334`) — added 2026-07-26, completed 2026-07-26
- [x] **[Resilience & tests]** Share flow observes no completion — temp PNG lingers, success is never confirmed, write is non-atomic; wire `completionWithItemsHandler` to clean up and confirm. Impact: Low. Effort: Low. (`SleepTokenKB/RunePadView.swift:344-349,445`) — added 2026-07-26, completed 2026-07-26
- [ ] **[Performance]** Unexplained fixed 50 ms sleep in renderImage plus main-actor PNG encoding — everything feeding the renderer is synchronous; replace with a commented yield or delete, move `pngData()` off the main actor. Note 2026-07-26: the sleep was replaced with a commented `Task.yield()`; the PNG encode deliberately stays on the main actor (occasional exports, ImageRenderer is main-bound anyway). Impact: Low (downgraded from Medium). Effort: Low. (`SleepTokenKB/RunePadView.swift:403,325,340`) — added 2026-07-26
- [x] **[Cleaner code]** Export menu metadata split between the view and RuneExportStyle — titles/symbols hand-written in three Button blocks while the enum owns ink and copy; make the enum CaseIterable with menuTitle/systemImage. Impact: Low. Effort: Low. (`SleepTokenKB/RunePadView.swift:265-281,428`) — added 2026-07-26, completed 2026-07-26

### 6. Letter input with QWERTY / A-Z grid layouts

_Current state: The layout data is genuinely clean: KeyboardLayout.qwertyRows and gridRows are shared, public, static tables that each contain all 26 letters exactly once, and both layouts render through one LetterPage rather than being forked into two views. Case is resolved in exactly one place (insertLetter at :118-124), so the input path itself is small and correct._

- [x] **[Accessibility]** No key carries the .isKeyboardKey trait, so VoiceOver cannot touch-type on this keyboard — Every key in the extension is a plain SwiftUI Button carrying at most an .accessibilityLabel. Impact: High. Effort: Low. (`SleepTokenKeyboard/KeyboardRootView.swift:291-292`) — added 2026-07-26, completed 2026-07-26
- [x] **[UI]** Hardcoded 12pt home-row inset makes key width differ per row, and the error grows with screen width — Row widths are produced by dividing whatever space is left among the keys, and the QWERTY home row is nudged in by a flat 12pt that is not the half-key offset a QWERTY needs. Impact: Medium. Effort: Medium. (`SleepTokenKeyboard/KeyboardRootView.swift:198`) — added 2026-07-26, completed 2026-07-26
- [x] **[Performance & Memory + Resilience & Tests]** Every keystroke constructs two UserDefaults suites before the character is inserted — KeyboardPreferences.defaults is a computed property that builds a brand-new `UserDefaults(suiteName:)` on every access. Impact: Medium. Effort: Low. (`Shared/LayoutMode.swift:62-64`) — added 2026-07-26, completed 2026-07-26
- [x] **[Performance & Memory]** The haptic generator is re-allocated with every root view, so the prepare() warm-up is thrown away — `impact` is a stored property of the KeyboardRootView struct, so a new UIImpactFeedbackGenerator is constructed inside every KeyboardRootView(...) — once in installKeyboardUI and once per... Impact: Medium. Effort: Low. (`SleepTokenKeyboard/KeyboardRootView.swift:19`) — added 2026-07-26, completed 2026-07-26
- [x] **[UX]** Keypress acknowledgement fades in over 80ms, and the haptic meant to back it up may be inert without Full Access — The only per-keystroke feedback is KeyPressStyle, whose opacity and scale changes are wrapped in one `.easeOut(duration: 0.08)` animated on isPressed — applied to press AND release, so the... Impact: Medium. Effort: Low. (`SleepTokenKeyboard/KeyboardRootView.swift:364-370`) — added 2026-07-26, completed 2026-07-26
- [x] **[Resilience & Tests + Architecture]** The text document proxy is snapshotted into the view, while every other host interaction goes through a closure — KeyboardRootView stores `let proxy: UITextDocumentProxy` and calls insertText/deleteBackward on it from inside view code, while every other controller interaction in the same struct... Impact: Medium. Effort: Low. (`SleepTokenKeyboard/KeyboardRootView.swift:7-8`) — added 2026-07-26, completed 2026-07-26
- [x] **[Cleaner code]** Every preference is read in two places — the @State initialisers and onAppear — and neither is identifiable as authoritative — layoutMode, keyFaceStyle and showLatinHints are each read from KeyboardPreferences in their @State declarations and then read again and re-assigned in onAppear. Impact: Low. Effort: Low. (`SleepTokenKeyboard/KeyboardRootView.swift:12-13`) — added 2026-07-26, completed 2026-07-26
- [x] **[Cleaner code]** Four key structs re-implement the same keycap chassis; Shift and Backspace differ only in four literals — LetterKeyButton, ShiftKeyButton, BackspaceKeyButton and KeyChromeButton each independently build `RoundedRectangle(cornerRadius: 6, style: .continuous)` as a background and each... Impact: Low. Effort: Low. (`SleepTokenKeyboard/KeyboardRootView.swift:286`) — added 2026-07-26, completed 2026-07-26
- [x] **[Resilience & Tests]** Shift and backspace placement is hardcoded to row index 2 of the QWERTY rows — On the letter page the shift and backspace keys are attached to `index == 2` and the middle-row inset to `index == 1`. Impact: Low. Effort: Low. (`SleepTokenKeyboard/KeyboardRootView.swift:178`) — added 2026-07-26, completed 2026-07-26
- [x] **[Resilience & Tests]** Neither keyboard layout's rows are validated for completeness or uniqueness — KeyboardLayout.qwertyRows and gridRows are hand-written literals that must together contain all 26 SleepTokenLetter cases exactly once, or a letter becomes untypeable in that layout. Impact: Low. Effort: Low. (`Shared/Alphabet.swift:76-80`) — added 2026-07-26, completed 2026-07-26

### 7. Key face style (rune art <-> ABC keycaps) + optional Latin hints under glyphs

_Current state: The style model is well-factored: one KeyFaceStyle enum with a `next` cycle, a single LetterKeyButton switch that renders both faces, and correct composition with the hints preference — line 187 suppresses hints in ABC mode so the two features never contradict each other. SymbolGlyphView also degrades gracefully to a geometric fallback if an asset is ever missing._

- [x] **[UI + Accessibility]** Dark mode inverts the key hierarchy: letter keycaps render darker than the keyboard behind them — Letter keys fill with `.systemBackground` while the keyboard field is `.secondarySystemBackground`. Impact: High. Effort: Low. (`SleepTokenKeyboard/KeyboardRootView.swift:287`) — added 2026-07-26, completed 2026-07-26
- [x] **[Accessibility]** SymbolGlyphView's own label and hint nest inside LetterKeyButton's Button, so identical keys announce differently per style — SymbolGlyphView unconditionally attaches `.accessibilityLabel(Text(letter.upperLatin))` and `.accessibilityHint(Text(letter.glyphDescription))` to itself. Impact: Medium. Effort: Low. (`Shared/SymbolGlyphView.swift:29-30`) — added 2026-07-26, completed 2026-07-26
- [x] **[Accessibility]** Dynamic Type is honoured only by the three modifier SF Symbols, which are exactly the ones inside fixed-height frames — Every text element on a key face uses a hard-coded point size — the Latin hint is `size: 9`, the ABC keycap `max(17, keyHeight * 0.42)`, chrome and all 30 symbol keys 11/12/15. Impact: Medium. Effort: Medium. (`SleepTokenKeyboard/KeyboardRootView.swift:269`) — added 2026-07-26, completed 2026-07-26
- [x] **[Architecture + Resilience & Tests]** refreshRoot() cannot refresh the preference state it appears to refresh; prefs are mirrored in four places — refreshRoot() assigns a freshly built KeyboardRootView to hostingController.rootView, but SwiftUI keeps existing @State for a view of the same type at the same position, so the initializer... Impact: Medium. Effort: Medium. (`SleepTokenKeyboard/KeyboardViewController.swift:82`) — added 2026-07-26, completed 2026-07-26
- [x] **[Security & Privacy]** The extension writes to the App Group container, a write its no-open-access sandbox denies, and the `?? .standard` fallback masks it — The layout and key-style chrome buttons persist by writing to the App Group suite, landing on `defaults.set(...)` against `UserDefaults(suiteName: "group.ai.altivum.SleepTokenFanKB")`. Impact: Medium. Effort: Low. (`SleepTokenKeyboard/Info.plist:33-34`) — added 2026-07-26, completed 2026-07-26
- [x] **[Performance & Memory]** SymbolGlyphView probes the asset catalog with UIImage(named:) inside its body, 26 times per render — SymbolGlyphView.body decides between asset and fallback by calling `UIImage(named: letter.assetName)` and discarding the result — it is used only as a nil test — then resolves the same... Impact: Low. Effort: Low. (`Shared/SymbolGlyphView.swift:16`) — added 2026-07-26, completed 2026-07-26
- [x] **[Cleaner code]** GeometricSymbol is unreachable in the extension, documented as a placeholder for art that has shipped, and builds a dead diamond Path on every fill — The MARK and doc comment describe GeometricSymbol as a stand-in 'until PDF assets are dropped in' so the keyboard is usable 'without hand-traced art' — but all 26 symbol_*.imageset PDFs... Impact: Low. Effort: Low. (`Shared/SymbolGlyphView.swift:34`) — added 2026-07-26, completed 2026-07-26
- [x] **[Cleaner code]** LetterKeyButton passes an argument that is already the default and stacks three frames on one branch only — The rune branch passes `foreground: .primary` to SymbolGlyphView, which already defaults that parameter to .primary. Impact: Low. Effort: Low. (`Shared/SymbolGlyphView.swift:9`) — added 2026-07-26, completed 2026-07-26
- [x] **[UI]** Rune keycap content sits 2pt above optical centre while the ABC keycap is centred, and the hint is a fixed 9pt literal — The two key faces are laid out by different mechanisms and do not balance. Impact: Low. Effort: Low. (`SleepTokenKeyboard/KeyboardRootView.swift:263-265`) — added 2026-07-26, completed 2026-07-26

### 8. Shift and caps lock (tap = shift one letter, second tap = sticky caps lock)

_Current state: The three-state cycle is functionally correct — every transition was traced (off -> shift -> caps -> off) and the one-shot consumption at :121 correctly leaves caps lock sticky while clearing a single shift. Case resolution is centralised in insertLetter, so letter keys never need to know about shift at all._

- [x] **[Accessibility + UX]** The three-state shift machine is flattened to a Bool before it reaches the key, so caps lock is indistinguishable from one-shot shift — toggleShift maintains a genuine three-state machine, but LetterPage is handed the already-collapsed `isShifted || isCapsLock` and ShiftKeyButton only accepts `let isActive: Bool`. Impact: High. Effort: Low. (`SleepTokenKeyboard/KeyboardRootView.swift:35`) — added 2026-07-26, completed 2026-07-26
- [x] **[Cleaner code + Architecture + Resilience & Tests]** Three shift states are encoded in two overlapping Bools, re-derived at two call sites, and no test target can reach them — isShifted and isCapsLock together encode off/shift/caps, with caps lock stored as both-true, so the combination (isCapsLock true, isShifted false) is a state the code can never produce yet... Impact: Medium. Effort: Medium. (`SleepTokenKeyboard/KeyboardRootView.swift:14-15`) — added 2026-07-26, completed 2026-07-26
- [x] **[Performance & Memory]** A shift tap re-evaluates all 26 letter keys, because each key carries a freshly allocated closure — Letter keys do not display shift state at all — case is resolved at tap time inside insertLetter — but isShifted is a parameter of LetterPage, so toggling shift or caps lock re-runs... Impact: Medium. Effort: Low. (`SleepTokenKeyboard/KeyboardRootView.swift:189`) — added 2026-07-26, completed 2026-07-26

### 9. Numbers and punctuation page (the "123" page)

_Current state: The data itself is correct and tidy: three rows of ten, all 30 symbols distinct, so the `id: \.self` identity the ForEach relies on can never collide. The page also reuses the letter page's keyHeight/rowGap metrics and the same BackspaceKeyButton, so it stays in step with the rest of the keyboard for free._

- [x] **[UI + Cleaner code + Architecture]** Every key on the 123 page is built from KeyChromeButton, so it inherits function-key styling and chrome-sized type by accident — SymbolsPage renders all 30 digit and punctuation keys with KeyChromeButton, the component written for the bottom function bar. Impact: Medium. Effort: Medium. (`SleepTokenKeyboard/KeyboardRootView.swift:232`) — added 2026-07-26, completed 2026-07-26
- [x] **[Cleaner code + Architecture + Performance & Memory + Resilience & Tests]** The symbol table is a private instance literal in the view, rebuilt per construction and enumerated only to discard the index — SymbolsPage owns its 30 symbols as an instance `private let` with a literal default inside a private struct in the extension target — so the arrays are re-materialised every time a... Impact: Low. Effort: Low. (`SleepTokenKeyboard/KeyboardRootView.swift:215`) — added 2026-07-26, completed 2026-07-26

### 10. Keyboard chrome (globe/space/return/layout/style bar) and adaptive keyboard height

_Current state: The chrome plumbing is the right shape: the globe key correctly appears only when needsInputModeSwitchKey is true, the height constraint is installed at priority 999 so it never fights the system, rotation re-applies it via viewWillTransition, and an onNeedsHeightUpdate callback already exists as the view->controller channel. The mechanism is sound; what it computes is not._

- [x] **[UI + UX + Resilience & Tests + Architecture + Cleaner code]** Keyboard height is a hand-maintained table that under-allocates the shipped default: the "landscape" branch is taken in portrait, and the grid and 123 pages need a fourth row it never accounts for — preferredKeyboardHeight is six literal totals chosen from inputs the view does not use, while the real drivers (keyHeight 44/40, rowGap 6, bottomBarHeight 42, 8/4 padding, row counts) live... Impact: High. Effort: Medium. (`SleepTokenKeyboard/KeyboardViewController.swift:88`) — added 2026-07-26, completed 2026-07-26
- [x] **[UI + UX + Cleaner code]** Two adjacent chrome buttons both read "ABC" in the default configuration, the layout button ships the misspelled "QWRTY", and three neighbouring keys use three different label conventions — The key-style button shows the destination style, so with the default runeArt it reads 'ABC'; the page button also shows its destination, so on the 123 page it reads 'ABC' too. Impact: Medium. Effort: Low. (`SleepTokenKeyboard/KeyboardRootView.swift:87`) — added 2026-07-26, completed 2026-07-26
- [x] **[Performance & Memory + Cleaner code + Architecture]** viewWillAppear and viewDidAppear have byte-identical bodies, so the root view is rebuilt three times per appearance with two forced layout passes — Both appearance callbacks execute the same three statements in the same order, with no comment explaining why, so neither call site is identifiable as authoritative and a maintainer cannot... Impact: Medium. Effort: Low. (`SleepTokenKeyboard/KeyboardViewController.swift:16-21`) — added 2026-07-26, completed 2026-07-26
- [x] **[Accessibility]** KeyPressStyle animates a scale on every keypress without checking Reduce Motion — KeyPressStyle is the shared button style for every key in the extension — letters, shift, backspace, symbols and all chrome. Impact: Low. Effort: Low. (`SleepTokenKeyboard/KeyboardRootView.swift:368`) — added 2026-07-26, completed 2026-07-26
- [x] **[Performance & Memory + Security & Privacy]** The extension registers and ships a custom rune font it never draws, and compiles the persistent font-installer into the same process — The extension's Info.plist declares UIAppFonts with SleepTokenRunes.ttf and the 11KB face is bundled because project.yml lists the whole SleepTokenKeyboard directory as sources, so iOS... Impact: Low. Effort: Low. (`SleepTokenKeyboard/Info.plist:41-44`) — added 2026-07-26, completed 2026-07-26
- [x] **[UI]** No shared spacing scale: rows use 2/3/5/6pt insets and gaps, and function keys are 34/42/48/50/60pt wide — Horizontal insets are set independently at three nesting levels, so rows do not share a left or right edge: the root applies 3pt, the bottom bar adds another 2pt, the grid function row adds... Impact: Low. Effort: Low. (`SleepTokenKeyboard/KeyboardRootView.swift:48`) — added 2026-07-26, completed 2026-07-26
- [x] **[UX]** The space bar is styled identically to the modifier keys and squeezed by five fixed widths — Every key in the bottom bar is the same KeyChromeButton with the same systemGray4 fill, so space and return carry no visual weight over the layout/style/123 modifiers — the bar reads as one... Impact: Low. Effort: Low. (`SleepTokenKeyboard/KeyboardRootView.swift:103-106`) — added 2026-07-26, completed 2026-07-26
- [x] **[Cleaner code]** The height constraint uses the legacy NSLayoutConstraint initialiser four lines above the modern anchors it sits with — installKeyboardUI builds the height constraint with the seven-argument NSLayoutConstraint initialiser — including a force-unwrapped `view!`, an `attribute: .notAnAttribute` sentinel and a... Impact: Low. Effort: Low. (`SleepTokenKeyboard/KeyboardViewController.swift:46-54`) — added 2026-07-26, completed 2026-07-26

### 18. Theme system: Ritual & Even in Arcadia

_Current state: Single observable store with stable raw values, palette that rethemes every call site untouched, deterministic petal layout, TimelineView correctly paused under Reduce Motion, ceremony hides the raw recolour behind an opaque curtain; persistence and hash determinism tested._

- [x] **[Accessibility]** Ceremony curtain is not modal to VoiceOver — covered controls stay reachable for the ~3.5 s it plays and the transition is never announced; `.accessibilityHidden(ceremonyActive)` on the content plus an announcement at `play()` start. Impact: Medium. Effort: Low. (`SleepTokenKB/ContentView.swift:115-125`, `SleepTokenKB/ArcadiaRevealView.swift:80-82`) — added 2026-07-26, completed 2026-07-26
- [x] **[Resilience & tests]** Ceremony cancellation fast-forwards through `try?` sleeps — under task cancellation the remaining timeline runs in one burst and `onCurtainClosed` can fire before the curtain is opaque; make cancellation explicit and commit the terminal state. Impact: Low. Effort: Low. (`SleepTokenKB/ArcadiaRevealView.swift:95-113`) — added 2026-07-26, completed 2026-07-26
- [x] **[Resilience & tests]** ThemeStore's fallback and palette switching asserted around, not through, the real code — the singleton's private init is untestable and no test flips the mode and asserts a colour changes; add an internal `init(defaults:)` and one palette-difference test. Impact: Low. Effort: Low. (`SleepTokenKB/Theme.swift:36-39,52`, `SleepTokenKBTests/ThemeTests.swift:46-48`) — added 2026-07-26, completed 2026-07-26
- [x] **[Performance]** PetalField recomputes frame-invariant seeds, colors, and paths every frame — hoist per-petal descriptors and draw via context transforms. Impact: Low (downgraded from Medium — the waste is microseconds against the 24fps budget). Effort: Low. (`SleepTokenKB/Theme.swift:318-348`) — added 2026-07-26, completed 2026-07-26
- [x] **[Cleaner code]** Arcadia rose and champagne literals hand-copied across Theme and the ceremony — three sites for rose, two for champagne; name them as fixed constants so the ceremony's stable-palette invariant holds by construction. Impact: Low (downgraded from Medium). Effort: Low. (`SleepTokenKB/Theme.swift:109,127,153`, `SleepTokenKB/ArcadiaRevealView.swift:26-27`) — added 2026-07-26, completed 2026-07-26
- [x] **[Consistency]** App-level `.tint(Theme.gold)` duplicates ContentView's tracked tint and lives where Observation tracking is not guaranteed — remove the app-level copy. Impact: Low. Effort: Low. (`SleepTokenKB/SleepTokenKBApp.swift:11`, `SleepTokenKB/ContentView.swift:114`) — added 2026-07-26, completed 2026-07-26

### 19. Latin read-back with live spell check

_Current state: latinTranslation is a small pure function with thorough round-trip coverage; the strip is visually polished with a two-channel flag treatment (color + underline) kept distinct from both themes' accents._

- [x] **[UX]** Lowercase-only checking false-flags proper nouns central to the app's vocabulary — "EUCLID" is flagged because only the lowercase form is checked while the strip displays uppercase; accept a word if lowercase or `.capitalized` passes. Impact: High. Effort: Low. (`SleepTokenKB/RunePadView.swift:123-128,163`, `Shared/Alphabet.swift:77-81`) — added 2026-07-26, completed 2026-07-26
- [x] **[UX]** The in-progress column flags mid-word, jittering the caption and re-fitting the canvas per keystroke — exclude the trailing column until it is finished (space or a later column), unlike the comment's claim of matching system behaviour. Impact: Medium. Effort: Low. (`SleepTokenKB/RunePadView.swift:118-131,148-152`) — added 2026-07-26, completed 2026-07-26
- [x] **[Accessibility]** VoiceOver never hears which words are flagged — the explicit "Reads …" label erases the spell-check signal entirely; add an accessibilityValue listing flagged words. Impact: Medium. Effort: Low. (`SleepTokenKB/RunePadView.swift:155-156,164-168`) — added 2026-07-26, completed 2026-07-26
- [ ] **[Performance]** UITextChecker rebuilt and every word re-checked on every body evaluation — including status/isExporting changes unrelated to text; hoist to `@State` updated in `.onChange(of: text)` with a small memo. Impact: Low (downgraded from Medium — millisecond-scale at this app's text sizes). Effort: Low. (`SleepTokenKB/RunePadView.swift:120-131,136`) — added 2026-07-26
- [x] **[Cleaner code]** latinWords recomputed four times per render and translationText is impure — bind once, pass explicitly, make the Text builder pure. Impact: Low. Effort: Low. (`SleepTokenKB/RunePadView.swift:135-156,160-174`) — added 2026-07-26, completed 2026-07-26
- [ ] **[Resilience & tests]** The flag pipeline above latinTranslation has zero coverage — columns split, empty-column filter, and the `count > 1` gate are view-private; extract the pure pipeline beside latinTranslation with an injectable checker. Impact: Low (downgraded from Medium — preventive, no observed defect). Effort: Medium. (`SleepTokenKB/RunePadView.swift:112-131,178-184`) — added 2026-07-26

### Highest-impact refinement

Feature 10 — \"Keyboard height is a hand-maintained table that under-allocates the shipped default.\" It is the only finding in the audit that breaks layout correctness rather than polish, and verification made it worse than originally filed: `KeyboardViewController.swift:88` derives `isLandscape` from the keyboard's own `view.bounds` (`bounds.width > bounds.height`), and a keyboard input view is wider than tall in portrait too — so after the first layout pass the flat 190/210 branch at :95-97 is taken in portrait as well, and the mode-aware table at :98-102 is effectively dead code. The A-Z grid layout and the 123 page each render a fourth full-height row (KeyboardRootView.swift:201-210 and :239-243), giving 238pt of fixed, non-compressible content inside a 190pt container that is bottom-aligned (:51), which pushes an entire key row outside the input view. Fixing it means replacing the literal table with a derivation from constants the view already owns — which simultaneously closes the keyFaceStyle drift, the missing height callback on the style button (:91-93), the invisible `showSymbols` page shape, and the ~88pt portrait dead band, and yields a pure function the existing test target can assert on.

### Suggested order

1. 1. Feature 10 — extract KeyboardMetrics + contentHeight() into Shared/ and derive preferredKeyboardHeight from it; fix the bounds-based orientation test; add onNeedsHeightUpdate to the style button; pass the current page up. This is the one correctness defect, and the shared-metrics extraction is the foundation several later items sit on.
2. 2. Feature 8 — replace the two shift Bools with a ShiftState enum in Shared/, pass it through LetterPage into ShiftKeyButton, and render/announce the three states (shift / shift.fill / capslock.fill, accessibilityValue, .isSelected). One piece of work: the enum refactor is the vehicle for the High-impact accessibility fix. Add ShiftStateTests in the same pass.
3. 3. Feature 6 — add .accessibilityAddTraits(.isKeyboardKey) to letter, shift, backspace and symbol keys (opting the chrome buttons out). Independent, Low effort, High impact for VoiceOver users.
4. 4. Feature 7 — dark-mode key palette: a KeyPalette dynamic color for the keycap fill at :287, lighten the field at :52 and KeyboardViewController.swift:12, gate or drop the shadow at :288. Isolated, Low effort, fixes legibility of every primary key in dark mode.
5. 5. Features 6 + 9 — extract the keycap chassis into one ViewModifier / IconKeyButton, then give SymbolsPage its own SymbolKeyButton with a content fill and explicit font size. Do these together; the extraction is a prerequisite for the 123-page restyle.
6. 6. Feature 7 — accessibilityHidden(true) on the nested SymbolGlyphView at :263 (and the hint Text at :268) so both key-face styles announce identically. Small and independent.
7. 7. Feature 10 — chrome labels: break the duplicate "ABC" tie, fix "QWRTY", and unify the three label conventions using LayoutMode.accessibilityLabel and KeyFaceStyle.next.title.
8. 8. Feature 6 — GeometryReader key unit in LetterPage and the derived home-row inset, replacing the literal 12. Do after the metrics extraction so the constants come from one place.
9. 9. Performance batch (features 6, 7, 8, 9, 10) — static let defaults in LayoutMode.swift:62, static impact generator, .equatable() on LetterKeyButton, static symbol rows + dropped enumeration, hoisted asset probe in SymbolGlyphView, drop the unused TTF and RuneFont from the extension target. All Low effort, all behaviour-preserving, all verifiable together.
10. 10. Lifecycle and hygiene batch (features 7, 10) — syncForAppearance(), guarded applyHeight, drop refreshRoot() from onNeedsHeightUpdate, delete showNextKeyboardKey, switch to the heightAnchor constraint, honour Reduce Motion, fix the press-in animation timing, resolve the App Group write path, and settle the single preference read path.
11. 11. Remaining Low cleanups (features 6, 7, 9, 10) — spacing/width constants, space-bar hierarchy, rune keycap centring, stale GeometricSymbol comments and dead diamond Path, row-index intent expressions, and the KeyboardLayout / symbol-table validation tests.


## Implementation notes — 2026-07-26

All 32 refinements for features 6-10 were implemented in the suggested order.

**New shared files**
- `Shared/KeyboardMetrics.swift` — one source of truth for keyboard geometry. Both the
  SwiftUI content and `KeyboardViewController` now derive height from `contentHeight(...)`,
  so the container can no longer promise less space than the rows occupy.
- `Shared/ShiftState.swift` — the three shift states as one value type; the illegal fourth
  combination of the old two-Bool encoding is now unrepresentable.
- `SleepTokenKeyboard/KeyPalette.swift` — dynamic key colours that keep primary keys the
  lightest surface in both appearances.

**Adapted rather than applied literally**
- *Landscape height*: rather than clamping the total (which is what allowed the overflow),
  `KeyboardMetrics` exposes compact key heights and both the view and the controller derive
  `compact` from the vertical size class, so they cannot disagree.
- *Reserved height*: the controller reserves `maxContentHeight` (tallest key style for the
  current page) rather than the exact current height, so toggling rune/ABC mid-session never
  clips a visible row.
- *Shared key unit*: applied to QWERTY only, where the column misalignment actually was.
  The grid layout keeps flexible key widths so its 9- and 8-key rows still fill the row.
- *`.renderingMode(.template)`*: removed only after verifying all 26 imagesets in **both**
  catalogs declare `template-rendering-intent`.

**Verification**
- `./scripts/test.sh` — builds both targets against the iOS Simulator 26.5 SDK and runs the
  full suite: **33 tests, 0 failures, 0 source warnings**.
- The script sets `DEVELOPER_DIR` because this machine's `xcode-select` points at
  CommandLineTools, which makes plain `xcodebuild` refuse to run even though Xcode is
  installed. That is why an earlier pass wrongly believed no iOS SDK was available.
- Two deprecations the build surfaced were fixed: `traitCollectionDidChange` →
  `registerForTraitChanges`, and `UIScreen.main.scale` → `@Environment(\.displayScale)`
  in Rune Pad.

**Still unverified**
- Everything device-specific: real VoiceOver behaviour, dark-mode contrast on hardware, and
  the actual keyboard height in a live text field. The simulator builds and the arithmetic
  is unit-tested, but neither proves the keyboard feels right in Messages.
- The haptic question raised under feature 6 (whether `impactOccurred` does anything with
  `RequestsOpenAccess = false`) still needs a real device to answer. The generator is now
  process-scoped and re-armed after each fire, but if it turns out to be inert on device,
  the honest follow-up is to remove it and stop presenting the haptics toggle as active.
