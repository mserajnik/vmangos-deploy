#!/usr/bin/env bash

# SPDX-FileCopyrightText: 2023-2026 Michael Serajnik <https://github.com/mserajnik>
# SPDX-License-Identifier: AGPL-3.0-or-later

# Runs once on first container start (via `/docker-entrypoint-initdb.d`) to
# create and seed the four VMaNGOS databases, then pre-acknowledges any baked
# migration edits so the next startup does not re-run a re-creation or halt for
# them.

set -euo pipefail

# shellcheck source=docker/database/db-functions.sh
source "/opt/scripts/db-functions.sh"

clear_database_ready
clear_change_sentinels

if [ "${VMANGOS_PROCESS_CUSTOM_SQL:-0}" = "1" ]; then
  vmangos_log "[x] Custom SQL processing is enabled."
else
  vmangos_log "[ ] Custom SQL processing is disabled."
fi

create_database "mangos"
create_database "characters"
create_database "realmd"
create_database "logs"

grant_permissions "mangos"
grant_permissions "characters"
grant_permissions "realmd"
grant_permissions "logs"

import_dump "mangos" "/sql/world.sql"
import_dump "characters" "/sql/characters.sql"
import_dump "realmd" "/sql/logon.sql"
import_dump "logs" "/sql/logs.sql"

import_updates "mangos" "/sql/migrations/world_db_updates.sql"
import_updates "characters" "/sql/migrations/characters_db_updates.sql"
import_updates "realmd" "/sql/migrations/logon_db_updates.sql"
import_updates "logs" "/sql/migrations/logs_db_updates.sql"

configure_realm

if [ "${VMANGOS_PROCESS_CUSTOM_SQL:-0}" = "1" ]; then
  process_custom_sql "/sql/custom"
fi

# A fresh install is already at the latest state, so any migration edits
# flagged in the baked state file are pre-acknowledged to avoid triggering an
# unnecessary world database re-creation or halt on the next start.
ensure_maintenance_db_exists
parse_migration_edits

if [ -n "$MIGRATION_EDIT_WORLD" ]; then
  acknowledge_correction "world" "$MIGRATION_EDIT_WORLD"
fi
if [ -n "$MIGRATION_EDIT_CHARACTERS" ]; then
  acknowledge_correction "characters" "$MIGRATION_EDIT_CHARACTERS"
fi
if [ -n "$MIGRATION_EDIT_REALMD" ]; then
  acknowledge_correction "realmd" "$MIGRATION_EDIT_REALMD"
fi
if [ -n "$MIGRATION_EDIT_LOGS" ]; then
  acknowledge_correction "logs" "$MIGRATION_EDIT_LOGS"
fi

mark_database_ready
