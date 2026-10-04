#!/bin/sh

# SPDX-FileCopyrightText: 2023-2026 Michael Serajnik <https://github.com/mserajnik>
# SPDX-License-Identifier: AGPL-3.0-or-later

# Starts `mangosd`.

set -eu

# shellcheck source=docker/check-deploy-version.sh
. /usr/local/lib/vmangos-deploy/check-deploy-version.sh
# shellcheck source=docker/server/drop-privileges.sh
. /usr/local/lib/vmangos-deploy/drop-privileges.sh

config_file="/opt/vmangos/config/mangosd.conf"

if [ ! -f "$config_file" ] || [ ! -r "$config_file" ]; then
  echo "[vmangos-deploy]: ERROR: The configuration file '$config_file' is missing or not readable. Your 'compose.yaml' has to mount it from a file on the host, as 'compose.yaml.example' shows. If that file did not exist when the container started, Docker created an empty directory in its place. Stop the containers with 'docker compose down', delete that directory on the host, copy the file, and start them again with 'docker compose up -d'." >&2
  exit 1
fi

exec /opt/vmangos/bin/mangosd -c "$config_file"
