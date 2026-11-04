#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PROJECT="$ROOT/iOS/Anchor/Anchor.xcodeproj"
SCHEME="Anchor"
STORE="$ROOT/build/screenshots"
MEDIA="$ROOT/website/assets/media"

pick() {
  xcrun simctl list devices available | grep -E "$1" | head -1 | sed -E 's/.*\(([0-9A-F-]{36})\).*/\1/'
}

IPHONE="$(pick 'iPhone .*Pro Max')"
IPAD="$(pick 'iPad Pro 13')"

if [ -z "$IPHONE" ]; then
  echo "No Pro Max iPhone simulator found. Install one in Xcode, Settings, Components."
  exit 1
fi

prepare() {
  xcrun simctl boot "$1" 2>/dev/null || true
  xcrun simctl bootstatus "$1" -b >/dev/null
  xcrun simctl status_bar "$1" override --time 9:41 --batteryState charged --batteryLevel 100 --cellularMode active --cellularBars 4 --wifiBars 3
  xcrun simctl ui "$1" appearance "$2"
}

# Parallel testing is off so the tests run on the simulator we picked, not a
# clone of it. simctl recordVideo records the original device, so with a clone
# the video only ever showed the Home Screen.
run_test() {
  TEST_RUNNER_SHOT_DIR="$3" xcodebuild test \
    -project "$PROJECT" -scheme "$SCHEME" -destination "id=$1" \
    -parallel-testing-enabled NO -disable-concurrent-destination-testing \
    -only-testing:"AnchorUITests/ScreenshotTests/$2" -quiet
}

build_tests() {
  xcodebuild build-for-testing \
    -project "$PROJECT" -scheme "$SCHEME" -destination "id=$1" -quiet
}

run_test_nobuild() {
  TEST_RUNNER_SHOT_DIR="$3" xcodebuild test-without-building \
    -project "$PROJECT" -scheme "$SCHEME" -destination "id=$1" \
    -parallel-testing-enabled NO -disable-concurrent-destination-testing \
    -only-testing:"AnchorUITests/ScreenshotTests/$2" -quiet
}

shots() {
  local udid="$1" label="$2" mode="$3"
  local dir="$STORE/$label-$mode"
  mkdir -p "$dir"
  if [ "$(ls "$dir"/[1-7]-*.png 2>/dev/null | wc -l | tr -d ' ')" = "7" ]; then
    echo "Skipping $label ($mode): all 7 screenshots already exist"
    return
  fi
  echo "Screenshots: $label ($mode)"
  prepare "$udid" "$mode"
  run_test "$udid" testScreenshots "$dir"
}

shots "$IPHONE" iphone light
shots "$IPHONE" iphone dark
if [ -n "$IPAD" ]; then
  shots "$IPAD" ipad light
  shots "$IPAD" ipad dark
else
  echo "No iPad Pro 13 simulator found, skipping iPad."
fi

mkdir -p "$MEDIA"
for i in 1 2 3 4 5 6; do
  cp "$STORE/iphone-light/$i-"*.png "$MEDIA/shot-$i.png"
done

if [ -f "$MEDIA/anchor-demo.mp4" ] && [ -z "${REDO_VIDEO:-}" ]; then
  echo "Skipping video: anchor-demo.mp4 exists (REDO_VIDEO=1 to redo)"
  xcrun simctl status_bar "$IPHONE" clear 2>/dev/null || true
  echo "Done."
  exit 0
fi
echo "Recording video"
prepare "$IPHONE" light
# Build first so the recording doesn't include minutes of compiling.
build_tests "$IPHONE"
RAW="$STORE/anchor-demo.mov"
rm -f "$RAW"
xcrun simctl io "$IPHONE" recordVideo --codec=h264 --force "$RAW" &
REC=$!
rm -rf "$STORE/tour"
T0="$(perl -MTime::HiRes=time -e 'printf "%.3f", time')"
sleep 2
run_test_nobuild "$IPHONE" testTour "$STORE/tour"
kill -INT "$REC" || true
wait "$REC" 2>/dev/null || true

if command -v ffmpeg >/dev/null 2>&1; then
  # Trim the lead-in (simulator installing the test runner and launching the app).
  CUT=0
  if [ -f "$STORE/tour/start.txt" ]; then
    CUT="$(awk -v s="$(cat "$STORE/tour/start.txt")" -v t="$T0" 'BEGIN{c=s-t-3; if(c<0)c=0; printf "%.2f", c}')"
  fi
  echo "Trimming first ${CUT}s of the recording"
  ffmpeg -y -loglevel error -ss "$CUT" -i "$RAW" -vf scale=-2:1280 -r 30 -an -movflags +faststart -pix_fmt yuv420p "$MEDIA/anchor-demo.mp4"
  echo "Video written to website/assets/media/anchor-demo.mp4"
else
  echo "ffmpeg not found. Install it with: brew install ffmpeg, then convert $RAW (see website/assets/media/README.txt)."
fi

xcrun simctl status_bar "$IPHONE" clear 2>/dev/null || true
echo "Done."
echo "Website images: website/assets/media"
echo "App Store sizes: build/screenshots/iphone-light, iphone-dark, ipad-light, ipad-dark"
