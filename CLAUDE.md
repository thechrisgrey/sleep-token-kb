# Ritual Keyboard

## Design Context

Read **[PRODUCT.md](PRODUCT.md)** before design or UI work; it carries the register,
users, purpose, and principles. **[DESIGN.md](DESIGN.md)** carries the visual system
itself — palette, type roles, geometry, components, and the named rules.

**Register:** brand. The host app is where design is the product. The keyboard
extension is a guest inside other apps and deliberately mirrors the system
keyboard instead — it has its own palette in `SleepTokenKeyboard/KeyPalette.swift`
and carries no theme. Do not unify the two systems.

**Personality:** reverent, exact, secret.

**The governing constraint: refine, never redesign.** The colors, the glyphs, the
two themes, and the form language are settled, intentional decisions. Work
sharpens execution — contrast, spacing, state coverage, motion timing, copy. It
does not re-open palette, type direction, or visual identity unless explicitly
asked.

**Accessibility: WCAG 2.2 AA, non-negotiable.** Body text at 4.5:1 against its
real background, full VoiceOver coverage including the Jerry hunt, a Reduce Motion
alternative for every animation, and Dynamic Type through accessibility sizes.
This is the current shipped standard, not an aspiration — do not lower it.
