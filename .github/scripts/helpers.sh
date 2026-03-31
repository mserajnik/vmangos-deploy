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

fail() {
  echo "ERROR: $*" >&2
  exit 1
}

require_env() {
  local name="$1"

  if [[ -z "${!name:-}" ]]; then
    fail "Environment variable '$name' is required"
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

  printf '%s=%s\n' "$name" "$value" >> "$GITHUB_OUTPUT"
}

write_multiline_output() {
  require_env GITHUB_OUTPUT

  local name="$1"
  local value="$2"
  local delimiter="EOF_${name}_$(date +%s)_$RANDOM"

  {
    printf '%s<<%s\n' "$name" "$delimiter"
    printf '%s\n' "$value"
    printf '%s\n' "$delimiter"
  } >> "$GITHUB_OUTPUT"
}

sanitize_docker_tag_fragment() {
  local original="$1"
  local sanitized

  sanitized="$(printf '%s' "$original" | sed -E \
    -e 's/[^A-Za-z0-9_.-]+/-/g' \
    -e 's/^[^A-Za-z0-9_]+//' \
    -e 's/[^A-Za-z0-9_.-]+$//')"

  if [[ -z "$sanitized" ]]; then
    fail "Value '$original' cannot be converted into a valid Docker tag fragment"
  fi

  printf '%s\n' "$sanitized"
}

package_versions_endpoint() {
  local owner="$1"
  local package_name="$2"
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
      fail "Unsupported package owner type '$owner_type' for '$owner'"
      ;;
  esac

  printf '/%s/%s/packages/container/%s/versions' "$namespace" "$owner" "$package_name"
}
