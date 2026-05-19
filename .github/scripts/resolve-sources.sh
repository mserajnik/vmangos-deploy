#!/usr/bin/env bash

# SPDX-FileCopyrightText: 2023-2026 Michael Serajnik <https://github.com/mserajnik>
# SPDX-License-Identifier: AGPL-3.0-or-later

# Resolves the upstream commit of each requested source to a full commit hash.
# Sources are opt-in: each one is resolved only when its matching environment
# variables are provided. The default workflow requests every source; the
# custom build workflow requests only the MariaDB entrypoint, because the other
# sources' resolved commit hashes have no consumer in the custom workflow.
# Emits the resolved commit hashes as job outputs so downstream steps (drift
# check, build decision, image builds) all reference the same revision set even
# if a branch tip moves during the run.

set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source-path=SCRIPTDIR
source "$script_dir/helpers.sh"

require_env GH_TOKEN

resolved_any=false

if [[ -n "${VMANGOS_REPOSITORY_OWNER:-}${VMANGOS_REPOSITORY_NAME:-}${VMANGOS_REVISION:-}" ]]; then
  require_env VMANGOS_REPOSITORY_OWNER
  require_env VMANGOS_REPOSITORY_NAME
  require_env VMANGOS_REVISION

  vmangos_repository="$VMANGOS_REPOSITORY_OWNER/$VMANGOS_REPOSITORY_NAME"
  vmangos_commit_hash="$(resolve_commit_hash \
    "$VMANGOS_REPOSITORY_OWNER" "$VMANGOS_REPOSITORY_NAME" "$VMANGOS_REVISION")"
  if [[ "$resolved_any" != "true" ]]; then printf 'Resolved sources:\n'; fi
  printf '  %s@%s\n' "$vmangos_repository" "$vmangos_commit_hash"
  write_output vmangos_repository "$vmangos_repository"
  write_output vmangos_commit_hash "$vmangos_commit_hash"
  resolved_any=true
fi

if [[ -n "${MARIADB_DOCKER_REPOSITORY_OWNER:-}${MARIADB_DOCKER_REPOSITORY_NAME:-}${MARIADB_DOCKER_REVISION:-}" ]]; then
  require_env MARIADB_DOCKER_REPOSITORY_OWNER
  require_env MARIADB_DOCKER_REPOSITORY_NAME
  require_env MARIADB_DOCKER_REVISION

  mariadb_docker_repository="$MARIADB_DOCKER_REPOSITORY_OWNER/$MARIADB_DOCKER_REPOSITORY_NAME"
  mariadb_docker_commit_hash="$(resolve_commit_hash \
    "$MARIADB_DOCKER_REPOSITORY_OWNER" "$MARIADB_DOCKER_REPOSITORY_NAME" \
    "$MARIADB_DOCKER_REVISION")"
  if [[ "$resolved_any" != "true" ]]; then printf 'Resolved sources:\n'; fi
  printf '  %s@%s\n' "$mariadb_docker_repository" "$mariadb_docker_commit_hash"
  write_output mariadb_docker_repository "$mariadb_docker_repository"
  write_output mariadb_docker_commit_hash "$mariadb_docker_commit_hash"
  resolved_any=true
fi

if [[ "$resolved_any" != "true" ]]; then
  fail "No sources requested; provide environment variables for at least one source."
fi
