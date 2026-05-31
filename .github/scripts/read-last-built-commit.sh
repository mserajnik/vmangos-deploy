#!/usr/bin/env bash

# SPDX-FileCopyrightText: 2023-2026 Michael Serajnik <https://github.com/mserajnik>
# SPDX-License-Identifier: AGPL-3.0-or-later

# Resolves the previous database image's VMaNGOS commit hash by reading the
# most recent commit hash tag from GHCR.

set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source-path=SCRIPTDIR
source "$script_dir/helpers.sh"

require_env GH_TOKEN
require_env PACKAGE_OWNER
require_env PACKAGE_NAME

# Anchor for the very first scan: `vmangos/core@c53391e` (2025-04-28, "Fixes
# for last commit."). It fixes up `a7a48b45` "Implement character flags." that
# landed ~40 minutes earlier; both touch the same `characters` migration. No
# vmangos-deploy image was built in between, so the interim state was never
# shipped, and we start the walk strictly after the fix. Used when the package
# registry has no prior version tagged with a commit hash, e.g. on a fork's
# first build.
MIGRATION_EDIT_CUTOFF_COMMIT_HASH="c53391ecfb2b8b936432c369aad5cabd6c996f06"

# shellcheck disable=SC2153
all_tags="$(existing_tags_for_package "$PACKAGE_OWNER" "$PACKAGE_NAME")"

# Take the most recent commit hash tag. The package list is sorted
# newest-first, so this is the previous build's commit even when newer versions
# exist with tags that aren't commit hashes (e.g., `latest`).
last_built_commit_hash="$(grep -E '^[0-9a-f]{40}$' <<<"$all_tags" | head -n1 || true)"

if [[ -z "$last_built_commit_hash" ]]; then
  echo "No prior package version with a commit hash tag found; falling back to migration edit cutoff."
  last_built_commit_hash="$MIGRATION_EDIT_CUTOFF_COMMIT_HASH"
fi

write_output commit_hash "$last_built_commit_hash"
