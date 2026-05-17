#!/usr/bin/env bash

# SPDX-FileCopyrightText: 2023-2026 Michael Serajnik <https://github.com/mserajnik>
# SPDX-License-Identifier: AGPL-3.0-or-later

# Compares pinned upstream references (the MariaDB entrypoint, VMaNGOS files we
# mirror) against current upstream `HEAD`. Fails the workflow when any has
# drifted so the matching local copy can be reviewed.

set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source-path=SCRIPTDIR
source "$script_dir/helpers.sh"

require_env MARIADB_DOCKER_KNOWN_SHA
require_env VMANGOS_KNOWN_SHA

workdir="$(mktemp -d)"
trap 'rm -rf "$workdir"' EXIT

# Each entry: <description>|<known_url>|<latest_url>.
declare -a checks=()

add_github_check() {
  local owner_repo="$1"
  local ref="$2"
  local latest_ref="$3"
  local path="$4"

  local desc="$owner_repo:$path"
  local known_url="https://raw.githubusercontent.com/$owner_repo/$ref/$path"
  local latest_url="https://raw.githubusercontent.com/$owner_repo/$latest_ref/$path"

  checks+=("$desc|$known_url|$latest_url")
}

# Patched MariaDB entrypoint. The vmangos-deploy
# `docker/database/docker-entrypoint.sh` extends functions defined in
# upstream's version, so any change there has to be reviewed for compatibility.
add_github_check MariaDB/mariadb-docker "$MARIADB_DOCKER_KNOWN_SHA" master \
  11.8/docker-entrypoint.sh

# Configs we mirror as `*.conf.example` and the top-level `CMakeLists.txt`,
# which is where new `find_package(...)` would typically introduce a new
# dependency that we would need to install.
vmangos_paths=(
  src/mangosd/mangosd.conf.dist.in
  src/realmd/realmd.conf.dist.in
  CMakeLists.txt
)

for path in "${vmangos_paths[@]}"; do
  add_github_check vmangos/core "$VMANGOS_KNOWN_SHA" development "$path"
done

failures=0

for check in "${checks[@]}"; do
  IFS='|' read -r desc known_url latest_url <<<"$check"

  curl --fail --silent --show-error --location \
    --output "$workdir/known" "$known_url"
  curl --fail --silent --show-error --location \
    --output "$workdir/latest" "$latest_url"

  if ! diff -u "$workdir/known" "$workdir/latest" >/dev/null; then
    printf '\n=== DRIFT DETECTED: %s ===\n' "$desc"
    diff -u "$workdir/known" "$workdir/latest" || true
    failures=$((failures + 1))
  else
    printf 'OK: %s\n' "$desc"
  fi
done

if ((failures > 0)); then
  printf '\n%s upstream reference(s) drifted from the pinned revision.\n' "$failures" >&2
  fail "Review the diff(s) above, refresh any local files that need to align, and bump the matching *_KNOWN_SHA."
fi
