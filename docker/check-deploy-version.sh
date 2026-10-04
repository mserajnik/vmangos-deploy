# shellcheck shell=sh

# SPDX-FileCopyrightText: 2023-2026 Michael Serajnik <https://github.com/mserajnik>
# SPDX-License-Identifier: AGPL-3.0-or-later

# Stops with an error when `VMANGOS_DEPLOY_VERSION` does not match the number
# this image expects. Every image sources this first.

# Raise this with each breaking change that needs the user to act, and add the
# change to `docs/breaking-changes.md`.
expected_deploy_version=1

deploy_version="${VMANGOS_DEPLOY_VERSION:-}"
if [ "$deploy_version" != "$expected_deploy_version" ]; then
  case "$deploy_version" in
    '') deploy_version_state="the variable is not set" ;;
    *[!0-9]*) deploy_version_state="the variable is not set to an expected value ('$deploy_version')" ;;
    *) deploy_version_state="the variable is '$deploy_version'" ;;
  esac
  deploy_version_error="[vmangos-deploy]: ERROR: This image expects 'VMANGOS_DEPLOY_VERSION=$expected_deploy_version', but $deploy_version_state."
  # Anything `-gt` cannot compare gets the upgrade advice.
  if [ "$deploy_version" -gt "$expected_deploy_version" ] 2>/dev/null; then
    echo "$deploy_version_error Pull a newer image, for example with 'docker compose pull'." >&2
  else
    echo "$deploy_version_error Apply the breaking changes up to version $expected_deploy_version to your configuration and set the variable to match. See the breaking changes:" >&2
    echo "https://github.com/mserajnik/vmangos-deploy/blob/master/docs/breaking-changes.md" >&2
  fi
  exit 1
fi
