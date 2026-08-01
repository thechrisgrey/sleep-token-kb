---
name: Ritual Keyboard
description: Obsidian and gold, or black stone and rose — a two-theme ritual system for an iOS keyboard and rune composer.
colors:
  obsidian: "#0E0D0F"
  obsidian-raised: "#181619"
  obsidian-high: "#252327"
  bone: "#EBE6D9"
  bone-dim: "#9E998F"
  bone-faint: "#8F8B85"
  antique-gold: "#CCAB66"
  antique-gold-deep: "#9E8047"
  arcadian-stone: "#0A0E0C"
  arcadian-green: "#131D17"
  arcadian-green-high: "#1C2A22"
  champagne: "#EDE6D1"
  champagne-dim: "#A3A694"
  rose-faint: "#A08993"
  dusty-rose: "#DE94AB"
  dusty-rose-deep: "#A85C75"
  champagne-gilt: "#C7B57A"
  sage: "#87A18C"
  caution-amber: "#DE8F52"
  key-field-dark: "#1C1C1C"
  key-field-light: "#D1D4D9"
  keycap-dark: "#525252"
  keycap-light: "#FFFFFF"
  key-function-dark: "#383838"
  key-function-light: "#ADADAD"
  key-active-dark: "#757575"
  key-active-light: "#858585"
typography:
  display:
    fontFamily: "New York, Georgia, serif"
    fontSize: "34pt"
    fontWeight: 600
    lineHeight: 1.05
    letterSpacing: "5pt"
  headline:
    fontFamily: "New York, Georgia, serif"
    fontSize: "20pt"
    fontWeight: 700
    lineHeight: 1.15
    letterSpacing: "normal"
  title:
    fontFamily: "New York, Georgia, serif"
    fontSize: "17pt"
    fontWeight: 600
    lineHeight: 1.2
    letterSpacing: "normal"
  body:
    fontFamily: "SF Pro Text, -apple-system, system-ui, sans-serif"
    fontSize: "15pt"
    fontWeight: 400
    lineHeight: 1.35
    letterSpacing: "normal"
  caption:
    fontFamily: "SF Pro Text, -apple-system, system-ui, sans-serif"
    fontSize: "12pt"
    fontWeight: 400
    lineHeight: 1.3
    letterSpacing: "normal"
  label:
    fontFamily: "SF Pro Text, -apple-system, system-ui, sans-serif"
    fontSize: "11pt"
    fontWeight: 600
    lineHeight: 1.2
    letterSpacing: "2.6pt"
  keycap:
    fontFamily: "SF Pro Rounded, ui-rounded, system-ui, sans-serif"
    fontSize: "17pt"
    fontWeight: 500
    lineHeight: 1
    letterSpacing: "normal"
  glyph:
    fontFamily: "SleepTokenRunes"
    fontSize: "40pt"
    fontWeight: 400
    lineHeight: 1
    letterSpacing: "normal"
rounded:
  key: "6pt"
  chip: "8pt"
  tile: "12pt"
  card: "16pt"
spacing:
  key-edge: "3pt"
  xs: "4pt"
  key-gap: "5pt"
  row-gap: "6pt"
  sm: "8pt"
  md: "10pt"
  lg: "14pt"
  card: "16pt"
  section: "18pt"
  stack: "28pt"
components:
  card-ritual:
    backgroundColor: "{colors.obsidian-raised}"
    textColor: "{colors.bone}"
    rounded: "{rounded.card}"
    padding: "16pt"
  card-arcadia:
    backgroundColor: "{colors.arcadian-green}"
    textColor: "{colors.champagne}"
    rounded: "{rounded.card}"
    padding: "16pt"
  destination-card:
    backgroundColor: "{colors.obsidian-raised}"
    textColor: "{colors.bone}"
    typography: "{typography.title}"
    rounded: "{rounded.card}"
    padding: "14pt"
  glyph-tile:
    backgroundColor: "{colors.obsidian-high}"
    textColor: "{colors.antique-gold}"
    rounded: "{rounded.tile}"
    size: "46pt"
  section-label:
    textColor: "{colors.bone-dim}"
    typography: "{typography.label}"
  keycap-letter:
    backgroundColor: "{colors.keycap-dark}"
    typography: "{typography.keycap}"
    rounded: "{rounded.key}"
    height: "40pt"
  keycap-letter-hinted:
    backgroundColor: "{colors.keycap-dark}"
    typography: "{typography.keycap}"
    rounded: "{rounded.key}"
    height: "44pt"
  keycap-function:
    backgroundColor: "{colors.key-function-dark}"
    typography: "{typography.keycap}"
    rounded: "{rounded.key}"
    width: "44pt"
    height: "40pt"
  keycap-function-active:
    backgroundColor: "{colors.key-active-dark}"
    typography: "{typography.keycap}"
    rounded: "{rounded.key}"
    width: "44pt"
    height: "40pt"
  runepad-key:
    backgroundColor: "{colors.obsidian-high}"
    textColor: "{colors.bone}"
    rounded: "{rounded.chip}"
    height: "46pt"
  jerry-counter:
    backgroundColor: "{colors.obsidian}"
    textColor: "{colors.dusty-rose}"
    typography: "{typography.caption}"
    rounded: "999pt"
    padding: "4pt 10pt"
---

# Design System: Ritual Keyboard

## Overview

**Creative North Star: "Candlelight on Stone"**

One light source, from above, falling on cold material. Everything in this system
answers to that image. The field is obsidian; a single radial bloom of gold sits
just off the top of the fold at 8.5% opacity and nothing else in the app glows.
Surfaces are stone that has been cut and raised, never lit — depth is three tonal
steps and a one-pixel hairline, never a shadow. The accent is rare enough to read
as flame rather than paint.

The system wears two aesthetics over identical structure. **Ritual** is obsidian
and antique gold: warm bone ink on near-black, the original ceremony. **Even in
Arcadia** is black stone with a breath of green, deep arcadian-green card panels
taken from the merch flag, champagne ink, and dusty rose in the accent role.
Switching between them changes color and ornament only — not one screen, control,
layout, or behavior differs. Any new component must resolve correctly in both
without a conditional, which is why every color is a role that resolves against
the active mode rather than a literal.

There is a second, deliberately separate system inside the same repository. The
keyboard extension is a guest in other apps, so it does not use this palette at
all: it mirrors the system keyboard through dynamic light/dark colors, keeps
primary keys the lightest element in both appearances, and carries no theme. Do
not unify these two systems. The separation is the design.

**Key Characteristics:**

- One light source: a single gold radial bloom, 8.5% opacity, above the fold
- Flat at rest — tonal layering plus a 1px hairline; zero resting shadows
- Two complete themes over one structure, resolved by role, never by literal
- Serif reserved for names and titles; system sans for every control and label
- Rune glyphs as ornament, always with a text equivalent for VoiceOver
- Restrained accent: gold or rose appears on interaction and identity, not decor

## Colors

A near-black field lit warm from one direction, with a single metal accent held
in reserve. Both themes are Committed to darkness and Restrained in accent — the
color that carries the brand is the *field*, not the highlight.

Values in the frontmatter are the portable hex reading. The normative source is
`SleepTokenKB/Theme.swift`, where colors are SwiftUI `Color(red:green:blue:)`
literals in 0–1 floats. Edit Swift, not this file, and never "correct" a Swift
literal to match a rounded hex.

### Primary

- **Antique Gold** (`#CCAB66`): the Ritual accent. Destination-card glyphs, the
  letter beneath each chart glyph, the tint on interactive controls, the rune
  wordmark. In Arcadia this role is filled by Dusty Rose instead.
- **Dusty Rose** (`#DE94AB`): the Arcadia accent, and a fixed constant that the
  ceremonies read directly so their palette holds steady while the theme flips
  underneath them. Petals, hairlines, the found-Jerry counter, ornament rules.

### Secondary

- **Champagne Gilt** (`#C7B57A`): reserved for the sacred in Arcadia — the
  `SLEEP TOKEN` wordmark and the `DAMOCLES` title, nothing else. In Ritual this
  role collapses onto Antique Gold so shared components can use it freely.
- **Antique Gold Deep** (`#9E8047`) / **Dusty Rose Deep** (`#A85C75`): the accent
  at large fill sizes, where full strength would glow too hard. Toggle tints,
  the lower Arcadia bloom.

### Tertiary

- **Sage** (`#87A18C`): the Arcadia section-label voice, so the flag's green stays
  present between the pinks. Ritual uses Bone Dim in this slot instead.
- **Caution Amber** (`#DE8F52`): the spell-check flag in Rune Pad, and the one
  color identical in both themes.

### Neutral

- **Obsidian** (`#0E0D0F`) / **Arcadian Stone** (`#0A0E0C`): the page itself.
  Near-black with a trace of warmth; Arcadia's carries a breath of green.
- **Obsidian Raised** (`#181619`) / **Arcadian Green** (`#131D17`): card surface.
  Arcadia's cards are the merch flag, which is why its surface is a hue and not
  a lighter neutral.
- **Obsidian High** (`#252327`) / **Arcadian Green High** (`#1C2A22`): interactive
  surfaces one step above card — pad keys, glyph tiles, chips.
- **Bone** (`#EBE6D9`) / **Champagne** (`#EDE6D1`): primary ink.
- **Bone Dim** (`#9E998F`) / **Champagne Dim** (`#A3A694`): supporting copy,
  captions, glyph construction notes.
- **Bone Faint** (`#8F8B85`) / **Rose Faint** (`#A08993`): ornament, chevrons,
  legal copy. Arcadia's carries a faint rose cast so pink reaches the quiet
  corners without shouting. Its level is set by the AA floor rather than by taste —
  it carries the unaffiliated notice and Rune Pad's empty state, and both themes
  keep their original channel ratios exactly, so only lightness moved.

### The keyboard extension's separate palette

Not part of the theme system. Dynamic light/dark UIKit colors in `KeyPalette.swift`,
sized so primary keys stay the lightest element in both appearances: field
`#1C1C1C` / `#D1D4D9`, keycap `#525252` / `#FFFFFF`, function `#383838` /
`#ADADAD`, engaged shift `#757575` / `#858585`.

### Named Rules

**The One Light Rule.** There is a single light source in this app: one gold
radial bloom at 8.5% opacity, centered above the fold. Arcadia adds exactly one
more, lower and dimmer. A third glow is a bug.

**The Two Stones Rule.** Every color is a role that resolves against the active
theme. The only hardcoded values are the four fixed Arcadia constants the
ceremonies depend on, and they are fixed *because* the theme flips beneath them.
A literal color in a new component is a defect.

**The Different Temperature Rule.** Caution Amber never rethemes. In Arcadia the
accent is pink, so a warning has to stay a clearly different temperature from
the thing it is warning about.

## Typography

**Display Font:** New York — the iOS system serif (with Georgia, serif fallback)
**Body Font:** SF Pro Text — the system sans (with -apple-system, system-ui)
**Keycap Font:** SF Pro Rounded — rounded system face, keycaps only
**Glyph Font:** SleepTokenRunes — 26 glyphs mapped into the Private Use Area at
`U+E900`–`U+E919`, used by Rune Pad; the keyboard extension renders vector assets
instead and deliberately never links the font

**Scaling:** every role is anchored to an iOS text style and scales with Dynamic
Type. The point sizes below are the default-size reading, not fixed values. Two
display moments (the 40pt hero, the 38pt Damocles title) do not land on a text
style and use `@ScaledMetric` instead, which scales them from their authored size.

**Character:** A serif that carries names and a sans that carries work. The pairing
is contrast-axis, not two-of-a-kind: the serif appears only where something is
being *named* — a destination, a letter, a wordmark, a dedication — and the sans
handles every label, caption, control, and piece of instruction. Nothing bundles a
second display face; the system serif is distinctive enough beside the glyphs.

### Hierarchy

- **Display** (semibold 600, 34–38pt, kerning 5–14pt animated): ceremony wordmarks
  only — `SLEEP TOKEN` and `DAMOCLES`. Letterspacing settles from 14pt to 5pt as
  the blur burns off; it is a motion property, not a static value.
- **Headline** (bold 700, 20pt serif): the Latin letter under each glyph in the
  alphabet chart. The one place a single character is the loudest thing on screen.
- **Title** (semibold 600, 17pt serif): destination-card titles, the two "ways to
  write" rows, Rune Pad's read-back line at 16pt medium.
- **Body** (regular, 15pt sans, 1.35): control labels and toggle titles.
- **Caption** (regular, 12pt / 11pt sans, +2–3pt line spacing): card detail copy,
  glyph construction notes, the permanent Full Access requirement note, legal.
- **Label** (semibold 600, 11pt sans, uppercase, tracked 2.6pt): section headings —
  `BEGIN`, `APPEARANCE`, `KEYBOARD DEFAULTS`. Rune Pad uses tighter variants at
  9pt/2.2 and 10pt/1.8 for in-card headings.
- **Keycap** (medium 500, rounded sans, size derived from key width): letter faces.
  The Latin hint under a rune is semibold at a smaller derived size.

### Named Rules

**The Serif-For-Sacred Rule.** The serif names things. It carries titles,
wordmarks, letters, and the dedication. It never carries a control label, a
caption, a keycap, or an error. If a new serif string is neither a name nor a
title, it is wrong.

**The Tracked Caps Rule.** Section labels are 11pt semibold uppercase tracked
2.6pt, in Bone Dim (Ritual) or Sage (Arcadia). This is the app's named section
voice and it predates this document — it is deliberate brand grammar, not an
eyebrow reflex. Do not add a *new* scaffold on top of it, and do not retrofit it
away.

**The No-Caps-Body Rule.** Uppercase is for section labels, ceremony subtitles,
and the `READS` strip. Never for body copy or captions.

**The No-Frozen-Type Rule.** Every font resolves from a text style, or from a
`@ScaledMetric` value anchored to one. A bare `.system(size:)` with a literal does
not scale, and mixing frozen titles with scaling captions inverts the hierarchy at
accessibility sizes rather than merely looking small. `Theme.display(scaledSize:)`
exists only for callers that have already scaled the number themselves.

## Layout

A single-column scroll on a full-bleed background, 16pt page padding, with a
28pt rhythm between major sections and 10pt between a section label and its
content. Cards are full-width; the app has no multi-column layout except the
alphabet chart.

**Vertical rhythm.** Section stacks are 28pt apart. Within a section, the label
sits 10pt above its card. Inside cards, related rows group at 14–16pt with 1px
hairline rules between them; a title and its detail line sit 3–4pt apart.

**The alphabet chart** is the one grid: three flexible columns at 10pt gutters,
dropping to **two columns at accessibility Dynamic Type sizes** so scaled
construction notes keep a workable measure. Descriptions carry no line limit —
the row grows rather than the prose truncating — with a 42pt minimum cell height
keeping rows even at default size.

**The keyboard** is a fixed geometry system, not a fluid one. All of it derives
from `Shared/KeyboardMetrics.swift`, which is the single source both the SwiftUI
content and the view controller's height reservation read, so the container can
never promise less space than the rows occupy. 3pt edge inset applied once at the
root so every row shares an edge; 5pt between keys; 6pt between rows; 8pt top and
4pt bottom padding. Key width is derived from the widest row (10 keys) so every
row shares a unit and columns line up, and the 9-key home row is inset by half a
key unit to center under the 10-key row above.

**Measure is capped on regular widths.** Every host-app screen wraps its content
column in `readableColumn()`, which caps it at `Theme.readableWidth` (620pt) and
centres it when the horizontal size class is `.regular`. Compact widths are left
untouched. The rule reads the size class rather than the device, so iPad Split View
and Slide Over — which hand a tablet a phone-width window — get the phone behaviour
without a special case.

**Responsive behavior is structural, by size class, not by breakpoint.** In a
compact height class (landscape iPhone) the keys shrink rather than the total
being clamped — 40pt to 32pt base, 44pt to 36pt hinted — and the bottom chrome bar
drops 42pt to 34pt alongside them, staying a shade taller than the keys because it
hosts the widest touch targets.

### Named Rules

**The One Geometry Rule.** Keyboard geometry lives in `KeyboardMetrics` and
nowhere else. A hardcoded key height, gap, or row total anywhere in the extension
is a defect — that exact drift previously under-allocated the grid layout by ~48pt
and pushed its top row off the edge of the input view.

**The Tallest Face Rule.** The container reserves the tallest key face available
for the current page, not the current one, so cycling the key face mid-session can
never clip an already-visible row.

## Elevation & Depth

**No resting surface casts a shadow.** Depth is entirely tonal: three steps from
field to card to interactive surface, plus a one-pixel hairline border. That is
the whole vocabulary at rest. On stone lit from a single source, a cast shadow
would imply a second light.

Shadow exists only inside ceremony, always as a *colored glow* rather than a
drop shadow — it is light spilling off something being revealed, not an object
floating above a plane.

### Shadow Vocabulary

- **Wordmark bloom** (`champagne @ 45%, radius 14`): behind the `SLEEP TOKEN` and
  `DAMOCLES` display type during the two ceremonies. Nowhere else.
- **Silhouette rim** (`rose @ 35%, radius 18` / `@ 50%, radius 24`): behind the
  black flamingo. The silhouette is near-black on black; the rim keeps it legible
  without breaking the shape.
- **Found pulse** (`rose @ 45%, radius 10`): the one interactive glow — a hidden
  Jerry brightens from 13% to 34% opacity and gains this rim permanently once
  found.

### Named Rules

**The Flat-At-Rest Rule.** Surfaces are flat. Depth is `field` → `surface` →
`surfaceHigh` plus a 1px hairline at 9% white (Ritual) or 16% rose (Arcadia). If
a new component needs a shadow to read, its tonal step is wrong.

**The Glow-Is-Ceremony Rule.** A shadow means something is being revealed. If
nothing is being revealed, there is no shadow.

## Shapes

Continuous corners throughout — every rounded rectangle uses `.continuous` style,
never the default circular curve. Radius scales with the element: 6pt keycaps,
8pt pad chips, 12pt glyph tiles, 16pt cards. Counters and status pills are full
capsules.

Borders are always exactly 1px and always a stroked border inset within the
shape, never an outer stroke — 9% white in Ritual, 16% dusty rose in Arcadia.
Dividers inside cards are 1px rectangles in the same hairline color, full width;
the footer's dedication rule is a deliberate 44pt-wide exception.

The recurring silhouette is the **diamond and the circle-with-center-dot** — the
alphabet's own construction vocabulary, where 14 of 26 glyphs are diamond
derivatives. Ornament that needs a shape should reach for the glyph set before
inventing one.

### Named Rules

**The Continuous-Corner Rule.** Every rounded shape is `.continuous`. A default
`RoundedRectangle` corner is a visual defect in this system, even though it looks
almost right.

**The Radius-Follows-Size Rule.** 6 / 8 / 12 / 16. A 46pt tile does not get a card's
16pt radius, and a card does not get a keycap's 6pt.

## Components

### Cards

The system's primary container, and the reason the app reads as cut stone.

- **Corner Style:** 16pt continuous
- **Background:** Obsidian Raised (Ritual) / Arcadian Green (Arcadia); Rune Pad's
  canvas overrides to a 55%-opacity fill in Arcadia so petals stay visible behind
  the runes
- **Border:** 1px inset stroke, hairline
- **Shadow:** none, at any state — see Elevation
- **Internal Padding:** 16pt default, 14pt for destination cards, 0 when the card
  wraps a grid cell that supplies its own padding
- **Nesting:** never. Cards do not contain cards; rows inside a card are separated
  by hairline rules instead.

### Destination Cards

The navigation primitive on the home screen — a glyph tile, a serif title, a
caption, and a chevron.

- **Glyph tile:** 46pt square, Obsidian High fill, 12pt continuous radius, 1px
  accent border at 22% opacity, holding a 22pt glyph in the accent color
- **Title / detail:** 17pt serif in Ink over 12pt sans in Ink Dim, 3pt apart
- **Trailing:** `chevron.right`, caption weight semibold, Ink Faint
- **Hit target:** the full 16pt-radius shape, set explicitly via content shape so
  the tap area matches the visible card rather than its contents

### Keys (extension)

Tactile and immediate. The key is the one component where response time matters
more than refinement.

- **Shape:** 6pt continuous, one shared keycap modifier — four key types previously
  redeclared this independently
- **Letter keys:** Keycap color (always the lightest surface in both appearances),
  40pt tall, 44pt when showing a Latin hint
- **Function keys** (shift, backspace): Function color, 44pt wide — the minimum
  touch target — never narrower
- **Engaged shift:** Active color, brighter than a resting function key in both
  appearances, with a distinct SF Symbol per state (`shift`, `shift.fill`,
  `capslock.fill`)
- **Pressed:** opacity to 55% and scale to 97%. The highlight lands instantly on
  touch-down with no animation; only the *release* fades, over 80ms ease-out.
  Reduce Motion drops the scale and both animations, keeping the opacity change.
- **Disabled:** 35% opacity (the return key when the host reports it inactive)
- **Repeat:** hold-to-repeat after 400ms, then every 120ms, accelerating to 50ms
  after 12 repeats

### Pickers and Toggles

Standard iOS segmented controls and switches, tinted with the accent. Not
restyled — reinventing a system control here would cost familiarity for nothing.

- **Segmented picker:** system style, accent tint, with each segment's VoiceOver
  label carrying the full name while the visible label carries the chrome-key
  short form
- **Toggle:** system switch tinted Accent Deep, over a two-line label — title at
  15pt sans in Ink, requirement caption at 11pt in Ink Dim
- **Row shape:** label above control, 8pt apart, optional caption 8pt below

### Rune Pad Canvas

The signature component. A plaque that binary-searches the largest glyph size
still fitting its bounds, so long compositions shrink rather than overflow.

- **Surface:** card with 0 padding and the canvas fill override; 16pt continuous
  clip so glyphs cannot escape the plaque
- **Read-back:** a `READS` strip at 9pt tracked 2.2 above 16pt serif, animating
  over 150ms ease-out on every keystroke
- **Flagged words:** Caution Amber, underlined in the same color, and announced to
  VoiceOver rather than only underlined
- **Pad keys:** 46pt tall, Obsidian High, 8pt continuous, glyph at 20pt over an
  8pt rounded-sans Latin hint in Ink Faint

### Ornament

- **Rune word rows:** a word spelled in glyphs, word gaps rendered as a 3pt centered
  dot at 50% opacity to keep the row's rhythm. Always carries the plain word as its
  accessibility label.
- **Petal field:** 17 petals ambient at 20% max opacity drifting 0.012 screen-heights
  per second; 26 petals at 80% and 0.09 during ceremony. Deterministically seeded per
  index — never real randomness, or every body evaluation reshuffles the sky. Hidden
  from the accessibility tree and excluded from hit testing.
- **Hidden Jerry:** 13% opacity at rest, 34% once found, with the found pulse rim.
  Twelve to fourteen points tall, inside a 44pt minimum tap target — the bird is
  deliberately small, the target is not. Always a labeled accessibility element.

### Named Rules

**The 44pt Rule.** Every tappable control clears 44×44pt, including the ones whose
*visible* mark is much smaller. Use `minHeight`/`minWidth` rather than a fixed
`height`, so a control still clears the floor once its label scales.

**The Destination Rule.** Every switch key names where the next tap takes you,
never its current state. This is why no two adjacent chrome keys can ever show the
same label, and it applies to any new mode control.

**The Touch-Down Rule.** Press feedback lands instantly and un-animated; only the
release is allowed to fade. An animated press-in makes a keyboard feel slow no
matter how short the duration.

## Do's and Don'ts

### Do:

- **Do** resolve every color through a `Theme` role so it retheme automatically.
  A new component must render correctly in both themes with no conditional.
- **Do** read all keyboard geometry from `KeyboardMetrics`, including any new key,
  gap, or reserved height.
- **Do** use `.continuous` corners at 6 / 8 / 12 / 16pt, matched to element size.
- **Do** carry depth with the three tonal steps and the 1px hairline.
- **Do** give every glyph a text equivalent — `RuneWordRow` labels itself with the
  plain word, and glyphs inside a labeled card are marked decorative so VoiceOver
  does not read them twice.
- **Do** ship a Reduce Motion alternative with every animation: petals freeze at
  speed 0, key presses stop scaling, ceremonies become crossfades.
- **Do** keep press feedback instant on touch-down and faded only on release.
- **Do** anchor every font to a text style so it scales; verify by running the app at
  the largest accessibility size, not by reading the code.
- **Do** wrap new screens in `readableColumn()` so iPad gets a measure instead of a
  stretched phone layout.
- **Do** keep tappable controls at 44pt minimum, sized with `minHeight` so they grow
  with their label.

### Don't:

- **Don't** redesign. Palette, glyphs, both themes, and the form language are
  settled decisions; work here sharpens execution — contrast, spacing, state
  coverage, motion timing, copy — and does not re-open identity.
- **Don't** put a shadow on a resting surface. If a component needs one to read,
  its tonal step is wrong.
- **Don't** apply this palette to the keyboard extension. It mirrors the system
  keyboard by design and carries no theme; unifying the two systems would break
  the one component that has to feel native inside other people's apps.
- **Don't** hardcode a color literal in a component. The four fixed Arcadia
  constants are the only exception and they exist because the ceremonies play
  while the theme flips beneath them.
- **Don't** nest cards, or reach for a card when a hairline-separated row inside an
  existing card would do.
- **Don't** set control labels, captions, keycaps, or errors in the serif.
- **Don't** add entrance motion to sections. Motion here marks a state change or a
  revealed moment; there is no fade-on-scroll anywhere in this app and there should
  not be.
- **Don't** add a third light source, or a glow to anything that is not being
  revealed.
- **Don't** use real randomness in ornament. Seed deterministically per index or
  the layout jitters on every render.
- **Don't** set type below 11pt. Three call sites did (8pt, 9pt, 10pt) and all three
  were unreadable rather than subtle.
- **Don't** pick an ink for a text role by eye. `ThemeContrastTests` holds the 4.5:1
  floor across both themes and all three surfaces; run it before trusting a value.
