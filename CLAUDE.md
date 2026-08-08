# Ceremonial Scripts

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

## Build and Test

```bash
./scripts/test.sh                # builds both targets and runs the suite
DEVICE="iPhone 16" ./scripts/test.sh
swiftlint lint --quiet --strict  # the tree is clean; run it before you commit
```

Never call `xcodebuild` bare: `xcode-select -p` points at CommandLineTools, so it
refuses to run. `scripts/test.sh` overrides `DEVELOPER_DIR` for its own invocation.

Nothing runs SwiftLint for you — not `scripts/test.sh`, not CI — so the clean tree
is a convention held by hand, not a gate. `.swiftlint.yml` names the real maximum
behind every tuned threshold, so a violation is news rather than noise.

`project.yml` is the source of truth. Both `Info.plist` files and both
`.entitlements` files are **generated** — edit the YAML, then `xcodegen generate`.
The extension target enumerates `Shared/` files one by one (the app target takes
the whole directory); a new `Shared/` file the keyboard needs must be listed there
or it silently fails to link.

## The keyboard cannot be driven in the Simulator

Text-entry rules therefore live in `Shared/` as pure types over the host field's
state — `AutoShift`, `PeriodShortcut`, `PageAfterSpace`, `GlideDecoder` — testable
without a live `UITextDocumentProxy`. New keyboard behavior goes there first, with
tests; the view only wires it up. Final keyboard verification happens by hand on
a device.

The host app *is* drivable. DEBUG launch arguments — `-force-enable-card`,
`-force-ritual`, `-force-arcadia`, `-route-settings`, `-route-runepad`,
`-route-alphabet`, `-seed-runes "<latin>"` — plus `xcrun simctl` route and
screenshot it, including at accessibility Dynamic Type sizes.

A script cannot tap a destination card any more than it can type into the
keyboard, so every surface a screenshot needs is reachable by launch argument or it
is not reachable at all. One route flag per launch; the first present wins.
`scripts/screenshots.sh` drives all of it and writes App Store sets into
`release/metadata/screenshots/`.

## Conventions

- Commit subjects are sentences describing what the change does — no `feat:` /
  `fix:` prefixes. The body carries the why when it isn't obvious.
- Build numbers come from the commit count. Never set one by hand.
- Release stages are cumulative and the default never uploads:
  `./scripts/release.sh preflight|archive|validate|upload`.
- Uploading is not distributing. A build reaches testers only once it is added to
  the TestFlight group and submitted for beta review — `externalBuildState` must
  read `IN_BETA_TESTING`. Full runbook: `docs/RELEASE.md`.
- **"Get it on TestFlight" is an instruction, not a question.** Run the release all
  the way through to `IN_BETA_TESTING` — archive, validate, upload, distribute, then
  poll `status` until it reads back. Do not stop at `upload`, do not ask whether to
  proceed, and do not reply with a list of things to check on a device first.
  Shipping is Christian's call and asking is him making it; hand-testing is his to
  schedule, never a gate a build is held behind. "Final verification happens on a
  device" describes who does it, not permission the release needs.
- Say what a build has behind it, not what it needs before it can go. If something
  is genuinely unverified, that is a sentence in the report after the upload — not a
  precondition, a recommendation, or a question.
