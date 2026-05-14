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

# Flattens `.github/migration-edit-state.json` to the `VMANGOS_MIGRATION_EDITS`
# build argument format: `world:<sha>|characters:<sha>|realmd:<sha>|logs:<sha>`
# (empty for null entries).

set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source-path=SCRIPTDIR
source "$script_dir/helpers.sh"

if [[ "$#" -ne 1 ]]; then
  fail "Usage: $0 <state-file>"
fi

state_file="$1"

if [[ ! -f "$state_file" ]]; then
  fail "State file '$state_file' does not exist."
fi

jq -r '
  ["world", "characters", "realmd", "logs"] as $order
  | [$order[] as $db | "\($db):\(.[$db].commit // "")"]
  | join("|")
' "$state_file"
