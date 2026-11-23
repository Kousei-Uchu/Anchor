#!/bin/bash
# Checks scripts/version.sh in a throwaway repository, against the examples in docs/VERSIONING.md.
cd "$(dirname "$0")/.." || exit 1
root=$(pwd)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/scripts"
cp scripts/version.sh scripts/tag-build.sh "$tmp/scripts/"
cd "$tmp" || exit 1
git init -q . && git config user.email t@t && git config user.name t
status=0
expect() { # description, expected, actual
  if [ "$2" = "$3" ]; then echo "  ok: $1 -> $3"; else echo "  FAILED: $1 -> expected $2, got $3"; status=1; fi
}
commit() { for _ in $(seq 1 "$1"); do git commit -q --allow-empty -m c; done; }
commit 120
expect "no tags yet, 120 commits" "0.0.120 120" "$(bash scripts/version.sh | cut -d' ' -f1,2)"
expect "first archive" "0.1.0 120" "$(bash scripts/version.sh --submit | cut -d' ' -f1,2)"
bash scripts/tag-build.sh >/dev/null
commit 9
expect "9 commits after build-0.1" "0.1.9 129" "$(bash scripts/version.sh | cut -d' ' -f1,2)"
commit 11
expect "second archive" "0.2.0 140" "$(bash scripts/version.sh --submit | cut -d' ' -f1,2)"
bash scripts/tag-build.sh >/dev/null
commit 5
expect "5 commits after build-0.2" "0.2.5 145" "$(bash scripts/version.sh | cut -d' ' -f1,2)"
git tag release-1
expect "a GitHub release (release-1) resets minor and patch" "1.0.0 145" "$(bash scripts/version.sh | cut -d' ' -f1,2)"
commit 2
expect "2 commits after release-1" "1.0.2 147" "$(bash scripts/version.sh | cut -d' ' -f1,2)"
expect "first archive after release-1" "1.1.0 147" "$(bash scripts/version.sh --submit | cut -d' ' -f1,2)"
expect "the next tag" "build-1.1" "$(bash scripts/version.sh --next-tag)"
bash scripts/tag-build.sh >/dev/null 2>&1; bash scripts/tag-build.sh >/dev/null 2>&1 && { echo "  FAILED: tagging the same build twice should be refused"; status=1; }
cd "$root" || exit 1
if [ "$status" = "0" ]; then echo "check-version: all examples match."; fi
exit $status
