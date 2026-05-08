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
# shellcheck source-path=SCRIPTDIR
source "$script_dir/helpers.sh"

require_env GH_TOKEN
require_env PACKAGE_OWNER
require_env PACKAGE_NAME

declare -A requested_digests=()

for digest in "${DIGEST_AMD64:-}" "${DIGEST_ARM64:-}"; do
  trimmed_digest="$(trim "$digest")"

  if [[ -n "$trimmed_digest" ]]; then
    requested_digests["$trimmed_digest"]=1
  fi
done

if ((${#requested_digests[@]} == 0)); then
  echo "No package digests were provided for cleanup."
  exit 0
fi

# shellcheck disable=SC2153
package_endpoint="$(package_versions_endpoint "$PACKAGE_OWNER" "$PACKAGE_NAME")"
package_versions_json="$(gh api --paginate --slurp "$package_endpoint?per_page=100")"

for digest in "${!requested_digests[@]}"; do
  mapfile -t version_ids < <(
    jq -r \
      --arg digest "$digest" \
      '.[][] |
       select(
         .name == $digest and
         ((.metadata.container.tags // []) | length == 0)
       ) |
       .id' <<<"$package_versions_json"
  )

  if ((${#version_ids[@]} == 0)); then
    printf 'No untagged package version found for %s.\n' "$digest"
    continue
  fi

  for version_id in "${version_ids[@]}"; do
    printf 'Deleting untagged package version %s for %s...\n' "$version_id" "$digest"
    gh api \
      --method DELETE \
      "$(package_version_endpoint "$PACKAGE_OWNER" "$PACKAGE_NAME" "$version_id")" \
      >/dev/null
  done
done
