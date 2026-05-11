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

# Parses an HTTPS or SSH Git URL into the owner and repository name and
# writes them as GitHub Actions outputs.

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
