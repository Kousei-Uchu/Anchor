#!/bin/bash
# Runs every check that does not need Xcode. Run it from anywhere:  bash scripts/check-all.sh
# It is a syntax check and a set of content checks. It is not a build.
cd "$(dirname "$0")/.." || exit 1
status=0
for check in check-about-content.mjs check-demo-coverage.mjs check-ai-gate.mjs check-dictation.mjs check-project-files.mjs check-locked-fields.mjs check-locked-files.mjs check-one-page.mjs; do
  echo "=== $check ==="
  node "scripts/$check" || status=1
done
echo "=== check-swift-syntax.py ==="
python3 scripts/check-swift-syntax.py
code=$?
if [ "$code" = "2" ]; then echo "(skipped: the parser packages are not installed)"; elif [ "$code" != "0" ]; then status=1; fi
if [ "$status" = "0" ]; then echo "All checks passed."; else echo "Some checks failed."; fi
exit $status
