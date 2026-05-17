#!/usr/bin/env bash

# SPDX-FileCopyrightText: 2023-2026 Michael Serajnik <https://github.com/mserajnik>
# SPDX-License-Identifier: AGPL-3.0-or-later

# Deletes untagged GHCR package versions left behind by a failed multi-arch
# publish, so they do not accumulate in the registry. Called from the reusable
# build workflow's cleanup step.

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
