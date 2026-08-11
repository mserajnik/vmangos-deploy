# SPDX-FileCopyrightText: 2023-2026 Michael Serajnik <https://github.com/mserajnik>
# SPDX-License-Identifier: AGPL-3.0-or-later

# shellcheck shell=bash

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
  local owner_endpoint

  # Resolve the owner endpoint before use, and return rather than printing on
  # failure: `fail` inside a substitution exits only its own subshell, so
  # printing anyway would build an endpoint missing its namespace, which 404s
  # exactly like a package that was never published. Callers must not use this
  # in argument position, where the non-zero status would be discarded.
  owner_endpoint="$(package_owner_endpoint "$owner")" || return 1

  printf '%s/packages/container/%s/versions' \
    "$owner_endpoint" \
    "$package_name"
}

existing_tags_for_package() {
  local package_owner="$1"
  local package_name="$2"
  local endpoint
  local errors
  local tags
  local status

  endpoint="$(package_versions_endpoint "$package_owner" "$package_name")"

  # An empty endpoint means the owner lookup failed; report that rather than
  # querying the API root.
  if [[ -z "$endpoint" ]]; then
    fail "Failed to resolve the package versions endpoint for '$package_owner/$package_name'."
  fi

  # `gh`'s stderr is kept out of the value: an advisory on an otherwise
  # successful call would become a phantom tag in the returned list.
  errors="$(mktemp)" || fail "Failed to create a temporary file."

  set +e
  tags="$(gh api --paginate "$endpoint?per_page=100" \
    --jq '.[].metadata.container.tags[]?' 2>"$errors")"
  status=$?
  set -e

  if [[ $status -ne 0 ]]; then
    # `gh` writes the error body to stdout, so only stderr can be tested here.
    if grep -Fq "HTTP 404" "$errors"; then
      rm -f "$errors"
      printf '%s' ""
      return 0
    fi

    cat "$errors" >&2
    rm -f "$errors"
    fail "Failed to query package versions for '$package_owner/$package_name'."
  fi

  rm -f "$errors"

  printf '%s' "$tags"
}

package_version_endpoint() {
  local owner="$1"
  local package_name="$2"
  local package_version_id="$3"
  local owner_endpoint

  owner_endpoint="$(package_owner_endpoint "$owner")" || return 1

  printf '%s/packages/container/%s/versions/%s' \
    "$owner_endpoint" \
    "$package_name" \
    "$package_version_id"
}

package_owner_endpoint() {
  local owner="$1"
  local owner_type
  local namespace

  # Without the check a failed lookup leaves `owner_type` empty and reports an
  # unsupported type, which points at the wrong thing entirely.
  if ! owner_type="$(gh api "/users/$owner" --jq '.type')"; then
    fail "Failed to look up the package owner '$owner'."
  fi

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
