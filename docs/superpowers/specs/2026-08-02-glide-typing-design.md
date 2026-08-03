# Glide Typing — Design

**Date:** 2026-08-02
**Status:** Approved pending user review
**Feature:** Slide a finger from letter to letter to type a word, on the Ritual
Keyboard extension.

## Decisions already made

These were settled in brainstorming and are not open:

| Decision | Choice | Why |
|---|---|---|
| Scope | QWERTY layout only, both key faces (rune art and ABC) | Glide rides QWERTY muscle memory, which works without reading the caps, so the rune face keeps the feature. The grid layout is alphabetical — nobody has a trained path for it — and stays tap-only. |
| Commit model | Stock behavior | Best match inserts on finger lift; alternates appear in the suggestion bar; one backspace immediately after a glide removes the whole word. |
| Engine | Path-template matching | Each candidate word's ideal polyline through the key centers is compared to the finger trace by shape distance, blended with word frequency. The SHARK² lineage every production glide keyboard descends from. Deterministic, unit-testable, explainable failures, all on-device. |

Rejected: probabilistic beam search (tuning cycles would each cost a TestFlight
round, since the keyboard cannot be driven in the simulator), corner-sequence
matching (visibly worse on straight-line words), CoreML (no training data, opaque,
memory-hungry in an extension).

## Architecture

Four pure components in `Shared/`, one gesture layer in the extension. The pure
parts follow the `PeriodShortcut` / `PageAfterSpace` precedent: text-entry rules
live outside the views so they can be tested without a live `UITextDocumentProxy`.

### KeyCenters (Shared)

Pure function from `(availableWidth, keyHeight)` to the center point of every
QWERTY letter key. Derived from the same `KeyboardMetrics` arithmetic `LetterPage`
lays out with (`keyUnit`, `homeRowInset`, `rowGap`, `keyGap`), so the decoder's
geometry is provably the rendered truth. A parity test locks the two together.
No grid-layout geometry exists: glide is QWERTY-only by construction.

### GlideLexicon (Shared)

A bundled word-frequency list: roughly the top 50k English words plus apostrophe
contractions, about 600KB, loaded once and held outside the view tree the way
`SuggestionEngine` is. Merged at runtime with the user's supplementary lexicon
from `requestSupplementaryLexicon` (contact names, text replacements). Exposes
candidates pruned by first/last key neighborhood so the decoder never scores the
whole dictionary.

### GlideDecoder (Shared)

Resamples the finger trace to a fixed point count. For each candidate that
survives pruning, builds the ideal polyline through the key centers lazily
(templates depend on geometry, so nothing is precomputed or cached across
widths), scores by shape distance blended with word frequency, and returns the
top candidate plus up to three alternates — the bar's capacity. Performance
budget: decode on lift in well under 50ms — pruning keeps the
scored set in the hundreds, and DTW over a few dozen resampled points is cheap.

### GlideSession (Shared)

The tap-versus-glide state machine. A touch that stays within a movement
threshold is a tap and belongs to the existing buttons; once it exceeds the
threshold it becomes a glide and collects samples until lift.
Starting threshold: half a key width, held as a named constant and tuned on
device.
Also owns cancellation: a system-cancelled touch discards the glide.

### Capture layer (extension)

`LetterPage` gains a `simultaneousGesture` drag and a trail overlay drawn in the
`KeyPalette` accent. The existing `LetterKeyButton`s are untouched — taps, key
repeat, and VoiceOver behave exactly as today, because SwiftUI buttons already
cancel when a touch moves off them. Glide is purely additive.

### Data flow

touch → `GlideSession` (threshold, samples) → lift → `GlideDecoder` (geometry
from `KeyCenters`, candidates from `GlideLexicon`) → `KeyboardRootView` inserts
the top word through the existing `insert()` path (haptic, `SpaceTracker`
interrupt, autocapitalization re-derivation all come free) → alternates go to
the existing `SuggestionBar`.

## Interaction rules

**Commit.** On lift, the top candidate inserts through `insert()`. If the
context before the cursor ends in a letter and the last insert was also a glide,
a space is inserted first — consecutive glides auto-space, as stock does. The
auto-space never feeds `SpaceTracker`'s double-space window; it is not a
spacebar press.

**Capitalization.** From `AutoShift`'s current state: sentence start or manual
shift capitalizes the first letter; caps lock uppercases the whole word. Shift
re-derives afterward exactly as a tapped letter would.

**Correction interplay.** A glided word is already a dictionary word:
`autoCorrectFinishedWord` skips it, so the space after a glide never rewrites
it. The suggestion bar shows the glide's alternates instead of spell candidates
until the next keystroke; tapping one swaps the word via `replaceCurrentWord`.

**Backspace.** One backspace immediately after a glide removes the whole word.
The "last insert was a glide" flag clears on any other keystroke, on field
change, and on any external host edit — the same discipline `spaceTracker`
follows. The next backspace is an ordinary single-character delete.

**Pages.** The gesture exists only on the letters page under QWERTY. Symbol,
emoji, and grid layouts never see it.

## Failure handling

- Below-threshold movement is a tap; the button under the finger owns it.
- Empty candidate set after pruning: widen the prune once; if still empty,
  insert the nearest-key letter sequence literally. The user gets what they
  drew, never silence.
- System touch cancellation (the case `KeyRepeat` already survives): the glide
  is discarded, nothing inserts, the trail clears.
- Haptic: one light tap on commit, behind the existing Full Access gate. No
  per-key-crossing haptics.

## Settings

One "Glide typing" toggle in the host app's keyboard defaults card (stock has
the same switch), stored via `KeyboardPreferences`, default on.

## Accessibility

- **VoiceOver:** buttons are unchanged and the glide gesture does not engage
  under VO — matching stock, where slide-to-type and VO touch typing do not mix.
- **Reduce Motion:** the trail renders as a plain line with no fade animation.
- **Dynamic Type:** unaffected; geometry derives from the layout itself.

WCAG 2.2 AA remains the shipped standard; nothing in this feature lowers it.

## Testing

Four suites in `SleepTokenKBTests`:

1. **Geometry parity** — `KeyCenters` equals `LetterPage`'s layout math across
   several widths and key heights.
2. **Decoder accuracy** — ideal center-line traces for the top 200 words decode
   top-3 (words sharing a collapsed path — to/too — legitimately tie on shape;
   the strongest common words are asserted top-1); jittered traces decode
   top-3; adversarial pairs (pit/pot, hello/jello) asserted explicitly. Both
   key faces share geometry, so one suite covers both.
3. **Session mechanics** — threshold behavior, sample collection, cancellation.
4. **Commit rules** — auto-space, capitalization, whole-word backspace, and the
   flag's clearing conditions.

Final behavioral verification happens on device by Christian; the keyboard
cannot be driven in the simulator, which is why every rule above lives in a pure
component.

## Out of scope (v1)

- Grid-layout glide.
- Personalization / learning from accepted words across sessions.
- Multilingual lexicons; the keyboard declares `en-US`.
- Per-key-crossing haptics or sounds.
- Any change to the host app UI beyond the one settings toggle (the welcome
  redesign is its own workstream and spec).
