#!/usr/bin/env bash

# SPDX-FileCopyrightText: 2023-2026 Michael Serajnik <https://github.com/mserajnik>
# SPDX-License-Identifier: AGPL-3.0-or-later

# Health gate for the database service. Reports unhealthy until startup signals
# ready by writing `/tmp/vmangos-database-ready`, then delegates to the
# upstream MariaDB healthcheck. Server containers gate on this via
# `depends_on: condition: service_healthy`.

set -eu

if [ ! -f /tmp/vmangos-database-ready ]; then
  exit 1
fi

exec healthcheck.sh --connect --innodb_initialized
