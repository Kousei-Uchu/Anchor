#!/bin/bash
# Gives every earlier commit its version tag (v<major>.<minor>.<patch>), the same tag the post-commit hook gives a new commit.
#   bash scripts/tag-history.sh          the commits after the newest build or release tag (fast)
#   bash scripts/tag-history.sh --all    every commit on this branch
# Tags that already exist are left alone. Nothing is pushed.
cd "$(git rev-parse --show-toplevel)" || exit 1
base=""
if [ "$1" != "--all" ]; then
  base=$( (git tag --list 'build-*' --merged HEAD; git tag --list 'release-[0-9]*' --merged HEAD) | head -200 | while read -r t; do echo "$(git rev-list --count "$t") $t"; done | sort -n | tail -1 | cut -d' ' -f2)
fi
range="HEAD"; [ -n "$base" ] && range="$base..HEAD"
made=0; kept=0
for c in $(git rev-list --reverse $range); do
  major=$(git tag --list 'release-[0-9]*' --merged "$c" | sed 's/^release-//' | sort -n | tail -1); major=${major:-0}
  minor=$(git tag --list "build-$major.[0-9]*" --merged "$c" | sed "s/^build-$major\\.//" | sort -n | tail -1); minor=${minor:-0}
  if [ "$minor" -gt 0 ]; then b="build-$major.$minor"; elif git rev-parse -q --verify "refs/tags/release-$major" >/dev/null && git merge-base --is-ancestor "release-$major" "$c" 2>/dev/null; then b="release-$major"; else b=""; fi
  if [ -n "$b" ]; then patch=$(git rev-list --count "$b..$c"); else patch=$(git rev-list --count "$c"); fi
  tag="v$major.$minor.$patch"
  if git rev-parse -q --verify "refs/tags/$tag" >/dev/null; then kept=$((kept+1)); else git tag -a "$tag" -m "Anchor $tag" "$c" && made=$((made+1)); fi
done
echo "Tagged $made commits ($kept already had a tag or a clashing name). Nothing pushed; git push --tags sends them."
