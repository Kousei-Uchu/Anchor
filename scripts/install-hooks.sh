#!/bin/bash
# One-time setup for this clone: use the hooks in scripts/hooks, and send version tags with every push.
#   scripts/hooks/pre-commit   runs the repo checks before a commit
#   scripts/hooks/post-commit  tags every commit with its version (v<major>.<minor>.<patch>)
cd "$(git rev-parse --show-toplevel)" || exit 1
chmod +x scripts/hooks/* scripts/*.sh 2>/dev/null
git config core.hooksPath scripts/hooks
git config push.followTags true
echo "Hooks are on for this clone. Every commit is now checked and tagged."
echo "To turn them off:  git config --unset core.hooksPath"
