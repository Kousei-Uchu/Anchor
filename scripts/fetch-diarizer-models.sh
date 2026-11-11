#!/usr/bin/env bash
# Fetches the speaker-separation model files that VN4a bundles inside the app (Patch VN4a1, D73).
# Run it once, from anywhere, on a computer with internet:   bash scripts/fetch-diarizer-models.sh
#
# What it does:
# 1. Asks Hugging Face which exact commit of FluidInference/speaker-diarization-coreml is current, and takes every
#    file from that one commit, so the files cannot change between two runs.
# 2. Downloads only what the app reads: Segmentation, FBank, Embedding and PldaRho (compiled Core ML folders) and
#    plda-parameters.json, plus the licence and notice files the CC-BY-4.0 licence asks us to keep with them.
# 3. Writes iOS/Anchor/Anchor/DiarizerModels/SOURCE.txt (the commit and the date) and SHA256SUMS (a checksum for every
#    file). scripts/check-diarizer-models.mjs checks the files against that list from then on.
# The app never downloads anything: these files are copied into the app when it is built. Nothing here runs on a phone.
#
# HF_BASE can point at another server, which is how the script itself is tested.

set -euo pipefail

REPO="FluidInference/speaker-diarization-coreml"
BASE="${HF_BASE:-https://huggingface.co}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DEST="${DIARIZER_DEST:-$ROOT/iOS/Anchor/Anchor/DiarizerModels}"

MODEL_FOLDERS=(Segmentation FBank Embedding PldaRho)
FOLDER_FILES=(coremldata.bin metadata.json model.mil weights/weight.bin analytics/coremldata.bin)
LOOSE_FILES=(plda-parameters.json LICENSE NOTICE.md PROVENANCE.md)

for tool in curl python3 shasum; do
  command -v "$tool" >/dev/null 2>&1 || { echo "This script needs $tool."; exit 1; }
done

echo "Asking $BASE which commit of $REPO is current..."
REV="$(curl -fsSL --retry 3 "$BASE/api/models/$REPO" | python3 -c 'import json,sys; print(json.load(sys.stdin)["sha"])')"
if ! [[ "$REV" =~ ^[0-9a-f]{40}$ ]]; then
  echo "Did not get a commit id back (got: $REV). Nothing was changed."
  exit 1
fi
echo "Using commit $REV"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

fetch() {
  local path="$1"
  mkdir -p "$TMP/$(dirname "$path")"
  curl -fsSL --retry 3 -o "$TMP/$path" "$BASE/$REPO/resolve/$REV/$path"
  [ -s "$TMP/$path" ] || { echo "Empty file: $path. Nothing was changed."; exit 1; }
}

for folder in "${MODEL_FOLDERS[@]}"; do
  for file in "${FOLDER_FILES[@]}"; do
    fetch "$folder.mlmodelc/$file"
  done
done
for file in "${LOOSE_FILES[@]}"; do
  fetch "$file"
done

printf 'repo: %s\ncommit: %s\nfetched: %s\n' "$REPO" "$REV" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" > "$TMP/SOURCE.txt"
(cd "$TMP" && find . -type f ! -name SHA256SUMS | sed 's|^\./||' | LC_ALL=C sort | while read -r f; do shasum -a 256 "$f"; done > SHA256SUMS)

# Replace the old copy only now that everything arrived.
rm -rf "$DEST"
mkdir -p "$(dirname "$DEST")"
cp -R "$TMP" "$DEST"

BYTES="$(find "$DEST" -type f -exec wc -c {} + | tail -1 | awk '{print $1}')"
echo
echo "Done: $(find "$DEST" -type f | wc -l | tr -d ' ') files, $BYTES bytes, in $DEST"
echo "Expected about 21.6 million bytes. If it is far from that, stop and tell me."
echo
echo "To check the files yourself, open https://huggingface.co/$REPO/tree/$REV and compare the SHA256 shown there"
echo "for each weights/weight.bin with the line for it in SHA256SUMS."
