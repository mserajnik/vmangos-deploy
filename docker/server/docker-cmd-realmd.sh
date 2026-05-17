#!/bin/sh

# SPDX-FileCopyrightText: 2023-2026 Michael Serajnik <https://github.com/mserajnik>
# SPDX-License-Identifier: AGPL-3.0-or-later

# Container command wrapper for the `realmd` binary. Drops privileges via
# `fixuid`, validates the bind-mounted config file, warns about deprecated
# `WAIT_*` environment variables, and launches `realmd`.

set -eu

eval "$(fixuid -q)"

config_file="/opt/vmangos/config/realmd.conf"

if [ ! -f "$config_file" ]; then
  echo "[vmangos-deploy]: ERROR: Configuration file '$config_file' is missing, exiting." >&2
  exit 1
fi

if [ -n "${WAIT_HOSTS:-}" ] || [ -n "${WAIT_TIMEOUT:-}" ]; then
  echo "[vmangos-deploy]: WARNING: The 'WAIT_HOSTS' and 'WAIT_TIMEOUT' environment variables are deprecated and have no effect. The server containers wait for the database via Docker Compose's 'depends_on: condition: service_healthy' instead. Remove these variables from your Compose configuration. After 2026-08-31, vmangos-deploy will fail to start if these are still set." >&2
fi

exec /opt/vmangos/bin/realmd -c "$config_file"
