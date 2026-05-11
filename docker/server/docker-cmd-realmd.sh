#!/bin/sh

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
