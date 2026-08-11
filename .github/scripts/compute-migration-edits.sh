#!/usr/bin/env bash

# SPDX-FileCopyrightText: 2023-2026 Michael Serajnik <https://github.com/mserajnik>
# SPDX-License-Identifier: AGPL-3.0-or-later

# Walks the commits between the previous and current build and updates
# `.github/migration-edit-state.json` with the most recent migration file edit
# per VMaNGOS database.
#
# The walk reads a blobless clone rather than the GitHub API, whose commit
# endpoint silently caps a file list and could hide a watched file.

set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source-path=SCRIPTDIR
source "$script_dir/helpers.sh"

require_env LAST_BUILT_COMMIT_HASH
require_env CURRENT_COMMIT_HASH
require_env STATE_FILE
require_env VMANGOS_REPOSITORY_OWNER
require_env VMANGOS_REPOSITORY_NAME

repo="$VMANGOS_REPOSITORY_OWNER/$VMANGOS_REPOSITORY_NAME"

# A state file `jq` cannot read as an object would make the writeback's
# comparison read as "already up to date" and silently drop an edit the walk
# just found.
if ! jq -e '
  type == "object"
  and all(.. | objects | select(has("commit")) | .commit;
          type == "string" and length == 40 and test("^[0-9a-f]{40}$"))
' "$STATE_FILE" >/dev/null; then
  fail "State file '$STATE_FILE' is missing, is not a JSON object, or holds a malformed commit hash."
fi

if [[ "$LAST_BUILT_COMMIT_HASH" == "$CURRENT_COMMIT_HASH" ]]; then
  echo "Last built and current commit are identical; nothing to scan."
  exit 0
fi

db_names=(world characters realmd logs)
db_suffixes=(world characters logon logs)

latest_commits=("" "" "" "")
latest_subjects=("" "" "" "")

echo "Scanning '$repo' for migration edits between $LAST_BUILT_COMMIT_HASH and $CURRENT_COMMIT_HASH..."

clone_dir="$(mktemp -d)"
trap 'rm -rf "$clone_dir"' EXIT

# Blobless so the clone carries commits and trees but no file contents, which
# is all `git diff-tree` needs to report paths and statuses.
git clone --filter=blob:none --no-checkout --quiet \
  "https://github.com/$repo.git" "$clone_dir"

# Merge commits are excluded because their diff against the first parent would
# attribute the merged branch's file changes to the merge commit itself, which
# would give us the wrong commit hash and subject.
commit_hashes_newest_first="$(git -C "$clone_dir" rev-list --no-merges --topo-order \
  "$LAST_BUILT_COMMIT_HASH..$CURRENT_COMMIT_HASH")"

if [[ -z "$commit_hashes_newest_first" ]]; then
  echo "No commits between $LAST_BUILT_COMMIT_HASH and $CURRENT_COMMIT_HASH."
  exit 0
fi

commit_hashes_total="$(wc -l <<<"$commit_hashes_newest_first")"
echo "Walking $commit_hashes_total commits newest-first."

found_count=0
scanned=0

while IFS= read -r commit_hash; do
  [[ -z "$commit_hash" ]] && continue
  scanned=$((scanned + 1))

  # We're walking newest-first, so once every database has a hit, no later
  # commit can win.
  if [[ "$found_count" -eq "${#db_names[@]}" ]]; then
    break
  fi

  # `core.quotePath` defaults to true, which wraps a path holding a non-ASCII
  # byte in quotes and escapes it, and no watched pattern matches such a value.
  #
  # Rename detection is limited to exact matches because the similarity scoring
  # `-M` performs otherwise reads file contents, which a blobless clone has to
  # fetch one commit at a time. A rename reports both its old and its new path,
  # and the checks below test both, so a watched file renamed away still
  # counts.
  #
  # A parentless commit reports nothing at all without `--root`, so an
  # unrelated history grafted into the window would pass as touching no watched
  # file. The flag changes nothing for every other commit.
  changed_files="$(git -C "$clone_dir" -c core.quotePath=false diff-tree \
    --no-commit-id --name-status --root -r -M100% "$commit_hash")"

  for i in "${!db_names[@]}"; do
    if [[ -n "${latest_commits[$i]}" ]]; then
      continue
    fi

    # The backslashes are doubled because `awk -v` processes escape sequences
    # in the value.
    has_edit="$(awk -F'\t' \
      -v pattern='^sql/migrations/.*_'"${db_suffixes[$i]}"'\\.sql$' '
      {
        status = substr($1, 1, 1)

        if (status == "R") {
          previous_path = $2
          path = $3
        } else {
          previous_path = ""
          path = $2
        }

        if (status ~ /^[MRDT]$/ && ((path ~ pattern) ||
          (previous_path != "" && previous_path ~ pattern))) {
          found = 1
        }
      }
      END { if (found) print "1" }' <<<"$changed_files")"

    if [[ "$has_edit" == "1" ]]; then
      subject="$(git -C "$clone_dir" log -1 --format=%s "$commit_hash")"
      latest_commits[i]="$commit_hash"
      latest_subjects[i]="$subject"
      found_count=$((found_count + 1))
      echo "  - ${db_names[$i]}: $commit_hash ($subject)"
    fi
  done
done <<<"$commit_hashes_newest_first"

echo "Scanned $scanned commit(s); found edits for $found_count database(s)."

if [[ "$found_count" -eq 0 ]]; then
  echo "No new migration edits; state file unchanged."
  exit 0
fi

# The single-quoted string is a jq filter, not a bash expression; `$existing`
# is a jq variable.
# shellcheck disable=SC2016
state_filter='. as $existing | {'
for i in "${!db_names[@]}"; do
  if [[ "$i" -gt 0 ]]; then
    state_filter+=','
  fi
  state_filter+=" \"${db_names[$i]}\": \$existing.\"${db_names[$i]}\""
done
state_filter+=' }'

new_state="$(jq "$state_filter" "$STATE_FILE")"

for i in "${!db_names[@]}"; do
  if [[ -n "${latest_commits[$i]}" ]]; then
    new_state="$(jq \
      --arg db "${db_names[$i]}" \
      --arg commit_hash "${latest_commits[$i]}" \
      --arg subject "${latest_subjects[$i]}" \
      '.[$db] = {commit: $commit_hash, subject: $subject}' \
      <<<"$new_state")"
  fi
done

existing_state="$(<"$STATE_FILE")"
if [[ "$new_state" == "$existing_state" ]]; then
  echo "'$STATE_FILE' already up to date."
  exit 0
fi

printf '%s\n' "$new_state" >"$STATE_FILE"
echo "Updated '$STATE_FILE'."
