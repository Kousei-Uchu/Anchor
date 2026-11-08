#!/bin/bash
# Builds Anchor, puts it on your connected iPhone (or a simulator) and opens it on made-up content
# with the numbered review bar. Your own data is never opened: the app runs on the in-memory store.
#
#   scripts/review-on-device.sh            your connected iPhone
#   scripts/review-on-device.sh --sim      an iPhone simulator instead
#   DEVICE="Aiden's iPhone" scripts/review-on-device.sh    pick a device by name or id
#
# Leave the app and open it normally afterwards and it opens your own data again.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PROJECT="$ROOT/iOS/Anchor/Anchor.xcodeproj"
BUNDLE="page.aspens.anchor"
OUT="$ROOT/build/review"

ARGS=(-AnchorDemo -AnchorReview
      -anchor.appLockEnabled NO -anchor.hasSeenTour YES
      -anchor.sleep.nowCard YES -anchor.sleep.journal YES -anchor.sleep.checkIn YES)

if [ "${1:-}" = "--sim" ]; then
  UDID="$(xcrun simctl list devices available | grep -E 'iPhone .*Pro' | head -1 | sed -E 's/.*\(([0-9A-F-]{36})\).*/\1/')"
  [ -n "$UDID" ] || { echo "No iPhone simulator found. Install one in Xcode, Settings, Components."; exit 1; }
  xcrun simctl boot "$UDID" 2>/dev/null || true
  open -a Simulator
  xcodebuild build -project "$PROJECT" -scheme Anchor -configuration Debug \
    -destination "id=$UDID" -derivedDataPath "$OUT" -quiet
  xcrun simctl install "$UDID" "$OUT/Build/Products/Debug-iphonesimulator/Anchor.app"
  xcrun simctl launch --terminate-running-process "$UDID" "$BUNDLE" "${ARGS[@]}"
  exit 0
fi

JSON="$(mktemp)"
xcrun devicectl list devices --json-output "$JSON" >/dev/null
CORE=""; UDID=""; NAME=""
read -r CORE UDID NAME < <(DEVICE="${DEVICE:-}" python3 - "$JSON" <<'PY'
import json, os, sys
want = os.environ.get("DEVICE", "").lower()
devices = json.load(open(sys.argv[1]))["result"]["devices"]
for d in devices:
    hw, props, conn = d.get("hardwareProperties", {}), d.get("deviceProperties", {}), d.get("connectionProperties", {})
    if hw.get("platform") != "iOS":
        continue
    if conn.get("tunnelState") == "unavailable":
        continue
    name = props.get("name", "iPhone")
    if want and want not in (name.lower(), hw.get("udid", "").lower(), d.get("identifier", "").lower()):
        continue
    print(d["identifier"], hw.get("udid", ""), name.replace(" ", "_"))
    break
PY
) || true
if [ -z "${CORE:-}" ]; then
  echo "No connected iPhone found. Plug it in, unlock it, tap Trust, turn on Developer Mode, then try again."
  echo "Or run: scripts/review-on-device.sh --sim"
  exit 1
fi
echo "Using ${NAME//_/ }"

xcodebuild build -project "$PROJECT" -scheme Anchor -configuration Debug \
  -destination "id=$UDID" -derivedDataPath "$OUT" -allowProvisioningUpdates -quiet
xcrun devicectl device install app --device "$CORE" "$OUT/Build/Products/Debug-iphoneos/Anchor.app"
xcrun devicectl device process launch --device "$CORE" --terminate-existing "$BUNDLE" -- "${ARGS[@]}"
