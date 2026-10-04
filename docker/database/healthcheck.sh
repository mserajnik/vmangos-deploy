#!/usr/bin/env bash

# SPDX-FileCopyrightText: 2023-2026 Michael Serajnik <https://github.com/mserajnik>
# SPDX-License-Identifier: AGPL-3.0-or-later

# Reports unhealthy until the start marks the database ready, then runs the
# MariaDB healthcheck.

set -eu

if [[ ! -f /tmp/vmangos-database-ready ]]; then
  exit 1
fi

exec healthcheck.sh --connect --innodb_initialized
