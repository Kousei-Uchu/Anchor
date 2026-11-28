# Version numbers

Anchor's version is written `v<major>.<minor>.<patch><tag>`, for example `v1.4.0-pre`. It is worked out from git by
`scripts/version.sh` every time the app is built, and shown in Settings > Your data and help > About Anchor.

| Part | Meaning | Comes from |
|---|---|---|
| major | A GitHub release, made for a big overhaul | the newest tag `release-N` |
| minor | A build sent to TestFlight or the App Store | how many tags `build-N.M` there are for that major |
| patch | Commits since the last build was sent | `git rev-list --count <newest build tag>..HEAD` (or since the release tag if no build has been sent yet) |
| tag | Where this copy came from | worked out by the app when it runs, not by git |

The tag: nothing for the App Store, `-pre` for TestFlight, `-dev` for a run from Xcode. It is decided when the app runs
(from the receipt the system gives the app), because one file can be sent to TestFlight and then released on the App Store.

Apple only allows digits and dots in the version, so `v` and the tag are only for display. The build number is the total
commit count, which only goes up, as App Store Connect needs.

## Examples

Last build sent was TestFlight build 0.3, then:

- Xcode run, 9 commits later: `v0.3.9-dev`
- Archive and upload: it is the new minor, patch 0: `v0.4.0` in the file, shown as `v0.4.0-pre` on TestFlight
- The same build released on the App Store: `v0.4.0`
- Xcode run, 5 commits after that: `v0.4.5-dev`
- A GitHub release is made (`git tag release-1`): `v1.0.0`, and minor and patch start again

## Automatic tagging and the helper scripts (Patch TG1)

Run **`bash scripts/install-hooks.sh`** once in each clone. After that:

- **Every commit is tagged** with its version by a post-commit hook (`scripts/hooks/post-commit`): `v<major>.<minor>.<patch>`, for example `v0.2.5`. The tag is annotated, so a plain `git push` sends it with the commit. These tags are only labels: the version numbers are still counted from the `release-N` and `build-N.M` tags, and `scripts/version.sh` ignores the `v` ones. A commit that is amended or rebased away has its tag follow the new commit, and a tag that already marks a commit still on a branch is never moved. To skip it once: `ANCHOR_NO_VERSION_TAG=1 git commit ...`.
- **Every commit is checked** first (`scripts/hooks/pre-commit` runs `scripts/check-all.sh`, about three seconds), and a commit that fails the checks is stopped with the reason. To commit anyway, once: `SKIP_CHECKS=1 git commit ...`.

Other scripts:

| Script | What it does |
|---|---|
| `scripts/version-status.sh` | Where things stand: this checkout's version, the last build sent and how many commits ago, the last release, what the next archive will be, and how many tags are not pushed |
| `PUSH=1 scripts/tag-build.sh` | After an upload: tags the build `build-N.M` and pushes the tag |
| `scripts/new-release.sh [--push]` | Starts a new major (`release-N`) on the current commit, and with `--push` pushes it and makes the GitHub release if the `gh` tool is installed |
| `scripts/tag-history.sh [--all]` | Gives earlier commits their `v...` tags, for the commits after the newest build or release tag, or with `--all` for every commit |

## What you do

1. After you upload a build: `bash scripts/tag-build.sh` (or `bash scripts/tag-build.sh <commit>` if you have committed since
   you archived; About shows the commit the build came from), then `git push --tags`.
2. For a GitHub release: `git tag release-N`, `git push --tags`, then make the release from that tag.
3. Releasing a TestFlight build on the App Store needs nothing: it is the same build, so it keeps its number and loses the `-pre`.

## Things to know

- Tags must be pushed, and a fresh clone or CI job must fetch the full history and the tags, or the patch number is wrong.
  The script warns on a shallow clone.
- With no git history, the version is `0.0.0`, build 1. A build never fails because of this.
- The widget gets the same number as the app, as App Store Connect requires.
- `scripts/check-version.sh` (part of `check-all.sh`) tests all of this in a throwaway repository.
