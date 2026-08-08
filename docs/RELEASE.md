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
| Add the build to the beta group, submit for Beta App Review | Yes | `scripts/release.sh distribute` |
| Expire the superseded builds | Yes, older ones only, and never before `IN_BETA_TESTING` | `scripts/release.sh distribute` |
| Read back review and submission state | Yes | `scripts/release.sh status` |
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
| `ai.altivum.SleepTokenKB` | App Groups -> `group.ai.altivum.SleepTokenKB` |
| `ai.altivum.SleepTokenKB.SleepTokenKeyboard` | App Groups -> same group |

Both bundles must be members of the same App Group or the keyboard silently stops
seeing preference changes made in the app.

### 3. Create the app record

App Store Connect -> Apps -> plus -> New App, bound to `ai.altivum.SleepTokenKB`.

This is the one step with no API at all. The App Store Connect API can read and
update apps but not create them, so it is the web UI or nothing.

### 4. Create an App Store Connect API key

Users and Access -> Integrations -> App Store Connect API -> plus.

Give it the **Admin** role. Apple's guidance and the developer forums agree that
cloud-managed distribution signing needs Admin; App Manager and Developer keys are
documented to fail at that step.

### A caveat, learned the hard way

An Admin key is necessary but was **not sufficient** to bootstrap this project's
signing assets from scratch. With no App IDs, no App Group and no distribution
certificate yet in existence, `xcodebuild -allowProvisioningUpdates` reported:

    error: Authentication failed: Make sure a bearer token was provided, it is
           properly configured and signed, and it has not expired.

That message is misleading. The same key authenticated fine against the App Store
Connect API at the same moment -- `/v1/bundleIds`, `/v1/certificates` and
`/v1/profiles` all returned 200. Xcode reaches the *provisioning* service, which is
a separate system, and it declined to mint the assets.

Ruled out, in case it recurs: wrong team, an unaccepted program agreement, key role,
argument order (build settings must come last), and key location (both
`~/.appstoreconnect/private_keys` and `~/Library/MobileDevice/Private Keys`).

The way through is to create the signing assets **once** through a signed-in Xcode
account (Xcode -> Settings -> Accounts, then select the Altivum Inc team), and let
the API key take over afterwards. Fetching existing assets is a far lighter
operation than creating them, and that is all the release pipeline needs from then
on.

Note also that App Groups are not exposed by the App Store Connect API at all --
`/v1/appGroups` returns 404, "The path provided does not match a defined resource
type." The group can only come from Xcode or from developer.apple.com by hand. No
amount of scripting against the public API will create it.

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

Two commands, in this order, and the order is not interchangeable:

```bash
./scripts/release.sh upload      # gets the build into App Store Connect
./scripts/release.sh distribute  # gets it in front of testers
```

**Uploading is not distributing.** A build that has finished processing has reached
Apple and reached nobody. It reaches testers only once it has been added to a beta
group and submitted for Beta App Review, and the one piece of state that proves it
did is `buildBetaDetail.externalBuildState == IN_BETA_TESTING`. A `processingState`
of `VALID` says only that Apple accepted the bundle.

**Only the newest build stays live, and expiring is one-way.** `distribute` expires
every live build older than the new one once it is distributed -- but not one second
before it has read `IN_BETA_TESTING` back from Apple. That interlock is not
decoration. A build was once declared live off `processingState` alone and the
previous build expired behind it, and every tester had nothing to install for twenty
minutes. There is no un-expiring; the only remedy is another upload.

### From your Mac

```bash
./scripts/release.sh preflight
```

Builds nothing. Prints the toolchain, whether a distribution certificate and API key
are present, whether both privacy manifests are valid, whether the version keys are
wired to build settings, and the version and build number this run would produce.
Safe to run at any time, including with no credentials configured at all.

```bash
./scripts/release.sh status
```

Builds nothing and changes nothing. Asks App Store Connect where the app actually
stands: the current version and its state, whether anything has been submitted to
App Review, the last five builds with their TestFlight beta-review state, the beta
groups and their public links, and -- while the version is still editable -- the
list of metadata fields that must be filled in before it can be submitted at all.

It reports the two Apple reviews **separately**, because they are routinely
confused and "approved" against the wrong one is the easy mistake to make:

| | Beta App Review | App Review |
|---|---|---|
| Gates | external TestFlight | the App Store |
| Turnaround | hours, often same day | days |
| Bar | does it launch, is it not obviously broken | the full Review Guidelines |
| Shown as | `external=BETA_APPROVED` | a submission under *App Store review* |

Passing the first says nothing about the second. Guideline 5.2 in particular is
not applied at beta review.

Unlike the build stages this one skips preflight and needs no Xcode: it only
needs the API key, `curl`, `jq` and `openssl`. It signs its own ES256 JWT rather
than pulling in a JWT library, so there is nothing to install. `distribute`, below,
runs on the same machinery.

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
processing, uploaded but not yet distributed to anyone.

```bash
./scripts/release.sh distribute
```

Builds nothing and uploads nothing: Apple rejects a second upload of a build number
outright, so this stage only ever works on a build that is already there. It takes
that build the rest of the way, in the only order that is safe:

1. Waits for `processingState` to reach `VALID`, and fails immediately on `INVALID`
   or `FAILED` rather than waiting out the timeout.
2. Adds the build to the beta group. Already a member is success, not failure --
   but only when the group itself says so. Apple has no single code for "you
   already did this", so a rejection that reads as one is confirmed by re-reading
   the group before it counts. A genuine rejection whose text merely contains the
   word *already* -- a group at its build limit, say -- stops the stage.
3. Submits it for Beta App Review. Already submitted is success, not failure --
   `WAITING_FOR_REVIEW`, `IN_REVIEW` and `APPROVED` all mean carry on. `REJECTED`,
   the remaining one of Apple's four, is the moment the operator most needs a
   failure signal rather than an `[ok]`, so it stops the stage: a rejection is
   answered with a new upload, not with another submission.
4. Waits for `externalBuildState` to reach `IN_BETA_TESTING`, printing each
   transition as it happens.
5. **Only then** expires every live build uploaded *before* it, naming each one
   with its id as it goes -- never the build being distributed, and never one
   uploaded after it.

If step 4 times out or is rejected, nothing is expired and the stage says so: the
build testers already have stays live, which is the entire point. Beta App Review
takes hours, so a timeout there is normal rather than a failure -- it exits **3**
rather than 1, and re-running `distribute` picks up exactly where it stopped, since
every step of it is safe to repeat. Exit 1 is reserved for the answers a re-run
cannot change: a rejection, a refused write, and the four `externalBuildState` dead
ends -- `PROCESSING_EXCEPTION`, `MISSING_EXPORT_COMPLIANCE`, `EXPIRED` and
`NOT_APPLICABLE` -- which stop the wait in seconds with the fix for each, rather
than polling half an hour to advise a re-run that could never help.

Step 5 re-reads the build list immediately before acting on it, and a read that
fails is reported as a failure rather than as an empty list. *There were none to
expire* and *I could not find out* are different answers, and the stage never
prints the first when it means the second. An empty response body, a body with no
`data` array, and a list the build is somehow missing from all take the second
path.

**Step 5 expires by age, not by build number.** A build uploaded while this one sat
in review is newer, not superseded -- expiring it would be one-way and wrong -- so
it is left live and named, and distributing *it* is what expires this one. Age is
read off Apple's own `-uploadedDate` ordering rather than by comparing the
timestamps, because they come back with a UTC offset (`2026-08-03T04:14:26-07:00`)
rather than as `Z`, and compared as text that instant sorts *before* `09:00:00Z`
when it is two hours after it. The list is also filtered to live builds so the
200-row page maximum is spent only on builds this step can act on; if there are
still more, it says so instead of quietly expiring the first page.

| Knob | Effect |
|---|---|
| `DRY_RUN` | performs every read, prints every write it would send -- the expiries included -- and sends none |
| `NO_EXPIRE` | distributes, but leaves the superseded builds live |
| `ASC_BETA_GROUP` | the group to ship to; defaults to `Fan Community`. Must be an external group -- an internal one moves `internalBuildState`, never the state step 4 waits on, so the stage refuses it up front rather than timing out |
| `BUILD_NUMBER` | the build to distribute; defaults to the commit count. Not unique on its own -- App Store Connect scopes it to the pre-release version -- so if more than one build carries it, the stage names them all and distributes the most recently uploaded |

`DRY_RUN` and `NO_EXPIRE` accept `1/0`, `true/false`, `yes/no` or `on/off`, in any
case. Anything else exits 2 before a single request is sent, rather than being read
as off. They are the two brakes on a one-way operation, and `NO_EXPIRE=ture`
silently meaning *expire everything* is precisely the class of accident this stage
exists to rule out.

A dry run runs every read for real and prints every write, the expiries included --
the irreversible one is the one worth previewing. It does not wait for
`IN_BETA_TESTING`, because the writes that would produce it were never sent, so the
expiry list it prints is what a real run would send **once that gate passed**, not a
claim that it has. It says as much on the line above the list. A state that gate can
never be reached from -- a rejection, or one of the four dead ends -- is reported
with the loud marker and exits 1: the preview still prints, but a build that can
never be distributed does not get to look like a clean run.

Like `status`, it skips preflight and needs no Xcode -- it builds nothing, so
gating it on a toolchain it never uses would only make it useless from a machine
that has the key and nothing else.

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
the privacy story directly. Expect to be asked why Full Access is requested, and
answer with the specific reason rather than a general one.

**Full Access is requested, for haptics and nothing else.**
`RequestsOpenAccess` is `true` because iOS refuses to deliver
`UIFeedbackGenerator` events from a keyboard extension without it — the toggle in
the app was a silent no-op for as long as the flag was `false`. No other feature
depends on it, there is still no networking code in either target, and
`KeyboardRootView.haptic()` checks `hasFullAccess` before firing rather than
assuming the grant.

This is a real weakening of the privacy claim and the copy has been changed to
match: `PRIVACY.md` and the README used to say the OS made exfiltration
impossible, which was true at `false` and is not true now. Do not restore that
wording. The honest version is "no networking code, public source, check it
yourself."

**Full Access is opt-in and usually off,** which is why `Shared/LayoutMode.swift`
still falls back to `UserDefaults.standard` when the App Group container is
unreachable. That fallback is not dead code: declaring the flag only makes the
Settings toggle appear, and most users never turn it on. Preferences set in the
app reach the keyboard only once they do. Do not describe the app as syncing
settings automatically.

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
| `No signing certificate "Apple Distribution" found` | Cloud-managed signing did not engage. The key is missing, is not Admin, or `-allowProvisioningUpdates` was dropped. An empty local keychain is **not** the cause — see below |
| `The bundle version must be higher than the previously uploaded version` | `BUILD_NUMBER` did not increase. Shallow clone in CI, or an amended commit locally |
| Upload rejected for a missing privacy manifest | `PrivacyInfo.xcprivacy` did not make it into the bundle. Run `xcodegen generate` |
| The upload succeeded but testers see nothing new | Uploading is not distributing. Run `./scripts/release.sh distribute` |
| `Invalid Bundle. ... extension ... version` | The extension and app disagree on a version key. Both come from build settings; regenerate |
| `xcodebuild requires Xcode` | `xcode-select -p` points at the Command Line Tools. The scripts already override `DEVELOPER_DIR` |
| Authentication fails in CI only | `ASC_KEY_P8` pasted raw instead of base64 encoded |
| `distribute` fails adding the build to the group: **404, "There is no resource of type 'builds' with id …"** | Apple saying *not yet* in the vocabulary of *not found*. See below — the id is not the problem |

### The 404 that names your build id

`distribute` used to fire the group-add as soon as `processingState` read `VALID`.
That is the wrong question: the binary is processed, but the build's external
record is still being assembled, and until it settles the relationship endpoint
rejects the write as a 404 that quotes your build id back at you.

The message sends you hunting for a stale or wrong identifier. It is not that. On
2026-08-07 build 89 was refused twice this way while `GET /v1/builds/<that same
id>` answered 200 with version 89 throughout, and the identical POST returned 204
minutes later once `externalBuildState` had moved off `PROCESSING`.

`distribute` now waits for that state before it writes anything, which is why the
stage has a **Submission readiness** step between Processing and the beta group.
The wait is deliberately not a retry around the write: a 404 meaning "too early"
and a 404 meaning "wrong id" are indistinguishable, so retrying would hide both.

If you see this error on a build made before that fix, waiting a few minutes and
re-running `distribute` is the whole remedy.

### An empty keychain is the normal state

`security find-identity -v -p codesigning` listing no **Apple Distribution**
identity does not mean this machine cannot ship a build. With cloud-managed
signing the distribution identity lives on Apple's side; Xcode fetches what it
needs per archive and installs nothing locally.

Build 24 was archived, exported, validated and uploaded from this Mac with:

- no Apple Distribution identity in the login keychain, and
- **zero** distribution certificates in the developer account
  (`GET /v1/certificates` returned two `DEVELOPMENT` certs and nothing else).

Preflight used to print `no Apple Distribution certificate installed yet` in that
situation, which reads as a missing prerequisite and is not one. It now says so
explicitly, and only remarks when there is neither a certificate nor an API key.

This also softens the caveat above. The API key genuinely could not *bootstrap*
signing assets from nothing — that needed one pass through a signed-in Xcode.
Once the App IDs and App Group exist, it handles the steady state on its own,
including minting distribution material that never touches the keychain. Do not
read a bare keychain as a reason to go create a certificate by hand.
