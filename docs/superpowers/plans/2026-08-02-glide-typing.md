# Glide Typing Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Slide a finger from letter to letter on the QWERTY layout to type a word, decoded on-device by path-template matching, committed stock-style (insert on lift, alternates in the bar, whole-word backspace).

**Architecture:** Four pure components in `Shared/` (`KeyCenters`, `GlideLexicon`, `GlideDecoder`, `GlideSession`) plus pure commit rules (`GlideCommit`, `GlideUndo`), all unit-tested; a `simultaneousGesture` capture layer with a trail overlay on `LetterPage`; wiring in `KeyboardRootView` through the existing `insert()` path. Spec: `docs/superpowers/specs/2026-08-02-glide-typing-design.md`.

**Tech Stack:** Swift 5 / SwiftUI / XCTest, xcodegen (project.yml is the project source of truth), python3 for the one-time lexicon build script.

## Global Constraints

- The keyboard **cannot be driven in the simulator**. Never claim glide "works" — say "tests pass, build succeeds"; Christian verifies behavior on device.
- Test command (all suites must stay green after every task):
  `xcodebuild -project SleepTokenKB.xcodeproj -scheme SleepTokenKB -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test`
- After every `project.yml` edit run `xcodegen generate` and commit the regenerated `SleepTokenKB.xcodeproj/project.pbxproj` with it.
- The app target compiles all of `Shared/` automatically (`- path: Shared`); the extension target **enumerates files individually** in `project.yml` — every new `Shared/*.swift` file must be added there in the same task that creates it.
- Extension UI uses `KeyPalette`, never the host app's `Theme`. No emojis anywhere in UI copy.
- WCAG 2.2 AA is the shipped standard: glide must not engage under VoiceOver; the trail needs a Reduce Motion alternative.
- QWERTY only. The grid layout, symbol pages, and emoji page never see the gesture.
- Commit messages: sentence-style summaries matching the repo's history (no `feat:` prefixes), ending with `Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>`.

## File Structure

| File | Responsibility |
|---|---|
| `Shared/KeyCenters.swift` (new) | QWERTY key-center geometry from the same `KeyboardMetrics` math `LetterPage` renders with |
| `Shared/GlideLexicon.swift` (new) | Word/frequency list: bundle load, supplementary merge, first/last-key pruning |
| `Shared/GlideDecoder.swift` (new) | Resample trace, build templates lazily, score, rank; literal fallback |
| `Shared/GlideSession.swift` (new) | Trace collection value type (start/extend/finish/cancel) |
| `Shared/GlideCommit.swift` (new) | Pure commit rules: casing, auto-space; `GlideUndo` whole-word-backspace bookkeeping |
| `Shared/Resources/glide_lexicon.txt` (new, generated) | ~50k `word<TAB>count` lines |
| `scripts/build_glide_lexicon.py` (new) | Generates the lexicon file from Norvig's `count_1w.txt` + contractions table |
| `Shared/LayoutMode.swift` (modify) | `KeyboardPreferences.glideTypingEnabled` |
| `SleepTokenKB/ContentView.swift` (modify) | Glide toggle row in the keyboard-defaults card |
| `SleepTokenKeyboard/KeyboardRootView.swift` (modify) | LetterPage gesture + trail; commit wiring; backspace rule; suggestion handoff |
| `SleepTokenKeyboard/KeyboardViewController.swift` (modify) | `requestSupplementaryLexicon` plumb |
| `project.yml` (modify per task) | Extension sources + lexicon resource for both targets |

---

### Task 1: KeyCenters geometry with LetterPage parity

**Files:**
- Create: `Shared/KeyCenters.swift`
- Test: `SleepTokenKBTests/KeyCentersTests.swift`
- Modify: `project.yml` (extension sources: add `- path: Shared/KeyCenters.swift` after the `Shared/KeyboardMetrics.swift` line)

**Interfaces:**
- Consumes: `KeyboardMetrics.keyUnit(availableWidth:keysPerRow:)`, `KeyboardMetrics.homeRowInset(keyUnit:)`, `KeyboardMetrics.keyGap`, `KeyboardMetrics.rowGap`, `KeyboardLayout.qwertyRows`, `SleepTokenLetter`
- Produces: `KeyCenters.qwerty(availableWidth: CGFloat, keyHeight: CGFloat) -> [SleepTokenLetter: CGPoint]` — coordinates in `LetterPage`'s local space (origin at the top-leading corner of the letter grid)

The geometry must mirror `LetterPage` exactly (`SleepTokenKeyboard/KeyboardRootView.swift`, the `LetterPage` struct): row 0 is ten `keyUnit`-wide keys separated by `keyGap` starting at x=0; row 1 is nine keys padded by `homeRowInset` on each side; row 2 is seven letters flanked by shift and backspace, both `KeyboardMetrics.functionKeyWidth` (44pt) wide — equal flanks, and the row HStack is centered by the enclosing VStack, so the seven-letter block is centered on the page's midline. Row r's vertical center is `r * (keyHeight + rowGap) + keyHeight / 2`.

- [ ] **Step 1: Write the failing test**

```swift
// SleepTokenKBTests/KeyCentersTests.swift
import XCTest
@testable import SleepTokenKB

/// The decoder's idea of where a key sits must be the rendered truth. These tests
/// re-derive LetterPage's layout arithmetic independently; if either side drifts,
/// glide decodes against a keyboard that is not on screen.
final class KeyCentersTests: XCTestCase {

    private let widths: [CGFloat] = [320, 384.5, 393, 430]
    private let heights: [CGFloat] = [40, 44, 32, 36]

    func testTopRowMatchesLetterPageMath() {
        for width in widths {
            for keyHeight in heights {
                let unit = KeyboardMetrics.keyUnit(availableWidth: width)
                let centers = KeyCenters.qwerty(availableWidth: width, keyHeight: keyHeight)
                for (index, letter) in KeyboardLayout.qwertyRows[0].enumerated() {
                    let expected = CGPoint(
                        x: CGFloat(index) * (unit + KeyboardMetrics.keyGap) + unit / 2,
                        y: keyHeight / 2
                    )
                    XCTAssertEqual(centers[letter]!.x, expected.x, accuracy: 0.001)
                    XCTAssertEqual(centers[letter]!.y, expected.y, accuracy: 0.001)
                }
            }
        }
    }

    func testHomeRowIsInsetByHalfAKey() {
        let width: CGFloat = 393, keyHeight: CGFloat = 40
        let unit = KeyboardMetrics.keyUnit(availableWidth: width)
        let inset = KeyboardMetrics.homeRowInset(keyUnit: unit)
        let centers = KeyCenters.qwerty(availableWidth: width, keyHeight: keyHeight)
        let a = centers[.a]!
        XCTAssertEqual(a.x, inset + unit / 2, accuracy: 0.001)
        XCTAssertEqual(a.y, keyHeight + KeyboardMetrics.rowGap + keyHeight / 2, accuracy: 0.001)
    }

    /// Shift and backspace flank row three at equal widths, so the seven-letter
    /// block is centered: its midpoint must sit exactly on the page midline.
    func testBottomRowLetterBlockIsCentered() {
        for width in widths {
            let centers = KeyCenters.qwerty(availableWidth: width, keyHeight: 40)
            let mid = (centers[.z]!.x + centers[.m]!.x) / 2
            XCTAssertEqual(mid, width / 2, accuracy: 0.001)
        }
    }

    func testEveryLetterHasACenterAndNeighborsDoNotCollide() {
        let centers = KeyCenters.qwerty(availableWidth: 393, keyHeight: 40)
        XCTAssertEqual(centers.count, 26)
        let unit = KeyboardMetrics.keyUnit(availableWidth: 393)
        XCTAssertEqual(abs(centers[.q]!.x - centers[.w]!.x), unit + KeyboardMetrics.keyGap, accuracy: 0.001)
    }
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `xcodebuild -project SleepTokenKB.xcodeproj -scheme SleepTokenKB -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test 2>&1 | grep -E "KeyCentersTests|error:" | head -20`
Expected: compile FAILURE — `cannot find 'KeyCenters' in scope`

- [ ] **Step 3: Write the implementation**

```swift
// Shared/KeyCenters.swift
import CoreGraphics

/// Center point of every QWERTY letter key, in LetterPage's local coordinate space.
///
/// Derived from the SAME KeyboardMetrics arithmetic LetterPage lays out with, never
/// measured from views: the decoder and the screen must share one geometry, and a
/// parity test (KeyCentersTests) holds this file and LetterPage together. The grid
/// layout deliberately has no entry here — glide is QWERTY-only by construction.
public enum KeyCenters {

    public static func qwerty(
        availableWidth: CGFloat,
        keyHeight: CGFloat
    ) -> [SleepTokenLetter: CGPoint] {
        let unit = KeyboardMetrics.keyUnit(availableWidth: availableWidth)
        let step = unit + KeyboardMetrics.keyGap
        var centers: [SleepTokenLetter: CGPoint] = [:]

        for (rowIndex, row) in KeyboardLayout.qwertyRows.enumerated() {
            let y = CGFloat(rowIndex) * (keyHeight + KeyboardMetrics.rowGap) + keyHeight / 2
            let leadingX: CGFloat
            switch rowIndex {
            case 0:
                leadingX = 0
            case 1:
                // Half-key inset that centres 9 keys under the 10-key top row.
                leadingX = KeyboardMetrics.homeRowInset(keyUnit: unit)
            default:
                // Shift and backspace flank this row at equal widths, so the letter
                // block is centered on the page midline by the enclosing VStack.
                let blockWidth = CGFloat(row.count) * unit + CGFloat(row.count - 1) * KeyboardMetrics.keyGap
                leadingX = (availableWidth - blockWidth) / 2
            }
            for (index, letter) in row.enumerated() {
                centers[letter] = CGPoint(x: leadingX + CGFloat(index) * step + unit / 2, y: y)
            }
        }
        return centers
    }
}
```

- [ ] **Step 4: Add to the extension target and regenerate**

In `project.yml`, in the `SleepTokenKeyboard` target's `sources`, after `- path: Shared/KeyboardMetrics.swift` add:
```yaml
      - path: Shared/KeyCenters.swift
```
Run: `xcodegen generate`

- [ ] **Step 5: Run tests to verify they pass**

Run: the test command from Global Constraints, grep `KeyCentersTests|TEST`
Expected: 4 new tests PASS, `** TEST SUCCEEDED **`

- [ ] **Step 6: Commit**

```bash
git add Shared/KeyCenters.swift SleepTokenKBTests/KeyCentersTests.swift project.yml SleepTokenKB.xcodeproj/project.pbxproj
git commit -m "Derive QWERTY key centers from the metrics LetterPage renders with"
```

---

### Task 2: Lexicon — build script, bundled resource, loader, pruning

**Files:**
- Create: `scripts/build_glide_lexicon.py`
- Create: `Shared/Resources/glide_lexicon.txt` (generated, committed)
- Create: `Shared/GlideLexicon.swift`
- Test: `SleepTokenKBTests/GlideLexiconTests.swift`
- Modify: `project.yml` (extension sources: add `- path: Shared/GlideLexicon.swift` and `- path: Shared/Resources/glide_lexicon.txt`)

**Interfaces:**
- Consumes: `SleepTokenLetter(rawValue:)`
- Produces:
  - `struct GlideWord: Equatable { let word: String; let path: [SleepTokenLetter]; let frequency: Double }` (`frequency` normalized 0…1, log-scaled; `path` is the word lowercased, non-letters stripped, **adjacent duplicate letters collapsed** — "hello" → h,e,l,o)
  - `final class GlideLexicon` with `init(rows: [(word: String, count: Double)])`, `static let shared: GlideLexicon` (bundled file via `Bundle(for:)`), `func merge(words: [String])`, `func candidates(startingNear: CGPoint, endingNear: CGPoint, centers: [SleepTokenLetter: CGPoint], radius: CGFloat) -> [GlideWord]`

- [ ] **Step 1: Write the build script**

```python
#!/usr/bin/env python3
"""Build the glide lexicon from Norvig's count_1w.txt (word<TAB>count, from the
Google Web Trillion Word Corpus; the data is free to use — norvig.com/ngrams).

Usage: python3 scripts/build_glide_lexicon.py count_1w.txt Shared/Resources/glide_lexicon.txt
"""
import re
import sys

TOP_N = 50_000
WORD = re.compile(r"^[a-z]{2,20}$")

# count_1w.txt strips apostrophes, so contractions are re-added by hand with
# counts on the same scale as the corpus (rough web frequencies).
CONTRACTIONS = {
    "it's": 500e6, "i'm": 300e6, "don't": 250e6, "that's": 200e6, "can't": 150e6,
    "you're": 140e6, "i've": 120e6, "he's": 110e6, "she's": 90e6, "i'll": 90e6,
    "won't": 80e6, "they're": 80e6, "there's": 80e6, "let's": 70e6, "what's": 70e6,
    "we're": 70e6, "didn't": 70e6, "i'd": 60e6, "doesn't": 60e6, "isn't": 60e6,
    "you'll": 50e6, "we'll": 50e6, "you've": 50e6, "wasn't": 40e6, "we've": 40e6,
    "he'll": 30e6, "she'll": 30e6, "who's": 30e6, "here's": 30e6, "aren't": 30e6,
    "they'll": 25e6, "they've": 25e6, "wouldn't": 25e6, "couldn't": 25e6,
    "shouldn't": 20e6, "haven't": 20e6, "hasn't": 20e6, "weren't": 15e6,
    "you'd": 15e6, "we'd": 12e6, "they'd": 10e6, "hadn't": 8e6,
}

def main(source: str, dest: str) -> None:
    rows: list[tuple[str, float]] = []
    with open(source) as handle:
        for line in handle:
            parts = line.split()
            if len(parts) != 2 or not WORD.match(parts[0]):
                continue
            rows.append((parts[0], float(parts[1])))
    rows.sort(key=lambda r: -r[1])
    rows = rows[:TOP_N] + list(CONTRACTIONS.items())
    rows.sort(key=lambda r: -r[1])
    with open(dest, "w") as out:
        for word, count in rows:
            out.write(f"{word}\t{int(count)}\n")
    print(f"wrote {len(rows)} words to {dest}")

if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])
```

- [ ] **Step 2: Generate the resource**

```bash
mkdir -p Shared/Resources
curl -sSL https://norvig.com/ngrams/count_1w.txt -o /tmp/count_1w.txt
python3 scripts/build_glide_lexicon.py /tmp/count_1w.txt Shared/Resources/glide_lexicon.txt
wc -l Shared/Resources/glide_lexicon.txt   # expect ~50042
head -3 Shared/Resources/glide_lexicon.txt # expect "the", "of", "and" with counts
```

- [ ] **Step 3: Write the failing test**

```swift
// SleepTokenKBTests/GlideLexiconTests.swift
import XCTest
@testable import SleepTokenKB

final class GlideLexiconTests: XCTestCase {

    /// Toy geometry: three keys on a line, 100pt apart.
    private let centers: [SleepTokenLetter: CGPoint] = [
        .a: CGPoint(x: 0, y: 0), .s: CGPoint(x: 100, y: 0), .d: CGPoint(x: 200, y: 0),
    ]

    func testPathCollapsesAdjacentDuplicatesAndStripsApostrophes() {
        let lexicon = GlideLexicon(rows: [("hello", 100), ("don't", 50)])
        let hello = lexicon.candidates(
            startingNear: CGPoint(x: 0, y: 0), endingNear: CGPoint(x: 0, y: 0),
            centers: [.h: .zero, .e: .zero, .l: .zero, .o: .zero,
                      .d: .zero, .n: .zero, .t: .zero],
            radius: 10
        )
        let paths = Dictionary(uniqueKeysWithValues: hello.map { ($0.word, $0.path) })
        XCTAssertEqual(paths["hello"], [.h, .e, .l, .o], "adjacent double letters share one key")
        XCTAssertEqual(paths["don't"], [.d, .o, .n, .t], "the apostrophe is not a key")
    }

    func testCandidatesArePrunedByFirstAndLastKey() {
        let lexicon = GlideLexicon(rows: [("as", 100), ("ad", 90), ("sad", 80), ("dad", 70)])
        let fromA = lexicon.candidates(
            startingNear: CGPoint(x: 5, y: 0), endingNear: CGPoint(x: 105, y: 0),
            centers: centers, radius: 30
        )
        XCTAssertEqual(Set(fromA.map(\.word)), ["as"], "only a→s survives both gates")
    }

    func testFrequencyIsNormalizedAndOrdered() {
        let lexicon = GlideLexicon(rows: [("as", 1_000_000), ("ad", 10)])
        let all = lexicon.candidates(
            startingNear: .zero, endingNear: CGPoint(x: 300, y: 0),
            centers: centers, radius: 1_000
        )
        let byWord = Dictionary(uniqueKeysWithValues: all.map { ($0.word, $0.frequency) })
        XCTAssertEqual(byWord["as"], 1.0, accuracy: 0.0001)
        XCTAssertEqual(byWord["ad"], 0.0, accuracy: 0.0001)
    }

    func testMergedSupplementaryWordsBecomeCandidates() {
        let lexicon = GlideLexicon(rows: [("as", 100)])
        lexicon.merge(words: ["Ada"])
        let found = lexicon.candidates(
            startingNear: .zero, endingNear: CGPoint(x: 5, y: 0),
            centers: centers, radius: 250
        )
        XCTAssertTrue(found.contains { $0.word == "Ada" && $0.path == [.a, .d, .a] })
        lexicon.merge(words: ["Ada"])   // idempotent
        XCTAssertEqual(found.filter { $0.word == "Ada" }.count, 1)
    }

    func testBundledLexiconLoadsWithContractions() {
        let lexicon = GlideLexicon.shared
        XCTAssertGreaterThan(lexicon.wordCount, 45_000)
        XCTAssertTrue(lexicon.containsWord("the"))
        XCTAssertTrue(lexicon.containsWord("don't"))
        XCTAssertFalse(lexicon.containsWord("a"), "single-letter words are tap territory")
    }
}
```

- [ ] **Step 4: Run to verify failure** — same test command; expected: compile FAILURE, `cannot find 'GlideLexicon'`

- [ ] **Step 5: Write the implementation**

```swift
// Shared/GlideLexicon.swift
import CoreGraphics
import Foundation

/// One glide-typable word: its display form, the key path that draws it, and a
/// log-normalized frequency the decoder blends into its score.
public struct GlideWord: Equatable {
    public let word: String
    public let path: [SleepTokenLetter]
    public let frequency: Double
}

/// The glide dictionary. Bundled words come from `glide_lexicon.txt` (built by
/// scripts/build_glide_lexicon.py); the user's supplementary lexicon (contact
/// names, text replacements) merges in at a fixed mid-high frequency. Entries
/// are bucketed by first path letter so pruning touches a fraction of the list.
public final class GlideLexicon {

    private struct Entry {
        let word: String
        let path: [SleepTokenLetter]
        let frequency: Double
    }

    private var buckets: [SleepTokenLetter: [Entry]] = [:]
    private var known: Set<String> = []
    public private(set) var wordCount = 0

    /// Loaded lazily on first use; `prepareForAppearance` warms it off-main so the
    /// first glide never pays the parse.
    public static let shared: GlideLexicon = {
        guard let url = Bundle(for: GlideLexicon.self)
            .url(forResource: "glide_lexicon", withExtension: "txt"),
              let text = try? String(contentsOf: url, encoding: .utf8) else {
            return GlideLexicon(rows: [])
        }
        let rows: [(String, Double)] = text.split(separator: "\n").compactMap { line in
            let parts = line.split(separator: "\t")
            guard parts.count == 2, let count = Double(parts[1]) else { return nil }
            return (String(parts[0]), count)
        }
        return GlideLexicon(rows: rows)
    }()

    public init(rows: [(word: String, count: Double)]) {
        guard !rows.isEmpty else { return }
        let logs = rows.map { log(max($0.count, 1)) }
        let lo = logs.min()!, hi = logs.max()!
        let span = max(hi - lo, .ulpOfOne)
        for (row, logCount) in zip(rows, logs) {
            add(word: row.word, frequency: (logCount - lo) / span)
        }
    }

    /// Contact names and text replacements from `requestSupplementaryLexicon`.
    /// Fixed 0.7 frequency: a name should outrank mid-list vocabulary. Idempotent.
    public func merge(words: [String]) {
        for word in words { add(word: word, frequency: 0.7) }
    }

    private func add(word: String, frequency: Double) {
        let path = Self.path(of: word)
        guard path.count >= 2, !known.contains(word.lowercased()) else { return }
        known.insert(word.lowercased())
        wordCount += 1
        buckets[path[0], default: []].append(Entry(word: word, path: path, frequency: frequency))
    }

    /// Lowercased letters only, adjacent duplicates collapsed: the finger visits
    /// "l" once in "hello", and the apostrophe in "don't" is not a key.
    static func path(of word: String) -> [SleepTokenLetter] {
        var result: [SleepTokenLetter] = []
        for character in word.lowercased() {
            guard let letter = SleepTokenLetter(rawValue: String(character)) else { continue }
            if result.last != letter { result.append(letter) }
        }
        return result
    }

    public func containsWord(_ word: String) -> Bool { known.contains(word.lowercased()) }

    /// Every word whose first path key is within `radius` of the trace start AND
    /// whose last path key is within `radius` of the trace end.
    public func candidates(
        startingNear start: CGPoint,
        endingNear end: CGPoint,
        centers: [SleepTokenLetter: CGPoint],
        radius: CGFloat
    ) -> [GlideWord] {
        let startLetters = centers.filter { hypot($0.value.x - start.x, $0.value.y - start.y) <= radius }
        var results: [GlideWord] = []
        for letter in startLetters.keys {
            for entry in buckets[letter] ?? [] {
                guard let lastCenter = centers[entry.path.last!] else { continue }
                guard hypot(lastCenter.x - end.x, lastCenter.y - end.y) <= radius else { continue }
                results.append(GlideWord(word: entry.word, path: entry.path, frequency: entry.frequency))
            }
        }
        return results
    }
}
```

- [ ] **Step 6: Wire the resource into both targets**

In `project.yml`:
- Extension target sources, after the `Shared/PageAfterSpace.swift` line:
```yaml
      - path: Shared/GlideLexicon.swift
      - path: Shared/Resources/glide_lexicon.txt
```
- The app target already includes `- path: Shared`, and xcodegen assigns non-source files in a sources path to the resources build phase. Run `xcodegen generate`, then **verify** both targets got the resource:
```bash
grep -c "glide_lexicon.txt" SleepTokenKB.xcodeproj/project.pbxproj   # expect >= 3 (1 fileref + 2 build files)
```
If the app target did not pick it up, add `- path: Shared/Resources/glide_lexicon.txt` to its sources list explicitly.

- [ ] **Step 7: Run tests** — expected: all `GlideLexiconTests` PASS, suite green.

- [ ] **Step 8: Commit**

```bash
git add scripts/build_glide_lexicon.py Shared/Resources/glide_lexicon.txt Shared/GlideLexicon.swift SleepTokenKBTests/GlideLexiconTests.swift project.yml SleepTokenKB.xcodeproj/project.pbxproj
git commit -m "Bundle a 50k-word frequency lexicon with first/last-key pruning"
```

---

### Task 3: GlideDecoder — resample, template, score, fallback

**Files:**
- Create: `Shared/GlideDecoder.swift`
- Test: `SleepTokenKBTests/GlideDecoderTests.swift`
- Modify: `project.yml` (extension sources: `- path: Shared/GlideDecoder.swift`)

**Interfaces:**
- Consumes: `KeyCenters.qwerty(availableWidth:keyHeight:)`, `GlideLexicon.candidates(startingNear:endingNear:centers:radius:)`, `GlideWord`
- Produces:
  - `struct Result: Equatable { let word: String; let score: Double }` (lower is better)
  - `GlideDecoder.decode(trace: [CGPoint], centers: [SleepTokenLetter: CGPoint], keyUnit: CGFloat, lexicon: GlideLexicon, limit: Int = 4) -> [Result]`
  - `GlideDecoder.nearestLetterSequence(trace: [CGPoint], centers: [SleepTokenLetter: CGPoint]) -> String`
  - Named tuning constants: `pruneRadiusFactor = 1.5`, `widenedPruneRadiusFactor = 2.5`, `frequencyWeight = 0.45`, `endpointWeight = 0.35`, `sampleCount = 64`

Scoring: resample the trace and each candidate's template polyline to 64 arc-length-equidistant points; shape cost = mean pointwise Euclidean distance divided by `keyUnit`; endpoint cost = the first-point and last-point distances averaged and divided by `keyUnit` (the SHARK² location channel's start/end anchoring — where a glide begins and ends is the user's most deliberate signal); total score = shape cost + `endpointWeight` × endpoint cost − `frequencyWeight` × frequency. Length gate: reject candidates whose template length is outside `[0.3 × traceLength, 3 × traceLength + 2 × keyUnit]`.

> **Amended 2026-08-02 during execution.** The original formula (shape − frequency
> only) was measured against the real lexicon and geometry: "hello" cannot beat
> the corpus-heavier "help" at any licensed `frequencyWeight`, and no path-only
> score can ever split "pit"/"pot"/"put" — i, o, and u lie exactly on the p→t
> segment, so all three templates resample to the same straight line. The
> endpoint term (already anticipated by the spec's "start/end anchoring")
> resolves the first; the second is a true geometric tie the commit model
> carries in the suggestion bar, and the adversarial test now asserts exactly
> that, plus a mid-path pair (form/from) that geometry genuinely can resolve.
> `endpointWeight` tunable 0.2–0.5 by the same rule as `frequencyWeight`.

- [ ] **Step 1: Write the failing test**

```swift
// SleepTokenKBTests/GlideDecoderTests.swift
import XCTest
@testable import SleepTokenKB

/// The accuracy floor for the engine, run on real QWERTY geometry at iPhone width.
/// Ideal traces are the word's own template polyline — if the engine cannot decode
/// its own templates, nothing else matters. Jitter uses a seeded generator: a
/// flaky accuracy suite would teach everyone to ignore it.
final class GlideDecoderTests: XCTestCase {

    private let width: CGFloat = 393
    private var centers: [SleepTokenLetter: CGPoint]!
    private var unit: CGFloat!

    override func setUp() {
        super.setUp()
        centers = KeyCenters.qwerty(availableWidth: width, keyHeight: 40)
        unit = KeyboardMetrics.keyUnit(availableWidth: width)
    }

    private func idealTrace(for word: String) -> [CGPoint] {
        GlideLexicon.path(of: word).map { centers[$0]! }
    }

    private func decode(_ trace: [CGPoint], lexicon: GlideLexicon) -> [String] {
        GlideDecoder.decode(trace: trace, centers: centers, keyUnit: unit,
                            lexicon: lexicon, limit: 4).map(\.word)
    }

    func testIdealTracesForCommonWordsDecodeTopOne() {
        let lexicon = GlideLexicon.shared
        for word in ["the", "and", "you", "hello", "keyboard", "ritual", "sleep"] {
            XCTAssertEqual(decode(idealTrace(for: word), lexicon: lexicon).first, word,
                           "ideal trace for '\(word)' must decode first")
        }
    }

    /// Words sharing a collapsed path ("to"/"too") legitimately tie on shape, so
    /// the broad sweep asserts top-3, not top-1.
    func testIdealTracesForTop200WordsDecodeTopThree() {
        let lexicon = GlideLexicon.shared
        for word in lexicon.mostFrequentWords(200) where GlideLexicon.path(of: word).count >= 2 {
            let top = decode(idealTrace(for: word), lexicon: lexicon)
            XCTAssertTrue(top.prefix(3).contains(word),
                          "'\(word)' missing from top-3: \(top)")
        }
    }

    func testJitteredTracesDecodeTopThree() {
        let lexicon = GlideLexicon.shared
        var rng = SplitMix64(seed: 0x5EED)
        var hits = 0
        let words = lexicon.mostFrequentWords(100).filter { GlideLexicon.path(of: $0).count >= 3 }
        for word in words {
            let jittered = idealTrace(for: word).map { point -> CGPoint in
                let dx = CGFloat(rng.nextUniform() - 0.5) * unit * 0.5
                let dy = CGFloat(rng.nextUniform() - 0.5) * unit * 0.5
                return CGPoint(x: point.x + dx, y: point.y + dy)
            }
            if decode(jittered, lexicon: lexicon).prefix(3).contains(word) { hits += 1 }
        }
        XCTAssertGreaterThanOrEqual(Double(hits) / Double(words.count), 0.9,
                                    "jittered accuracy fell below 90%")
    }

    /// pit/pot/put share one ideal trace — a straight line along the top row,
    /// because i, o, and u all lie ON the p→t segment. No score over the path
    /// alone can split them; the commit model carries that ambiguity in the
    /// bar, so all three must be offered. Pairs whose mid-path shapes genuinely
    /// differ (form/from swap their zigzag) must still resolve top-1.
    func testAdversarialPairsResolveByPathOrSurfaceInAlternates() {
        let lexicon = GlideLexicon.shared
        let sharedLine = decode(idealTrace(for: "pit"), lexicon: lexicon)
        for word in ["pit", "pot", "put"] {
            XCTAssertTrue(sharedLine.contains(word),
                          "'\(word)' missing from the shared p-t line's candidates: \(sharedLine)")
        }
        XCTAssertEqual(decode(idealTrace(for: "form"), lexicon: lexicon).first, "form")
        XCTAssertEqual(decode(idealTrace(for: "from"), lexicon: lexicon).first, "from")
        XCTAssertTrue(decode(idealTrace(for: "jello"), lexicon: lexicon).prefix(3).contains("jello"))
    }

    func testEmptyCandidatesFallBackToNearestLetters() {
        let empty = GlideLexicon(rows: [])
        let straight = idealTrace(for: "qp")
        XCTAssertTrue(GlideDecoder.decode(trace: straight, centers: centers, keyUnit: unit,
                                          lexicon: empty, limit: 4).isEmpty)
        XCTAssertEqual(GlideDecoder.nearestLetterSequence(trace: straight, centers: centers),
                       "qp", "a straight drag has no corners — only its endpoints speak")
        let elbow = idealTrace(for: "qpm")   // along the top row, then down to m
        XCTAssertEqual(GlideDecoder.nearestLetterSequence(trace: elbow, centers: centers),
                       "qpm", "the corner at p is a deliberate point and must survive")
    }

    /// Regression tripwire, not a benchmark: debug builds run this unoptimized,
    /// so the ceiling is deliberately loose — it catches an accidental
    /// order-of-magnitude regression, not a lost millisecond. The real budget
    /// (50ms, release, on device) is verified by hand on device.
    func testDecodeStaysInsideTheLatencyBudget() {
        let lexicon = GlideLexicon.shared
        let trace = idealTrace(for: "keyboard")
        _ = GlideDecoder.decode(trace: trace, centers: centers, keyUnit: unit,
                                lexicon: lexicon, limit: 4)   // warm the lexicon
        let start = ContinuousClock.now
        for _ in 0..<5 {
            _ = GlideDecoder.decode(trace: trace, centers: centers, keyUnit: unit,
                                    lexicon: lexicon, limit: 4)
        }
        let elapsed = ContinuousClock.now - start
        let seconds = Double(elapsed.components.seconds)
            + Double(elapsed.components.attoseconds) / 1e18
        XCTAssertLessThan(seconds / 5, 0.15, "decode regressed an order of magnitude")
    }
}

/// Deterministic RNG so jitter is identical on every run.
struct SplitMix64 {
    private var state: UInt64
    init(seed: UInt64) { state = seed }
    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
    mutating func nextUniform() -> Double { Double(next() >> 11) / Double(1 << 53) }
}
```

This requires one lexicon addition — declare it in this task, implement in `GlideLexicon.swift`:
```swift
    /// The N most frequent words, for the accuracy suite.
    public func mostFrequentWords(_ n: Int) -> [String] {
        buckets.values.flatMap { $0 }
            .sorted { $0.frequency > $1.frequency }
            .prefix(n).map(\.word)
    }
```

- [ ] **Step 2: Run to verify failure** — expected: compile FAILURE, `cannot find 'GlideDecoder'`

- [ ] **Step 3: Write the implementation**

```swift
// Shared/GlideDecoder.swift
import CoreGraphics
import Foundation

/// Path-template matching: score the finger's trace against each candidate word's
/// ideal polyline through the key centers (SHARK² lineage). Deterministic and
/// synchronous — decode runs on lift, on the main actor, inside a strict budget;
/// pruning (GlideLexicon) keeps the scored set in the hundreds.
public enum GlideDecoder {

    public struct Result: Equatable {
        public let word: String
        public let score: Double   // lower is better
    }

    public static let sampleCount = 64
    public static let pruneRadiusFactor: CGFloat = 1.5
    public static let widenedPruneRadiusFactor: CGFloat = 2.5
    public static let frequencyWeight = 0.45
    /// Start/end anchoring: where a glide begins and ends is the user's most
    /// deliberate signal, so endpoint misses cost more than mid-path wobble.
    public static let endpointWeight = 0.35

    public static func decode(
        trace: [CGPoint],
        centers: [SleepTokenLetter: CGPoint],
        keyUnit: CGFloat,
        lexicon: GlideLexicon,
        limit: Int = 4
    ) -> [Result] {
        guard let start = trace.first, let end = trace.last, trace.count >= 2 else { return [] }

        var pool = lexicon.candidates(startingNear: start, endingNear: end,
                                      centers: centers, radius: pruneRadiusFactor * keyUnit)
        if pool.isEmpty {
            // One widening only: the trace may have started sloppily off-key.
            pool = lexicon.candidates(startingNear: start, endingNear: end,
                                      centers: centers, radius: widenedPruneRadiusFactor * keyUnit)
        }
        guard !pool.isEmpty else { return [] }

        let sampled = resample(trace, to: sampleCount)
        let traceLength = length(of: trace)

        var results: [Result] = []
        results.reserveCapacity(pool.count)
        for candidate in pool {
            let polyline = candidate.path.compactMap { centers[$0] }
            guard polyline.count == candidate.path.count else { continue }
            let templateLength = length(of: polyline)
            // A word whose drawn shape is wildly longer or shorter than the trace
            // cannot be what the finger meant, whatever the endpoints say.
            guard templateLength >= 0.3 * traceLength,
                  templateLength <= 3 * traceLength + 2 * keyUnit else { continue }
            let template = resample(polyline, to: sampleCount)
            var total: CGFloat = 0
            for index in 0..<sampleCount {
                total += hypot(sampled[index].x - template[index].x,
                               sampled[index].y - template[index].y)
            }
            let shapeCost = Double(total / CGFloat(sampleCount) / keyUnit)
            let endpointCost = Double(
                (hypot(sampled[0].x - template[0].x,
                       sampled[0].y - template[0].y)
                 + hypot(sampled[sampleCount - 1].x - template[sampleCount - 1].x,
                         sampled[sampleCount - 1].y - template[sampleCount - 1].y))
                / (2 * keyUnit)
            )
            results.append(Result(word: candidate.word,
                                  score: shapeCost + endpointWeight * endpointCost
                                      - frequencyWeight * candidate.frequency))
        }
        return Array(results.sorted { $0.score < $1.score }.prefix(limit))
    }

    /// Last-resort literal: the trace's deliberate points — its endpoints plus
    /// the corners where the finger turned by more than 45 degrees — mapped to
    /// their nearest keys, adjacent duplicates collapsed. Sampling every point
    /// would transcribe the stroke (a q-to-p drag crosses the whole top row);
    /// corners are where the user meant something. The user gets what they
    /// drew, never silence.
    public static func nearestLetterSequence(
        trace: [CGPoint],
        centers: [SleepTokenLetter: CGPoint]
    ) -> String {
        guard !centers.isEmpty, let first = trace.first, let last = trace.last else { return "" }
        let sampled = resample(trace, to: 16)
        var anchors: [CGPoint] = [first]
        for index in 1..<(sampled.count - 1) {
            let previous = sampled[index - 1]
            let point = sampled[index]
            let next = sampled[index + 1]
            let inbound = atan2(point.y - previous.y, point.x - previous.x)
            let outbound = atan2(next.y - point.y, next.x - point.x)
            var turn = abs(outbound - inbound)
            if turn > .pi { turn = 2 * .pi - turn }
            if turn > .pi / 4 { anchors.append(point) }
        }
        anchors.append(last)
        var letters: [SleepTokenLetter] = []
        for point in anchors {
            let nearest = centers.min {
                hypot($0.value.x - point.x, $0.value.y - point.y)
                    < hypot($1.value.x - point.x, $1.value.y - point.y)
            }!.key
            if letters.last != nearest { letters.append(nearest) }
        }
        return letters.map(\.latin).joined()
    }

    // MARK: - Geometry

    static func length(of points: [CGPoint]) -> CGFloat {
        guard points.count > 1 else { return 0 }
        return (1..<points.count).reduce(CGFloat(0)) { total, index in
            total + hypot(points[index].x - points[index - 1].x,
                          points[index].y - points[index - 1].y)
        }
    }

    /// `count` points spaced equally along the polyline's arc length. A single
    /// point (or zero length) repeats itself, so degenerate inputs stay total.
    static func resample(_ points: [CGPoint], to count: Int) -> [CGPoint] {
        guard let first = points.first else { return [] }
        let total = length(of: points)
        guard total > 0, points.count > 1 else {
            return Array(repeating: first, count: count)
        }
        let step = total / CGFloat(count - 1)
        var result = [first]
        var accumulated: CGFloat = 0
        var index = 1
        var previous = first
        while result.count < count - 1, index < points.count {
            let segment = hypot(points[index].x - previous.x, points[index].y - previous.y)
            if accumulated + segment >= step {
                let t = (step - accumulated) / segment
                let next = CGPoint(x: previous.x + t * (points[index].x - previous.x),
                                   y: previous.y + t * (points[index].y - previous.y))
                result.append(next)
                previous = next
                accumulated = 0
            } else {
                accumulated += segment
                previous = points[index]
                index += 1
            }
        }
        while result.count < count { result.append(points.last!) }
        return result
    }
}
```

- [ ] **Step 4: Add `- path: Shared/GlideDecoder.swift` to the extension sources in `project.yml`, run `xcodegen generate`**

- [ ] **Step 5: Run tests.** Expected: all `GlideDecoderTests` PASS. If `testJitteredTracesDecodeTopThree` fails marginally (< 90%), tune `frequencyWeight` between 0.3 and 0.6 — change the constant, not the test.

- [ ] **Step 6: Commit**

```bash
git add Shared/GlideDecoder.swift Shared/GlideLexicon.swift SleepTokenKBTests/GlideDecoderTests.swift project.yml SleepTokenKB.xcodeproj/project.pbxproj
git commit -m "Decode glide traces by template matching with a frequency blend"
```

---

### Task 4: GlideSession — trace collection

**Files:**
- Create: `Shared/GlideSession.swift`
- Test: `SleepTokenKBTests/GlideSessionTests.swift`
- Modify: `project.yml` (extension sources: `- path: Shared/GlideSession.swift`)

**Interfaces:**
- Produces: `struct GlideSession: Equatable` with `points: [CGPoint]` (read-only), `isActive: Bool`, `mutating func extend(start: CGPoint, to current: CGPoint)`, `mutating func finish(at final: CGPoint) -> [CGPoint]`, `mutating func cancel()`

The movement threshold itself lives at the gesture layer (`DragGesture(minimumDistance: unit / 2)` in Task 7) — `GlideSession` is the sample collector. One drag keeps one `startLocation` for its whole life, so a call whose `start` differs from the session's first point can only be a NEW gesture: the session resets and begins fresh. That is what actually replaces a stale session abandoned by a system-cancelled touch (no `onEnded`, no `cancel()`) — merely "recording start once when idle" would stitch the new gesture onto the abandoned trace.

> **Amended 2026-08-02 during execution.** The Task 4 review traced the original
> "record start only when idle" rule to its failure: a session abandoned without
> `cancel()` kept its points, so the next gesture's samples were appended to the
> stale trace and its own start was dropped. The differing-start rule makes the
> session self-healing on the one signal `DragGesture` guarantees.

- [ ] **Step 1: Write the failing test**

```swift
// SleepTokenKBTests/GlideSessionTests.swift
import XCTest
@testable import SleepTokenKB

final class GlideSessionTests: XCTestCase {

    func testASingleGestureAccumulatesFromOneStart() {
        var session = GlideSession()
        XCTAssertFalse(session.isActive)
        session.extend(start: CGPoint(x: 1, y: 1), to: CGPoint(x: 5, y: 5))
        session.extend(start: CGPoint(x: 1, y: 1), to: CGPoint(x: 9, y: 9))
        XCTAssertEqual(session.points,
                       [CGPoint(x: 1, y: 1), CGPoint(x: 5, y: 5), CGPoint(x: 9, y: 9)],
                       "one drag keeps one start; its samples accumulate")
    }

    func testFinishReturnsTheTraceAndResets() {
        var session = GlideSession()
        session.extend(start: .zero, to: CGPoint(x: 5, y: 0))
        let trace = session.finish(at: CGPoint(x: 10, y: 0))
        XCTAssertEqual(trace, [.zero, CGPoint(x: 5, y: 0), CGPoint(x: 10, y: 0)])
        XCTAssertFalse(session.isActive)
        XCTAssertTrue(session.points.isEmpty)
    }

    /// A system-cancelled touch never calls finish OR cancel; the stale session
    /// must still not leak its points into the next glide. A differing start is
    /// the signal: one drag keeps one startLocation for its whole life.
    func testANewGestureReplacesAStaleSession() {
        var session = GlideSession()
        session.extend(start: .zero, to: CGPoint(x: 5, y: 0))
        // Deliberately no cancel() and no finish(): the touch was abandoned.
        session.extend(start: CGPoint(x: 50, y: 50), to: CGPoint(x: 60, y: 50))
        XCTAssertEqual(session.points,
                       [CGPoint(x: 50, y: 50), CGPoint(x: 60, y: 50)],
                       "the stale trace must be replaced, not continued")
    }

    /// cancel() still exists for the explicit paths (page change, VoiceOver
    /// engaging mid-glide) and must leave the session idle.
    func testCancelLeavesTheSessionIdle() {
        var session = GlideSession()
        session.extend(start: .zero, to: CGPoint(x: 5, y: 0))
        session.cancel()
        XCTAssertFalse(session.isActive)
        XCTAssertTrue(session.points.isEmpty)
    }

    func testFinishOnAnIdleSessionReturnsEmpty() {
        var session = GlideSession()
        XCTAssertTrue(session.finish(at: .zero).isEmpty)
    }
}
```

- [ ] **Step 2: Run to verify failure** — compile FAILURE, `cannot find 'GlideSession'`

- [ ] **Step 3: Write the implementation**

```swift
// Shared/GlideSession.swift
import CoreGraphics

/// Collects one glide's touch samples. A value type held in `@State` so every
/// appended point invalidates the trail overlay; the movement threshold that
/// distinguishes tap from glide lives at the gesture layer
/// (`DragGesture(minimumDistance:)`), not here.
public struct GlideSession: Equatable {
    public private(set) var points: [CGPoint] = []

    public var isActive: Bool { !points.isEmpty }

    public init() {}

    /// Appends a sample. One drag keeps one start location for its whole life,
    /// so a differing `start` can only mean a new gesture — the previous
    /// session was abandoned by a cancelled touch and is replaced, not
    /// continued.
    public mutating func extend(start: CGPoint, to current: CGPoint) {
        if points.isEmpty || points.first != start {
            points = [start]
        }
        points.append(current)
    }

    /// The completed trace, ending at the lift point. Resets for the next glide.
    public mutating func finish(at final: CGPoint) -> [CGPoint] {
        guard isActive else { return [] }
        points.append(final)
        defer { points = [] }
        return points
    }

    public mutating func cancel() { points = [] }
}
```

- [ ] **Step 4: Add to extension sources in `project.yml`, `xcodegen generate`**
- [ ] **Step 5: Run tests** — all `GlideSessionTests` PASS.
- [ ] **Step 6: Commit**

```bash
git add Shared/GlideSession.swift SleepTokenKBTests/GlideSessionTests.swift project.yml SleepTokenKB.xcodeproj/project.pbxproj
git commit -m "Collect glide traces in a value-type session the trail can observe"
```

---

### Task 5: Commit rules — casing, auto-space, whole-word backspace

**Files:**
- Create: `Shared/GlideCommit.swift`
- Test: `SleepTokenKBTests/GlideCommitTests.swift`
- Modify: `project.yml` (extension sources: `- path: Shared/GlideCommit.swift`)

**Interfaces:**
- Consumes: `ShiftState` (`.off` / `.shifted` / `.capsLocked`)
- Produces:
  - `GlideCommit.Insertion: Equatable { let text: String; let word: String }` — `text` is what goes to the proxy (possibly with a leading space); `word` is the cased word alone (its `count` is what backspace removes; it is also the suggestion-bar literal)
  - `GlideCommit.insertion(word: String, shift: ShiftState, contextBefore: String?, lastInsertWasGlide: Bool) -> Insertion`
  - `final class GlideUndo` with `var isArmed: Bool`, `func record(wordLength: Int)`, `func consume() -> Int?`, `func interrupt()`, `func noteLocalChange()`, `func hostTextDidChange()` — the same echo discipline as `SpaceTracker`

- [ ] **Step 1: Write the failing test**

```swift
// SleepTokenKBTests/GlideCommitTests.swift
import XCTest
@testable import SleepTokenKB

final class GlideCommitTests: XCTestCase {

    // MARK: - Casing

    func testShiftStatesCaseTheWord() {
        XCTAssertEqual(GlideCommit.insertion(word: "hello", shift: .off,
                                             contextBefore: nil, lastInsertWasGlide: false).word, "hello")
        XCTAssertEqual(GlideCommit.insertion(word: "hello", shift: .shifted,
                                             contextBefore: nil, lastInsertWasGlide: false).word, "Hello")
        XCTAssertEqual(GlideCommit.insertion(word: "hello", shift: .capsLocked,
                                             contextBefore: nil, lastInsertWasGlide: false).word, "HELLO")
    }

    // MARK: - Auto-space: only between consecutive glides, only after a letter

    func testConsecutiveGlidesAutoSpace() {
        let insertion = GlideCommit.insertion(word: "world", shift: .off,
                                              contextBefore: "hello", lastInsertWasGlide: true)
        XCTAssertEqual(insertion.text, " world")
        XCTAssertEqual(insertion.word, "world", "the word excludes the space — backspace keeps it")
    }

    func testAGlideAfterTappedTextDoesNotAutoSpace() {
        XCTAssertEqual(GlideCommit.insertion(word: "world", shift: .off,
                                             contextBefore: "hello", lastInsertWasGlide: false).text, "world")
    }

    func testAGlideAfterASpaceOrPunctuationDoesNotAutoSpace() {
        for context in ["hello ", "hello.", "", "5"] {
            let insertion = GlideCommit.insertion(word: "world", shift: .off,
                                                  contextBefore: context, lastInsertWasGlide: true)
            XCTAssertEqual(insertion.text, "world", "context '\(context)' must not auto-space")
        }
    }

    // MARK: - GlideUndo lifecycle

    func testConsumeReturnsTheLengthOnceAndDisarms() {
        let undo = GlideUndo()
        undo.record(wordLength: 5)
        XCTAssertTrue(undo.isArmed)
        XCTAssertEqual(undo.consume(), 5)
        XCTAssertNil(undo.consume())
        XCTAssertFalse(undo.isArmed)
    }

    func testAnyOtherKeystrokeDisarms() {
        let undo = GlideUndo()
        undo.record(wordLength: 5)
        undo.interrupt()
        XCTAssertNil(undo.consume())
    }

    /// The settle of our own insert arrives back as a host text change; that echo
    /// must not disarm, while a genuinely external edit must.
    func testTheEchoOfOurOwnEditPassesThroughButExternalEditsDisarm() {
        let undo = GlideUndo()
        undo.record(wordLength: 5)
        undo.noteLocalChange()
        undo.hostTextDidChange()          // the echo
        XCTAssertTrue(undo.isArmed)
        undo.hostTextDidChange()          // a cursor jump, a host-side clear
        XCTAssertFalse(undo.isArmed)
    }
}
```

- [ ] **Step 2: Run to verify failure** — compile FAILURE, `cannot find 'GlideCommit'`

- [ ] **Step 3: Write the implementation**

```swift
// Shared/GlideCommit.swift
import Foundation

/// How a decoded glide word lands in the document.
public enum GlideCommit {

    public struct Insertion: Equatable {
        /// Everything the proxy receives, possibly space-prefixed.
        public let text: String
        /// The cased word alone: the suggestion-bar literal, and the character
        /// count a whole-word backspace removes (the auto-space stays, as stock
        /// leaves it).
        public let word: String
    }

    /// Auto-space joins CONSECUTIVE glides only — "context ends in a letter and
    /// the last insert was also a glide" (spec). A glide after tapped text, after
    /// punctuation, or at a field start inserts bare.
    public static func insertion(
        word: String,
        shift: ShiftState,
        contextBefore: String?,
        lastInsertWasGlide: Bool
    ) -> Insertion {
        let cased: String
        switch shift {
        case .off: cased = word
        case .shifted: cased = word.prefix(1).uppercased() + word.dropFirst()
        case .capsLocked: cased = word.uppercased()
        }
        let needsSpace = lastInsertWasGlide && (contextBefore?.last?.isLetter ?? false)
        return Insertion(text: needsSpace ? " " + cased : cased, word: cased)
    }
}

/// Arms exactly one whole-word backspace after a glide commit, with the same
/// local-echo discipline as `SpaceTracker`: the settle of this keyboard's own
/// edit passes through silently, any external host change disarms.
public final class GlideUndo {
    private var wordLength: Int?
    private var pendingLocalEcho = false

    public init() {}

    public var isArmed: Bool { wordLength != nil }

    public func record(wordLength length: Int) {
        wordLength = length
    }

    /// The armed length, exactly once. The backspace that consumes it deletes
    /// this many characters instead of one.
    public func consume() -> Int? {
        defer { wordLength = nil }
        return wordLength
    }

    /// Any keystroke that is not the consuming backspace, and any field change.
    public func interrupt() {
        wordLength = nil
    }

    public func noteLocalChange() {
        pendingLocalEcho = true
    }

    public func hostTextDidChange() {
        if pendingLocalEcho {
            pendingLocalEcho = false
        } else {
            wordLength = nil
        }
    }
}
```

- [ ] **Step 4: Add to extension sources in `project.yml`, `xcodegen generate`**
- [ ] **Step 5: Run tests** — all `GlideCommitTests` PASS.
- [ ] **Step 6: Commit**

```bash
git add Shared/GlideCommit.swift SleepTokenKBTests/GlideCommitTests.swift project.yml SleepTokenKB.xcodeproj/project.pbxproj
git commit -m "Give glide commits their casing, auto-space, and one-shot undo rules"
```

---

### Task 6: Preference and host-app toggle

**Files:**
- Modify: `Shared/LayoutMode.swift` (the `KeyboardPreferences` enum, after `hapticsEnabled`)
- Modify: `SleepTokenKB/ContentView.swift` (keyboard-defaults card + a `GlideToggle` view after `HapticsToggle`, around line 383)
- Test: `SleepTokenKBTests/KeyboardPreferencesTests.swift` (append one test to the existing class)

**Interfaces:**
- Produces: `KeyboardPreferences.glideTypingEnabled: Bool` (default `true`), `KeyboardPreferences.glideTypingKey = "glideTypingEnabled"`

- [ ] **Step 1: Write the failing test** (append inside the existing `KeyboardPreferencesTests` class; match its setup/teardown conventions — read the file first and mirror how existing tests isolate UserDefaults)

```swift
    func testGlideTypingDefaultsOnAndRoundTrips() {
        XCTAssertTrue(KeyboardPreferences.glideTypingEnabled, "glide ships on")
        KeyboardPreferences.glideTypingEnabled = false
        XCTAssertFalse(KeyboardPreferences.glideTypingEnabled)
        KeyboardPreferences.glideTypingEnabled = true
        XCTAssertTrue(KeyboardPreferences.glideTypingEnabled)
    }
```

- [ ] **Step 2: Run to verify failure** — compile FAILURE, no member `glideTypingEnabled`

- [ ] **Step 3: Implement the preference** (in `Shared/LayoutMode.swift`, inside `KeyboardPreferences`, after the `hapticsEnabled` property)

```swift
    public static let glideTypingKey = "glideTypingEnabled"

    /// Slide-to-type on the QWERTY letters page. On by default, like stock.
    public static var glideTypingEnabled: Bool {
        get { storedBool(glideTypingKey, default: true) }
        set { store(newValue, glideTypingKey) }
    }
```

- [ ] **Step 4: Add the host-app toggle** (in `SleepTokenKB/ContentView.swift`: a private view after `HapticsToggle`, and one row in the keyboard-defaults card after `HapticsToggle()` with the same `Rectangle().fill(Theme.hairline).frame(height: 1)` divider the card uses between rows)

```swift
private struct GlideToggle: View {
    var body: some View {
        PreferenceBacked(
            read: { KeyboardPreferences.glideTypingEnabled },
            write: { KeyboardPreferences.glideTypingEnabled = $0 }
        ) { $enabled in
            Toggle(isOn: $enabled) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Glide typing")
                        .font(.subheadline)
                        .foregroundStyle(Theme.ink)
                    Text("Slide from letter to letter to type a word. QWERTY layout only.")
                        .font(.caption2)
                        .foregroundStyle(Theme.inkDim)
                }
            }
            .tint(Theme.goldDeep)
        }
    }
}
```

And in the defaults card:
```swift
                            HapticsToggle()
                            Rectangle().fill(Theme.hairline).frame(height: 1)
                            GlideToggle()
```

- [ ] **Step 5: Run tests** — new preference test PASSES, suite green (the toggle is view code; the build proves it compiles).
- [ ] **Step 6: Commit**

```bash
git add Shared/LayoutMode.swift SleepTokenKB/ContentView.swift SleepTokenKBTests/KeyboardPreferencesTests.swift
git commit -m "Add the glide typing preference and its host-app toggle"
```

---

### Task 7: Capture layer — gesture and trail on LetterPage

**Files:**
- Modify: `SleepTokenKeyboard/KeyboardRootView.swift` (`LetterPage` struct and its single call site in the root view's `body`)

No unit tests — this is view plumbing over already-tested parts; the deliverable is a green build with the whole suite passing, and the wiring lands in Task 8.

**Interfaces:**
- Consumes: `GlideSession`, `KeyboardMetrics.keyUnit(availableWidth:)`, `KeyPalette.active`
- Produces: `LetterPage` gains `let glideEnabled: Bool` and `let onGlide: (_ trace: [CGPoint], _ availableWidth: CGFloat) -> Void`; call site passes both (wired for real in Task 8, with a placeholder no-op closure acceptable only if Task 8 lands in the same PR — otherwise wire directly per Task 8's `handleGlide`)

- [ ] **Step 1: Extend LetterPage**

Add to `LetterPage`'s stored properties:
```swift
    /// Glide typing: QWERTY-only, off under VoiceOver, additive over the buttons.
    let glideEnabled: Bool
    let onGlide: (_ trace: [CGPoint], _ availableWidth: CGFloat) -> Void

    @State private var glide = GlideSession()
    /// True while the finger is down in THIS gesture. `@GestureState`, not
    /// `@State`, and the difference is the whole point (see BackspaceKey): its
    /// reset also runs when the system CANCELS the touch, so a call banner
    /// mid-glide cannot wedge the keyboard.
    @GestureState private var isGliding = false
    /// Keeps taps suppressed one runloop tick past lift, so the origin key's
    /// Button cannot fire on the same touch-up. During the drag itself the
    /// suppression rides `isGliding`.
    @State private var suppressesTaps = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
```

Wrap the letter action (in the `ForEach(row)` where `LetterKeyButton` is built), replacing `action: { onLetter(letter) }` with:
```swift
                                action: {
                                    guard !(isGliding || suppressesTaps) else { return }
                                    onLetter(letter)
                                }
```

Attach the gesture and trail to the GeometryReader's content (after the existing `.frame(width: geo.size.width, alignment: .top)`):
```swift
            .overlay {
                if glide.isActive {
                    GlideTrailView(points: glide.points, reduceMotion: reduceMotion)
                        .allowsHitTesting(false)
                }
            }
            .simultaneousGesture(glideGesture(width: geo.size.width), including: glideActive ? .all : .subviews)
            .onChange(of: isGliding) { _, active in
                // @GestureState's reset is the only signal a CANCELLED touch
                // gives us: falling while the session is still active means no
                // onEnded came — discard the glide, clear the trail. This is
                // the spec's cancellation clause, and GlideSession.cancel's
                // one production caller.
                guard !active, glide.isActive else { return }
                glide.cancel()
                suppressesTaps = false
            }
```
with, inside `LetterPage`:
```swift
    private var glideActive: Bool {
        glideEnabled && layoutMode == .qwerty && !UIAccessibility.isVoiceOverRunning
    }

    private func glideGesture(width: CGFloat) -> some Gesture {
        let unit = KeyboardMetrics.keyUnit(availableWidth: width)
        return DragGesture(minimumDistance: unit / 2, coordinateSpace: .local)
            .updating($isGliding) { _, state, _ in state = true }
            .onChanged { value in
                guard glideActive else { return }
                if glide.points.first != value.startLocation {
                    // A glide must BEGIN on a letter: a thumb drifting off a
                    // held backspace or shift is not a word. 0.9 units reaches
                    // a letter key's corners and rejects the function keys.
                    guard nearestLetterDistance(to: value.startLocation, width: width)
                        <= unit * 0.9 else { return }
                }
                suppressesTaps = true
                glide.extend(start: value.startLocation, to: value.location)
            }
            .onEnded { value in
                guard glideActive, glide.isActive else { return }
                let trace = glide.finish(at: value.location)
                onGlide(trace, width)
                // Release tap suppression on the next runloop tick, after the
                // origin Button has had its chance to (not) fire for this touch.
                Task { @MainActor in suppressesTaps = false }
            }
    }

    private func nearestLetterDistance(to point: CGPoint, width: CGFloat) -> CGFloat {
        let centers = KeyCenters.qwerty(availableWidth: width, keyHeight: keyHeight)
        return centers.values.map { hypot($0.x - point.x, $0.y - point.y) }.min() ?? .infinity
    }

> **Amended 2026-08-02 during execution.** The Task 7 review caught the original
> gesture recreating the exact cancellation wedge BackspaceKey's own comment
> documents: `suppressesTaps` was cleared only in `onEnded`, which a system-
> cancelled touch never delivers — leaving every letter tap dead behind a
> stale trail. `@GestureState` is the fix the codebase itself teaches: its
> reset fires on cancellation too, and its falling edge (with the session
> still active) is where the discarded glide finally satisfies the spec's
> cancellation clause. The review also caught a thumb drifting off a held
> backspace emitting a word: a glide must now BEGIN within 0.9 key units of a
> letter center. `onEnded` gains the `glideActive` guard so a VoiceOver flip
> mid-drag cannot commit.
```

- [ ] **Step 2: Add the trail view** (file-private, alongside the other key views in `KeyboardRootView.swift`)

```swift
/// The comet trail behind a gliding finger. Reduce Motion gets a uniform line —
/// same information, no animated fade.
private struct GlideTrailView: View {
    let points: [CGPoint]
    let reduceMotion: Bool

    var body: some View {
        Canvas { context, _ in
            guard points.count > 1 else { return }
            if reduceMotion {
                var path = Path()
                path.addLines(points)
                context.stroke(path, with: .color(KeyPalette.active.opacity(0.55)),
                               style: StrokeStyle(lineWidth: 5, lineCap: .round, lineJoin: .round))
            } else {
                // Newest segments brightest: opacity climbs along the trail.
                let count = points.count
                for index in 1..<count {
                    var segment = Path()
                    segment.move(to: points[index - 1])
                    segment.addLine(to: points[index])
                    let progress = Double(index) / Double(count)
                    context.stroke(segment, with: .color(KeyPalette.active.opacity(0.15 + 0.55 * progress)),
                                   style: StrokeStyle(lineWidth: 5, lineCap: .round, lineJoin: .round))
                }
            }
        }
    }
}
```

- [ ] **Step 3: Update the call site** (the `case .letters:` branch of the root `body`'s page switch) — add the two new arguments; wire `onGlide` to `handleGlide` if executing Tasks 7+8 together, else a `{ _, _ in }` placeholder that Task 8 replaces:
```swift
                LetterPage(
                    layoutMode: layoutMode,
                    keyFaceStyle: keyFaceStyle,
                    shift: autoShift.state,
                    keyHeight: keyHeight,
                    hintSize: hintSize,
                    faceSize: letterFaceSize,
                    glideEnabled: glideEnabled,
                    onLetter: insertLetter,
                    onShift: toggleShift,
                    onBackspace: { deleteBackward(isRepeat: $0) },
                    onGlide: handleGlide
                )
```
(`glideEnabled` is a new root `@State`, loaded in Task 8's `loadPreferences` — declare it now: `@State private var glideEnabled = true`.)

- [ ] **Step 4: Run the full test suite** — expected: builds, everything green (behavioral wiring lands next task).
- [ ] **Step 5: Commit**

```bash
git add SleepTokenKeyboard/KeyboardRootView.swift
git commit -m "Capture glide traces on the letter page with a reduced-motion-safe trail"
```

---

### Task 8: Commit wiring, backspace rule, supplementary lexicon, final gate

**Files:**
- Modify: `SleepTokenKeyboard/KeyboardRootView.swift` (root view actions)
- Modify: `SleepTokenKeyboard/KeyboardViewController.swift` (supplementary lexicon)

**Interfaces:**
- Consumes: everything from Tasks 1–7
- Produces: the working feature; no new public API

- [ ] **Step 1: Root-view state** (alongside the existing `@State`s)

```swift
    /// Whole-word backspace bookkeeping for the last glide. Reference type in
    /// `@State` for the same reason `spaceTracker` is: nothing renders it.
    @State private var glideUndo = GlideUndo()
    /// True while the suggestion bar is showing a glide's alternates: the echo of
    /// the glide commit must not overwrite them with spell candidates.
    @State private var showsGlideAlternates = false
```
`glideEnabled` was declared in Task 7. In `loadPreferences()` add:
```swift
        glideEnabled = KeyboardPreferences.glideTypingEnabled
```
In `prepareForAppearance()` add (after `loadPreferences()`):
```swift
        if glideEnabled {
            // Warm the 50k-word parse off-main so the first glide never pays
            // it. The merge hops back to the main actor: candidates() runs on
            // main during a glide, and GlideLexicon is deliberately unlocked —
            // single-actor access IS the synchronization. (Resolves the Task 2
            // review's unsynchronized-state flag.)
            let supplementary = supplementaryWords
            Task.detached(priority: .utility) {
                _ = GlideLexicon.shared   // static-let init is thread-safe
                await MainActor.run {
                    GlideLexicon.shared.merge(words: supplementary)
                }
            }
        }
```
Add the new root-view input (with the other `let`s): `let supplementaryWords: [String]`.

- [ ] **Step 2: The glide handler** (new method after `insertSpace()`)

```swift
    /// A finished glide: decode against the same geometry the page rendered with,
    /// insert stock-style, hand the alternates to the bar, arm whole-word undo.
    private func handleGlide(_ trace: [CGPoint], availableWidth: CGFloat) {
        let unit = KeyboardMetrics.keyUnit(availableWidth: availableWidth)
        let centers = KeyCenters.qwerty(availableWidth: availableWidth, keyHeight: keyHeight)
        let results = GlideDecoder.decode(trace: trace, centers: centers, keyUnit: unit,
                                          lexicon: .shared)
        let word = results.first?.word
            ?? GlideDecoder.nearestLetterSequence(trace: trace, centers: centers)
        guard !word.isEmpty else { return }

        let commit = GlideCommit.insertion(word: word, shift: autoShift.state,
                                           contextBefore: host.contextBefore(),
                                           lastInsertWasGlide: glideUndo.isArmed)
        insert(commit.text)                       // haptic, space window, echo note
        glideUndo.record(wordLength: commit.word.count)
        glideUndo.noteLocalChange()
        autoShift.didInsertLetter()
        applyAutocapitalization()

        suggestions = SuggestionSet(literal: commit.word,
                                    candidates: results.dropFirst().map(\.word))
        showsGlideAlternates = !results.isEmpty
    }
```

Note the ordering trap: `insert()` must call `glideUndo.interrupt()` (Step 3), so `record` comes AFTER `insert` — a glide commit first disarms the previous glide, then arms itself. `lastInsertWasGlide` is read BEFORE `insert` for the same reason.

- [ ] **Step 3: Thread GlideUndo through the existing mutation paths**

In `insert(_:)`, alongside the `spaceTracker` calls:
```swift
        glideUndo.interrupt()
```
In `deleteBackward(isRepeat:)`, at the top:
```swift
        // One backspace right after a glide removes the whole word; the next
        // behaves normally. Repeats never consume it — a held delete is a
        // deliberate different gesture.
        if !isRepeat, let length = glideUndo.consume() {
            haptic()
            for _ in 0..<length { onDeleteBackward() }
            spaceTracker.interrupt()
            spaceTracker.noteLocalChange()
            applyAutocapitalization()
            return
        }
```
Also add `glideUndo.interrupt()` beside the existing `spaceTracker.interrupt()` in the non-glide path of `deleteBackward`, and in `.onChange(of: fieldGeneration)` add:
```swift
            glideUndo.interrupt()
```
In `.onChange(of: hostTextGeneration)` replace the body's first lines with:
```swift
            spaceTracker.hostTextDidChange()
            glideUndo.hostTextDidChange()
            applyAutocapitalization()
            if showsGlideAlternates {
                // The echo of the glide commit: keep the alternates one round.
                showsGlideAlternates = false
            } else {
                refreshSuggestions()
            }
```
In `autoCorrectFinishedWord()`, first line:
```swift
        guard !glideUndo.isArmed else { return }   // a glided word is already a dictionary word
```

- [ ] **Step 4: Supplementary lexicon in the controller** (`KeyboardViewController`)

Add a property: `private var supplementaryWords: [String] = []`
In `viewDidLoad`, after `installKeyboardUI()`:
```swift
        // Contact names and text replacements, folded into the glide lexicon.
        // Arrives async; the next refreshRoot delivers it into the view.
        requestSupplementaryLexicon { [weak self] lexicon in
            DispatchQueue.main.async {
                self?.supplementaryWords = lexicon.entries.map(\.documentText)
                self?.refreshRoot()
            }
        }
```
In `makeRootView()`, pass `supplementaryWords: supplementaryWords` (order must match the struct's property order from Task 7/8).

- [ ] **Step 5: Full gate**

Run the full suite — every existing test plus the five new files must pass. Then build the release configuration compiles cleanly:
```bash
xcodebuild -project SleepTokenKB.xcodeproj -scheme SleepTokenKB -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test 2>&1 | tail -3
```
Expected: `** TEST SUCCEEDED **`

- [ ] **Step 6: Commit**

```bash
git add SleepTokenKeyboard/KeyboardRootView.swift SleepTokenKeyboard/KeyboardViewController.swift
git commit -m "Wire glide commits through the insert path with stock undo and alternates"
```

- [ ] **Step 7: Device checklist for Christian** (report, do not attempt)

Say plainly: tests pass and both targets build; behavior is unverified until the device check. The checklist:
1. Glide "hello" on rune-art caps — word appears on lift, trail follows the finger.
2. Glide two words back-to-back — a single space appears between them.
3. Backspace once after a glide — whole word gone; again — single character.
4. Tap letters normally — no regression, no stray letters after a glide.
5. Sentence start — glided word capitalizes; caps lock — whole word uppercase.
6. Grid layout and 123 page — no glide, no trail.
7. Settings toggle off — gesture gone entirely.
8. VoiceOver on — keys speak and tap normally, no glide.
9. Reduce Motion on — trail is a plain line.

---

## Self-Review (completed)

- **Spec coverage:** scope/QWERTY-only (Tasks 1, 7), commit model (Tasks 5, 8), engine (Task 3), lexicon + supplementary (Tasks 2, 8), session/threshold (Tasks 4, 7), trail + Reduce Motion (Task 7), VoiceOver gate (Task 7), settings toggle (Task 6), auto-space/casing/undo (Tasks 5, 8), correction interplay (Task 8 Steps 2–3), fallback literal (Tasks 3, 8), latency budget (Task 3 measure), device verification boundary (Task 8 Step 7). No gaps found.
- **Placeholder scan:** none; every step carries code or an exact command.
- **Type consistency:** `GlideLexicon.candidates(startingNear:endingNear:centers:radius:)` used identically in Tasks 2/3; `GlideCommit.Insertion.word`/`.text` consistent across 5/8; `GlideSession.extend/finish(at:)/cancel` consistent across 4/7; `KeyCenters.qwerty(availableWidth:keyHeight:)` consistent across 1/3/8; `mostFrequentWords(_:)` declared in Task 3 and added to `GlideLexicon`.
