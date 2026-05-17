#!/usr/bin/env bash

# SPDX-FileCopyrightText: 2023-2026 Michael Serajnik <https://github.com/mserajnik>
# SPDX-License-Identifier: AGPL-3.0-or-later

# Commits the given files to the configured branch via GitHub's GraphQL
# `createCommitOnBranch` mutation. The resulting commit is signed by GitHub
# server-side, which is what gives it the "Verified" badge on the web UI; a
# plain `git commit && git push` over `GITHUB_TOKEN` produces an unsigned
# commit instead. Only files that actually changed against `HEAD` are included
# in the commit, so this is safe to call unconditionally after a step that may
# or may not have edited a file.

set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source-path=SCRIPTDIR
source "$script_dir/helpers.sh"

require_env GH_TOKEN
require_env BRANCH
require_env REPO_NWO

if [ "$#" -lt 2 ]; then
  fail "Usage: $0 <message> <path> [<path> ...]"
fi

message="$1"
shift
paths=("$@")

changed=()
for path in "${paths[@]}"; do
  if [ ! -f "$path" ]; then
    fail "Path '$path' does not exist or is not a regular file."
  fi
  if ! git diff --quiet -- "$path"; then
    changed+=("$path")
  fi
done

if [ "${#changed[@]}" -eq 0 ]; then
  echo "No tracked file changes among the requested paths; nothing to commit."
  exit 0
fi

# The branch's current tip on the remote. The mutation refuses to commit if the
# tip moves underneath us (e.g., a concurrent run pushed first), which is the
# right behavior; the next scheduled run will pick up the leftover edits.
expected_head_oid="$(gh api "repos/$REPO_NWO/branches/$BRANCH" --jq '.commit.sha')"

if [ -z "$expected_head_oid" ]; then
  fail "Failed to resolve remote tip of branch '$BRANCH'."
fi

additions='[]'
for path in "${changed[@]}"; do
  contents_b64="$(base64 -w0 <"$path")"
  additions="$(jq \
    --arg path "$path" \
    --arg contents "$contents_b64" \
    '. + [{path: $path, contents: $contents}]' <<<"$additions")"
done

payload="$(jq -n \
  --arg repo "$REPO_NWO" \
  --arg branch "$BRANCH" \
  --arg head "$expected_head_oid" \
  --arg headline "$message" \
  --argjson additions "$additions" \
  '{
    query: "mutation($input: CreateCommitOnBranchInput!) { createCommitOnBranch(input: $input) { commit { url oid } } }",
    variables: {
      input: {
        branch: {repositoryNameWithOwner: $repo, branchName: $branch},
        message: {headline: $headline},
        expectedHeadOid: $head,
        fileChanges: {additions: $additions}
      }
    }
  }')"

result="$(gh api graphql --input - <<<"$payload")"

new_oid="$(jq -r '.data.createCommitOnBranch.commit.oid // empty' <<<"$result")"
new_url="$(jq -r '.data.createCommitOnBranch.commit.url // empty' <<<"$result")"

if [ -z "$new_oid" ]; then
  printf '%s\n' "$result" >&2
  fail "GraphQL mutation did not return a commit OID."
fi

echo "Committed $new_oid via GraphQL: $new_url"
