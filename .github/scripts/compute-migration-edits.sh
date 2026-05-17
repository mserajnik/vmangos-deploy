#!/usr/bin/env bash

# SPDX-FileCopyrightText: 2023-2026 Michael Serajnik <https://github.com/mserajnik>
# SPDX-License-Identifier: AGPL-3.0-or-later

# Walks the commits between the previous and current build via the GitHub API
# and updates `.github/migration-edit-state.json` with the most recent
# migration file edit per VMaNGOS database.

set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source-path=SCRIPTDIR
source "$script_dir/helpers.sh"

require_env GH_TOKEN
require_env LAST_BUILT_COMMIT_HASH
require_env CURRENT_COMMIT_HASH
require_env STATE_FILE
require_env VMANGOS_REPOSITORY_OWNER
require_env VMANGOS_REPOSITORY_NAME

repo="$VMANGOS_REPOSITORY_OWNER/$VMANGOS_REPOSITORY_NAME"

if [[ ! -f "$STATE_FILE" ]]; then
  fail "State file '$STATE_FILE' does not exist."
fi

if [[ "$LAST_BUILT_COMMIT_HASH" == "$CURRENT_COMMIT_HASH" ]]; then
  echo "Last built and current commit are identical; nothing to scan."
  exit 0
fi

db_names=(world characters realmd logs)
db_suffixes=(world characters logon logs)

latest_commits=("" "" "" "")
latest_subjects=("" "" "" "")

echo "Scanning $repo for migration edits between $LAST_BUILT_COMMIT_HASH and $CURRENT_COMMIT_HASH..."

# The compare endpoint returns commits oldest-first across pages; we reverse it
# so we can short-circuit per database once the newest hit is found.
shas_oldest_first="$(gh api --paginate \
  "repos/$repo/compare/$LAST_BUILT_COMMIT_HASH...$CURRENT_COMMIT_HASH" \
  --jq '.commits[].sha')"

if [[ -z "$shas_oldest_first" ]]; then
  echo "No commits between $LAST_BUILT_COMMIT_HASH and $CURRENT_COMMIT_HASH."
  exit 0
fi

shas_newest_first="$(tac <<<"$shas_oldest_first")"
shas_total="$(wc -l <<<"$shas_newest_first" | tr -d ' ')"
echo "Walking $shas_total commits newest-first."

found_count=0
scanned=0

# Each iteration makes one `gh api ...commits/<sha>` call. The 5000 calls per
# hour `GITHUB_TOKEN` rate limit bounds the worst case (~14 months of history
# from the cutoff anchor on a fresh fork's first build).
while IFS= read -r sha; do
  [[ -z "$sha" ]] && continue
  scanned=$((scanned + 1))

  # We're walking newest-first, so once every database has a hit, no later
  # commit can win.
  if [[ "$found_count" -eq "${#db_names[@]}" ]]; then
    break
  fi

  commit_data="$(gh api "repos/$repo/commits/$sha")"

  # We skip merge commits because their diff against the first parent would
  # attribute the merged branch's file changes to the merge commit itself,
  # which would give us the wrong timestamp and subject.
  parent_count="$(jq -r '.parents | length' <<<"$commit_data")"
  if [[ "$parent_count" -ne 1 ]]; then
    continue
  fi

  files_json="$(jq -c '.files' <<<"$commit_data")"
  subject="$(jq -r '.commit.message | split("\n")[0]' <<<"$commit_data")"

  for i in "${!db_names[@]}"; do
    if [[ -n "${latest_commits[$i]}" ]]; then
      continue
    fi

    suffix="${db_suffixes[$i]}"
    has_edit="$(jq -r --arg suffix "$suffix" '
      [.[]
        | select(.status == "modified" or .status == "renamed" or .status == "removed")
        | select((.filename | test("^sql/migrations/.*_" + $suffix + "\\.sql$")) or ((.previous_filename // "") | test("^sql/migrations/.*_" + $suffix + "\\.sql$")))
      ] | length' <<<"$files_json")"

    if [[ "$has_edit" -gt 0 ]]; then
      latest_commits[i]="$sha"
      latest_subjects[i]="$subject"
      found_count=$((found_count + 1))
      echo "  - ${db_names[$i]}: $sha ($subject)"
    fi
  done
done <<<"$shas_newest_first"

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
      --arg sha "${latest_commits[$i]}" \
      --arg subject "${latest_subjects[$i]}" \
      '.[$db] = {commit: $sha, subject: $subject}' \
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
