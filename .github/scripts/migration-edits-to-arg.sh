#!/usr/bin/env bash

# SPDX-FileCopyrightText: 2023-2026 Michael Serajnik <https://github.com/mserajnik>
# SPDX-License-Identifier: AGPL-3.0-or-later

# Flattens `.github/migration-edit-state.json` to the `VMANGOS_MIGRATION_EDITS`
# build argument: pipe-separated `<database>:<commit-hash>` entries for each of
# `world`, `characters`, `realmd`, `logs` (empty value for null entries).

set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source-path=SCRIPTDIR
source "$script_dir/helpers.sh"

if [[ "$#" -ne 1 ]]; then
  fail "Usage: $0 <state-file>"
fi

state_file="$1"

# A state file `jq` cannot read as an object would yield an empty token, which
# reads as "no recorded edits".
if ! jq -e '
  type == "object"
  and all(.. | objects | select(has("commit")) | .commit;
          type == "string" and length == 40 and test("^[0-9a-f]{40}$"))
' "$state_file" >/dev/null; then
  fail "State file '$state_file' is missing, is not a JSON object, or holds a malformed commit hash."
fi

jq -r '
  ["world", "characters", "realmd", "logs"] as $order
  | [$order[] as $db | "\($db):\(.[$db].commit // "")"]
  | join("|")
' "$state_file"
