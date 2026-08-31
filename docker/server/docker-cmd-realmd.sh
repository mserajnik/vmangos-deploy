#!/bin/sh

# SPDX-FileCopyrightText: 2023-2026 Michael Serajnik <https://github.com/mserajnik>
# SPDX-License-Identifier: AGPL-3.0-or-later

# Container command wrapper for the `realmd` binary. Drops privileges via
# `fixuid`, validates the bind-mounted config file, rejects unsupported
# `WAIT_*` environment variables, and launches `realmd`.

set -eu

# Capture the `fixuid -q` exit status first since `eval` discards it.
fixuid_output="$(fixuid -q)"
eval "$fixuid_output"

config_file="/opt/vmangos/config/realmd.conf"

if [ ! -f "$config_file" ]; then
  echo "[vmangos-deploy]: ERROR: Configuration file '$config_file' is missing, exiting." >&2
  exit 1
fi

if [ -n "${WAIT_HOSTS:-}" ] || [ -n "${WAIT_TIMEOUT:-}" ]; then
  echo "[vmangos-deploy]: ERROR: The 'WAIT_HOSTS' and 'WAIT_TIMEOUT' environment variables are no longer supported. The server containers wait for the database via Docker Compose's 'depends_on: condition: service_healthy' instead. For details, see the breaking changes section of the README: https://github.com/mserajnik/vmangos-deploy#breaking-changes" >&2
  exit 1
fi

exec /opt/vmangos/bin/realmd -c "$config_file"
