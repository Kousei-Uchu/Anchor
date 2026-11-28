#!/bin/bash
# A summary of where the version numbers stand: bash scripts/version-status.sh
cd "$(git rev-parse --show-toplevel)" || exit 1
read -r now build commit <<<"$(bash scripts/version.sh)"
read -r next _ <<<"$(bash scripts/version.sh --submit)"
major=${now%%.*}
last_build=$(git tag --list "build-$major.[0-9]*" | sed "s/^build-$major\\.//" | sort -n | tail -1)
release=$(git tag --list 'release-[0-9]*' | sed 's/^release-//' | sort -n | tail -1)
echo "Anchor version status"
echo "  This checkout:        v$now-dev   (build $build, commit $commit)"
if [ -n "$last_build" ]; then
  tag="build-$major.$last_build"
  echo "  Last build sent:      $tag, $(git rev-list --count "$tag..HEAD") commits ago ($(git log -1 --format=%cd --date=short "$tag"))"
else
  echo "  Last build sent:      none tagged yet (tag one with: git tag -a build-$major.1 <commit>)"
fi
echo "  Last GitHub release:  ${release:+release-$release}${release:-none yet, so the major is 0}"
echo "  Next archive will be: v$next"
unpushed=$(comm -23 <(git tag | sort) <(git ls-remote --tags --refs origin 2>/dev/null | sed 's#.*refs/tags/##' | sort) | wc -l | tr -d ' ')
echo "  Tags not pushed yet:  $unpushed   (a plain git push sends them once install-hooks.sh has been run)"
