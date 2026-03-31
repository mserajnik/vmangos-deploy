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

require_env MARIADB_ENTRYPOINT_KNOWN_URL
require_env MARIADB_ENTRYPOINT_LATEST_URL

workdir="$(mktemp -d)"

cleanup() {
  rm -rf "$workdir"
}

trap cleanup EXIT

curl --fail --silent --show-error --location \
  --output "$workdir/known-entrypoint.sh" \
  "$MARIADB_ENTRYPOINT_KNOWN_URL"

curl --fail --silent --show-error --location \
  --output "$workdir/latest-entrypoint.sh" \
  "$MARIADB_ENTRYPOINT_LATEST_URL"

diff -u "$workdir/known-entrypoint.sh" "$workdir/latest-entrypoint.sh"
