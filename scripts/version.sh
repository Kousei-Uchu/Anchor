#!/bin/bash
# Works out Anchor's version from git. Version numbers are  v<major>.<minor>.<patch><tag>
#
#   major  the newest tag release-N (a GitHub release, made for a big overhaul)
#   minor  how many builds have been sent to TestFlight or the App Store since that release, from the
#          tags build-N.M. A TestFlight build that is later released is the same build, so it is one minor.
#   patch  commits since the newest of those build tags (or since the release tag, if there is no build yet)
#   tag    "" App Store, "-pre" TestFlight, "-dev" run from Xcode. The tag is NOT worked out here: one file can go to
#          TestFlight and then the App Store, so the app works the tag out itself when it runs (see AppVersion).
#
# An archive (what you upload) is the new minor itself, so it is minor+1, patch 0.
#
#   scripts/version.sh                 prints  MAJOR.MINOR.PATCH BUILD COMMIT   for the current checkout
#   scripts/version.sh --submit        the same, but as the build that is about to be sent
#   scripts/version.sh --apply         (Xcode Run Script) writes it into the built Info.plist
#   scripts/version.sh --next-tag      prints the tag that should be put on a build once it has been sent
#
# Apple only allows digits and dots in the version, so the "v" and the tag are added for display only.
# BUILD is the total number of commits, which only ever goes up, as App Store Connect needs.
# With no git history the version is 0.0.0 and the build 1, so a build never fails because of this.
cd "$(dirname "$0")/.." 2>/dev/null || exit 0

mode="print"
submit=0
for arg in "$@"; do
  case "$arg" in
    --submit) submit=1 ;;
    --apply) mode="apply" ;;
    --next-tag) mode="next-tag" ;;
  esac
done
# Xcode sets ACTION=install for an archive.
if [ "$mode" = "apply" ] && [ "${ACTION:-}" = "install" ]; then submit=1; fi

if ! git rev-parse --git-dir >/dev/null 2>&1; then
  major=0; minor=0; patch=0; build=1; commit="none"
else
  if [ "$(git rev-parse --is-shallow-repository 2>/dev/null)" = "true" ]; then
    echo "warning: this is a shallow clone, so the patch number may be wrong. Fetch the full history and the tags." >&2
  fi
  major=$(git tag --list 'release-[0-9]*' | sed 's/^release-//' | sort -n | tail -1)
  major=${major:-0}
  last_minor=$(git tag --list "build-$major.[0-9]*" | sed "s/^build-$major\\.//" | sort -n | tail -1)
  last_minor=${last_minor:-0}
  if [ "$last_minor" -gt 0 ]; then
    base="build-$major.$last_minor"
  elif git rev-parse -q --verify "refs/tags/release-$major" >/dev/null 2>&1; then
    base="release-$major"
  else
    base=""
  fi
  build=$(git rev-list --count HEAD 2>/dev/null || echo 1)
  commit=$(git rev-parse --short HEAD 2>/dev/null || echo none)
  if [ "$submit" = "1" ] || [ "$mode" = "next-tag" ]; then
    minor=$((last_minor + 1)); patch=0
  else
    minor=$last_minor
    if [ -n "$base" ]; then patch=$(git rev-list --count "$base..HEAD" 2>/dev/null || echo 0)
    else patch=$build; fi
  fi
fi

case "$mode" in
  print) echo "$major.$minor.$patch $build $commit" ;;
  next-tag) echo "build-$major.$minor" ;;
  apply)
    plist="${TARGET_BUILD_DIR}/${INFOPLIST_PATH}"
    if [ ! -f "$plist" ]; then echo "warning: version.sh could not find $plist"; exit 0; fi
    set_key() {
      /usr/libexec/PlistBuddy -c "Set :$1 $2" "$plist" 2>/dev/null || /usr/libexec/PlistBuddy -c "Add :$1 string $2" "$plist"
    }
    set_key CFBundleShortVersionString "$major.$minor.$patch"
    set_key CFBundleVersion "$build"
    set_key AnchorGitCommit "$commit"
    echo "Anchor version $major.$minor.$patch (build $build, $commit)"
    ;;
esac
