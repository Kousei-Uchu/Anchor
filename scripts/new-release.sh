#!/bin/bash
# Marks a GitHub release (a new major version) on the current commit: tags release-N, resets minor and patch.
#   bash scripts/new-release.sh          tags HEAD as the next release (release-1, release-2, ...)
#   bash scripts/new-release.sh --push   also pushes the tag, and makes the GitHub release if the gh tool is installed
cd "$(git rev-parse --show-toplevel)" || exit 1
if [ -n "$(git status --porcelain --untracked-files=no)" ]; then echo "You have uncommitted changes. Commit them first."; exit 1; fi
latest=$(git tag --list 'release-[0-9]*' | sed 's/^release-//' | sort -n | tail -1)
next=$(( ${latest:-0} + 1 ))
tag="release-$next"
if git rev-parse -q --verify "refs/tags/$tag" >/dev/null; then echo "$tag already exists."; exit 1; fi
git tag -a "$tag" -m "Anchor $next.0: a GitHub release" && echo "Tagged $(git rev-parse --short HEAD) as $tag. The next build will be v$next.1.0."
if [ "$1" = "--push" ]; then
  git push origin "$tag" || exit 1
  if command -v gh >/dev/null 2>&1; then
    gh release create "$tag" --title "Anchor $next.0" --generate-notes
  else
    echo "Pushed. The gh tool is not installed, so make the release on GitHub from the tag $tag."
  fi
else
  echo "Not pushed. When ready:  git push origin $tag   (or run this again with --push)"
fi
