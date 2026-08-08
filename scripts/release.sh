#!/usr/bin/env bash
# Archive, export, upload and distribute a signed build to App Store Connect.
#
# archive, validate and upload are cumulative, and the default stage never
# uploads anything. preflight and status build nothing and change nothing:
#
#   scripts/release.sh preflight    inspect the environment; builds nothing
#   scripts/release.sh status       ask App Store Connect where the app stands
#   scripts/release.sh archive      archive and export a signed .ipa   (default)
#   scripts/release.sh validate     ...then run App Store validation on it
#   scripts/release.sh upload       ...then upload it to App Store Connect
#   scripts/release.sh distribute   put an already-uploaded build in front of testers
#   scripts/release.sh metadata     fill in everything App Review needs, and stop
#
# distribute is not cumulative and never archives, validates or uploads. Apple
# rejects a second upload of a build number outright, so the build it works on is
# always one that is already there.
#
# metadata writes the App Store listing from release/metadata/ and deliberately
# stops one step short of submitting: it never POSTs /v1/reviewSubmissions. Sending
# a version to App Review is a judgement about rights clearance, not a build step,
# and this app's exposure to Guideline 5.2 makes that the operator's call every
# time. See docs/RELEASE.md.
#
# Signing authenticates with an App Store Connect API key rather than a checked-in
# certificate, so no .p12, no certificate password, and no keychain juggling. With
# -allowProvisioningUpdates, Xcode creates the distribution certificate and both
# provisioning profiles on demand (`xcodebuild -help`, signingStyle).
#
# Set up once, then never again:
#
#   ~/.appstoreconnect/private_keys/AuthKey_<KEYID>.p8   <- the key you downloaded
#   export ASC_KEY_ID=<KEYID>
#   export ASC_ISSUER_ID=<issuer uuid>
#
# That path is one of the four locations altool searches by default, which is why
# the upload stage needs no key argument of its own.
#
# Other knobs, all optional:
#
#   BUILD_NUMBER               defaults to the commit count, which only ever grows
#   MARKETING_VERSION          overrides project.yml for a one-off build
#   TESTFLIGHT_INTERNAL_ONLY   1 marks the build internal-testing-only
#   ASC_KEY_PATH               overrides the .p8 location
#   DEVELOPER_DIR              overrides which Xcode is used
#   ASC_BETA_GROUP             the group distribute ships to (default Fan Community)
#   DRY_RUN                    makes distribute print its writes and send none
#   NO_EXPIRE                  makes distribute leave superseded builds live
#
# DRY_RUN and NO_EXPIRE accept 1/0, true/false, yes/no or on/off, in any case.
# Anything else is refused outright rather than read as off: they are the two
# brakes on a one-way operation, and a brake must not fail open on a typo.
#
# distribute exits 0 when the build is live and the builds it supersedes are
# expired, 3 when Beta App Review simply has not finished yet -- normal, and safe
# to re-run -- and 1 for an answer a re-run cannot change: a rejection, a dead-end
# external state, or a write Apple refused.
set -euo pipefail

# Same reason as scripts/test.sh: `xcode-select -p` on this machine points at the
# Command Line Tools, which makes xcodebuild refuse to run. Override it for this
# process only -- no sudo, no change to the machine's global toolchain setting.
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"

cd "$(dirname "$0")/.."
REPO_ROOT="$PWD"

PROJECT="SleepTokenKB.xcodeproj"
SCHEME="SleepTokenKB"
APP_BUNDLE_ID="ai.altivum.SleepTokenKB"
EXPORT_OPTIONS="$REPO_ROOT/scripts/ExportOptions.plist"
BUILD_DIR="$REPO_ROOT/build/release"
ARCHIVE_PATH="$BUILD_DIR/$SCHEME.xcarchive"
EXPORT_DIR="$BUILD_DIR/export"
IPA_PATH="$EXPORT_DIR/$SCHEME.ipa"

ASC_KEY_PATH="${ASC_KEY_PATH:-$HOME/.appstoreconnect/private_keys/AuthKey_${ASC_KEY_ID:-unset}.p8}"

# Whether BUILD_NUMBER was asked for or merely defaulted, recorded before the
# default lands. The commit count names the build this checkout *would* produce,
# which is routinely one that has not been uploaded yet -- fine for archive, wrong
# for metadata, where attaching a build nobody has tested to the version going to
# App Review is a quiet way to ship the wrong thing.
BUILD_NUMBER_WAS_SET="${BUILD_NUMBER:+1}"
BUILD_NUMBER="${BUILD_NUMBER:-$(git rev-list --count HEAD 2>/dev/null || echo 1)}"

STAGE="${1:-archive}"
case "$STAGE" in
  preflight|status|archive|validate|upload|distribute|metadata) ;;
  # Print the header comment and stop at the first line that is not one, so the
  # usage text cannot drift out of range as this file grows.
  -h|--help|help)
    awk 'NR>1 && /^#/ { sub(/^# ?/, ""); print; next } NR>1 { exit }' "$0"
    exit 0 ;;
  *) echo "Unknown stage: $STAGE (expected preflight, status, archive, validate, upload, distribute, or metadata)" >&2; exit 2 ;;
esac

TMP_ROOT="$(mktemp -d)"
trap 'rm -rf "$TMP_ROOT"' EXIT

ok()   { printf '  [ok]   %s\n' "$*"; }
note() { printf '  [--]   %s\n' "$*"; }
bad()  { printf '  [!!]   %s\n' "$*" >&2; }
step() { printf '\n==> %s\n' "$*"; }

have_asc_key() {
  [ -n "${ASC_KEY_ID:-}" ] && [ -n "${ASC_ISSUER_ID:-}" ] && [ -f "$ASC_KEY_PATH" ]
}

# ---------------------------------------------------------------- preflight ---

preflight() {
  local fatal=0
  step "Toolchain"
  if [ -d "$DEVELOPER_DIR" ]; then
    ok "$(xcodebuild -version | head -1) at $DEVELOPER_DIR"
  else
    bad "Xcode not found at $DEVELOPER_DIR. Set DEVELOPER_DIR."
    fatal=1
  fi

  step "Signing"
  # An empty local keychain is NOT a problem here, and saying so cost someone an
  # afternoon. With cloud-managed signing the distribution identity stays on
  # Apple's side and is never installed locally: builds 23 and 24 were both signed,
  # exported and uploaded from this machine with no Apple Distribution identity in
  # the keychain and no distribution certificate in the account at all. Only the
  # case with neither a certificate nor a key is worth remarking on.
  if security find-identity -v -p codesigning 2>/dev/null | grep -q "Apple Distribution"; then
    ok "a local Apple Distribution certificate is installed"
  elif have_asc_key; then
    ok "no local distribution certificate, and none needed -- signing is cloud-managed via the API key"
  else
    note "no distribution certificate and no API key"
    note "archive may still work if Xcode is signed in to the team; validate and upload cannot"
  fi

  step "App Store Connect API key"
  if have_asc_key; then
    ok "key $ASC_KEY_ID (issuer $ASC_ISSUER_ID) at $ASC_KEY_PATH"
  else
    [ -n "${ASC_KEY_ID:-}" ]    || note "ASC_KEY_ID is not set"
    [ -n "${ASC_ISSUER_ID:-}" ] || note "ASC_ISSUER_ID is not set"
    if [ -n "${ASC_KEY_ID:-}" ] && [ ! -f "$ASC_KEY_PATH" ]; then
      note "no key file at $ASC_KEY_PATH"
    fi
    case "$STAGE" in
      validate|upload) bad "the $STAGE stage cannot run without an API key"; fatal=1 ;;
      *)               note "archive may still work if Xcode is signed in to the developer account" ;;
    esac
  fi

  step "Release metadata"
  if [ -f "$EXPORT_OPTIONS" ]; then
    ok "export options: method=$(plist_read "$EXPORT_OPTIONS" method), team=$(plist_read "$EXPORT_OPTIONS" teamID)"
  else
    bad "missing $EXPORT_OPTIONS"
    fatal=1
  fi

  local manifest
  for manifest in SleepTokenKB/PrivacyInfo.xcprivacy SleepTokenKeyboard/PrivacyInfo.xcprivacy; do
    if plutil -lint "$manifest" >/dev/null 2>&1; then
      ok "$manifest is valid"
    else
      bad "$manifest is missing or malformed -- App Store Connect will reject the upload"
      fatal=1
    fi
  done

  # A literal here means CURRENT_PROJECT_VERSION never reaches the bundle, so every
  # upload after the first is rejected as a duplicate build number.
  local plist
  for plist in SleepTokenKB/Info.plist SleepTokenKeyboard/Info.plist; do
    if [ "$(plist_read "$plist" CFBundleVersion)" = '$(CURRENT_PROJECT_VERSION)' ]; then
      ok "$plist takes its build number from build settings"
    else
      bad "$plist hardcodes CFBundleVersion; BUILD_NUMBER would be ignored"
      fatal=1
    fi
  done

  step "This build"
  note "version $(marketing_version), build $BUILD_NUMBER"
  note "bundle $APP_BUNDLE_ID"
  if [ -n "$(git status --porcelain 2>/dev/null)" ]; then
    note "working tree is dirty -- the archive will not match any commit"
  else
    ok "working tree is clean at $(git rev-parse --short HEAD)"
  fi

  return $fatal
}

plist_read() {
  /usr/libexec/PlistBuddy -c "Print :$2" "$1" 2>/dev/null || echo "?"
}

marketing_version() {
  if [ -n "${MARKETING_VERSION:-}" ]; then
    echo "$MARKETING_VERSION"
  else
    awk '/MARKETING_VERSION:/ {gsub(/[" ]/, "", $2); print $2; exit}' project.yml
  fi
}

# ------------------------------------------------------------------- status ---
#
# Everything below talks to the App Store Connect API with the same key the
# upload stage already uses, and only ever issues GETs. It answers the question
# the web UI answers -- has Apple looked at this yet, and if not, why not --
# without a browser and without a login.
#
# Two different Apple reviews exist and they are routinely confused. Beta App
# Review gates a build for *external* TestFlight and takes hours. App Review
# gates the App Store itself and is a different queue, a different submission,
# and a different bar. This prints both, separately, because "approved" against
# the wrong one is the easiest mistake to make here.

b64url() { openssl base64 -A | tr '+/' '-_' | tr -d '='; }

# Left-pad or trim a hex integer to exactly 32 bytes.
#
# DER stores integers minimally, dropping leading zero bytes and adding one back
# whenever the top bit would otherwise make the value read as negative. JWS
# wants neither: both halves are fixed-width. So a 33-byte half loses its pad
# byte and a 31-byte half gains one.
pad32() {
  local h="$1"
  while [ ${#h} -gt 64 ] && [ "${h:0:2}" = "00" ]; do h="${h:2}"; done
  while [ ${#h} -lt 64 ]; do h="0$h"; done
  printf '%s' "$h"
}

# openssl emits an ECDSA signature as DER -- SEQUENCE { INTEGER r, INTEGER s }.
# JWS wants the raw 64-byte r||s concatenation instead. This is the only part of
# the token that is not a straight base64 of something obvious.
der_to_jose() {
  local hex p rlen slen r s
  hex="$(xxd -p -c 4096 | tr -d '\n')"
  # A P-256 signature is ~70 bytes, so the length is short-form in practice, but
  # honour the long form rather than silently mis-parsing if that ever changes.
  p=4
  [ "${hex:2:2}" = "81" ] && p=6
  rlen=$(( 16#${hex:$((p + 2)):2} ))
  r="${hex:$((p + 4)):$((2 * rlen))}"
  p=$(( p + 4 + 2 * rlen ))
  slen=$(( 16#${hex:$((p + 2)):2} ))
  s="${hex:$((p + 4)):$((2 * slen))}"
  printf '%s%s' "$(pad32 "$r")" "$(pad32 "$s")" | xxd -r -p
}

# Apple caps the lifetime at 20 minutes and rejects anything longer outright.
asc_jwt() {
  local now header payload signing_input sig
  now="$(date +%s)"
  header="$(printf '{"alg":"ES256","kid":"%s","typ":"JWT"}' "$ASC_KEY_ID" | b64url)"
  payload="$(printf '{"iss":"%s","iat":%s,"exp":%s,"aud":"appstoreconnect-v1"}' \
             "$ASC_ISSUER_ID" "$now" "$((now + 600))" | b64url)"
  signing_input="$header.$payload"
  sig="$(printf '%s' "$signing_input" \
         | openssl dgst -sha256 -sign "$ASC_KEY_PATH" \
         | der_to_jose | b64url)"
  printf '%s.%s' "$signing_input" "$sig"
}

# Brackets are percent-encoded by every caller: curl will pass them through
# literally, but Apple's gateway is inconsistent about accepting them raw.
asc_get() {
  curl -sS -H "Authorization: Bearer $ASC_TOKEN" \
    "https://api.appstoreconnect.apple.com$1"
}

# Report a value that must be filled in before the app can be submitted.
# Absent is the interesting case, so it is the one that gets the loud marker.
required() {
  local label="$1" value="$2"
  if [ -z "$value" ] || [ "$value" = "null" ]; then
    bad "$label -- not set"
    return 1
  fi
  ok "$label: $value"
}

do_status() {
  if ! have_asc_key; then
    bad "status needs an App Store Connect API key"
    note "set ASC_KEY_ID and ASC_ISSUER_ID, and put the .p8 at $ASC_KEY_PATH"
    return 1
  fi
  command -v jq >/dev/null || { bad "status needs jq"; return 1; }

  ASC_TOKEN="$(asc_jwt)"

  step "App record"
  local app app_id
  app="$(asc_get "/v1/apps?filter%5BbundleId%5D=$APP_BUNDLE_ID&fields%5Bapps%5D=name,bundleId,contentRightsDeclaration")"
  if [ -n "$(jq -r '.errors // empty' <<<"$app")" ]; then
    bad "App Store Connect rejected the request:"
    jq -r '.errors[] | "         \(.title): \(.detail)"' <<<"$app" >&2
    return 1
  fi
  app_id="$(jq -r '.data[0].id // empty' <<<"$app")"
  if [ -z "$app_id" ]; then
    bad "no app record for $APP_BUNDLE_ID"
    note "the app record is created by hand in App Store Connect; see docs/RELEASE.md"
    return 1
  fi
  ok "$(jq -r '.data[0].attributes.name' <<<"$app") ($APP_BUNDLE_ID), Apple ID $app_id"

  # ---- App Store ----------------------------------------------------------
  step "App Store review"
  local versions version_id version_state review
  versions="$(asc_get "/v1/apps/$app_id/appStoreVersions?limit=5&fields%5BappStoreVersions%5D=versionString,appStoreState,appVersionState,createdDate,copyright,usesIdfa")"
  version_id="$(jq -r '.data[0].id // empty' <<<"$versions")"
  version_state="$(jq -r '.data[0].attributes.appStoreState // empty' <<<"$versions")"
  if [ -z "$version_id" ]; then
    note "no App Store version exists yet"
  else
    note "version $(jq -r '.data[0].attributes.versionString' <<<"$versions") is $version_state"
  fi

  review="$(asc_get "/v1/reviewSubmissions?limit=10&filter%5Bapp%5D=$app_id&fields%5BreviewSubmissions%5D=state,platform,submittedDate")"
  if [ "$(jq -r '.data | length' <<<"$review")" = "0" ]; then
    note "nothing has ever been submitted to App Review"
  else
    jq -r '.data[] | "  [--]   submission \(.attributes.state) (submitted \(.attributes.submittedDate // "not yet"))"' <<<"$review"
  fi

  # ---- TestFlight ---------------------------------------------------------
  step "TestFlight"
  local builds
  # buildBetaDetail has to appear in fields[builds] as well as in include: a
  # restricted field list drops the relationships object entirely, and then
  # there is nothing to join the included records against.
  builds="$(asc_get "/v1/builds?limit=5&sort=-uploadedDate&filter%5Bapp%5D=$app_id&include=buildBetaDetail&fields%5Bbuilds%5D=version,uploadedDate,processingState,expired,buildBetaDetail&fields%5BbuildBetaDetails%5D=internalBuildState,externalBuildState")"
  if [ "$(jq -r '.data | length' <<<"$builds")" = "0" ]; then
    note "no builds uploaded"
  else
    jq -r '
      (reduce (.included // [])[] as $i ({}; .[$i.id] = $i.attributes)) as $detail
      | .data[]
      | (.relationships.buildBetaDetail.data.id // "") as $bid
      | (if $bid == "" then {} else ($detail[$bid] // {}) end) as $d
      | "  [\(if .attributes.expired then "--" else "ok" end)]   build \(.attributes.version)"
        + "  uploaded \(.attributes.uploadedDate[:10])"
        + "  \(.attributes.processingState)"
        + "  external=\($d.externalBuildState // "?")"
        + (if .attributes.expired then "  EXPIRED" else "" end)
    ' <<<"$builds"
  fi

  local groups
  groups="$(asc_get "/v1/betaGroups?limit=20&filter%5Bapp%5D=$app_id&fields%5BbetaGroups%5D=name,isInternalGroup,publicLinkEnabled,publicLink")"
  jq -r '.data[]
    | "  [--]   group \"\(.attributes.name)\" (\(if .attributes.isInternalGroup then "internal" else "external" end))"
      + (if .attributes.publicLink then "  \(.attributes.publicLink)"
         else "  no public link" end)' <<<"$groups"

  # ---- What is still missing ----------------------------------------------
  #
  # Only worth printing while the version is still editable. Once it is with
  # Apple these fields are frozen and listing them reads as a problem when it
  # is not.
  [ "$version_state" = "PREPARE_FOR_SUBMISSION" ] || return 0
  [ -n "$version_id" ] || return 0

  step "Before this version can be submitted"
  local loc loc_id shots infos info_loc

  required "content rights declaration" \
    "$(jq -r '.data[0].attributes.contentRightsDeclaration' <<<"$app")" || true

  # Four of the checks below hang off appInfos rather than off the version, and
  # that distinction is not cosmetic: /v1/appStoreVersions/<id>/ageRatingDeclaration
  # answers 404 PATH_ERROR, "The relationship 'ageRatingDeclaration' does not
  # exist". Age rating, both categories and the privacy policy URL are properties
  # of the app's *info* record, which outlives any one version.
  infos="$(asc_get "/v1/apps/$app_id/appInfos?include=primaryCategory&fields%5BappInfos%5D=appStoreAgeRating,primaryCategory")"
  required "age rating" "$(jq -r '.data[0].attributes.appStoreAgeRating' <<<"$infos")" || true
  required "primary category" \
    "$(jq -r '.data[0].relationships.primaryCategory.data.id // "null"' <<<"$infos")" || true

  info_loc="$(asc_get "/v1/appInfos/$(jq -r '.data[0].id' <<<"$infos")/appInfoLocalizations?fields%5BappInfoLocalizations%5D=locale,privacyPolicyUrl")"
  required "privacy policy URL" \
    "$(jq -r '[.data[] | select(.attributes.locale == "en-US")][0].attributes.privacyPolicyUrl' <<<"$info_loc")" || true

  required "copyright" "$(jq -r '.data[0].attributes.copyright' <<<"$versions")" || true
  # usesIdfa is a tri-state: true, false, and never answered. false is a complete
  # answer and must read as one, so the test is on null rather than on falsiness.
  required "IDFA declaration" \
    "$(jq -r '.data[0].attributes.usesIdfa | if . == null then null else tostring end' <<<"$versions")" || true

  if [ -n "$(jq -r ".data // empty" <<<"$(asc_get "/v1/appStoreVersions/$version_id/build")")" ]; then
    ok "a build is attached to the version"
  else
    bad "no build attached to the version -- not set"
  fi

  loc="$(asc_get "/v1/appStoreVersions/$version_id/appStoreVersionLocalizations?fields%5BappStoreVersionLocalizations%5D=locale,description,keywords,supportUrl")"
  loc_id="$(jq -r '.data[0].id // empty' <<<"$loc")"
  required "description"  "$(jq -r '.data[0].attributes.description | if . == null then null else "\(.[:40])..." end' <<<"$loc")" || true
  required "keywords"     "$(jq -r '.data[0].attributes.keywords'    <<<"$loc")" || true
  required "support URL"  "$(jq -r '.data[0].attributes.supportUrl'  <<<"$loc")" || true

  if [ -n "$loc_id" ]; then
    shots="$(asc_get "/v1/appStoreVersionLocalizations/$loc_id/appScreenshotSets")"
    if [ "$(jq -r '.data | length' <<<"$shots")" = "0" ]; then
      bad "screenshots -- not set"
    else
      ok "screenshots: $(jq -r '[.data[].attributes.screenshotDisplayType] | join(", ")' <<<"$shots")"
    fi
  fi

  if [ -n "$(jq -r '.data // empty' <<<"$(asc_get "/v1/appStoreVersions/$version_id/appStoreReviewDetail")")" ]; then
    ok "App Review contact details"
  else
    bad "App Review contact details -- not set"
  fi

  # This line used to read "all of the above are web-UI only; the API cannot fill
  # them in for you". That was wrong, and wrong in the expensive direction: it sent
  # the operator to a browser for eight fields that all have documented write
  # endpoints. Creating the *app record* has no API; filling this list does.
  note "every field above is API-writable -- run ./scripts/release.sh metadata"
  note "what needs a human is the content of the copy and the rights position, not the writing of it"
}

# Provisioning flags shared by archive and export.
#
# -allowProvisioningUpdates is passed unconditionally, and separately from the key.
# It is what permits Xcode to create the App Store distribution profiles, and that
# is needed whether it authenticates with an API key or with an account signed in
# through Xcode -> Settings -> Accounts. Bundling the two together meant a run
# without a key silently dropped it, and the export failed with the very
# misleading `No profiles for '<bundle id>' were found` -- misleading because the
# profiles did not exist and nothing had been allowed to create them.
auth_args() {
  printf '%s\n' -allowProvisioningUpdates
  if have_asc_key; then
    printf '%s\n' \
      -authenticationKeyPath "$ASC_KEY_PATH" \
      -authenticationKeyID "$ASC_KEY_ID" \
      -authenticationKeyIssuerID "$ASC_ISSUER_ID"
  fi
}

# ------------------------------------------------------------------ archive ---

do_archive() {
  local auth=()
  while IFS= read -r line; do auth+=("$line"); done < <(auth_args)

  # Spelled out as an `if` rather than `test && append`: under `set -e` a trailing
  # false test would take the whole script down with it.
  local settings=(CURRENT_PROJECT_VERSION="$BUILD_NUMBER")
  if [ -n "${MARKETING_VERSION:-}" ]; then
    settings+=(MARKETING_VERSION="$MARKETING_VERSION")
  fi

  step "Archiving $SCHEME ($(marketing_version) build $BUILD_NUMBER)"
  rm -rf "$ARCHIVE_PATH" "$EXPORT_DIR"
  mkdir -p "$BUILD_DIR"
  xcodebuild archive \
    -project "$PROJECT" \
    -scheme "$SCHEME" \
    -configuration Release \
    -destination 'generic/platform=iOS' \
    -archivePath "$ARCHIVE_PATH" \
    "${settings[@]}" \
    ${auth[@]+"${auth[@]}"}

  # testFlightInternalTestingOnly is a per-build decision, so it is stamped onto a
  # copy rather than committed into the shared export options.
  local options="$EXPORT_OPTIONS"
  if [ "${TESTFLIGHT_INTERNAL_ONLY:-0}" = "1" ]; then
    options="$TMP_ROOT/ExportOptions.plist"
    cp "$EXPORT_OPTIONS" "$options"
    /usr/libexec/PlistBuddy -c "Add :testFlightInternalTestingOnly bool true" "$options"
    note "marked internal-testing-only: this build cannot go to external TestFlight or the App Store"
  fi

  step "Exporting .ipa"
  xcodebuild -exportArchive \
    -archivePath "$ARCHIVE_PATH" \
    -exportPath "$EXPORT_DIR" \
    -exportOptionsPlist "$options" \
    ${auth[@]+"${auth[@]}"}

  verify_ipa
}

# Confirm the .ipa actually contains what the App Store expects, rather than
# trusting that a zero exit code means the bundle is correct.
verify_ipa() {
  step "Verifying $IPA_PATH"
  [ -f "$IPA_PATH" ] || { bad "no .ipa was produced"; return 1; }

  local dir="$TMP_ROOT/ipa"
  mkdir -p "$dir"
  unzip -qq "$IPA_PATH" -d "$dir"

  local app appex
  app="$(find "$dir/Payload" -maxdepth 1 -name '*.app' -print -quit)"
  [ -n "$app" ] || { bad "no .app inside Payload/"; return 1; }
  ok "$(basename "$app") -- $(du -h "$IPA_PATH" | cut -f1) packaged"

  local version build
  version="$(plist_read "$app/Info.plist" CFBundleShortVersionString)"
  build="$(plist_read "$app/Info.plist" CFBundleVersion)"
  if [ "$build" = "$BUILD_NUMBER" ]; then
    ok "version $version, build $build"
  else
    bad "build number is $build but BUILD_NUMBER was $BUILD_NUMBER"
    return 1
  fi

  appex="$(find "$app/PlugIns" -maxdepth 1 -name '*.appex' -print -quit 2>/dev/null || true)"
  if [ -n "$appex" ]; then
    ok "embedded extension $(basename "$appex")"
  else
    bad "the keyboard extension is missing from PlugIns/"
    return 1
  fi

  local target
  for target in "$app" "$appex"; do
    if [ -f "$target/PrivacyInfo.xcprivacy" ]; then
      ok "privacy manifest present in $(basename "$target")"
    else
      bad "no privacy manifest in $(basename "$target") -- upload will be rejected"
      return 1
    fi
  done

  if codesign --verify --deep --strict "$app" 2>/dev/null; then
    ok "code signature verifies"
  else
    note "code signature did not verify (expected for an unsigned local build)"
  fi
}

# ------------------------------------------------------- validate / upload ---

altool() {
  xcrun altool "$@" \
    --type ios \
    --file "$IPA_PATH" \
    --apiKey "$ASC_KEY_ID" \
    --apiIssuer "$ASC_ISSUER_ID"
}

do_validate() {
  step "Validating against App Store Connect"
  altool --validate-app
  ok "validation passed"
}

do_upload() {
  step "Uploading to App Store Connect"
  altool --upload-app
  ok "uploaded: version $(marketing_version), build $BUILD_NUMBER"
  note "processing takes a few minutes; the build then appears in TestFlight"
  note "the build is uploaded, not distributed; run ./scripts/release.sh distribute next"
}

# --------------------------------------------------------------- distribute ---
#
# Uploading a build is not distributing it. A build that has finished processing
# has reached Apple and reached nobody: it reaches testers only once it has been
# added to a beta group and submitted for Beta App Review, and the single piece
# of state that proves it did is buildBetaDetail.externalBuildState ==
# IN_BETA_TESTING.
#
# This stage exists because that was once got wrong. A build was declared live off
# processingState == VALID alone, the previous build was expired behind it, and
# every tester had nothing to install for twenty minutes. Expiring is one-way and
# cannot be undone, so the order here is the whole point of the stage: nothing is
# expired until IN_BETA_TESTING has actually been read back from Apple.
#
# Everything is safe to re-run. A build already in the group, or already submitted,
# is success rather than failure, so an interrupted run is fixed by running it again.

ASC_BETA_GROUP="${ASC_BETA_GROUP:-Fan Community}"

# The two flags below are the only things standing between a run and an
# irreversible expire, so they are parsed rather than string-compared. Comparing
# against a literal "1" means DRY_RUN=true, NO_EXPIRE=yes and every other honest
# spelling read as off, and the operator who asked for a preview gets the real
# thing. Off is the default; anything unrecognised is refused rather than guessed,
# because the direction a guess fails in here is one-way.
normalize_flag() {
  local name="$1" value="${!1:-0}"
  case "$(printf '%s' "$value" | tr '[:upper:]' '[:lower:]')" in
    1|true|yes|on)     printf -v "$name" '1' ;;
    0|false|no|off|'') printf -v "$name" '0' ;;
    *)
      bad "$name=$value is not an on/off value"
      note "use 1/0, true/false, yes/no or on/off -- refusing to guess before a one-way step"
      exit 2 ;;
  esac
}
normalize_flag DRY_RUN
normalize_flag NO_EXPIRE

POLL_INTERVAL=30
PROCESSING_TIMEOUT=1800
BETA_STATE_TIMEOUT=1800

ASC_STATUS=""
ASC_BODY=""

# asc_jwt mints a token good for ten minutes and the polls below can outlast it by
# twenty, so it is re-minted on a timer rather than left to expire mid-wait. A 401
# arriving halfway through a poll would read as a failure of the thing being waited
# on, which is exactly the misreading this stage exists to prevent.
ASC_TOKEN_MINTED=0
asc_token_fresh() {
  local now
  now="$(date +%s)"
  if [ "$((now - ASC_TOKEN_MINTED))" -ge 300 ]; then
    ASC_TOKEN="$(asc_jwt)"
    ASC_TOKEN_MINTED="$now"
  fi
}

# asc_get can judge a request by whether an errors array came back. A write cannot:
# Apple answers "already a member" with a body shaped exactly like a real failure,
# and 204 carries no body at all. So both the status line and the body are kept,
# in globals rather than in one string every caller would have to take apart.
asc_send() {
  local method="$1" path="$2" body="$3" response
  response="$(curl -sS -X "$method" \
    -H "Authorization: Bearer $ASC_TOKEN" \
    -H "Content-Type: application/json" \
    -d "$body" \
    -w $'\n%{http_code}' \
    "https://api.appstoreconnect.apple.com$path")"
  ASC_STATUS="${response##*$'\n'}"
  ASC_BODY="${response%$'\n'*}"
}

# Every write in this stage goes through here, so DRY_RUN cannot be honoured at one
# call site and forgotten at the next one somebody adds later.
asc_mutate() {
  local label="$1" method="$2" path="$3" body="$4"
  if [ "$DRY_RUN" = "1" ]; then
    note "would $label"
    note "       $method $path"
    note "       $body"
    return 0
  fi
  asc_token_fresh
  asc_send "$method" "$path" "$body"
  case "$ASC_STATUS" in
    2*) ok "$label (HTTP $ASC_STATUS)"; return 0 ;;
    *)  return 1 ;;
  esac
}

asc_post()  { asc_mutate "$1" POST  "$2" "$3"; }
asc_patch() { asc_mutate "$1" PATCH "$2" "$3"; }

# Report a rejected write in the same shape do_status uses, reached from a status
# code instead of from the presence of an errors array.
asc_rejected() {
  bad "$1 (HTTP $ASC_STATUS)"
  jq -r '.errors[]? | "         \(.title): \(.detail)"' <<<"$ASC_BODY" >&2 2>/dev/null || true
}

# Apple has no one code for "you already did this" -- the group relationship and the
# review submission each phrase it their own way -- so the test is on the text of
# whatever error came back. Both writes are idempotent in intent, and a re-run of
# this stage must not read as a failure.
asc_already_done() {
  jq -e -r '[.errors[]? | "\(.code // "") \(.title // "") \(.detail // "")"]
            | join(" ") | ascii_downcase
            | test("already|exists|duplicate")' <<<"$ASC_BODY" >/dev/null 2>&1
}

build_external_state() {
  asc_get "/v1/builds/$1/buildBetaDetail?fields%5BbuildBetaDetails%5D=externalBuildState" \
    | jq -r '.data.attributes.externalBuildState // empty'
}

# ExternalBetaState has thirteen values. The five below never advance on their own:
# they are answered by a new upload or by a human in the web UI, never by waiting.
# The other eight -- PROCESSING, READY_FOR_BETA_SUBMISSION,
# IN_EXPORT_COMPLIANCE_REVIEW, WAITING_FOR_BETA_REVIEW, IN_BETA_REVIEW,
# BETA_APPROVED, READY_FOR_BETA_TESTING and IN_BETA_TESTING itself -- are all
# genuinely "not yet", and waiting is the right answer for every one of them.
# Polling a dead end for half an hour and then advising a re-run spends thirty
# minutes to give advice that was already wrong when the first read came back.
external_dead_end() {
  case "$1" in
    BETA_REJECTED|PROCESSING_EXCEPTION|MISSING_EXPORT_COMPLIANCE|EXPIRED|NOT_APPLICABLE) return 0 ;;
    *) return 1 ;;
  esac
}

# What the operator actually does about each dead end, which is never "wait".
external_dead_end_note() {
  case "$1" in
    BETA_REJECTED)             printf 'a rejection is answered with a new upload, not by waiting' ;;
    PROCESSING_EXCEPTION)      printf 'Apple could not finish processing this binary; upload a new build' ;;
    MISSING_EXPORT_COMPLIANCE) printf 'declare export compliance in App Store Connect, then re-run distribute' ;;
    EXPIRED)                   printf 'expiring is one-way; upload a new build' ;;
    NOT_APPLICABLE)            printf 'this build is not eligible for external testing; check TESTFLIGHT_INTERNAL_ONLY' ;;
  esac
}

# Does the group actually contain the build? Read, not inferred. `.data[]?` means
# an error body answers no rather than blowing up, which is the direction this
# question has to fail in.
group_contains_build() {
  local group="$1" build="$2" members
  members="$(asc_get "/v1/betaGroups/$group/builds?limit=200&fields%5Bbuilds%5D=version")"
  [ -n "$(jq -r --arg id "$build" '[.data[]? | select(.id == $id)][0] // empty' <<<"$members")" ]
}

do_distribute() {
  if ! have_asc_key; then
    bad "distribute needs an App Store Connect API key"
    note "set ASC_KEY_ID and ASC_ISSUER_ID, and put the .p8 at $ASC_KEY_PATH"
    return 1
  fi
  command -v jq >/dev/null || { bad "distribute needs jq"; return 1; }

  asc_token_fresh
  if [ "$DRY_RUN" = "1" ]; then
    step "Dry run"
    note "every read below is real; every write is printed and not sent"
  fi

  # ---- 1. the app record ---------------------------------------------------
  step "App record"
  local app app_id
  app="$(asc_get "/v1/apps?filter%5BbundleId%5D=$APP_BUNDLE_ID&fields%5Bapps%5D=name,bundleId")"
  if [ -n "$(jq -r '.errors // empty' <<<"$app")" ]; then
    bad "App Store Connect rejected the request:"
    jq -r '.errors[] | "         \(.title): \(.detail)"' <<<"$app" >&2
    return 1
  fi
  app_id="$(jq -r '.data[0].id // empty' <<<"$app")"
  if [ -z "$app_id" ]; then
    bad "no app record for $APP_BUNDLE_ID"
    note "the app record is created by hand in App Store Connect; see docs/RELEASE.md"
    return 1
  fi
  ok "$(jq -r '.data[0].attributes.name' <<<"$app") ($APP_BUNDLE_ID), Apple ID $app_id"

  # ---- 2. the build --------------------------------------------------------
  step "Build $BUILD_NUMBER"
  local builds build_id twins
  builds="$(asc_get "/v1/builds?limit=200&sort=-uploadedDate&filter%5Bapp%5D=$app_id&fields%5Bbuilds%5D=version,uploadedDate,processingState,expired")"
  # Same distinction step 7 makes: a list that could not be read is not an empty
  # list, and must not be reported as "that build was never uploaded".
  if ! jq -e '(.data | type) == "array"' <<<"$builds" >/dev/null 2>&1; then
    bad "could not read the build list"
    jq -r '.errors[]? | "         \(.title): \(.detail)"' <<<"$builds" >&2 2>/dev/null || true
    return 1
  fi
  build_id="$(jq -r --arg v "$BUILD_NUMBER" \
    '[.data[] | select(.attributes.version == $v) | .id][0] // empty' <<<"$builds")"
  if [ -z "$build_id" ]; then
    bad "no build $BUILD_NUMBER has been uploaded"
    note "uploaded builds: $(jq -r '[.data[].attributes.version] | join(", ")' <<<"$builds")"
    note "distribute never uploads; run ./scripts/release.sh upload first"
    return 1
  fi
  ok "build $BUILD_NUMBER is $build_id, uploaded $(jq -r --arg v "$BUILD_NUMBER" \
    '[.data[] | select(.attributes.version == $v) | .attributes.uploadedDate][0][:10]' <<<"$builds")"

  # A build number is not unique in App Store Connect: it is scoped to the
  # pre-release version, so 1.0 (75) and 1.1 (75) can both exist and the sort above
  # silently picks the newer. Step 7 compares upload dates rather than numbers and
  # names the id it expires, so the ambiguity is survivable -- but it is said out
  # loud rather than resolved in silence before anything irreversible happens.
  twins="$(jq -r --arg v "$BUILD_NUMBER" \
    '[.data[] | select(.attributes.version == $v) | .id] | join(", ")' <<<"$builds")"
  if [ "$twins" != "$build_id" ]; then
    note "more than one build carries the number $BUILD_NUMBER: $twins"
    note "the most recently uploaded one is the one being distributed; the rest are superseded"
  fi

  # An expired build can never enter beta testing, so stopping here saves a wait
  # that could only ever time out.
  if [ "$(jq -r --arg v "$BUILD_NUMBER" \
      '[.data[] | select(.attributes.version == $v) | .attributes.expired][0]' <<<"$builds")" = "true" ]; then
    bad "build $BUILD_NUMBER is expired and cannot be distributed"
    note "expiring is one-way; upload a new build"
    return 1
  fi

  # ---- 3. processing -------------------------------------------------------
  step "Processing"
  local state last="" elapsed=0
  while :; do
    asc_token_fresh
    state="$(asc_get "/v1/builds/$build_id?fields%5Bbuilds%5D=processingState" \
             | jq -r '.data.attributes.processingState // empty')"
    case "$state" in
      VALID)
        ok "processing finished: VALID"
        break ;;
      INVALID|FAILED)
        bad "build $BUILD_NUMBER did not process: $state"
        note "no group was touched and nothing was expired"
        return 1 ;;
      "")
        bad "could not read the processing state of build $BUILD_NUMBER"
        return 1 ;;
    esac
    if [ "$state" != "$last" ]; then
      note "processing: $state"
      last="$state"
    elif [ "$elapsed" -gt 0 ] && [ "$((elapsed % 300))" -eq 0 ]; then
      note "still $state after $((elapsed / 60))m"
    fi
    if [ "$elapsed" -ge "$PROCESSING_TIMEOUT" ]; then
      bad "build $BUILD_NUMBER was still $state after $((PROCESSING_TIMEOUT / 60)) minutes"
      note "no group was touched and nothing was expired; re-run distribute later"
      return 1
    fi
    sleep "$POLL_INTERVAL"
    elapsed=$((elapsed + POLL_INTERVAL))
  done

  # ---- 3b. submission readiness --------------------------------------------
  #
  # processingState VALID is not the same question as "may this build be put in a
  # group". The binary is processed; the build's external record is still being
  # assembled, and until it settles the relationship endpoint refuses the write --
  # as HTTP 404, phrased "There is no resource of type 'builds' with id <id>".
  #
  # That message names the build, so it reads as a wrong or stale identifier and
  # sends you looking at the id. The id is fine: on 2026-08-07 build 89 was rejected
  # twice this way, `GET /v1/builds/<same id>` answered 200 with version 89
  # throughout, and the identical POST succeeded 204 minutes later once the state
  # below had moved off PROCESSING. Apple is saying "not yet" in the vocabulary of
  # "not found".
  #
  # So the wait belongs here, before anything is written, rather than as a retry
  # around the write: a 404 that means "too early" is indistinguishable from a 404
  # that means "wrong id", and retrying on it would paper over both.
  step "Submission readiness"
  local ext_state ext_last="" ext_elapsed=0
  while :; do
    asc_token_fresh
    ext_state="$(build_external_state "$build_id")"
    if external_dead_end "$ext_state"; then
      bad "build $BUILD_NUMBER is $ext_state and cannot be distributed"
      note "$(external_dead_end_note "$ext_state")"
      note "no group was touched and nothing was expired"
      return 1
    fi
    # PROCESSING is the only state that has not yet reached the group endpoint.
    # Everything else -- including the states past it, which a re-run legitimately
    # sees -- means the write below will be accepted.
    if [ -n "$ext_state" ] && [ "$ext_state" != "PROCESSING" ]; then
      ok "ready for the beta group: $ext_state"
      break
    fi
    if [ "$ext_state" != "$ext_last" ]; then
      note "external state: ${ext_state:-not published yet}"
      ext_last="$ext_state"
    elif [ "$ext_elapsed" -gt 0 ] && [ "$((ext_elapsed % 300))" -eq 0 ]; then
      note "still ${ext_state:-unpublished} after $((ext_elapsed / 60))m"
    fi
    if [ "$ext_elapsed" -ge "$PROCESSING_TIMEOUT" ]; then
      bad "build $BUILD_NUMBER was still ${ext_state:-unpublished} after $((PROCESSING_TIMEOUT / 60)) minutes"
      note "no group was touched and nothing was expired; re-run distribute later"
      return 1
    fi
    sleep "$POLL_INTERVAL"
    ext_elapsed=$((ext_elapsed + POLL_INTERVAL))
  done

  # ---- 4. the beta group ---------------------------------------------------
  step "Beta group \"$ASC_BETA_GROUP\""
  local groups group_id
  groups="$(asc_get "/v1/betaGroups?limit=200&filter%5Bapp%5D=$app_id&fields%5BbetaGroups%5D=name,isInternalGroup")"
  # The same distinction steps 2 and 7 make: a list that could not be read is not a
  # list with no matching group in it. Without this, an error body reached the jq
  # below and killed the stage with "Cannot iterate over null" and an exit code no
  # other path here uses.
  if ! jq -e '(.data | type) == "array"' <<<"$groups" >/dev/null 2>&1; then
    bad "could not read the beta groups"
    jq -r '.errors[]? | "         \(.title): \(.detail)"' <<<"$groups" >&2 2>/dev/null || true
    return 1
  fi
  group_id="$(jq -r --arg n "$ASC_BETA_GROUP" \
    '[.data[] | select(.attributes.name == $n) | .id][0] // empty' <<<"$groups")"
  if [ -z "$group_id" ]; then
    bad "no beta group named \"$ASC_BETA_GROUP\""
    note "groups that exist: $(jq -r '[.data[].attributes.name] | join(", ")' <<<"$groups")"
    note "override with ASC_BETA_GROUP=<name>"
    return 1
  fi

  # isInternalGroup is asked for anyway, so it is read. An internal group moves
  # internalBuildState, never externalBuildState, so the state step 6 waits on can
  # never arrive through one: the run would spend the full timeout to learn what
  # this line already knows.
  if [ "$(jq -r --arg n "$ASC_BETA_GROUP" \
      '[.data[] | select(.attributes.name == $n) | .attributes.isInternalGroup][0]' <<<"$groups")" = "true" ]; then
    bad "\"$ASC_BETA_GROUP\" is an internal group"
    note "this stage proves distribution with externalBuildState, which an internal group never sets"
    note "point ASC_BETA_GROUP at an external group; nothing was touched"
    return 1
  fi

  # Membership is read before it is written so a re-run says what is true rather
  # than claiming to have added a build that was already there.
  if group_contains_build "$group_id" "$build_id"; then
    ok "build $BUILD_NUMBER is already in \"$ASC_BETA_GROUP\""
  elif asc_post "add build $BUILD_NUMBER to \"$ASC_BETA_GROUP\"" \
         "/v1/betaGroups/$group_id/relationships/builds" \
         "$(printf '{"data":[{"type":"builds","id":"%s"}]}' "$build_id")"; then
    :
  elif asc_already_done; then
    # "Already a member" is Apple's phrasing of a failure, not an observation of
    # one, and asc_already_done only greps text: a genuine rejection that happens
    # to contain the word "already" -- a group at its build limit, say -- reaches
    # here too. Membership is the one leg of the interlock with no later gate of
    # its own, so it is read back before it counts, exactly as step 7 re-reads the
    # list it is about to act on.
    if group_contains_build "$group_id" "$build_id"; then
      ok "build $BUILD_NUMBER was already in \"$ASC_BETA_GROUP\""
    else
      asc_rejected "\"$ASC_BETA_GROUP\" rejected build $BUILD_NUMBER as already added, but does not contain it"
      note "the message said already; the group says otherwise, so the group is believed"
      note "nothing was expired"
      return 1
    fi
  else
    asc_rejected "could not add build $BUILD_NUMBER to \"$ASC_BETA_GROUP\""
    note "nothing was expired"
    return 1
  fi

  # ---- 5. Beta App Review --------------------------------------------------
  step "Beta App Review"
  local submission review_state
  submission="$(asc_get "/v1/betaAppReviewSubmissions?limit=1&filter%5Bbuild%5D=$build_id&fields%5BbetaAppReviewSubmissions%5D=betaReviewState")"
  # The same distinction steps 2, 4 and 7 make: a list that could not be read is not
  # an empty list. Without this, a rolled token or a 429 on this one call reads as
  # "never submitted", and a REJECTED build is submitted again instead of reported.
  if ! jq -e '(.data | type) == "array"' <<<"$submission" >/dev/null 2>&1; then
    bad "could not read the Beta App Review submissions for build $BUILD_NUMBER"
    jq -r '.errors[]? | "         \(.title): \(.detail)"' <<<"$submission" >&2 2>/dev/null || true
    note "nothing was expired"
    return 1
  fi
  review_state="$(jq -r '.data[0].attributes.betaReviewState // empty' <<<"$submission")"
  # BetaReviewState has four values. Three of them mean carry on; the fourth is the
  # one moment in this stage where the operator most needs a failure signal, and
  # reporting it with the same [ok] marker as the other three inverted it.
  case "$review_state" in
    WAITING_FOR_REVIEW|IN_REVIEW|APPROVED)
      ok "build $BUILD_NUMBER is already submitted: $review_state" ;;
    REJECTED)
      bad "Beta App Review rejected build $BUILD_NUMBER"
      note "a rejection is answered with a new upload, not with another submission"
      note "nothing was expired"
      return 1 ;;
    "")
      if asc_post "submit build $BUILD_NUMBER for Beta App Review" \
           "/v1/betaAppReviewSubmissions" \
           "$(printf '{"data":{"type":"betaAppReviewSubmissions","relationships":{"build":{"data":{"type":"builds","id":"%s"}}}}}' "$build_id")"; then
        :
      elif asc_already_done; then
        ok "build $BUILD_NUMBER was already submitted for Beta App Review"
      else
        asc_rejected "could not submit build $BUILD_NUMBER for Beta App Review"
        note "nothing was expired"
        return 1
      fi ;;
    *)
      # A value Apple added after this was written. Not a failure of its own -- the
      # gate that decides anything is step 6 -- but not an [ok] either.
      note "build $BUILD_NUMBER is in an unrecognised review state: $review_state"
      note "step 6 decides on externalBuildState regardless" ;;
  esac

  # ---- 6. the state that actually proves distribution ----------------------
  step "External TestFlight state"
  # reached is the interlock: it says whether Apple confirmed distribution, and
  # step 7 refuses to expire anything without it. outcome is what the stage exits
  # with, which is a different question -- a dry run reaches step 7 by design and
  # still has to report a build that can never be distributed as a failure. It
  # starts at 1 so that a path which forgets to answer fails closed.
  local ext reached=0 outcome=1
  if [ "$DRY_RUN" = "1" ]; then
    # A dry run sent neither write, so waiting for a state those writes would have
    # caused could only ever time out. One read, reported honestly, instead.
    ext="$(build_external_state "$build_id")"
    if [ "$ext" = "IN_BETA_TESTING" ]; then
      ok "build $BUILD_NUMBER is IN_BETA_TESTING -- already distributed"
      outcome=0
    elif external_dead_end "$ext"; then
      # The one class of state that is not "not yet". Reported with the quiet
      # marker and exited 0, a preview of a build that can never be distributed
      # read as an entirely clean run.
      bad "external state is $ext -- build $BUILD_NUMBER cannot reach IN_BETA_TESTING"
      note "$(external_dead_end_note "$ext")"
      note "a real run would stop here and expire nothing"
    else
      note "external state is ${ext:-unknown}"
      note "a real run would wait here until IN_BETA_TESTING before expiring anything"
      outcome=0
    fi
    # Carry on to step 7 regardless. The expire PATCH is the single irreversible
    # write in this stage and therefore the one a preview most needs to show; a
    # dry run that stops here can only ever preview the writes that do not matter.
    # This is not a claim that the gate passed -- step 7 says so in as many words.
    reached=1
  else
    # A sentinel no state can equal, so the first read always prints. Left empty,
    # an unreadable state matched it and the run sat silent for five minutes with
    # no line saying what it was waiting on.
    last="-"
    elapsed=0
    while :; do
      asc_token_fresh
      ext="$(build_external_state "$build_id")"
      if [ "$ext" != "$last" ]; then
        note "external state: ${ext:-unknown}"
        last="$ext"
      elif [ "$elapsed" -gt 0 ] && [ "$((elapsed % 300))" -eq 0 ]; then
        note "still ${ext:-unknown} after $((elapsed / 60))m"
      fi
      if [ "$ext" = "IN_BETA_TESTING" ]; then
        ok "build $BUILD_NUMBER is IN_BETA_TESTING -- testers can install it"
        reached=1
        outcome=0
        break
      fi
      if [ "$ext" = "BETA_REJECTED" ]; then
        bad "Beta App Review rejected build $BUILD_NUMBER"
        note "$(external_dead_end_note "$ext")"
        break
      fi
      if external_dead_end "$ext"; then
        bad "build $BUILD_NUMBER is $ext and will not reach beta testing on its own"
        note "$(external_dead_end_note "$ext")"
        break
      fi
      if [ "$elapsed" -ge "$BETA_STATE_TIMEOUT" ]; then
        # Not a failure, and the exit code says so: 3 is "not yet", which is what
        # a review that has not finished actually is. 1 stays reserved for the
        # answers a re-run cannot change.
        bad "build $BUILD_NUMBER was still ${ext:-unknown} after $((BETA_STATE_TIMEOUT / 60)) minutes"
        note "Beta App Review can take hours; re-running distribute later picks up where this stopped"
        outcome=3
        break
      fi
      sleep "$POLL_INTERVAL"
      elapsed=$((elapsed + POLL_INTERVAL))
    done
  fi

  # ---- 7. and only now, the previous builds --------------------------------
  step "Superseded builds"
  if [ "$reached" != "1" ]; then
    bad "build $BUILD_NUMBER is not IN_BETA_TESTING, so nothing was expired"
    note "the build testers currently have stays live, which is the point"
    return "$outcome"
  fi
  if [ "$NO_EXPIRE" = "1" ]; then
    note "NO_EXPIRE is on -- every other build stays live"
    return "$outcome"
  fi

  # Re-read rather than reuse the list from step 2: a real run may have spent half
  # an hour waiting, and this is the list something irreversible happens to.
  #
  # The rows are materialised before the loop rather than piped into it. Fed
  # through a process substitution, a jq that failed on an error body -- a rolled
  # token, a 429, any 5xx -- produced no rows and no exit status either set -e or
  # pipefail could see, so the loop ran zero times and the stage reported "no other
  # live builds to expire" and exited 0 with every superseded build still live.
  # Nothing was destroyed, but the operator was told the opposite of what happened.
  # "There were none to expire" and "I could not find out" are different answers
  # and this stage must never confuse them.
  #
  # filter[expired]=false spends the page budget on live builds only -- 200 is the
  # documented maximum for this endpoint, so a longer list cannot be answered by
  # asking for more. links.next is reported below instead: quietly expiring the
  # first page of a longer list is the same silence.
  local others rows id ver expired=0 failed=0 newer
  asc_token_fresh
  others="$(asc_get "/v1/builds?limit=200&sort=-uploadedDate&filter%5Bapp%5D=$app_id&filter%5Bexpired%5D=false&fields%5Bbuilds%5D=version,uploadedDate,expired")"

  # An empty body was the one input the guard below could not see: jq reads
  # nothing, emits nothing and exits 0, the loop runs zero times, and the stage
  # prints "there were none to expire" when the truth is "I could not find out".
  # A curl that fails as a process aborts the script at the assignment above; this
  # covers the other case, an edge or a WAF answering 200 with zero bytes.
  #
  # What may be expired: "only the newest build stays live" is a rule about what
  # supersedes what, and a build uploaded after this one supersedes it rather than
  # the other way round. This list is deliberately re-read after the wait in step
  # 6, so a build a colleague or a CI job uploaded during that half hour appears in
  # it -- and with no test for it, it was expired, permanently, for the crime of
  # being newer. The only build this step may expire is one it can prove it came
  # after.
  #
  # That proof is read off the position in Apple's own sort, not off the dates:
  # uploadedDate comes back with a UTC offset (2026-08-03T04:14:26-07:00), not as
  # Z, and compared as strings that instant sorts before 09:00:00Z when it is two
  # hours after it. The direction that error fails in is expiring a build newer
  # than this one. The response is sorted -uploadedDate, so everything after this
  # build in it is older than it whatever offset the timestamps carry. A build
  # missing from its own list cannot be placed at all, which is the "could not find
  # out" path rather than a licence to guess.
  if [ -z "$others" ] || ! rows="$(jq -r --arg id "$build_id" '
        if (.data | type) != "array" then error("no data array")
        elif (.data | map(.id) | index($id)) == null then error("not in its own list")
        else
          (.data | map(.id) | index($id)) as $i
          | [ .data[$i + 1:][]
              | select(.attributes.expired == false)
              | "\(.id)|\(.attributes.version)" ]
            | join("\n")
        end' <<<"$others" 2>/dev/null)"; then
    bad "could not re-read the build list, so no build was expired"
    jq -r '.errors[]? | "         \(.title): \(.detail)"' <<<"$others" >&2 2>/dev/null || true
    note "nothing was expired, so every other build is still live"
    note "re-run distribute to finish the job; it picks up from here"
    return 1
  fi

  newer="$(jq -r --arg id "$build_id" \
    '(.data | map(.id) | index($id)) as $i
     | [ .data[:$i][] | select(.attributes.expired == false) | .attributes.version ]
     | join(", ")' <<<"$others")"
  if [ -n "$newer" ]; then
    note "uploaded after build $BUILD_NUMBER and therefore left live: $newer"
    note "distribute those to supersede this one; expiring them here would be one-way"
  fi
  if [ -n "$(jq -r '.links.next // empty' <<<"$others")" ]; then
    note "more than 200 live builds exist; only the newest 200 were considered here"
    note "any older live build beyond that page is untouched rather than silently expired"
  fi

  if [ "$DRY_RUN" = "1" ] && [ -n "$rows" ]; then
    # The preview lists the one irreversible write whatever the state, so the line
    # introducing it has to carry the verdict as well. Left as a single fixed
    # sentence, a build in a dead-end state was told the run would stop and expire
    # nothing, and then shown the list of builds it would expire.
    if [ "$outcome" -ne 0 ]; then
      note "a real run would stop at the state above and expire none of these"
    elif [ "$ext" = "IN_BETA_TESTING" ]; then
      note "a real run would expire these now"
    else
      note "a real run would expire these only after build $BUILD_NUMBER reached IN_BETA_TESTING"
    fi
  fi

  while IFS='|' read -r id ver; do
    [ -n "$id" ] || continue
    expired=$((expired + 1))
    # The id is in the label because the number is not unique: two builds can carry
    # 75, and "expire build 75" logged while distributing build 75 reads as the
    # exact disaster this stage was written to prevent.
    if ! asc_patch "expire build $ver ($id)" "/v1/builds/$id" \
         "$(printf '{"data":{"id":"%s","type":"builds","attributes":{"expired":true}}}' "$id")"; then
      asc_rejected "could not expire build $ver ($id)"
      failed=$((failed + 1))
    fi
  done <<<"$rows"

  [ "$expired" -gt 0 ] || note "no build older than $BUILD_NUMBER was live"
  [ "$failed" -eq 0 ] || return 1
  return "$outcome"
}

# ------------------------------------------------------------------ metadata ---
#
# Fill in everything App Review needs, from files under release/metadata/, and
# stop there.
#
# The split is deliberate: this stage is the mechanism, and the files are the
# content. Copy, category, age rating and the rights position are judgements, and
# they belong in the repository where they can be diffed and argued with -- not in
# argv, and not in a browser tab where the only record of the decision is that
# somebody once clicked something.
#
# What it never does is submit. POST /v1/reviewSubmissions exists and works; it is
# not called here and must not be added here. This app is named after a band and
# draws its alphabet from that band's iconography, which is Guideline 5.2 territory
# exactly, and whether the rights position is good enough to spend a submission on
# is not a decision a build script gets to make on someone's behalf.
#
# Everything is idempotent. A field already carrying the wanted value is reported
# and not rewritten, an unauthored file is skipped rather than blanking what is
# there, and the stage ends by re-reading Apple's answer rather than trusting its
# own writes.

METADATA_DIR="$REPO_ROOT/release/metadata"
METADATA_LOCALE="${METADATA_LOCALE:-en-US}"

# An absent file and an empty one say the same thing -- not authored yet -- so both
# answer no. That is what makes the stage safe to run against a half-written
# release/metadata/: it fills what exists and leaves the rest alone.
meta_file() {
  local path="$METADATA_DIR/$1"
  [ -s "$path" ] && printf '%s' "$path"
}

# Pull a structured value out of app.json. null, absent and empty string all mean
# unauthored; false does not, so the test cannot be on truthiness.
meta_value() {
  local path="$METADATA_DIR/app.json"
  [ -f "$path" ] || return 0
  jq -r --arg k "$1" '.[$k] | if . == null or . == "" then empty else tostring end' "$path"
}

# Apple enforces these server-side and answers a long field with a generic 409 that
# names the entity rather than the limit. Checking locally turns that into the one
# sentence the operator can act on, before a single request is sent.
meta_too_long() {
  local label="$1" file="$2" limit="$3" len
  # Counted through jq on the same trimmed string the PATCH will carry, so the
  # number checked here is the number Apple receives. wc -m would count the
  # trailing newline this stage strips, and disagree at exactly the boundary.
  len="$(jq -rn --rawfile v "$file" '$v | sub("\\s+$"; "") | length')"
  if [ "$len" -gt "$limit" ]; then
    bad "$label is $len characters; Apple's limit is $limit"
    return 0
  fi
  return 1
}

# PATCH a single-attribute change only when it is actually a change. The read is
# free, the write is not idempotent in Apple's audit log, and a stage that rewrites
# every field on every run makes its own output useless for spotting what moved.
meta_patch_attr() {
  local label="$1" path="$2" type="$3" id="$4" attr="$5" value="$6" current="$7" raw="${8:-string}"
  if [ "$current" = "$value" ]; then
    # The description is 1600 characters long, and echoing it back to say it did
    # not change would bury every line that did.
    if [ "${#value}" -gt 48 ]; then
      ok "$label is already set (${#value} characters, unchanged)"
    else
      ok "$label is already \"$value\""
    fi
    return 0
  fi
  local body
  if [ "$raw" = "bool" ]; then
    body="$(jq -nc --arg id "$id" --arg t "$type" --arg a "$attr" --argjson v "$value" \
      '{data: {id: $id, type: $t, attributes: {($a): $v}}}')"
  else
    body="$(jq -nc --arg id "$id" --arg t "$type" --arg a "$attr" --arg v "$value" \
      '{data: {id: $id, type: $t, attributes: {($a): $v}}}')"
  fi
  if ! asc_patch "set $label" "$path/$id" "$body"; then
    asc_rejected "could not set $label"
    return 1
  fi
}

# ---- screenshots -------------------------------------------------------------
#
# Three calls per image, and the order is fixed: reserve the asset, upload the
# bytes to the URLs Apple hands back, then commit it with a checksum. The commit is
# what makes the asset real; an uploaded-but-uncommitted screenshot sits in
# UPLOAD_COMPLETE forever and does not count towards the submission.

SCREENSHOT_SET_ID=""

ensure_screenshot_set() {
  local loc_id="$1" display_type="$2" sets
  sets="$(asc_get "/v1/appStoreVersionLocalizations/$loc_id/appScreenshotSets?limit=50&fields%5BappScreenshotSets%5D=screenshotDisplayType")"
  SCREENSHOT_SET_ID="$(jq -r --arg t "$display_type" \
    '[.data[]? | select(.attributes.screenshotDisplayType == $t) | .id][0] // empty' <<<"$sets")"
  [ -z "$SCREENSHOT_SET_ID" ] || return 0

  local body
  body="$(jq -nc --arg t "$display_type" --arg loc "$loc_id" \
    '{data: {type: "appScreenshotSets",
             attributes: {screenshotDisplayType: $t},
             relationships: {appStoreVersionLocalization:
               {data: {type: "appStoreVersionLocalizations", id: $loc}}}}}')"
  if ! asc_post "create the $display_type screenshot set" "/v1/appScreenshotSets" "$body"; then
    asc_rejected "could not create the $display_type screenshot set"
    return 1
  fi
  # A dry run has no set to add anything to, and inventing an id here would make
  # the rest of the preview a fiction.
  [ "$DRY_RUN" = "1" ] && return 0
  SCREENSHOT_SET_ID="$(jq -r '.data.id // empty' <<<"$ASC_BODY")"
  [ -n "$SCREENSHOT_SET_ID" ] || { bad "the $display_type set was created but Apple returned no id"; return 1; }
}

# Apple returns one or more upload operations per asset: a method, a URL, headers
# to replay verbatim, and the byte range each one covers. A small PNG comes back as
# a single whole-file PUT, but the range is honoured rather than assumed -- a
# multi-part reservation uploaded as one part yields an asset that never leaves
# UPLOAD_COMPLETE, and the failure surfaces days later as a missing screenshot.
upload_screenshot_parts() {
  local file="$1" operations="$2" count i method url offset length headers part code
  count="$(jq -r 'length' <<<"$operations")"
  for (( i = 0; i < count; i++ )); do
    method="$(jq -r ".[$i].method" <<<"$operations")"
    url="$(jq -r ".[$i].url" <<<"$operations")"
    offset="$(jq -r ".[$i].offset" <<<"$operations")"
    length="$(jq -r ".[$i].length" <<<"$operations")"
    headers="$(jq -c ".[$i].requestHeaders // []" <<<"$operations")"

    part="$TMP_ROOT/part.bin"
    # tail | head rather than dd: dd with bs=1 spends a syscall per byte, and these
    # files are megabytes.
    tail -c "+$((offset + 1))" "$file" | head -c "$length" >"$part"

    local args=(-sS -X "$method" --data-binary "@$part" -o /dev/null -w '%{http_code}')
    while IFS= read -r header; do
      [ -n "$header" ] && args+=(-H "$header")
    done < <(jq -r '.[] | "\(.name): \(.value)"' <<<"$headers")

    code="$(curl "${args[@]}" "$url")"
    case "$code" in
      2*) ;;
      *)  bad "uploading part $((i + 1)) of $(basename "$file") failed (HTTP $code)"; return 1 ;;
    esac
  done
}

upload_screenshot() {
  local set_id="$1" file="$2" name size checksum body ss_id operations
  name="$(basename "$file")"
  size="$(stat -f%z "$file")"

  body="$(jq -nc --arg n "$name" --argjson s "$size" --arg set "$set_id" \
    '{data: {type: "appScreenshots",
             attributes: {fileName: $n, fileSize: $s},
             relationships: {appScreenshotSet: {data: {type: "appScreenshotSets", id: $set}}}}}')"
  if ! asc_post "reserve $name" "/v1/appScreenshots" "$body"; then
    asc_rejected "could not reserve $name"
    return 1
  fi
  [ "$DRY_RUN" = "1" ] && { note "       would then upload $size bytes and commit with an md5 checksum"; return 0; }

  ss_id="$(jq -r '.data.id // empty' <<<"$ASC_BODY")"
  operations="$(jq -c '.data.attributes.uploadOperations // []' <<<"$ASC_BODY")"
  if [ -z "$ss_id" ] || [ "$(jq -r 'length' <<<"$operations")" = "0" ]; then
    bad "$name was reserved but Apple returned no upload operations"
    return 1
  fi

  upload_screenshot_parts "$file" "$operations" || return 1

  # The checksum is Apple's own integrity check on what it just received, and the
  # commit is refused without it.
  checksum="$(md5 -q "$file")"
  body="$(jq -nc --arg id "$ss_id" --arg sum "$checksum" \
    '{data: {id: $id, type: "appScreenshots", attributes: {uploaded: true, sourceFileChecksum: $sum}}}')"
  if ! asc_patch "commit $name" "/v1/appScreenshots/$ss_id" "$body"; then
    asc_rejected "could not commit $name"
    return 1
  fi
}

# Apple validates dimensions after the commit, not during it, so a wrong-sized
# screenshot uploads cleanly and then fails asynchronously. Reading the delivery
# state back is the only way to know an accepted upload produced a usable asset.
#
# Three states, and conflating the middle one with the last is the mistake worth
# avoiding: COMPLETE is accepted, FAILED is rejected and names why, and
# UPLOAD_COMPLETE means Apple has the bytes and has not finished looking at them.
# Reporting "not yet" as a failure a second after uploading would make every clean
# run look broken.
report_screenshot_state() {
  local set_id="$1" shots
  shots="$(asc_get "/v1/appScreenshotSets/$set_id/appScreenshots?limit=50&fields%5BappScreenshots%5D=fileName,assetDeliveryState")"
  jq -r '.data[]? | .attributes as $a
    | ($a.assetDeliveryState.state // "?") as $state
    | ([$a.assetDeliveryState.errors[]?.description] | join("; ")) as $why
    | if $state == "COMPLETE" then "  [ok]   \($a.fileName) accepted"
      elif $state == "UPLOAD_COMPLETE" and $why == ""
        then "  [--]   \($a.fileName) uploaded, still being validated by Apple"
      else "  [!!]   \($a.fileName) is \($state)" + (if $why == "" then "" else ": \($why)" end)
      end' <<<"$shots"
}

do_metadata() {
  if ! have_asc_key; then
    bad "metadata needs an App Store Connect API key"
    note "set ASC_KEY_ID and ASC_ISSUER_ID, and put the .p8 at $ASC_KEY_PATH"
    return 1
  fi
  command -v jq >/dev/null || { bad "metadata needs jq"; return 1; }
  if [ ! -d "$METADATA_DIR" ]; then
    bad "no $METADATA_DIR"
    note "the listing content lives in files there; see release/metadata/README.md"
    return 1
  fi

  asc_token_fresh
  if [ "$DRY_RUN" = "1" ]; then
    step "Dry run"
    note "every read below is real; every write is printed and not sent"
  fi

  # ---- the app record ------------------------------------------------------
  step "App record"
  local app app_id
  app="$(asc_get "/v1/apps?filter%5BbundleId%5D=$APP_BUNDLE_ID&fields%5Bapps%5D=name,bundleId,contentRightsDeclaration")"
  if [ -n "$(jq -r '.errors // empty' <<<"$app")" ]; then
    bad "App Store Connect rejected the request:"
    jq -r '.errors[] | "         \(.title): \(.detail)"' <<<"$app" >&2
    return 1
  fi
  app_id="$(jq -r '.data[0].id // empty' <<<"$app")"
  if [ -z "$app_id" ]; then
    bad "no app record for $APP_BUNDLE_ID"
    note "the app record is created by hand in App Store Connect; see docs/RELEASE.md"
    return 1
  fi
  ok "$(jq -r '.data[0].attributes.name' <<<"$app") ($APP_BUNDLE_ID), Apple ID $app_id"

  # ---- the version, and whether it is still writable -----------------------
  local versions version_id version_state
  versions="$(asc_get "/v1/apps/$app_id/appStoreVersions?limit=1&fields%5BappStoreVersions%5D=versionString,appStoreState,copyright,usesIdfa")"
  version_id="$(jq -r '.data[0].id // empty' <<<"$versions")"
  version_state="$(jq -r '.data[0].attributes.appStoreState // empty' <<<"$versions")"
  if [ -z "$version_id" ]; then
    bad "no App Store version exists yet"
    note "create version $(marketing_version) in App Store Connect first"
    return 1
  fi
  # Once a version is with Apple these fields are frozen, and a PATCH against a
  # frozen version is refused per-field with errors that read like bugs in this
  # script. Stopping up front is the honest failure.
  if [ "$version_state" != "PREPARE_FOR_SUBMISSION" ]; then
    bad "version $(jq -r '.data[0].attributes.versionString' <<<"$versions") is $version_state, not PREPARE_FOR_SUBMISSION"
    note "its metadata is frozen while Apple holds it; nothing was written"
    return 1
  fi
  ok "version $(jq -r '.data[0].attributes.versionString' <<<"$versions") is editable"

  local failed=0

  # ---- content rights ------------------------------------------------------
  #
  # Left unauthored on purpose. This is the declaration that tells Apple whether
  # the app contains third-party content, and for this app it is the same question
  # Guideline 5.2 asks. It is a legal position, not a config value, so the script
  # will write whatever app.json says and will never pick for you.
  step "Content rights"
  local rights
  rights="$(meta_value contentRightsDeclaration)"
  if [ -z "$rights" ]; then
    note "contentRightsDeclaration is unset in app.json -- skipped"
    note "USES_THIRD_PARTY_CONTENT or DOES_NOT_USE_THIRD_PARTY_CONTENT; yours to answer, see release/metadata/README.md"
  else
    meta_patch_attr "content rights" "/v1/apps" "apps" "$app_id" \
      contentRightsDeclaration "$rights" \
      "$(jq -r '.data[0].attributes.contentRightsDeclaration // empty' <<<"$app")" || failed=1
  fi

  # ---- app info: categories, age rating, privacy policy --------------------
  #
  # These live on appInfos rather than on the version. Reaching for
  # /v1/appStoreVersions/<id>/ageRatingDeclaration looks right and answers 404
  # PATH_ERROR: the relationship genuinely does not exist there.
  step "App information"
  local infos info_id primary secondary
  infos="$(asc_get "/v1/apps/$app_id/appInfos?include=primaryCategory,secondaryCategory&fields%5BappInfos%5D=appStoreState,appStoreAgeRating,primaryCategory,secondaryCategory")"
  info_id="$(jq -r '[.data[] | select(.attributes.appStoreState == "PREPARE_FOR_SUBMISSION")][0].id // .data[0].id' <<<"$infos")"

  primary="$(meta_value primaryCategory)"
  secondary="$(meta_value secondaryCategory)"
  local cat_body="{}" cat_label=""
  if [ -n "$primary" ] && \
     [ "$primary" != "$(jq -r --arg i "$info_id" '[.data[] | select(.id == $i)][0].relationships.primaryCategory.data.id // empty' <<<"$infos")" ]; then
    cat_body="$(jq -nc --arg c "$primary" '{primaryCategory: {data: {type: "appCategories", id: $c}}}')"
    cat_label="primary category $primary"
  fi
  if [ -n "$secondary" ] && \
     [ "$secondary" != "$(jq -r --arg i "$info_id" '[.data[] | select(.id == $i)][0].relationships.secondaryCategory.data.id // empty' <<<"$infos")" ]; then
    cat_body="$(jq -nc --argjson base "$cat_body" --arg c "$secondary" \
      '$base + {secondaryCategory: {data: {type: "appCategories", id: $c}}}')"
    cat_label="${cat_label:+$cat_label, }secondary category $secondary"
  fi
  if [ "$cat_body" != "{}" ]; then
    if ! asc_patch "set $cat_label" "/v1/appInfos/$info_id" \
         "$(jq -nc --arg id "$info_id" --argjson rel "$cat_body" \
            '{data: {id: $id, type: "appInfos", relationships: $rel}}')"; then
      asc_rejected "could not set the categories"
      failed=1
    fi
  else
    [ -n "$primary" ] && ok "categories already set" || note "no categories in app.json -- skipped"
  fi

  # The age rating declaration shares the app info's id, which looks like a bug in
  # the API and is not: the relationship resolves to the same uuid.
  local rating_file
  if rating_file="$(meta_file age-rating.json)"; then
    local rating_body
    rating_body="$(jq -nc --arg id "$info_id" --slurpfile attrs "$rating_file" \
      '{data: {id: $id, type: "ageRatingDeclarations", attributes: $attrs[0]}}')"
    if ! asc_patch "set the age rating declaration" "/v1/ageRatingDeclarations/$info_id" "$rating_body"; then
      asc_rejected "could not set the age rating declaration"
      failed=1
    fi
  else
    note "no age-rating.json -- skipped"
  fi

  local info_locs info_loc_id subtitle privacy
  info_locs="$(asc_get "/v1/appInfos/$info_id/appInfoLocalizations?fields%5BappInfoLocalizations%5D=locale,name,subtitle,privacyPolicyUrl")"
  info_loc_id="$(jq -r --arg l "$METADATA_LOCALE" '[.data[] | select(.attributes.locale == $l)][0].id // empty' <<<"$info_locs")"
  if [ -z "$info_loc_id" ]; then
    bad "no $METADATA_LOCALE app info localization"
    failed=1
  else
    # The App Store name is a localization attribute, not an app attribute, and it
    # is the one field here that is also a trademark decision -- so it is authored
    # in app.json like everything else rather than derived from the bundle.
    local store_name
    store_name="$(meta_value name)"
    if [ -n "$store_name" ]; then
      printf '%s' "$store_name" >"$TMP_ROOT/store_name"
      if meta_too_long "app name" "$TMP_ROOT/store_name" 30; then
        failed=1
      else
        meta_patch_attr "app name" "/v1/appInfoLocalizations" appInfoLocalizations "$info_loc_id" \
          name "$store_name" \
          "$(jq -r --arg l "$METADATA_LOCALE" '[.data[] | select(.attributes.locale == $l)][0].attributes.name // empty' <<<"$info_locs")" || failed=1
      fi
    else
      note "no name in app.json -- skipped"
    fi

    subtitle="$(meta_value subtitle)"
    if [ -n "$subtitle" ]; then
      printf '%s' "$subtitle" >"$TMP_ROOT/subtitle"
      if meta_too_long "subtitle" "$TMP_ROOT/subtitle" 30; then
        failed=1
      else
        meta_patch_attr "subtitle" "/v1/appInfoLocalizations" appInfoLocalizations "$info_loc_id" \
          subtitle "$subtitle" \
          "$(jq -r --arg l "$METADATA_LOCALE" '[.data[] | select(.attributes.locale == $l)][0].attributes.subtitle // empty' <<<"$info_locs")" || failed=1
      fi
    else
      note "no subtitle in app.json -- skipped"
    fi

    privacy="$(meta_value privacyPolicyUrl)"
    if [ -n "$privacy" ]; then
      meta_patch_attr "privacy policy URL" "/v1/appInfoLocalizations" appInfoLocalizations "$info_loc_id" \
        privacyPolicyUrl "$privacy" \
        "$(jq -r --arg l "$METADATA_LOCALE" '[.data[] | select(.attributes.locale == $l)][0].attributes.privacyPolicyUrl // empty' <<<"$info_locs")" || failed=1
    else
      note "no privacyPolicyUrl in app.json -- skipped"
    fi
  fi

  # ---- version attributes: copyright and IDFA ------------------------------
  step "Version attributes"
  local copyright idfa
  copyright="$(meta_value copyright)"
  if [ -n "$copyright" ]; then
    meta_patch_attr "copyright" "/v1/appStoreVersions" appStoreVersions "$version_id" \
      copyright "$copyright" "$(jq -r '.data[0].attributes.copyright // empty' <<<"$versions")" || failed=1
  else
    note "no copyright in app.json -- skipped"
  fi

  # usesIdfa is a tri-state and false is a real answer, so it is read as JSON
  # rather than through the empty-means-unset shortcut the strings use.
  idfa="$(jq -r '.usesIdfa | if . == null then empty else tostring end' "$METADATA_DIR/app.json" 2>/dev/null || true)"
  if [ -n "$idfa" ]; then
    meta_patch_attr "IDFA declaration" "/v1/appStoreVersions" appStoreVersions "$version_id" \
      usesIdfa "$idfa" \
      "$(jq -r '.data[0].attributes.usesIdfa | if . == null then empty else tostring end' <<<"$versions")" bool || failed=1
  else
    note "no usesIdfa in app.json -- skipped"
  fi

  # ---- the listing copy ----------------------------------------------------
  step "Listing copy ($METADATA_LOCALE)"
  local locs loc_id
  locs="$(asc_get "/v1/appStoreVersions/$version_id/appStoreVersionLocalizations?fields%5BappStoreVersionLocalizations%5D=locale,description,keywords,supportUrl,marketingUrl,promotionalText,whatsNew")"
  loc_id="$(jq -r --arg l "$METADATA_LOCALE" '[.data[] | select(.attributes.locale == $l)][0].id // empty' <<<"$locs")"
  if [ -z "$loc_id" ]; then
    bad "no $METADATA_LOCALE version localization to write to"
    failed=1
  else
    local current="$(jq -c --arg l "$METADATA_LOCALE" '[.data[] | select(.attributes.locale == $l)][0].attributes' <<<"$locs")"
    local field file limit attr label
    # file basename, API attribute, Apple's character limit, what to call it.
    while IFS='|' read -r field attr limit label; do
      if ! file="$(meta_file "$METADATA_LOCALE/$field.txt")"; then
        note "no $METADATA_LOCALE/$field.txt -- skipped"
        continue
      fi
      if meta_too_long "$label" "$file" "$limit"; then
        failed=1
        continue
      fi
      # --rawfile keeps the file's trailing newline, which Apple stores verbatim
      # and the web UI then shows as a stray blank line.
      local want
      want="$(jq -rn --rawfile v "$file" '$v | sub("\\s+$"; "")')"
      meta_patch_attr "$label" "/v1/appStoreVersionLocalizations" appStoreVersionLocalizations "$loc_id" \
        "$attr" "$want" "$(jq -r --arg a "$attr" '.[$a] // empty' <<<"$current")" || failed=1
    done <<'FIELDS'
description|description|4000|description
keywords|keywords|100|keywords
support-url|supportUrl|255|support URL
marketing-url|marketingUrl|255|marketing URL
promotional-text|promotionalText|170|promotional text
whats-new|whatsNew|4000|what's new
FIELDS
  fi

  # ---- the build under review ----------------------------------------------
  #
  # Which build goes to App Review is not the same question as which build this
  # checkout would produce. Defaulting to the commit count would attach a build
  # that may not exist yet, so the default here is the newest build Apple actually
  # has, and BUILD_NUMBER only wins when it was asked for explicitly.
  step "Build under review"
  local builds want_build build_id attached
  builds="$(asc_get "/v1/builds?limit=200&sort=-uploadedDate&filter%5Bapp%5D=$app_id&fields%5Bbuilds%5D=version,uploadedDate,processingState,expired")"
  if ! jq -e '(.data | type) == "array"' <<<"$builds" >/dev/null 2>&1; then
    bad "could not read the build list"
    jq -r '.errors[]? | "         \(.title): \(.detail)"' <<<"$builds" >&2 2>/dev/null || true
    failed=1
  else
    if [ -n "$BUILD_NUMBER_WAS_SET" ]; then
      want_build="$BUILD_NUMBER"
    else
      want_build="$(jq -r '[.data[] | select(.attributes.expired == false and .attributes.processingState == "VALID")][0].attributes.version // empty' <<<"$builds")"
      [ -n "$want_build" ] && note "no BUILD_NUMBER given, so using the newest live build: $want_build"
    fi
    build_id="$(jq -r --arg v "$want_build" \
      '[.data[] | select(.attributes.version == $v and .attributes.expired == false)][0].id // empty' <<<"$builds")"
    if [ -z "$build_id" ]; then
      bad "no live build $want_build to attach"
      note "live builds: $(jq -r '[.data[] | select(.attributes.expired == false) | .attributes.version] | join(", ")' <<<"$builds")"
      failed=1
    else
      attached="$(asc_get "/v1/appStoreVersions/$version_id/build?fields%5Bbuilds%5D=version" | jq -r '.data.id // empty')"
      if [ "$attached" = "$build_id" ]; then
        ok "build $want_build is already attached"
      elif ! asc_patch "attach build $want_build" "/v1/appStoreVersions/$version_id/relationships/build" \
             "$(jq -nc --arg id "$build_id" '{data: {type: "builds", id: $id}}')"; then
        asc_rejected "could not attach build $want_build"
        failed=1
      fi
    fi
  fi

  # ---- App Review contact details ------------------------------------------
  step "App Review contact"
  local detail detail_id contact notes_file review_attrs
  detail="$(asc_get "/v1/appStoreVersions/$version_id/appStoreReviewDetail")"
  detail_id="$(jq -r '.data.id // empty' <<<"$detail")"
  contact="$(meta_file review/contact.json || true)"
  notes_file="$(meta_file review/notes.txt || true)"

  # contact.local.json is merged over contact.json and is gitignored, because this
  # repository is public and the review contact is the one field here that is
  # personal data rather than product copy. A phone number committed to a public
  # repo is permanent -- forks and mirrors keep it after any later deletion -- so
  # the number reaches Apple without ever entering git history.
  local contact_local="$METADATA_DIR/review/contact.local.json"
  if [ -n "$contact" ] && [ -s "$contact_local" ]; then
    if jq -se '.[0] * .[1]' "$contact" "$contact_local" >"$TMP_ROOT/contact.json" 2>/dev/null; then
      contact="$TMP_ROOT/contact.json"
      ok "merged review/contact.local.json over the committed contact"
    else
      # Not silently falling back to the committed file: it is the one with the
      # blank phone, so the fallback would look like a clean run and send nothing.
      bad "review/contact.local.json is not valid JSON, so the contact was not sent"
      failed=1
      contact=""
    fi
  elif [ -n "$contact" ] && [ ! -e "$contact_local" ]; then
    note "no review/contact.local.json; the committed contact is being used as-is"
  fi

  if [ -z "$contact" ]; then
    note "no usable review contact -- skipped"
  else
    # Apple requires all four contact fields and answers a missing one with a 409
    # naming the entity rather than the field. Checking here turns that into the
    # name of the thing to go and fill in.
    local blank
    blank="$(jq -r '["contactFirstName","contactLastName","contactEmail","contactPhone"]
                    - [to_entries[] | select((.value | tostring) != "") | .key]
                    | join(", ")' "$contact")"
    if [ -n "$blank" ]; then
      bad "review/contact.json is missing: $blank"
      note "App Review will not accept a partial contact, so none of it was sent"
      failed=1
      contact=""
    fi
  fi
  if [ -n "$contact" ]; then
    review_attrs="$(jq -c '.' "$contact")"
    if [ -n "$notes_file" ]; then
      review_attrs="$(jq -c --rawfile n "$notes_file" '. + {notes: ($n | sub("\\s+$"; ""))}' <<<"$review_attrs")"
    fi
    if [ -n "$detail_id" ]; then
      if ! asc_patch "update the review contact" "/v1/appStoreReviewDetails/$detail_id" \
           "$(jq -nc --arg id "$detail_id" --argjson a "$review_attrs" \
              '{data: {id: $id, type: "appStoreReviewDetails", attributes: $a}}')"; then
        asc_rejected "could not update the review contact"
        failed=1
      fi
    elif ! asc_post "create the review contact" "/v1/appStoreReviewDetails" \
           "$(jq -nc --arg v "$version_id" --argjson a "$review_attrs" \
              '{data: {type: "appStoreReviewDetails", attributes: $a,
                       relationships: {appStoreVersion: {data: {type: "appStoreVersions", id: $v}}}}}')"; then
      asc_rejected "could not create the review contact"
      failed=1
    fi
  fi

  # ---- screenshots ---------------------------------------------------------
  step "Screenshots"
  if [ -z "${loc_id:-}" ]; then
    note "no version localization, so nothing to attach screenshots to"
  elif [ ! -d "$METADATA_DIR/screenshots" ]; then
    note "no release/metadata/screenshots/ -- skipped"
  else
    local display_dir display_type shot existing
    for display_dir in "$METADATA_DIR"/screenshots/*/; do
      [ -d "$display_dir" ] || continue
      display_type="$(basename "$display_dir")"
      # The set is per display type, and Apple validates the image dimensions
      # against the type after the commit rather than before it.
      ensure_screenshot_set "$loc_id" "$display_type" || { failed=1; continue; }
      if [ -z "$SCREENSHOT_SET_ID" ]; then
        note "the $display_type set does not exist yet, so its uploads are not previewed"
        continue
      fi
      existing="$(asc_get "/v1/appScreenshotSets/$SCREENSHOT_SET_ID/appScreenshots?limit=50&fields%5BappScreenshots%5D=fileName,sourceFileChecksum,assetDeliveryState")"
      local shot_name shot_sum stale
      for shot in "$display_dir"*.png; do
        [ -f "$shot" ] || continue
        shot_name="$(basename "$shot")"
        shot_sum="$(md5 -q "$shot")"
        # Matched on checksum, not on filename. Screenshots get re-captured, and
        # dedupe by name alone means an edited image under the same name is
        # silently never replaced -- the listing keeps showing the old one and the
        # run reports "already uploaded", which is the worst of both answers.
        if [ -n "$(jq -r --arg n "$shot_name" --arg s "$shot_sum" \
             '[.data[]? | select(.attributes.fileName == $n
                                 and .attributes.sourceFileChecksum == $s
                                 and (.attributes.assetDeliveryState.state // "") == "COMPLETE")][0].id // empty' <<<"$existing")" ]; then
          ok "$shot_name is already uploaded, unchanged"
          continue
        fi
        # Apple has no replace, so a changed image is a delete and a re-upload.
        # Scoped and recoverable -- the source of truth is the file on disk -- but
        # said out loud rather than done quietly.
        stale="$(jq -r --arg n "$shot_name" \
          '[.data[]? | select(.attributes.fileName == $n)][0].id // empty' <<<"$existing")"
        if [ -n "$stale" ]; then
          note "$shot_name changed on disk, so the uploaded copy is being replaced"
          if ! asc_mutate "remove the previous $shot_name" DELETE "/v1/appScreenshots/$stale" ""; then
            asc_rejected "could not remove the previous $shot_name"
            failed=1
            continue
          fi
        fi
        upload_screenshot "$SCREENSHOT_SET_ID" "$shot" || failed=1
      done

      # Renaming a slug leaves the old upload behind under its old name, and
      # nothing above would ever touch it: the loop only visits files that exist on
      # disk. The listing would then show both, in filename order, and the extra one
      # is invisible from here. The directory is the source of truth, so anything
      # uploaded that is no longer in it goes.
      local orphan_name
      while IFS= read -r orphan_name; do
        [ -n "$orphan_name" ] || continue
        [ -f "$display_dir$orphan_name" ] && continue
        note "$orphan_name is uploaded but no longer in $display_type/"
        if ! asc_mutate "remove the orphaned $orphan_name" DELETE \
             "/v1/appScreenshots/$(jq -r --arg n "$orphan_name" \
               '[.data[]? | select(.attributes.fileName == $n)][0].id' <<<"$existing")" ""; then
          asc_rejected "could not remove the orphaned $orphan_name"
          failed=1
        fi
      done < <(jq -r '.data[]?.attributes.fileName' <<<"$existing")

      [ "$DRY_RUN" = "1" ] || report_screenshot_state "$SCREENSHOT_SET_ID"
    done
  fi

  # ---- what Apple says is still missing ------------------------------------
  #
  # Read back rather than reported from the writes above. A stage that trusts its
  # own 204s is exactly how a version gets declared ready and then sits in
  # PREPARE_FOR_SUBMISSION with one empty field nobody looked for.
  if [ "$DRY_RUN" = "1" ]; then
    step "Dry run complete"
    note "nothing was written, so the state below is unchanged"
  fi
  do_status || true

  step "Not submitted, deliberately"
  note "this stage never POSTs /v1/reviewSubmissions -- submitting is a rights decision, not a build step"
  note "see docs/RELEASE.md, 'Submitting for App Review', for what that costs and who decides"

  [ "$failed" -eq 0 ] || { step "Some writes were refused"; return 1; }
  return 0
}

# --------------------------------------------------------------------- main ---

# status and distribute both act on a build that already exists, so they
# deliberately skip preflight: none of the local toolchain matters, and requiring
# Xcode to answer "did review finish" would make either stage useless from a
# machine that only has the key. distribute in particular must never build, so
# gating it behind the Xcode preflight would be gating it on something it does not
# and must not do.
case "$STAGE" in
  status)
    do_status
    exit $? ;;
  distribute)
    do_distribute
    exit $? ;;
  metadata)
    do_metadata
    exit $? ;;
esac

if ! preflight; then
  step "Preflight failed"
  exit 1
fi

case "$STAGE" in
  preflight) step "Preflight passed -- nothing built"; exit 0 ;;
  archive)   do_archive ;;
  validate)  do_archive; do_validate ;;
  upload)    do_archive; do_validate; do_upload ;;
esac

step "Done: $STAGE"
