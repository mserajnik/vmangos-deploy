#!/usr/bin/env bash

# SPDX-FileCopyrightText: 2023-2026 Michael Serajnik <https://github.com/mserajnik>
# SPDX-License-Identifier: AGPL-3.0-or-later

# Shared helpers sourced by the other scripts in this directory: error
# handling, environment variable checks, output writers for GitHub Actions,
# Docker tag sanitization, GHCR endpoint helpers, and commit hash resolution.

fail() {
  echo "ERROR: $*" >&2
  exit 1
}

require_env() {
  local name="$1"

  if [[ -z "${!name:-}" ]]; then
    fail "Environment variable '$name' is required."
  fi
}

trim() {
  local value="$1"

  value="${value#"${value%%[![:space:]]*}"}"
  value="${value%"${value##*[![:space:]]}"}"

  printf '%s' "$value"
}

write_output() {
  require_env GITHUB_OUTPUT

  local name="$1"
  local value="$2"

  printf '%s=%s\n' "$name" "$value" >>"$GITHUB_OUTPUT"
}

write_multiline_output() {
  require_env GITHUB_OUTPUT

  local name="$1"
  local value="$2"
  local delimiter
  delimiter="EOF_${name}_$(date +%s)_$RANDOM"

  {
    printf '%s<<%s\n' "$name" "$delimiter"
    printf '%s\n' "$value"
    printf '%s\n' "$delimiter"
  } >>"$GITHUB_OUTPUT"
}

sanitize_docker_tag_fragment() {
  local original="$1"
  local sanitized

  sanitized="$(printf '%s' "$original" | sed -E \
    -e 's/[^A-Za-z0-9_.-]+/-/g' \
    -e 's/^[^A-Za-z0-9_]+//' \
    -e 's/[^A-Za-z0-9_.-]+$//')"

  if [[ -z "$sanitized" ]]; then
    fail "Value '$original' cannot be converted into a valid Docker tag fragment."
  fi

  printf '%s\n' "$sanitized"
}

package_versions_endpoint() {
  local owner="$1"
  local package_name="$2"

  printf '%s/packages/container/%s/versions' \
    "$(package_owner_endpoint "$owner")" \
    "$package_name"
}

existing_tags_for_package() {
  local package_owner="$1"
  local package_name="$2"
  local endpoint
  local tags
  local status

  endpoint="$(package_versions_endpoint "$package_owner" "$package_name")"

  set +e
  tags="$(gh api --paginate "$endpoint?per_page=100" \
    --jq '.[].metadata.container.tags[]?' 2>&1)"
  status=$?
  set -e

  if [[ $status -ne 0 ]]; then
    if grep -Fq "HTTP 404" <<<"$tags"; then
      printf '%s' ""
      return 0
    fi

    printf '%s\n' "$tags" >&2
    fail "Failed to query package versions for '$package_owner/$package_name'."
  fi

  printf '%s' "$tags"
}

package_version_endpoint() {
  local owner="$1"
  local package_name="$2"
  local package_version_id="$3"

  printf '%s/packages/container/%s/versions/%s' \
    "$(package_owner_endpoint "$owner")" \
    "$package_name" \
    "$package_version_id"
}

package_owner_endpoint() {
  local owner="$1"
  local owner_type
  local namespace

  owner_type="$(gh api "/users/$owner" --jq '.type')"

  case "$owner_type" in
    Organization)
      namespace="orgs"
      ;;
    User)
      namespace="users"
      ;;
    *)
      fail "Unsupported package owner type '$owner_type' for '$owner'."
      ;;
  esac

  printf '/%s/%s' "$namespace" "$owner"
}

resolve_commit_hash() {
  local repository_owner="$1"
  local repository_name="$2"
  local repository_ref="$3"
  local result

  result="$(gh api \
    "/repos/$repository_owner/$repository_name/commits/$repository_ref" \
    --jq '.sha')"
  if [[ ! "$result" =~ ^[0-9a-f]{40}$ ]]; then
    fail "Could not resolve $repository_owner/$repository_name@$repository_ref to a 40-character commit hash."
  fi

  printf '%s' "$result"
}
