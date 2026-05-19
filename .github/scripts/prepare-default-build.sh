#!/usr/bin/env bash

# SPDX-FileCopyrightText: 2023-2026 Michael Serajnik <https://github.com/mserajnik>
# SPDX-License-Identifier: AGPL-3.0-or-later

# Decides whether the default workflow should build images this run (skipping
# when an image for the current VMaNGOS commit already exists, unless the run
# is a scheduled Monday rebuild or a manual force rebuild). Consumes the
# `vmangos_commit_hash` resolved by `resolve-sources.sh`.

set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source-path=SCRIPTDIR
source "$script_dir/helpers.sh"

require_env GH_TOKEN
require_env GITHUB_EVENT_NAME
require_env PACKAGE_OWNER
require_env PACKAGE_NAME
require_env VMANGOS_COMMIT_HASH

# shellcheck disable=SC2153
vmangos_commit_hash="$(trim "$VMANGOS_COMMIT_HASH")"
force_rebuild="${FORCE_REBUILD:-false}"
schedule_force_build="false"
any_images_to_build="true"

if [[ "$GITHUB_EVENT_NAME" == "schedule" && "$(date +%u)" -eq 1 ]]; then
  schedule_force_build="true"
fi

if [[ "$schedule_force_build" != "true" && "$force_rebuild" != "true" ]]; then
  # shellcheck disable=SC2153
  existing_tags="$(existing_tags_for_package "$PACKAGE_OWNER" "$PACKAGE_NAME")"

  if grep -Fxq "$vmangos_commit_hash" <<<"$existing_tags"; then
    any_images_to_build="false"
  fi
fi

write_output any_images_to_build "$any_images_to_build"
