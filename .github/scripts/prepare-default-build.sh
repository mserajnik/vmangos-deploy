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

set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$script_dir/helpers.sh"

require_env GH_TOKEN
require_env GITHUB_EVENT_NAME
require_env PACKAGE_OWNER
require_env PACKAGE_NAME
require_env VMANGOS_REPOSITORY_OWNER
require_env VMANGOS_REPOSITORY_NAME
require_env VMANGOS_REVISION

vmangos_repository_owner="$VMANGOS_REPOSITORY_OWNER"
vmangos_repository_name="$VMANGOS_REPOSITORY_NAME"
vmangos_revision="$VMANGOS_REVISION"
force_rebuild="${FORCE_REBUILD:-false}"
images_already_exist="false"

commit_hash="$(gh api "/repos/$vmangos_repository_owner/$vmangos_repository_name/commits/$vmangos_revision" --jq '.sha')"

if [[ "$GITHUB_EVENT_NAME" == "schedule" && "$(date +%u)" -eq 1 ]]; then
  images_already_exist="false"
elif [[ "$force_rebuild" == "true" ]]; then
  images_already_exist="false"
else
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
      fail "Failed to query package versions for '$PACKAGE_OWNER/$PACKAGE_NAME'"
    fi
  fi

  if grep -Fxq "$commit_hash" <<<"$existing_tags"; then
    images_already_exist="true"
  fi
fi

write_output commit_hash "$commit_hash"
write_output images_already_exist "$images_already_exist"
