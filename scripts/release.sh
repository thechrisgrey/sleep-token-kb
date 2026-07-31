#!/usr/bin/env bash
# Archive, export, and upload a signed build to App Store Connect.
#
# archive, validate and upload are cumulative, and the default stage never
# uploads anything. preflight and status build nothing and change nothing:
#
#   scripts/release.sh preflight   inspect the environment; builds nothing
#   scripts/release.sh status      ask App Store Connect where the app stands
#   scripts/release.sh archive     archive and export a signed .ipa   (default)
#   scripts/release.sh validate    ...then run App Store validation on it
#   scripts/release.sh upload      ...then upload it to App Store Connect
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
BUILD_NUMBER="${BUILD_NUMBER:-$(git rev-list --count HEAD 2>/dev/null || echo 1)}"

STAGE="${1:-archive}"
case "$STAGE" in
  preflight|status|archive|validate|upload) ;;
  # Print the header comment and stop at the first line that is not one, so the
  # usage text cannot drift out of range as this file grows.
  -h|--help|help)
    awk 'NR>1 && /^#/ { sub(/^# ?/, ""); print; next } NR>1 { exit }' "$0"
    exit 0 ;;
  *) echo "Unknown stage: $STAGE (expected preflight, status, archive, validate, or upload)" >&2; exit 2 ;;
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
  versions="$(asc_get "/v1/apps/$app_id/appStoreVersions?limit=5&fields%5BappStoreVersions%5D=versionString,appStoreState,appVersionState,createdDate")"
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
  local loc loc_id shots infos

  required "content rights declaration" \
    "$(jq -r '.data[0].attributes.contentRightsDeclaration' <<<"$app")" || true

  infos="$(asc_get "/v1/apps/$app_id/appInfos?fields%5BappInfos%5D=appStoreAgeRating")"
  required "age rating" "$(jq -r '.data[0].attributes.appStoreAgeRating' <<<"$infos")" || true

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
      ok "screenshots: $(jq -r '.data | length' <<<"$shots") set(s)"
    fi
  fi

  if [ -n "$(jq -r '.data // empty' <<<"$(asc_get "/v1/appStoreVersions/$version_id/appStoreReviewDetail")")" ]; then
    ok "App Review contact details"
  else
    bad "App Review contact details -- not set"
  fi

  note "all of the above are web-UI only; the API cannot fill them in for you"
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
}

# --------------------------------------------------------------------- main ---

# status asks Apple about a build that already exists, so it deliberately skips
# preflight: none of the local toolchain matters, and requiring Xcode to answer
# "did review finish" would make the stage useless from a machine that only has
# the key.
if [ "$STAGE" = "status" ]; then
  do_status
  exit $?
fi

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
