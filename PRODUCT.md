# Product

Ritual Keyboard — an unofficial Sleep Token fan project. Two targets in one app:
a system keyboard extension whose keycaps wear the ritual alphabet, and Rune Pad,
a composer that writes real vertical runes and carries them out as images.

## Register

brand

The host app is the brand surface: design *is* the product there. The keyboard
extension is a guest inside other people's apps and behaves like one — it mirrors
the system keyboard and disappears into the task. Both matter equally; see
"Two registers under one roof" below.

## Users

Sleep Token listeners who already know what the ritual alphabet is and want to
write in it. They are fans first and users second: they arrive knowing the
iconography, and they notice when it is handled carelessly.

Two contexts, both real:

- **Mid-conversation.** Typing in Messages, Notes, Safari, a group chat. The job
  is ordinary typing with the runes on the keys — the text that arrives is plain
  `a`–`z`, so nothing breaks for the person on the other end.
- **Composing something to keep.** Sitting with Rune Pad to build a vertical
  inscription, read it back in Latin, and export it as a transparent PNG, a
  plaque, or plain text. The job is making an artifact, not sending a message.

The keyboard is used constantly and half-consciously; Rune Pad is used
deliberately and rarely. Design for both without letting either set the terms
for the other.

## Product Purpose

Put a private language in the user's hands without breaking anything it touches.

The central constraint is honest: iOS keyboards can only insert text, and rune
text arrives as tofu in every app without the font. So the keyboard inserts plain
English and keeps the runes on the keycaps, and Rune Pad carries real glyphs out
as pictures. That split is not a compromise to be designed around — it is the
product.

Success is a fan who enables the keyboard once and forgets it is third-party,
plus a fan who exports an inscription and wants to send it to someone.

**Where this is headed:** public App Store release. That is a change in stakes,
not in direction. It means rights clearance and unaffiliated labeling become
design problems, and it means first-run comprehension has to work for someone
who arrives without context.

## Brand Personality

**Reverent, exact, secret.**

A liturgy you had to be initiated into. Ceremony is earned, never decorative.
The runes mean something to the people using them, and the interface's job is to
treat them as though they do.

- **Reverent** — the atmosphere is candlelight on stone, not spectacle. Restraint
  reads as respect.
- **Exact** — geometry is hand-specified, glyph fallbacks are hand-coded, the
  reserved keyboard height provably covers its content. Precision is part of the
  voice, not just the engineering.
- **Secret** — ten hidden Jerrys at 13% opacity, a wordmark spelled in runes, a
  reward that only unlocks if you found all of them. The app rewards attention
  rather than demanding it.

Voice in copy: plain, quiet, declarative. No exclamation, no encouragement, no
onboarding cheer. "One-time setup in Settings. Then the runes follow you into
every app."

## Anti-references

**The overriding constraint: this is aesthetic refinement, not redesign.** The
colors, the glyphs, the two themes, and the detailed design decisions are already
intentionally selected. Design work sharpens how well those decisions are
executed. It does not re-open them. Any command that would propose a new palette,
a new font direction, or a restructured visual identity is out of scope unless
explicitly asked for.

What this must never look like:

- **Official band merch mimicry.** Nothing that could be mistaken for Sleep
  Token's own product. This is the sharpest one now that public release is the
  goal — the unaffiliated statement is a design element, not fine print to bury.
- **Generic dark-mode SaaS.** Purple-to-blue gradients, glassmorphic cards,
  big-number hero metrics. Dark is not automatically ritual.
- **Occult-costume cliche.** Pentagrams, dripping type, blackletter,
  Halloween-store gothic. The band's aesthetic is restrained; costume-goth would
  cheapen it.

**One live tension, recorded rather than resolved.** The current surface sits
near the editorial-typographic lane the brand register flags as saturated: system
serif display, tracked-uppercase section labels above every section, hairline
rules, near-monochrome with a single accent. Identity-preservation wins here —
the tracked caps are the app's named section voice, committed to before this
document existed, and the "refine, don't redesign" constraint governs. Flag it if
a *new* surface reaches for the same scaffolding by reflex; do not retrofit the
existing ones.

## Design Principles

1. **Refine, never redesign.** The identity is decided. Work sharpens execution:
   contrast, spacing, state coverage, motion timing, copy. It does not re-open
   palette, glyph, or theme decisions.

2. **The runes are the interface, never the payload.** The keyboard inserts plain
   English so the text works everywhere; Rune Pad exports pictures so the glyphs
   survive. Any feature that blurs this line breaks the product's central promise.

3. **Two registers under one roof.** The extension mirrors the system keyboard
   because it is a guest in other apps — earned familiarity, no invented
   affordances, no theme. The host app is where ceremony lives. Judge each by its
   own standard; never import the host app's expression into the keyboard.

4. **Ceremony is earned.** One curtain-rise for a theme change. One Damocles
   reward for finding all ten. Not fade-on-scroll for every section. Motion that
   marks a moment is voice; motion applied uniformly is scaffolding.

5. **Unaffiliated, and visibly so.** Fan work that never pretends otherwise. No
   bundled artwork or audio, linked-not-embedded rewards, and clear labeling
   treated as part of the design rather than a legal afterthought.

## Accessibility & Inclusion

**WCAG 2.2 AA, non-negotiable.** Not aspirational — the current build already
holds this line, and future work does not get to lower it.

- Body text at 4.5:1 minimum against its actual background, verified rather than
  assumed. The dim ink roles (`inkDim`, `inkFaint`) are the ones most at risk and
  should be checked whenever they carry real copy.
- Full VoiceOver coverage, including the game: keyboard keys carry
  `.isKeyboardKey` so touch-typing works, shift announces its three states
  distinctly, the rune canvas speaks composed words rather than letter-by-letter,
  flagged spell-check words are announced and not merely underlined, and every
  hidden Jerry is a labeled element so the hunt is playable without sight.
- Reduce Motion has a real alternative everywhere, never a disabled feature:
  petals freeze, key presses stop scaling, both ceremonies become crossfades.
- Dynamic Type scales through accessibility sizes; the alphabet chart drops to
  two columns rather than truncating.
- Decorative ornament (petal field, background blooms) is hidden from the
  accessibility tree and excluded from hit testing.

Both ceremonies hide the covered UI from the accessibility tree while the curtain
is up, and announce themselves on arrival.
