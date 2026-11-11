#!/bin/bash
# Records the real app for the website's tappable demo (Patch 55b). Needs a Mac with Xcode and a Pro Max simulator.
#
#   scripts/make-demo-capture.sh             records every screen not yet recorded, then builds the demo
#   REDO=1 scripts/make-demo-capture.sh      starts again from nothing
#   DEMO_ONLY=plan,plan-tasks scripts/make-demo-capture.sh
#                                            records only those screens (delete their files first to redo them)
#
# What it does:
#   1. runs AnchorUITests/DemoCaptureTests (it launches the app in demo mode once per screen)
#      -> build/demo-capture/<name>.png and <name>.json
#   2. shrinks the pictures to website/public/demo/<name>.jpg (sips, which every Mac has)
#   3. runs scripts/sync-demo-screens.mjs -> website/src/content/demo.screens.generated.json
# The screens are the table in DemoCaptureTests.swift. Commit website/public/demo and the generated file.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PROJECT="$ROOT/iOS/Anchor/Anchor.xcodeproj"
SCHEME="Anchor"
OUT="$ROOT/build/demo-capture"
SITE="$ROOT/website/public/demo"

IPHONE="$(xcrun simctl list devices available | grep -E 'iPhone .*Pro Max' | head -1 | sed -E 's/.*\(([0-9A-F-]{36})\).*/\1/')"
if [ -z "$IPHONE" ]; then
  echo "No Pro Max iPhone simulator found. Install one in Xcode, Settings, Components."
  exit 1
fi

if [ -n "${REDO:-}" ]; then
  rm -rf "$OUT" "$SITE"
fi
mkdir -p "$OUT" "$SITE"

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

echo "Shrinking the pictures"
for png in "$OUT"/*.png; do
  [ -e "$png" ] || continue
  name="$(basename "$png" .png)"
  sips -s format jpeg -s formatOptions 82 --resampleWidth 786 "$png" --out "$SITE/$name.jpg" >/dev/null
done

node "$ROOT/scripts/sync-demo-screens.mjs"
echo "Done. Look at it with: cd website && npm run dev, then open /demo"
echo "Commit website/public/demo and website/src/content/demo.screens.generated.json"
