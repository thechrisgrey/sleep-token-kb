# App Store listing content

Everything App Review needs, as files. `./scripts/release.sh metadata` reads this
directory and writes it to App Store Connect; the script is the mechanism and these
files are the content.

The point of keeping it here rather than in a browser is that a listing change
becomes a diff. What the app claims about itself, and how it describes its
relationship to a band it is not affiliated with, is the highest-stakes copy in the
project. It should be reviewable like code.

`metadata` is idempotent, skips anything unauthored rather than blanking it, and
**never submits**. See the "Submitting for App Review" section of
[../../docs/RELEASE.md](../../docs/RELEASE.md).

## Layout

| Path | Goes to |
|---|---|
| `app.json` | app record, app info, and version-level fields — including `name`, the App Store name (limit 30) |
| `age-rating.json` | `ageRatingDeclarations` attributes, verbatim |
| `en-US/description.txt` | version localization `description` (limit 4000) |
| `en-US/keywords.txt` | `keywords`, comma separated (limit 100) |
| `en-US/support-url.txt` | `supportUrl` (limit 255) |
| `en-US/promotional-text.txt` | `promotionalText` (limit 170) |
| `en-US/marketing-url.txt` | `marketingUrl`, optional |
| `en-US/whats-new.txt` | `whatsNew`, meaningless on a first version |
| `review/contact.json` | `appStoreReviewDetails` contact fields |
| `review/notes.txt` | the same record's `notes` |
| `screenshots/<DISPLAY_TYPE>/*.png` | one screenshot set per display type |

The stage checks every length limit locally before sending, because Apple answers
an over-long field with a 409 that names the record rather than the field.

Screenshot directories are named for App Store Connect's own `ScreenshotDisplayType`
values. `APP_IPHONE_67` is the 6.7-inch and 6.9-inch iPhone set; there is no 6.9
type of its own. `APP_IPAD_PRO_3GEN_129` is the 13-inch iPad set, which this app
needs because `TARGETED_DEVICE_FAMILY` is `1,2`. Filenames sort into display order,
so they carry a numeric prefix.

## The three decisions that are not the script's to make

**1. `contentRightsDeclaration` is deliberately `null`.**

Its two legal values are `USES_THIRD_PARTY_CONTENT` and
`DOES_NOT_USE_THIRD_PARTY_CONTENT`. For this app that is the same question
Guideline 5.2 asks, and answering it is a legal position rather than a config value,
so the stage skips the field with a note instead of choosing. Nothing else in the
listing is blocked by leaving it unset; the submission is.

**2. `review/notes.txt` ends with a "Third-party references" paragraph.**

It states what the app does: fan project, labeled unaffiliated, no bundled artwork
or audio, the song reward links out rather than embedding. It deliberately makes no
claim about permission, because none has been recorded. If the rights position
changes, that paragraph is the one to change with it.

**3. `review/contact.json` has an empty `contactPhone`.**

Apple requires all four contact fields and rejects a partial record, so the stage
refuses to send an incomplete one rather than letting Apple do it less clearly.
Fill the phone number in and the block goes through.

## The name, and what a rename does not reach

`name` is the App Store name. It is a localization attribute rather than an app
attribute, so it lives on `appInfoLocalizations` alongside the subtitle, and it is
writable at any time while the version is editable.

Three things a rename does **not** change, and all three are visible to a reviewer:

- **The bundle identifier stays `ai.altivum.SleepTokenKB`.** Builds are already
  uploaded against it and it cannot be changed without a new app record and the loss
  of the TestFlight history. `PRIVACY.md` names it directly rather than paraphrasing.
- **`ThemeMode.evenInArcadia` stays.** Its `rawValue` is what `ThemeStore` persists
  to `appThemeMode`, and an unrecognised stored value falls back to `.ritual` —
  renaming the case would silently reset the theme for everyone who had chosen it.
  Only the picker's `title` changed.
- **The two ceremonial surfaces still carry the band's wordmark.** The home hero
  renders `RuneWordRow(word: "sleep token")` and the theme-switch ceremony renders
  `Text("SLEEP TOKEN")` full-screen. Those are the largest remaining Guideline 5.2
  surfaces in the app, and they are design decisions rather than metadata.

## Judgement calls that are easy to change

- **Categories.** `UTILITIES` primary, `ENTERTAINMENT` secondary. A keyboard is a
  utility; `REFERENCE` is the arguable alternative for the secondary, on the
  strength of the alphabet chart. Valid ids come from `GET /v1/appCategories`.
- **Subtitle.** 30 characters is the ceiling and it binds hard: "The ritual
  alphabet on your keys" is 32 and does not fit.
- **Privacy policy URL** points at `PRIVACY.md` on the public repository. It
  resolves, and it is the same document the app's own privacy claim lives in. A
  hosted page would read better to a reviewer.
- **`usesIdfa: false`** is a statement of fact: there is no advertising identifier
  use, because there is no networking code.
- **`age-rating.json`** answers every descriptor conservatively. The API returns
  these as `null` before they are ever set, which means their expected types cannot
  be read back off an unset record. If Apple refuses a field here, the error names
  it, and the fix is that one line.
