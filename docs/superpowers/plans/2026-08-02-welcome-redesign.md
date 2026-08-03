# Welcome Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Turn the host app's settings-dump entry screen into an entrance hall — hero, state-aware enable card, three destination doors — with all settings behind a new Settings screen that also carries a spoiler-free Jerry tally.

**Architecture:** Two pure rules (`EnableThreshold`, `JerryTally`) unit-tested in the host target; one new screen (`SettingsView`) receiving the moved cards and their Jerrys intact; a slimmed `ContentView`. Ceremony overlays, `JerrySpot` raw values, and the entire visual system are untouched. Spec: `docs/superpowers/specs/2026-08-02-welcome-redesign-design.md`.

**Tech Stack:** SwiftUI, XCTest, xcodegen. Host app only — the keyboard extension is out of scope.

## Global Constraints

- Work on branch `welcome-redesign`, created from the current `glide-typing` HEAD (stacked on PR #1; it carries the approved spec commit). Work in the existing worktree at `/Users/cperez/dev/altivum-dev/sleep-token-kb/.claude/worktrees/glide-typing`. Never touch the main checkout.
- Test command: `xcodebuild -project SleepTokenKB.xcodeproj -scheme SleepTokenKB -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test` — full suite green after every task (245 at branch start).
- New files under `SleepTokenKB/` and `SleepTokenKBTests/` are picked up by the target globs, but `xcodegen generate` must still run after adding files, and the regenerated `project.pbxproj` commits with them. No `project.yml` edits are needed.
- `JerrySpot` raw values are the hunt's persistence format — never rename one. The four home Jerrys move only as passengers on their host views.
- Host app uses `Theme`, never `KeyPalette`. No emojis in UI copy. Copy voice: plain, quiet, declarative — no exclamation, no onboarding cheer.
- WCAG 2.2 AA: moved elements keep their labels and traits; decorative ornament is `accessibilityHidden`; the tally's VoiceOver output is the count and nothing else.
- The host app CAN run in the simulator — Task 6 ships screenshots. The keyboard-extension no-driving rule is irrelevant here.
- Commit messages: sentence-style summaries, trailer `Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>`.
- SourceKit "Cannot find X in scope" diagnostics are editor noise; xcodebuild is the truth.

## File Structure

| File | Responsibility |
|---|---|
| `SleepTokenKB/EnableThreshold.swift` (new) | Pure rule: does the welcome show the enable card |
| `SleepTokenKB/JerryTally.swift` (new) | Pure rule: tally visibility, wording, replay line |
| `SleepTokenKB/SettingsView.swift` (new) | The Settings door: Appearance, Keyboard, Two ways to write, the tally. Receives the moved private controls (`LayoutPicker`, `KeyFacePicker`, `HapticsToggle`, `GlideToggle`, `DefaultsRow`, `PreferenceBacked`, `waysRow`) |
| `SleepTokenKB/ContentView.swift` (modify) | Slims to hero + threshold card + three doors + footer; keeps ceremony state and passes the theme binding down |
| `SleepTokenKB/EnableKeyboardView.swift` (modify) | Gains the manual "hide the setup card" affordance |
| `SleepTokenKBTests/EnableThresholdTests.swift`, `SleepTokenKBTests/JerryTallyTests.swift` (new) | The pure rules' suites |

---

### Task 1: EnableThreshold rule

**Files:**
- Create: `SleepTokenKB/EnableThreshold.swift`
- Test: `SleepTokenKBTests/EnableThresholdTests.swift`

**Interfaces:**
- Produces: `EnableThreshold.showsEnableCard(enabledKeyboards: [String]?, manuallyHidden: Bool) -> Bool`, `EnableThreshold.keyboardBundleID`, `EnableThreshold.manuallyHiddenKey = "enableCardManuallyHidden"`

- [ ] **Step 1: Write the failing test**

```swift
// SleepTokenKBTests/EnableThresholdTests.swift
import XCTest
@testable import SleepTokenKB

/// The welcome's one state-aware element. The rule's bias is deliberate: showing
/// setup to someone who finished it is a shrug, hiding it from someone who has
/// not is a dead end — so every unreadable state keeps the card.
final class EnableThresholdTests: XCTestCase {

    private let enabled = ["en_US@sw=QWERTY", EnableThreshold.keyboardBundleID]

    func testAnEnabledKeyboardHidesTheCard() {
        XCTAssertFalse(EnableThreshold.showsEnableCard(enabledKeyboards: enabled,
                                                       manuallyHidden: false))
    }

    func testAMissingKeyboardShowsTheCard() {
        XCTAssertTrue(EnableThreshold.showsEnableCard(enabledKeyboards: ["en_US@sw=QWERTY"],
                                                      manuallyHidden: false))
    }

    /// The degraded read: nil (preference unreadable) and empty both keep the card.
    func testAnUnreadableListShowsTheCard() {
        XCTAssertTrue(EnableThreshold.showsEnableCard(enabledKeyboards: nil, manuallyHidden: false))
        XCTAssertTrue(EnableThreshold.showsEnableCard(enabledKeyboards: [], manuallyHidden: false))
    }

    /// The manual override wins over everything, including a readable list that
    /// lacks the keyboard — it exists precisely for when the read lies.
    func testManualHideWinsRegardlessOfTheList() {
        XCTAssertFalse(EnableThreshold.showsEnableCard(enabledKeyboards: nil, manuallyHidden: true))
        XCTAssertFalse(EnableThreshold.showsEnableCard(enabledKeyboards: ["other"], manuallyHidden: true))
        XCTAssertFalse(EnableThreshold.showsEnableCard(enabledKeyboards: enabled, manuallyHidden: true))
    }
}
```

- [ ] **Step 2: Run to verify compile failure** (`cannot find 'EnableThreshold'`) — test command from Global Constraints, grep `EnableThresholdTests|error:`.

- [ ] **Step 3: Implement**

```swift
// SleepTokenKB/EnableThreshold.swift
import Foundation

/// Whether the welcome screen shows the "Enable the keyboard" card.
///
/// Detection reads the system's enabled-keyboards preference (the caller passes
/// `UserDefaults.standard.stringArray(forKey: "AppleKeyboards")`), which is not
/// formally documented — so the rule degrades toward showing: an unreadable or
/// empty list keeps the card, and the enable guide's manual hide is the human
/// override for a read that lies. Pure, so every branch is testable.
enum EnableThreshold {
    static let keyboardBundleID = "ai.altivum.SleepTokenKB.SleepTokenKeyboard"
    static let manuallyHiddenKey = "enableCardManuallyHidden"

    static func showsEnableCard(enabledKeyboards: [String]?, manuallyHidden: Bool) -> Bool {
        if manuallyHidden { return false }
        guard let enabledKeyboards, !enabledKeyboards.isEmpty else { return true }
        return !enabledKeyboards.contains(keyboardBundleID)
    }
}
```

- [ ] **Step 4: `xcodegen generate`, run tests** — 4 new PASS, suite green (249).
- [ ] **Step 5: Commit** (`SleepTokenKB/EnableThreshold.swift`, test file, `project.pbxproj`): "Decide the welcome's enable card with a rule that degrades toward showing"

---

### Task 2: JerryTally rule

**Files:**
- Create: `SleepTokenKB/JerryTally.swift`
- Test: `SleepTokenKBTests/JerryTallyTests.swift`

**Interfaces:**
- Consumes: nothing.
- Produces: `JerryTally.presentation(found: Int, total: Int) -> JerryTally.Presentation?` where `Presentation: Equatable { let text: String; let showsReplay: Bool }`. Returns `nil` when `found == 0`.

- [ ] **Step 1: Write the failing test**

```swift
// SleepTokenKBTests/JerryTallyTests.swift
import XCTest
@testable import SleepTokenKB

/// Counts without hinting. Nothing before the first find — a newcomer never
/// learns from the UI that a hunt exists — and the reward's replay line only
/// once every Jerry is home.
final class JerryTallyTests: XCTestCase {

    func testNothingBeforeTheFirstFind() {
        XCTAssertNil(JerryTally.presentation(found: 0, total: 10))
    }

    func testCountsAreWrittenOut() {
        XCTAssertEqual(JerryTally.presentation(found: 1, total: 10)?.text, "One of ten")
        XCTAssertEqual(JerryTally.presentation(found: 4, total: 10)?.text, "Four of ten")
        XCTAssertEqual(JerryTally.presentation(found: 9, total: 10)?.text, "Nine of ten")
    }

    func testTheReplayLineAppearsOnlyAtTen() {
        XCTAssertEqual(JerryTally.presentation(found: 9, total: 10)?.showsReplay, false)
        let complete = JerryTally.presentation(found: 10, total: 10)
        XCTAssertEqual(complete?.text, "Ten of ten")
        XCTAssertEqual(complete?.showsReplay, true)
    }
}
```

- [ ] **Step 2: Run to verify compile failure** (`cannot find 'JerryTally'`).

- [ ] **Step 3: Implement**

```swift
// SleepTokenKB/JerryTally.swift
import Foundation

/// The hunt's count, written out — "Four of ten" — with no names, no locations,
/// and nothing at all before the first find. The words match the register the
/// enable guide's roman numerals set: ceremony over digits.
enum JerryTally {
    struct Presentation: Equatable {
        let text: String
        let showsReplay: Bool
    }

    private static let words = [
        "zero", "one", "two", "three", "four", "five",
        "six", "seven", "eight", "nine", "ten",
    ]

    static func presentation(found: Int, total: Int) -> Presentation? {
        guard found > 0 else { return nil }
        return Presentation(
            text: "\(word(for: found).capitalized) of \(word(for: total))",
            showsReplay: found >= total
        )
    }

    private static func word(for count: Int) -> String {
        count < words.count ? words[count] : "\(count)"
    }
}
```

- [ ] **Step 4: `xcodegen generate`, run tests** — 3 new PASS, suite green (252).
- [ ] **Step 5: Commit**: "Count found Jerrys without hinting where the rest hide"

---

### Task 3: SettingsView — the door that holds what the welcome dumps

**Files:**
- Create: `SleepTokenKB/SettingsView.swift`
- Modify: `SleepTokenKB/ContentView.swift` (move-out only in this task: delete the moved private views from ContentView **in Task 4**, not here — this task only adds the new file, so both compile)

**Interfaces:**
- Consumes: `JerryTally.presentation(found:total:)`, `JerryHunt.shared` (`found`, `totalCount`, `celebrationPending = true` for replay), `KeyboardPreferences.*`, `Theme`, `SectionLabel`, `.ritualCard()`, `readableColumn()`, `RitualBackground`, `HiddenJerry(spot:height:)`, `BlackFlamingo(height:)`, `ThemeMode`.
- Produces: `struct SettingsView: View { init(theme: Binding<ThemeMode>) }` — ContentView passes its existing `themeBinding`, so the ceremony (`requestTheme`, `pendingMode`, `ceremonyActive`, the overlay) stays exactly where it is and still fires from the pushed screen.

- [ ] **Step 1: Create the screen.** Copy — verbatim, structure intact — from `ContentView.swift` into `SettingsView.swift`: the private views `LayoutPicker`, `KeyFacePicker`, `HapticsToggle`, `GlideToggle`, `DefaultsRow`, `PreferenceBacked`, and the `waysRow(title:detail:)` helper. Then build:

```swift
// SleepTokenKB/SettingsView.swift
import SwiftUI

/// The Settings door: everything the welcome used to dump, in the card language
/// with the tracked-caps section voice — a directory screen is where that
/// scaffolding belongs. The theme binding comes from ContentView, so the Arcadia
/// ceremony still runs on the root overlay above this pushed screen.
struct SettingsView: View {
    @Binding var theme: ThemeMode
    @State private var hunt = JerryHunt.shared

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                VStack(alignment: .leading, spacing: 10) {
                    SectionLabel(text: "Appearance")
                    DefaultsRow(title: "Theme", caption: themeCaption) {
                        Picker("Theme", selection: $theme) {
                            ForEach(ThemeMode.allCases) { mode in
                                Text(mode.title).tag(mode)
                            }
                        }
                        .pickerStyle(.segmented)
                    }
                    .ritualCard()
                    .overlay(alignment: .topTrailing) {
                        HiddenJerry(spot: .appearanceCard, height: 12)
                    }
                }

                VStack(alignment: .leading, spacing: 10) {
                    SectionLabel(text: "Keyboard defaults")
                    VStack(spacing: 16) {
                        LayoutPicker()
                        Rectangle().fill(Theme.hairline).frame(height: 1)
                        KeyFacePicker()
                        Rectangle().fill(Theme.hairline).frame(height: 1)
                        HapticsToggle()
                        Rectangle().fill(Theme.hairline).frame(height: 1)
                        GlideToggle()
                    }
                    .ritualCard()
                }

                VStack(alignment: .leading, spacing: 10) {
                    SectionLabel(text: "Two ways to write")
                    VStack(alignment: .leading, spacing: 14) {
                        waysRow(
                            title: "System keyboard",
                            detail: "Rune or ABC keycaps — always inserts normal English, so it works in Messages, Notes, everywhere."
                        )
                        Rectangle().fill(Theme.hairline).frame(height: 1)
                        waysRow(
                            title: "Rune Pad",
                            detail: "Real vertical runes, exported as images or text for apps that accept pictures."
                        )
                    }
                    .ritualCard()
                    .overlay(alignment: .bottomTrailing) {
                        HiddenJerry(spot: .waysCard, height: 13)
                    }
                }

                if let tally = JerryTally.presentation(found: hunt.found.count,
                                                       total: hunt.totalCount) {
                    VStack(alignment: .leading, spacing: 10) {
                        SectionLabel(text: "The hunt")
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(spacing: 10) {
                                // Decorative echo of a found Jerry — not a hiding
                                // spot, not tappable, invisible to VoiceOver.
                                BlackFlamingo(height: 14)
                                    .opacity(0.34)
                                    .accessibilityHidden(true)
                                Text(tally.text)
                                    .font(Theme.display(.body))
                                    .foregroundStyle(Theme.inkDim)
                            }
                            if tally.showsReplay {
                                Button("Play the reward again") {
                                    hunt.celebrationPending = true
                                }
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(Theme.gold)
                            }
                        }
                        .ritualCard()
                    }
                }
            }
            .padding(20)
            .readableColumn()
        }
        .background(RitualBackground())
        .navigationTitle("Settings")
    }

    private var themeCaption: String {
        switch theme {
        case .ritual: "Obsidian and gold. The original ceremony."
        case .evenInArcadia: "Pink overgrowth on black stone. The flamingo keeps watch."
        }
    }

    // ... the moved private views land below, verbatim from ContentView ...
}
```

Match the navigation-title treatment the other pushed screens use (check `EnableKeyboardView`'s tail and `AlphabetChartView`; if they set an inline display mode, mirror it).

- [ ] **Step 2: Build + full suite** (`xcodegen generate` first for the new file). Duplicate private view definitions across two files are fine this task — they are `private` per file. Suite green.
- [ ] **Step 3: Commit**: "Give the settings a door of their own, with the hunt's quiet tally"

---

### Task 4: The welcome becomes an entrance hall

**Files:**
- Modify: `SleepTokenKB/ContentView.swift`

**Interfaces:**
- Consumes: `EnableThreshold`, `SettingsView(theme:)`, everything already in the file.
- Produces: the slimmed welcome. `themeBinding`, `requestTheme`, `pendingMode`, `ceremonyActive`, both overlays, and `themeCaption`'s REMOVAL (it lives in SettingsView now).

- [ ] **Step 1: Delete the moved code from ContentView:** the Appearance section, the Keyboard-defaults section, the "Two ways to write" section, `waysRow`, `themeCaption`, and the private views `LayoutPicker`, `KeyFacePicker`, `HapticsToggle`, `GlideToggle`, `DefaultsRow`, `PreferenceBacked` (now living in SettingsView.swift). Keep `DestinationCard` — the welcome uses it.

- [ ] **Step 2: Rebuild the body's scroll content:**

```swift
                VStack(alignment: .leading, spacing: 28) {
                    hero

                    VStack(alignment: .leading, spacing: 10) {
                        if showsEnableCard {
                            NavigationLink { EnableKeyboardView() } label: {
                                DestinationCard(
                                    glyph: .e,
                                    title: "Enable the keyboard",
                                    detail: "One-time setup in Settings. Then the runes follow you into every app."
                                )
                            }
                        }
                        NavigationLink { RunePadView() } label: {
                            DestinationCard(
                                glyph: .r,
                                title: "Rune Pad",
                                detail: "Compose vertical ritual text, read it back in Latin, export it anywhere."
                            )
                        }
                        NavigationLink { AlphabetChartView() } label: {
                            DestinationCard(
                                glyph: .a,
                                title: "The alphabet",
                                detail: "All twenty-six glyphs with their letters and construction notes."
                            )
                        }
                        NavigationLink { SettingsView(theme: themeBinding) } label: {
                            DestinationCard(
                                glyph: .s,
                                title: "Settings",
                                detail: "Theme, layout, key faces, haptics."
                            )
                        }
                    }

                    footer
                }
```

No section label above the cards — four items do not need the tracked-caps scaffolding, per the spec and PRODUCT.md's tension note.

- [ ] **Step 3: The hero breathes.** Replace the value-prop paragraph's text with `"English everywhere, runes on the keys — and real runes in Rune Pad."` (same font, style, spacing modifiers). Raise the hero's `.padding(.top, 8)` to `.padding(.top, 24)` and its internal `spacing: 14` to `spacing: 16`; judge the final values against the Task 6 screenshots rather than on faith.

- [ ] **Step 4: The threshold state.**

```swift
    @State private var showsEnableCard = true

    private func refreshThreshold() {
        showsEnableCard = EnableThreshold.showsEnableCard(
            enabledKeyboards: UserDefaults.standard.stringArray(forKey: "AppleKeyboards"),
            manuallyHidden: UserDefaults.standard.bool(forKey: EnableThreshold.manuallyHiddenKey)
        )
    }
```

Call `refreshThreshold()` from `.onAppear` (alongside the existing `RuneFont.registerIfNeeded()`) and from a `.onChange(of: scenePhase)` when it becomes `.active` (add `@Environment(\.scenePhase)`) — the user returns from Settings.app having just enabled the keyboard, and the card should be gone before they scroll.

- [ ] **Step 5: DEBUG screenshot affordances** (deliberately tiny, DEBUG-gated, argument-driven):

```swift
    #if DEBUG
    @State private var debugRouteToSettings = false

    private func applyScreenshotOverrides() {
        let arguments = ProcessInfo.processInfo.arguments
        if arguments.contains("-force-enable-card") { showsEnableCard = true }
        if arguments.contains("-force-arcadia") { store.mode = .evenInArcadia }
        if arguments.contains("-route-settings") { debugRouteToSettings = true }
    }
    #endif
```

Call `applyScreenshotOverrides()` at the end of `.onAppear` inside `#if DEBUG`. Add, on the ScrollView, `#if DEBUG` a `.navigationDestination(isPresented: $debugRouteToSettings) { SettingsView(theme: themeBinding) }` `#endif`.

- [ ] **Step 6: Build + full suite green. Commit**: "Open the welcome into an entrance hall with doors instead of a dump"

---

### Task 5: The enable guide's manual override and copy reconciliation

**Files:**
- Modify: `SleepTokenKB/EnableKeyboardView.swift`

- [ ] **Step 1:** At the end of the guide's scroll content (after the Troubleshooting card), add the quiet override:

```swift
                Button {
                    UserDefaults.standard.set(true, forKey: EnableThreshold.manuallyHiddenKey)
                    hidConfirmation = true
                } label: {
                    Text(hidConfirmation
                         ? "The setup card is hidden."
                         : "Already enabled? Hide the setup card on the welcome screen.")
                        .font(.footnote)
                        .foregroundStyle(Theme.inkDim)
                        .frame(maxWidth: .infinity)
                        .multilineTextAlignment(.center)
                }
                .buttonStyle(.plain)
                .disabled(hidConfirmation)
```

with `@State private var hidConfirmation = false`. The welcome recomputes on appear, so the card is gone when they navigate back. VoiceOver: the button's text IS its label; after tapping, the disabled state plus changed text announce the result.

- [ ] **Step 2: Copy reconciliation check** (spec: moves, not deletions). The hero's cut sentence — "Type English everywhere with ritual keycaps. When you want real runes, compose in Rune Pad and carry them out as images." — must survive in substance: the guide's intro paragraph plus the "Use it" step already carry both halves (verify by reading them); the ways card carries them verbatim in Settings. If any clause is genuinely absent from every remaining home, add it to the guide's intro. Record the verdict in the commit message.

- [ ] **Step 3: Build + full suite green. Commit**: "Let the enable guide hide the welcome's setup card by hand"

---

### Task 6: Simulator proof and the final gate

**Files:** none (screenshots to the session scratchpad)

- [ ] **Step 1: Full suite** — green (252 expected).
- [ ] **Step 2: Screenshot matrix.** Boot the iOS 26.5 iPhone 17 Pro simulator (`59A65E60-74F5-45C9-B09C-469ECE6E6F76`), build+install the Debug app, then for each row: launch with the arguments, wait ~2s, `xcrun simctl io booted screenshot <name>.png`, terminate.

| Shot | Launch arguments | Extra setup |
|---|---|---|
| welcome-needs-setup | `-force-enable-card` | — |
| welcome-enabled | (none — the sim has the keyboard enabled) | — |
| welcome-arcadia | `-force-arcadia` | — |
| settings | `-route-settings` | — |
| settings-arcadia | `-route-settings -force-arcadia` | — |
| welcome-a11y | `-force-enable-card` | `xcrun simctl ui booted content_size accessibility-extra-large` first, reset after |
| settings-a11y | `-route-settings` | same |

`xcrun simctl launch booted ai.altivum.SleepTokenKB <args>` passes arguments after the bundle id. If `welcome-enabled` still shows the card (the AppleKeyboards read can be empty in a fresh sim), note it honestly — the forced shot covers the layout, and the real-device check covers detection.

- [ ] **Step 3: Read every screenshot** and check: hero air, card rhythm, footer intact, tally absent (fresh sim, zero Jerrys — correct), Dynamic Type not truncating, both themes correct in both screens.
- [ ] **Step 4: Commit anything Step 3 fixed**; final suite run; present the screenshots to Christian with plain statements of what is and is not verified (detection on device is his check, as is the ceremony from the Settings screen).

---

## Self-Review (completed)

- **Spec coverage:** welcome structure (T4), spacious hero (T4), threshold + degrade + manual override (T1, T4, T5), Settings door with moved cards and Jerrys (T3), tally + replay (T2, T3), hunt integrity (T3 — spots ride hosts, raw values untouched), copy moves (T3 verbatim ways card, T5 reconciliation), a11y (T3 ornament hidden, T5 button labeling, T6 Dynamic Type shots), simulator proof (T6). No gaps.
- **Placeholder scan:** none.
- **Type consistency:** `EnableThreshold.showsEnableCard(enabledKeyboards:manuallyHidden:)` identical in T1/T4; `JerryTally.presentation(found:total:) -> Presentation?` identical in T2/T3; `SettingsView(theme: Binding<ThemeMode>)` identical in T3/T4.
