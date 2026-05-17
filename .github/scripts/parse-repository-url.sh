#!/usr/bin/env bash

# SPDX-FileCopyrightText: 2023-2026 Michael Serajnik <https://github.com/mserajnik>
# SPDX-License-Identifier: AGPL-3.0-or-later

# Parses an HTTPS or SSH Git URL into the owner and repository name and writes
# them as GitHub Actions outputs.

set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source-path=SCRIPTDIR
source "$script_dir/helpers.sh"

require_env REPOSITORY_URL

# shellcheck disable=SC2153
repository_url="$(trim "$REPOSITORY_URL")"
repository_owner=""
repository_name=""

if [[ "$repository_url" =~ ^git@[^:]+:([^/]+)/([^/]+)$ ]]; then
  repository_owner="${BASH_REMATCH[1]}"
  repository_name="${BASH_REMATCH[2]}"
elif [[ "$repository_url" =~ ^[[:alpha:]][[:alnum:].+-]*://[^/]+/([^/]+)/([^/]+)/?$ ]]; then
  repository_owner="${BASH_REMATCH[1]}"
  repository_name="${BASH_REMATCH[2]}"
fi

repository_name="${repository_name%.git}"

if [[ -z "$repository_owner" || -z "$repository_name" ]]; then
  fail "Failed to parse repository URL '$repository_url'."
fi

write_output repository_owner "$repository_owner"
write_output repository_name "$repository_name"
