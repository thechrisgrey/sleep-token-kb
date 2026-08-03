# Welcome Redesign — Design

**Date:** 2026-08-02
**Status:** Approved pending user review
**Surface:** the host app's entry experience. The keyboard extension is untouched.

## The problem

Opening the app feels like dropping into a settings menu: the first screen mixes
navigation (three cards), explanation (the "Two ways to write" card), and live
settings (theme picker, layout, key face, haptics, glide) in one long scroll.
Users are forced to read everything to start using anything. The fix is
structural — an inviting welcome that routes — with the visual system untouched:
palette, serif display, tracked caps, card language, and both themes are settled
decisions and stay exactly as they are.

## Decisions already made

| Decision | Choice |
|---|---|
| Structure | Welcome + doors: hero, state-aware enable card, three destination cards, footer. All settings behind a Settings door. Existing `NavigationStack`; no tab bar. |
| Feel | Spacious and ceremonial: the hero breathes, copy trimmed hard, the page reads as an entrance hall. Cut copy moves to the screens it describes. |
| Jerry tally | New: a count of found Jerrys, in Settings, visible only after the first find. Counts without hinting — no names, no locations, no checklist. |

## The welcome screen

Five elements, vertical rhythm, inside the existing `NavigationStack`,
`RitualBackground`, and `readableColumn`:

1. **Hero, opened up.** Overline, serif title, rune wordmark with its Jerry
   (`heroRow`) — unchanged. The value-prop paragraph compresses to one sentence
   in `inkDim`: "English everywhere, runes on the keys — and real runes in
   Rune Pad." More air above and below; the hero owns the first third of the
   screen.
2. **The threshold card** — the one state-aware element. While the keyboard is
   not enabled: a full `DestinationCard` for "Enable the keyboard," first
   position, the only gold glyph on the page. Once enabled it disappears
   entirely. Detection reads the system's enabled-keyboards preference
   (`AppleKeyboards`) looking for the extension's bundle identifier, wrapped in
   one small pure rule so the read is testable; an unreadable or empty result
   is treated as not-enabled and the card stays — showing setup to someone who
   finished it is a shrug, hiding it from someone who has not is a dead end.
   The enable guide gains a "Done — hide this" affordance as the manual
   override for that degraded case, persisted via the app's preference pattern.
3. **Three destination cards** — Rune Pad, The alphabet, Settings — existing
   `DestinationCard` form: glyph, title, one detail line, chevron. No section
   label above them: with four items on the page the tracked-caps scaffolding
   is not needed, and PRODUCT.md's tension note says not to reach for it on new
   surfaces by reflex.
4. **Footer, unchanged.** Theme ornament, dedication, unaffiliated statement,
   its Jerry (`homeFooter`).
5. **Nothing else.** No inline pickers, no explainer card, no toggles.

## The Settings screen (new)

Pushed from the welcome. Title in the display voice. Card language and
tracked-caps section labels — a directory screen is where that scaffolding
belongs:

- **Appearance** — the theme picker card moved intact: segmented control,
  captions, ceremony trigger, Jerry (`appearanceCard`).
- **Keyboard** — the defaults card moved intact: Layout, Key look, Haptics,
  Glide typing; same `PreferenceBacked` rows and hairline dividers.
- **Two ways to write** — the explainer card moved intact, Jerry (`waysCard`).
  Reference material now, not front-door reading.
- **The tally** — a quiet row rendered only when `hunt.found.count > 0`:
  the count written out ("Four of ten"), serif, one rune ornament, nothing
  tappable, no hints. When the count reaches ten, one line appears beneath it
  offering the Damocles reveal again, so the reward stops being a missable
  one-time event. Wording and visibility live in one pure rule so both are
  unit-tested.

## Hunt integrity

- All ten `JerrySpot` raw values are untouched; found-state persists.
- `waysCard` and `appearanceCard` change screens but stay on the same host
  cards. A found Jerry stays found; an unfound one is still findable.
- The tally's VoiceOver label speaks only the count. Every Jerry keeps its
  labeled-element treatment; the hunt remains playable without sight and
  secret without exceptions.
- The tally must not appear anywhere before the first find — a newcomer never
  learns from the UI that a hunt exists.

## Copy moves, not deletions

- Hero paragraph, second half → enable guide (most of it already exists there;
  reconcile rather than duplicate).
- "Two ways to write" card → Settings, verbatim.
- Destination card detail lines stay one line each; the current Enable card
  detail ("One-time setup in Settings…") is already right.
- Anything composed for the old layout that loses its slot is either given a
  new home or cut deliberately in the plan — never dropped silently.

## Accessibility

WCAG 2.2 AA holds, non-negotiable:

- Every moved element keeps its existing labels, traits, and hit targets.
- Welcome and Settings verified through Dynamic Type accessibility sizes.
- The tally row is `inkDim` on card fill — an already-verified 4.5:1 pair; any
  deviation gets re-verified.
- Ceremony behavior (curtain overlays, accessibility-tree hiding, Reduce
  Motion crossfades) is untouched and must be retested on the new navigation
  paths — the Damocles overlay sits on the NavigationStack and must still
  cover the Settings screen.

## Testing

- **Pure rules, unit-tested:** threshold-card visibility (system read result +
  manual override → show/hide) and tally presentation (found count → hidden /
  "N of ten" wording / Damocles line at ten). Both live as small pure types in
  the host app target, following the `PeriodShortcut` precedent.
- **Simulator proof:** the host app runs in the simulator. Implementation ends
  with screenshots of the welcome (both enable states), Settings, both themes,
  at default and accessibility Dynamic Type sizes, for Christian's review.
  This is the surface where screenshots are possible — the standing
  keyboard-extension restriction does not apply.

## Out of scope

- Any keyboard-extension change.
- Any palette, type, glyph, or theme change.
- New onboarding flows, coach marks, or tooltips.
- Restructuring Rune Pad, the alphabet chart, or the enable guide beyond
  receiving moved copy.
