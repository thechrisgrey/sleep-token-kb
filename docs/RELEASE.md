# Release runbook

How a build gets from this repo to TestFlight and, eventually, the App Store.

The build and upload are scripted end to end. The account setup is not, and cannot
be: parts of it exist only in Apple's web UI, and the last step is a human reviewer.
This document separates the two so it is always obvious which is which.

---

## What is automated, and what is not

| Step | Automated | Where |
|---|---|---|
| Archive, sign, export `.ipa` | Yes | `scripts/release.sh archive` |
| App Store validation | Yes | `scripts/release.sh validate` |
| Upload to App Store Connect | Yes | `scripts/release.sh upload` |
| Build number management | Yes | commit count, see below |
| Distribution certificate and profiles | Yes, on demand | Xcode, via the API key |
| Register the two bundle IDs | Once, by hand | App Store Connect |
| Create the app record | Once, by hand | App Store Connect (no public API) |
| Screenshots, description, keywords | By hand for v1 | App Store Connect |
| Submit for review | By hand | App Store Connect |
| **App Review** | **No. Humans, and days of latency** | Apple |

---

## One-time setup

Everything in this section is yours to do. None of it can be scripted, and none of
it should be handed to a tool that would need your credentials to perform it.

### 1. Apple Developer Program

Team `SGS94RW73Z` (Altivum Inc, enrolled as an Organization) needs an active paid
membership. The free tier can run the app on your own device but cannot distribute it.

Check the team ID against Membership details at developer.apple.com/account before
trusting it. A Mac signed in to more than one team will happily archive against a
personal team, and the failure only surfaces at export as `No Account for Team`,
which reads like an authentication problem rather than a wrong-team problem.

### 2. Register the bundle identifiers

Certificates, Identifiers & Profiles -> Identifiers. Two of them, and the order
matters because the second is a child of the first:

| Identifier | Capability to enable |
|---|---|
| `ai.altivum.SleepTokenFanKB` | App Groups -> `group.ai.altivum.SleepTokenFanKB` |
| `ai.altivum.SleepTokenFanKB.SleepTokenKeyboard` | App Groups -> same group |

Both bundles must be members of the same App Group or the keyboard silently stops
seeing preference changes made in the app.

### 3. Create the app record

App Store Connect -> Apps -> plus -> New App, bound to `ai.altivum.SleepTokenFanKB`.

This is the one step with no API at all. The App Store Connect API can read and
update apps but not create them, so it is the web UI or nothing.

### 4. Create an App Store Connect API key

Users and Access -> Integrations -> App Store Connect API -> plus.

Give it the **App Manager** role. Developer is not enough: creating the distribution
certificate on first archive requires App Manager.

You can download the `.p8` exactly once. Put it where altool and the release script
both look by default:

```bash
mkdir -p ~/.appstoreconnect/private_keys
mv ~/Downloads/AuthKey_XXXXXXXXXX.p8 ~/.appstoreconnect/private_keys/
chmod 600 ~/.appstoreconnect/private_keys/AuthKey_XXXXXXXXXX.p8
```

Then export the two identifiers, which are not secret in the way the key is:

```bash
export ASC_KEY_ID=XXXXXXXXXX
export ASC_ISSUER_ID=xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
```

### 5. Add the GitHub secrets

Only needed if you want to release from CI rather than your Mac.

Settings -> Secrets and variables -> Actions:

| Secret | Value |
|---|---|
| `ASC_KEY_ID` | the key identifier |
| `ASC_ISSUER_ID` | the issuer UUID |
| `ASC_KEY_P8` | the `.p8`, base64 encoded |

```bash
base64 -i ~/.appstoreconnect/private_keys/AuthKey_XXXXXXXXXX.p8 | pbcopy
```

The workflow rejects a raw paste with a clear message rather than failing later
with an opaque authentication error.

---

## Releasing

### From your Mac

```bash
./scripts/release.sh preflight
```

Builds nothing. Prints the toolchain, whether a distribution certificate and API key
are present, whether both privacy manifests are valid, whether the version keys are
wired to build settings, and the version and build number this run would produce.
Safe to run at any time, including with no credentials configured at all.

```bash
./scripts/release.sh archive
```

Archives and exports a signed `.ipa` to `build/release/export/`, then verifies it:
that the keyboard extension is actually embedded in `PlugIns/`, that both bundles
carry a privacy manifest, and that the build number in the bundle is the one that
was requested. Uploads nothing.

```bash
./scripts/release.sh validate
```

Archive, then run Apple's own validation without submitting. This is the step that
catches missing icons, entitlement mismatches, and privacy-manifest problems.

```bash
./scripts/release.sh upload
```

Archive, validate, upload. The build appears in TestFlight after a few minutes of
processing.

### From CI

Actions -> Release -> Run workflow. Pick a stage. `archive` is the default, so a
mis-click builds and uploads nothing.

Leave **internal_only** checked for anything that is not a real release candidate.
It stamps `testFlightInternalTestingOnly`, which permanently bars that build from
external TestFlight and the App Store: a safe way to prove the pipeline works.

---

## Build numbers

`BUILD_NUMBER` defaults to `git rev-list --count HEAD`, the commit count. It only
ever increases, needs no state, and never collides between your Mac and CI, which
is why CI checks out with `fetch-depth: 0` -- a shallow clone would restart the
count and get the upload rejected as a duplicate.

`MARKETING_VERSION` comes from `project.yml`. Bump it there for a real version
change; override for a one-off with `MARKETING_VERSION=1.1 ./scripts/release.sh`.

Both reach the bundle through build settings rather than literals in `Info.plist`.
That is deliberate, and preflight enforces it: with a hardcoded `CFBundleVersion`,
`BUILD_NUMBER` is silently ignored and every upload after the first is rejected.

---

## Review notes specific to this app

**It is a custom keyboard.** Reviewers treat those as high risk and will exercise
the privacy story directly. This one is in good shape: `RequestsOpenAccess` is
`false`, so iOS denies the extension both network access and the shared container.
There is no networking anywhere in either target.

**Full Access is never requested,** which is why `Shared/LayoutMode.swift` falls
back to `UserDefaults.standard` when the App Group container is unavailable. That
is a real functional constraint, not a workaround: preferences set in the app do
not reach the keyboard unless the user grants Full Access. Do not describe the app
as syncing settings automatically.

**Privacy manifests are required.** Both bundles declare the `UserDefaults`
required-reason API (`1C8F.1` for the App Group suite, `CA92.1` for their own
defaults) and declare zero data collection and zero tracking. Without these the
upload fails during processing, not at review.

**Third-party branding is the real risk.** The app is named after a band, uses
their rune alphabet, themes itself on one of their albums, and links out to one of
their songs. Guideline 5.2 covers exactly this, and unauthorized band-branded fan
apps get rejected under it routinely. Nothing in this pipeline changes that; the
dependency is permission from the band or their label, not tooling. Until that
exists, TestFlight is the honest ceiling.

Reference art under `even-in-arcadia(theme)/` is gitignored and must stay that way.
It is local design reference, not ours to redistribute.

---

## Troubleshooting

| Symptom | Cause |
|---|---|
| `No signing certificate "Apple Distribution" found` | API key missing, or its role is Developer rather than App Manager |
| `The bundle version must be higher than the previously uploaded version` | `BUILD_NUMBER` did not increase. Shallow clone in CI, or an amended commit locally |
| Upload rejected for a missing privacy manifest | `PrivacyInfo.xcprivacy` did not make it into the bundle. Run `xcodegen generate` |
| `Invalid Bundle. ... extension ... version` | The extension and app disagree on a version key. Both come from build settings; regenerate |
| `xcodebuild requires Xcode` | `xcode-select -p` points at the Command Line Tools. The scripts already override `DEVELOPER_DIR` |
| Authentication fails in CI only | `ASC_KEY_P8` pasted raw instead of base64 encoded |
