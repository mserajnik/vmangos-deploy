#!/usr/bin/env bash

# vmangos-deploy
# Copyright (C) 2023-2026  Michael Serajnik  https://github.com/mserajnik

# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.

# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Affero General Public License for more details.

# You should have received a copy of the GNU Affero General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

# Resolves the previous database image's VMaNGOS commit hash by reading the
# most recent commit hash tag from GHCR.

set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source-path=SCRIPTDIR
source "$script_dir/helpers.sh"

require_env GH_TOKEN
require_env PACKAGE_OWNER
require_env PACKAGE_NAME

# Anchor for the very first scan: vmangos/core@c53391e (2025-04-28, "Fixes
# for last commit."). It fixes up a7a48b45 "Implement character flags."
# that landed ~40 minutes earlier; both touch the same `characters`
# migration. No vmangos-deploy image was built in between, so the interim
# state was never shipped, and we start the walk strictly after the fix.
# Used when the package registry has no prior version tagged with a
# commit hash, e.g. on a fork's first build.
MIGRATION_EDIT_CUTOFF_COMMIT_HASH="c53391ecfb2b8b936432c369aad5cabd6c996f06"

# shellcheck disable=SC2153
package_endpoint="$(package_versions_endpoint "$PACKAGE_OWNER" "$PACKAGE_NAME")"

set +e
all_tags="$(gh api --paginate "$package_endpoint?per_page=100" \
  --jq '.[].metadata.container.tags[]?' 2>&1)"
gh_status=$?
set -e

if [[ $gh_status -ne 0 ]]; then
  if grep -Fq "HTTP 404" <<<"$all_tags"; then
    all_tags=""
  else
    printf '%s\n' "$all_tags" >&2
    fail "Failed to query package versions for '$PACKAGE_OWNER/$PACKAGE_NAME'."
  fi
fi

# Take the most recent commit hash tag. The package list is sorted
# newest-first, so this is the previous build's commit even when newer
# versions exist with tags that aren't SHAs (e.g., `latest`).
last_built_commit_hash="$(grep -E '^[0-9a-f]{40}$' <<<"$all_tags" | head -n1 || true)"

if [[ -z "$last_built_commit_hash" ]]; then
  echo "No prior package version with a commit hash tag found; falling back to migration edit cutoff."
  last_built_commit_hash="$MIGRATION_EDIT_CUTOFF_COMMIT_HASH"
fi

write_output commit_hash "$last_built_commit_hash"
