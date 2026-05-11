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

# Resolves the current upstream VMaNGOS commit and decides whether the
# default workflow should build images this run (skipping when an image for
# that commit already exists, unless the run is a scheduled Monday rebuild
# or a manual force rebuild).

set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source-path=SCRIPTDIR
source "$script_dir/helpers.sh"

require_env GH_TOKEN
require_env GITHUB_EVENT_NAME
require_env PACKAGE_OWNER
require_env PACKAGE_NAME
require_env VMANGOS_REPOSITORY_OWNER
require_env VMANGOS_REPOSITORY_NAME
require_env VMANGOS_REVISION

# shellcheck disable=SC2153
vmangos_repository_owner="$VMANGOS_REPOSITORY_OWNER"
# shellcheck disable=SC2153
vmangos_repository_name="$VMANGOS_REPOSITORY_NAME"
# shellcheck disable=SC2153
vmangos_revision="$VMANGOS_REVISION"
force_rebuild="${FORCE_REBUILD:-false}"
any_images_to_build="true"

commit_hash="$(gh api "/repos/$vmangos_repository_owner/$vmangos_repository_name/commits/$vmangos_revision" --jq '.sha')"

if [[ "$GITHUB_EVENT_NAME" == "schedule" && "$(date +%u)" -eq 1 ]]; then
  any_images_to_build="true"
elif [[ "$force_rebuild" == "true" ]]; then
  any_images_to_build="true"
else
  # shellcheck disable=SC2153
  package_endpoint="$(package_versions_endpoint "$PACKAGE_OWNER" "$PACKAGE_NAME")"
  set +e
  existing_tags="$(gh api --paginate "$package_endpoint?per_page=100" --jq '.[].metadata.container.tags[]?' 2>&1)"
  gh_status=$?
  set -e

  if [[ $gh_status -ne 0 ]]; then
    if grep -Fq "HTTP 404" <<<"$existing_tags"; then
      existing_tags=""
    else
      printf '%s\n' "$existing_tags" >&2
      fail "Failed to query package versions for '$PACKAGE_OWNER/$PACKAGE_NAME'."
    fi
  fi

  if grep -Fxq "$commit_hash" <<<"$existing_tags"; then
    any_images_to_build="false"
  fi
fi

write_output commit_hash "$commit_hash"
write_output any_images_to_build "$any_images_to_build"
