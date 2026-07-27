#!/usr/bin/env bash
# Archive, export, and upload a signed build to App Store Connect.
#
# Stages are cumulative, and the default stage never uploads anything:
#
#   scripts/release.sh preflight   inspect the environment; builds nothing
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
APP_BUNDLE_ID="ai.altivum.SleepTokenFanKB"
EXPORT_OPTIONS="$REPO_ROOT/scripts/ExportOptions.plist"
BUILD_DIR="$REPO_ROOT/build/release"
ARCHIVE_PATH="$BUILD_DIR/$SCHEME.xcarchive"
EXPORT_DIR="$BUILD_DIR/export"
IPA_PATH="$EXPORT_DIR/$SCHEME.ipa"

ASC_KEY_PATH="${ASC_KEY_PATH:-$HOME/.appstoreconnect/private_keys/AuthKey_${ASC_KEY_ID:-unset}.p8}"
BUILD_NUMBER="${BUILD_NUMBER:-$(git rev-list --count HEAD 2>/dev/null || echo 1)}"

STAGE="${1:-archive}"
case "$STAGE" in
  preflight|archive|validate|upload) ;;
  -h|--help|help) sed -n '2,40p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
  *) echo "Unknown stage: $STAGE (expected preflight, archive, validate, or upload)" >&2; exit 2 ;;
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
  if security find-identity -v -p codesigning 2>/dev/null | grep -q "Apple Distribution"; then
    ok "an Apple Distribution certificate is installed"
  else
    note "no Apple Distribution certificate installed yet"
    note "Xcode will create one on first archive, given an API key and -allowProvisioningUpdates"
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

# Auth flags shared by archive and export. Empty when no key is configured, which
# lets a locally signed-in Xcode still archive.
auth_args() {
  if have_asc_key; then
    printf '%s\n' \
      -allowProvisioningUpdates \
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
