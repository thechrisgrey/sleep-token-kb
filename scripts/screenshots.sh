#!/usr/bin/env bash
# Capture the App Store screenshot sets for the host app from the iOS Simulator.
#
# The app is universal -- project.yml sets TARGETED_DEVICE_FAMILY "1,2" -- so the
# App Store wants two complete sets and this script produces both:
#
#   release/metadata/screenshots/APP_IPHONE_67/           the 6.7"/6.9" iPhone set
#   release/metadata/screenshots/APP_IPAD_PRO_3GEN_129/   the 12.9"/13" iPad set
#
# The directories are named for the App Store Connect API's screenshot display
# types so the destination of a file is readable off its path. Files carry a
# zero-padded ordering prefix because the App Store shows screenshots in the order
# they are listed, which makes the order a decision rather than a byproduct: the
# brand surface, then the reason to install, then proof the alphabet is real, then
# the second theme, then what the user controls.
#
# Nothing here uploads. Screenshots reach a version through App Store Connect,
# which this script deliberately never talks to -- it only fills the directories.
#
# The keyboard extension is absent on purpose. It cannot be driven in the Simulator
# at all (CLAUDE.md), and a composited keyboard shot would be a picture of
# something that was never rendered. Those keycaps are photographed by hand, on a
# device, and this script does not pretend otherwise.
#
# Knobs, all optional:
#
#   DEVICE        the iPhone to shoot on   (default iPhone 17 Pro Max -> 1320x2868)
#   DEVICE_IPAD   the iPad to shoot on     (default iPad Pro 12.9-inch 6th gen -> 2048x2732)
#   ONLY          iphone or ipad, to shoot a single set
#   KEEP_BOOTED   1 leaves the simulators running when the run finishes
#   DEVELOPER_DIR overrides which Xcode is used
#
# Re-running is the normal case and costs nothing but time: each set reinstalls the
# app from scratch and overwrites its own files in place.
set -euo pipefail

# Same reason as scripts/test.sh and scripts/release.sh: `xcode-select -p` on this
# machine points at the Command Line Tools, which makes xcodebuild refuse to run.
# Override it for this process only -- no sudo, no change to the machine's global
# toolchain setting.
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"

cd "$(dirname "$0")/.."
REPO_ROOT="$PWD"

PROJECT="SleepTokenKB.xcodeproj"
SCHEME="SleepTokenKB"
APP_BUNDLE_ID="ai.altivum.SleepTokenKB"
# Its own derived-data root, so a screenshot run never invalidates the incremental
# build that scripts/test.sh is working from.
DERIVED_DIR="$REPO_ROOT/build/screenshots"
APP_PATH="$DERIVED_DIR/Build/Products/Debug-iphonesimulator/$SCHEME.app"
OUT_ROOT="$REPO_ROOT/release/metadata/screenshots"

DEVICE="${DEVICE:-iPhone 17 Pro Max}"
DEVICE_IPAD="${DEVICE_IPAD:-iPad Pro (12.9-inch) (6th generation)}"
ONLY="${ONLY:-both}"

case "$ONLY" in
  both|iphone|ipad) ;;
  *) echo "ONLY=$ONLY is not a set (expected iphone, ipad, or unset)" >&2; exit 2 ;;
esac

ok()   { printf '  [ok]   %s\n' "$*"; }
note() { printf '  [--]   %s\n' "$*"; }
bad()  { printf '  [!!]   %s\n' "$*" >&2; }
step() { printf '\n==> %s\n' "$*"; }

TMP_ROOT="$(mktemp -d)"
BOOTED_HERE=()
cleanup() {
  rm -rf "$TMP_ROOT"
  if [ "${KEEP_BOOTED:-0}" != "1" ]; then
    local udid
    for udid in ${BOOTED_HERE[@]+"${BOOTED_HERE[@]}"}; do
      xcrun simctl shutdown "$udid" >/dev/null 2>&1 || true
    done
  fi
}
trap cleanup EXIT

# The sizes Apple lists for each set, from
# developer.apple.com/help/app-store-connect/reference/screenshot-specifications.
# Checked rather than assumed: a set captured at a size Apple does not list is
# refused at upload, and by then the only thing that can be changed about it is the
# device it was shot on. The iPad set is captured at 2048x2732 because that size
# appears under both the 12.9" and the 13" headings, which makes it the one value
# that cannot be wrong for a slot named after the 12.9" iPad Pro.
IPHONE_ACCEPTED="1260x2736 1290x2796 1320x2868"
IPAD_ACCEPTED="2064x2752 2048x2732"

# order | file slug | Rune Pad seed, Latin, blank everywhere else | launch arguments
#
# Both themes and every distinct surface, in display order. Home carries the hero,
# the destinations and the unaffiliated notice, so it opens and it repeats in
# Arcadia -- the two themes are one structure in two palettes, and showing the same
# screen twice is the only way to say so. Rune Pad is second because a composed
# inscription is the thing the app is downloaded for.
#
# The Rune Pad seed is the app's own copy rather than anything of the band's. A
# store screenshot is the most public asset in the project, and PRODUCT.md names
# merch mimicry as the sharpest anti-reference now that public release is the goal:
# an inscription of their devotional phrase, on a listing already exposed to
# Guideline 5.2, spends risk to demonstrate nothing extra. Any a-z string works, so
# the safer one is free.
SHOTS=(
  "01|home-ritual||-force-ritual -force-enable-card"
  "02|rune-pad-ritual|the runes follow you|-force-ritual -route-runepad"
  "03|alphabet-ritual||-force-ritual -route-alphabet"
  "04|home-eia||-force-arcadia -force-enable-card"
  "05|settings-eia||-force-arcadia -route-settings"
)

# ------------------------------------------------------------------ devices ---

# `simctl list devices available` prints one section per runtime, oldest runtime
# first, and one indented line per device: "<name> (<udid>) (<state>)". So the last
# line matching the name is that device on the newest installed runtime. The runtime
# is printed alongside rather than merely used, because "which OS did these come
# from" is a question about the screenshots themselves.
#
# The trailing " (" is what anchors the match: without it "iPhone 17 Pro" also
# selects "iPhone 17 Pro Max".
device_line() {
  xcrun simctl list devices available | awk -v name="$1" '
    /^-- / { runtime = $0; gsub(/^-- | --$/, "", runtime); next }
    index($0, name " (") { found = $0; at = runtime }
    END {
      if (found == "") exit 1
      match(found, /[0-9A-F]{8}-[0-9A-F-]{27}/)
      print substr(found, RSTART, RLENGTH) "\t" at
    }'
}

# Create the device rather than fail on it. A named simulator that happens not to
# exist on this machine is a setup detail, not a decision anybody made, and the
# device type is looked up by the same name so an overridden DEVICE works too.
create_device() {
  local name="$1" type runtime
  # No `exit` in the awk: it would close the pipe early and, under pipefail, the
  # assignment would fail on simctl's SIGPIPE rather than on a missing device type.
  type="$(xcrun simctl list devicetypes \
    | awk -v n="$name" 'index($0, n " (com.apple") && t == "" { t = $NF } END { print t }' \
    | tr -d '()')"
  if [ -z "$type" ]; then
    bad "no simulator named \"$name\" exists and no device type matches that name either"
    note "pick one from: xcrun simctl list devicetypes"
    return 1
  fi
  runtime="$(xcrun simctl list runtimes | awk '/^iOS /{ id = $NF } END { print id }')"
  if [ -z "$runtime" ]; then
    bad "no iOS simulator runtime is installed"
    return 1
  fi
  note "creating \"$name\" on $runtime"
  xcrun simctl create "$name" "$type" "$runtime" >/dev/null
}

# Resolves the name to a booted device, and records whether this run booted it so
# cleanup can put the machine back the way it found it.
#
# The answer comes back in globals rather than on stdout. Every other function here
# reports as it goes, and a function that both reports and returns a value on the
# same channel hands its caller the log lines as part of the value.
DEVICE_UDID=""
DEVICE_RUNTIME=""
boot_device() {
  local name="$1" line
  if ! line="$(device_line "$name")"; then
    create_device "$name" || return 1
    line="$(device_line "$name")" || { bad "created \"$name\" but cannot find it"; return 1; }
  fi
  DEVICE_UDID="${line%%$'\t'*}"
  DEVICE_RUNTIME="${line#*$'\t'}"
  local udid="$DEVICE_UDID"

  # Same reason app_running does not pipe into grep: pipefail plus an early exit
  # reports the writer's SIGPIPE as the answer.
  local devices
  devices="$(xcrun simctl list devices)"
  if [ "${devices#*"$udid) (Booted)"}" != "$devices" ]; then
    ok "$name ($DEVICE_RUNTIME) is already booted"
  else
    xcrun simctl boot "$udid" >/dev/null 2>&1 || true
    BOOTED_HERE+=("$udid")
    ok "$name ($DEVICE_RUNTIME) booted"
  fi
  # bootstatus blocks until the runtime finishes coming up. Installing into a
  # half-booted device fails in ways that read as a bad .app rather than a race.
  xcrun simctl bootstatus "$udid" -b >/dev/null 2>&1 || true

  # Everything a screenshot must not vary by: the appearance the app's dark palette
  # expects, the default reading size, and a status bar that says the same thing on
  # every device instead of reporting this machine's clock and battery.
  xcrun simctl ui "$udid" appearance dark >/dev/null 2>&1 || true
  xcrun simctl ui "$udid" content_size large >/dev/null 2>&1 || true
  xcrun simctl status_bar "$udid" override \
    --time "9:41" \
    --dataNetwork wifi --wifiMode active --wifiBars 3 \
    --cellularMode active --cellularBars 4 \
    --batteryState discharging --batteryLevel 100 >/dev/null 2>&1 || true
}

# ------------------------------------------------------------------- capture ---

# Matched against a captured string rather than piped into `grep -q`. Under
# `pipefail` a grep that exits on its first match SIGPIPEs simctl, and the pipeline
# then reports the failure of the writer -- so the check failed exactly when the app
# was running, which is the one answer it exists to detect.
app_running() {
  local list
  list="$(xcrun simctl spawn "$1" launchctl list 2>/dev/null || true)"
  case "$list" in
    *"UIKitApplication:$APP_BUNDLE_ID"*) return 0 ;;
    *) return 1 ;;
  esac
}

# `simctl launch` returns as soon as the process is spawned, which is before launchd
# lists it. Appearing is therefore waited for, and only after that does disappearing
# mean a crash -- otherwise the very first liveness check loses the race with the
# launch it is checking and every shot fails as "not running".
wait_for_app() {
  local udid="$1" tries=0
  while [ "$tries" -lt 40 ]; do
    if app_running "$udid"; then return 0; fi
    tries=$(( tries + 1 ))
    sleep 0.25
  done
  bad "$APP_BUNDLE_ID never appeared in launchd's list after launch"
  return 1
}

# A screenshot taken before the app has drawn is the classic failure here, and it
# does not announce itself: this app's field is near-black and so is an empty launch
# screen, so a blank capture survives every eyeball test and lands in a store
# listing. Three signals instead of a sleep and a hope.
#
#   running    a crash drops to SpringBoard, which screenshots perfectly happily
#   size       a flat fill compresses to a fraction of what serif type, 26 glyphs
#              and a grid of hairlines ever will
#   stability  consecutive captures must agree in size to within a few percent --
#              loose enough for Arcadia's drifting petals, tight enough that a push
#              animation still in flight fails it
MIN_PNG_BYTES=60000
SETTLE_TOLERANCE=2
SETTLE_AGREEMENTS=2
SETTLE_MAX_TRIES=40
SETTLE_INTERVAL=0.4

within_tolerance() {
  local a="$1" b="$2" delta
  delta=$(( a > b ? a - b : b - a ))
  [ $(( delta * 100 )) -le $(( a * SETTLE_TOLERANCE )) ]
}

capture_settled() {
  local udid="$1" path="$2" tries=0 agreed=0 prev=0 size=0
  while [ "$tries" -lt "$SETTLE_MAX_TRIES" ]; do
    tries=$(( tries + 1 ))
    if ! app_running "$udid"; then
      bad "$APP_BUNDLE_ID is not running -- it crashed or never launched"
      return 1
    fi
    xcrun simctl io "$udid" screenshot --type=png "$path" >/dev/null 2>&1
    size="$(stat -f%z "$path")"
    if [ "$size" -ge "$MIN_PNG_BYTES" ] && [ "$prev" -gt 0 ] && within_tolerance "$size" "$prev"; then
      agreed=$(( agreed + 1 ))
      if [ "$agreed" -ge "$SETTLE_AGREEMENTS" ]; then return 0; fi
    else
      agreed=0
    fi
    prev="$size"
    sleep "$SETTLE_INTERVAL"
  done
  bad "the screen never settled: $tries captures, last one $size bytes"
  return 1
}

png_dimensions() {
  sips -g pixelWidth -g pixelHeight "$1" 2>/dev/null \
    | awk '/pixelWidth/ { w = $2 } /pixelHeight/ { h = $2 } END { print w "x" h }'
}

# ---------------------------------------------------------------------- sets ---

# Named so the summary can print every file with the dimensions it actually has,
# which is the only form of this report worth reading: a set is correct or it is
# rejected, and the pixel count is the whole of the difference.
CAPTURED=()

shoot_set() {
  local label="$1" device="$2" display_type="$3" accepted="$4"
  local udid runtime out entry order slug seed args dims verdict
  local -a launch_args

  step "$label"
  boot_device "$device" || return 1
  udid="$DEVICE_UDID"
  runtime="$DEVICE_RUNTIME"

  # A fresh install rather than an upgrade. Persisted state -- the chosen theme, the
  # dismissed enable card, which hidden Jerrys have been found -- changes what these
  # screens look like, and a screenshot set has to be a picture of a new install
  # rather than of whatever this simulator has been through.
  xcrun simctl terminate "$udid" "$APP_BUNDLE_ID" >/dev/null 2>&1 || true
  xcrun simctl uninstall "$udid" "$APP_BUNDLE_ID" >/dev/null 2>&1 || true
  xcrun simctl install "$udid" "$APP_PATH"
  ok "installed $SCHEME.app"

  out="$OUT_ROOT/$display_type"
  mkdir -p "$out"
  # Clear the set, do not merge into it. A slug renamed in SHOTS would otherwise
  # leave its old file behind, still numbered, still uploaded.
  rm -f "$out"/[0-9][0-9]-*.png

  for entry in "${SHOTS[@]}"; do
    IFS='|' read -r order slug seed args <<<"$entry"

    # Deliberate word splitting: the field holds a list of flags, not one argument.
    IFS=' ' read -r -a launch_args <<<"$args"
    if [ -n "$seed" ]; then
      launch_args+=(-seed-runes "$seed")
    fi

    # simctl launch will not re-launch a running app with new arguments, and the
    # arguments are the entire mechanism here, so every shot starts from terminated.
    xcrun simctl terminate "$udid" "$APP_BUNDLE_ID" >/dev/null 2>&1 || true
    xcrun simctl launch "$udid" "$APP_BUNDLE_ID" "${launch_args[@]}" >/dev/null

    if ! wait_for_app "$udid" || ! capture_settled "$udid" "$TMP_ROOT/$order-$slug.png"; then
      bad "$display_type/$order-$slug.png was not captured"
      return 1
    fi
    mv "$TMP_ROOT/$order-$slug.png" "$out/$order-$slug.png"

    dims="$(png_dimensions "$out/$order-$slug.png")"
    case " $accepted " in
      *" $dims "*) verdict="matches an accepted size" ;;
      *) verdict="NOT a size Apple lists for this set" ;;
    esac
    ok "$order-$slug.png  $dims  ($verdict)"
    CAPTURED+=("$display_type/$order-$slug.png	$dims	$verdict")
  done

  xcrun simctl terminate "$udid" "$APP_BUNDLE_ID" >/dev/null 2>&1 || true
  note "shot on $device, $runtime"
}

# ---------------------------------------------------------------------- main ---

step "Toolchain"
if [ -d "$DEVELOPER_DIR" ]; then
  ok "$(xcodebuild -version | head -1) at $DEVELOPER_DIR"
else
  bad "Xcode not found at $DEVELOPER_DIR. Set DEVELOPER_DIR."
  exit 1
fi

# Debug, not Release, and not by accident: the launch arguments that reach these
# screens are compiled out of a Release build, so a Release screenshot run could only
# ever photograph the home screen five times. The two configurations draw the same
# pixels -- nothing here is behind a DEBUG branch except the routing itself.
step "Building $SCHEME (Debug, simulator)"
xcodebuild build \
  -project "$PROJECT" \
  -scheme "$SCHEME" \
  -configuration Debug \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath "$DERIVED_DIR" \
  CODE_SIGNING_ALLOWED=NO \
  -quiet
[ -d "$APP_PATH" ] || { bad "no app bundle at $APP_PATH"; exit 1; }
ok "$APP_PATH"

if [ "$ONLY" != "ipad" ]; then
  shoot_set "iPhone set -- APP_IPHONE_67" "$DEVICE" APP_IPHONE_67 "$IPHONE_ACCEPTED"
fi
if [ "$ONLY" != "iphone" ]; then
  shoot_set "iPad set -- APP_IPAD_PRO_3GEN_129" "$DEVICE_IPAD" APP_IPAD_PRO_3GEN_129 "$IPAD_ACCEPTED"
fi

step "Captured"
printf '%s\n' ${CAPTURED[@]+"${CAPTURED[@]}"} | column -t -s $'\t'
note "relative to $OUT_ROOT"
note "the keyboard extension is not here and cannot be: capture it by hand on a device"
