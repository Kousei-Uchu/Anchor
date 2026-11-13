#!/bin/bash
# Records every screen of the real app in demo mode and keeps the pictures in reference-shots/, so the website's
# rebuild of each screen can be compared against the app. Nothing in reference-shots/ is shipped on the website,
# and this script does not touch website/public/demo or the generated demo screens file.
#
#   scripts/save-reference-shots.sh                 records the screens not saved yet
#   REDO=1 scripts/save-reference-shots.sh          starts again from nothing
#   DEMO_ONLY=plan,plan-more scripts/save-reference-shots.sh
#                                                   records only those screens (delete their files first to redo them)
#
# The screens are the table in iOS/Anchor/AnchorUITests/DemoCaptureTests.swift. For each one this keeps
#   reference-shots/<name>.jpg    the screen, 660 pixels wide
#   reference-shots/<name>.json   the buttons on it with their labels and positions
# Needs a Mac with Xcode and a Pro Max simulator.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PROJECT="$ROOT/iOS/Anchor/Anchor.xcodeproj"
SCHEME="Anchor"
OUT="$ROOT/build/reference-capture"
REF="$ROOT/reference-shots"

IPHONE="$(xcrun simctl list devices available | grep -E 'iPhone .*Pro Max' | head -1 | sed -E 's/.*\(([0-9A-F-]{36})\).*/\1/')"
if [ -z "$IPHONE" ]; then
  echo "No Pro Max iPhone simulator found. Install one in Xcode, Settings, Components."
  exit 1
fi

if [ -n "${REDO:-}" ]; then
  rm -rf "$OUT" "$REF"
fi
mkdir -p "$OUT" "$REF"

echo "Preparing the simulator"
xcrun simctl boot "$IPHONE" 2>/dev/null || true
xcrun simctl bootstatus "$IPHONE" -b >/dev/null
xcrun simctl status_bar "$IPHONE" override --time 9:41 --batteryState charged --batteryLevel 100 --cellularMode active --cellularBars 4 --wifiBars 3
xcrun simctl ui "$IPHONE" appearance light

echo "Recording the app, one fresh launch per screen. This takes a few minutes."
set +e
TEST_RUNNER_SHOT_DIR="$OUT" TEST_RUNNER_DEMO_ONLY="${DEMO_ONLY:-}" xcodebuild test \
  -project "$PROJECT" -scheme "$SCHEME" -destination "id=$IPHONE" \
  -parallel-testing-enabled NO -disable-concurrent-destination-testing \
  -only-testing:AnchorUITests/DemoCaptureTests/testCapture -quiet
STATUS=$?
set -e
xcrun simctl status_bar "$IPHONE" clear 2>/dev/null || true
if [ "$STATUS" -ne 0 ]; then
  echo "The test run failed (xcodebuild exit $STATUS). Whatever was recorded before it is kept. Run this script again to carry on."
  exit "$STATUS"
fi

if [ -s "$OUT/failed.txt" ]; then
  echo
  echo "These screens could not be reached (the label may have changed, or the screen needs another step):"
  sed 's/^/  /' "$OUT/failed.txt"
  echo "Fix the table in iOS/Anchor/AnchorUITests/DemoCaptureTests.swift and run again. The ones that worked are kept."
fi

echo "Saving the pictures to reference-shots/"
COUNT=0
for png in "$OUT"/*.png; do
  [ -e "$png" ] || continue
  name="$(basename "$png" .png)"
  sips -s format jpeg -s formatOptions 85 --resampleWidth 660 "$png" --out "$REF/$name.jpg" >/dev/null
  [ -e "$OUT/$name.json" ] && cp "$OUT/$name.json" "$REF/$name.json"
  COUNT=$((COUNT + 1))
done
echo "Saved $COUNT screens to reference-shots/"
