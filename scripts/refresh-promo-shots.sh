#!/bin/bash
# Puts the current app's screenshots into the promo video (Patch 52). Needs a Mac (sips).
#
#   scripts/make-screenshots.sh        first: records the screenshots from the real app (build/screenshots/iphone-light)
#   scripts/refresh-promo-shots.sh     then: makes remotion-project/public/shots/*.jpg from them and copies them to the website
#
# It does not render the video. Look at it with `cd remotion-project && npm run studio`, then `npm run render`.
# The captions are in FEATURES in remotion-project/src/Promo.tsx. Change them there if a screen changed.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
FROM="$ROOT/build/screenshots/iphone-light"
TO="$ROOT/remotion-project/public/shots"

if [ ! -d "$FROM" ]; then
  echo "No screenshots at build/screenshots/iphone-light. Run scripts/make-screenshots.sh first."
  exit 1
fi

# promo name : screenshot taken by ScreenshotTests.testScreenshots
for pair in now:1-now plan:3-plan journal:4-journal bridge:5-bridge thread:6-thread checkin:7-checkin; do
  name="${pair%%:*}"
  src="$FROM/${pair#*:}.png"
  if [ ! -f "$src" ]; then
    echo "Missing $src. Run scripts/make-screenshots.sh again."
    exit 1
  fi
  sips -s format jpeg -s formatOptions 85 --resampleWidth 660 "$src" --out "$TO/$name.jpg" >/dev/null
  echo "Made shots/$name.jpg"
done

(cd "$ROOT/website" && npm run sync:promo)
node "$ROOT/scripts/check-promo-shots.mjs"
echo "Next: cd remotion-project && npm run studio (to look), then npm run render"
echo "Commit remotion-project/public/shots and website/public/shots"
