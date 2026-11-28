#!/bin/bash
# Run this after a build has been uploaded to TestFlight or the App Store. It puts the tag build-N.M on the
# commit that was built, which is what makes the next minor and the patch count come out right.
#
#   scripts/tag-build.sh            tags HEAD
#   PUSH=1 scripts/tag-build.sh     tags HEAD and pushes the tag in one go
#   scripts/tag-build.sh <commit>   tags that commit (use this if you have committed since you archived;
#                                   Settings -> About Anchor shows the commit the build came from)
#
# A GitHub release (a new major) is a tag release-N on the commit you release, for example:  git tag release-2
cd "$(dirname "$0")/.." || exit 1
commit="${1:-HEAD}"
if git tag --points-at "$commit" | grep -q '^build-'; then
  echo "That commit already has a build tag: $(git tag --points-at "$commit" | grep '^build-' | tr '\n' ' ')" >&2; exit 1
fi
tag=$(bash scripts/version.sh --next-tag)
if git rev-parse -q --verify "refs/tags/$tag" >/dev/null; then
  echo "$tag already exists." >&2; exit 1
fi
git tag -a "$tag" -m "Sent to TestFlight or the App Store" "$commit" && echo "Tagged $(git rev-parse --short "$commit") as $tag."
if [ "$PUSH" = "1" ]; then git push origin "$tag"; else echo "Now push it:  git push origin $tag   (or run this again with PUSH=1)"; fi
