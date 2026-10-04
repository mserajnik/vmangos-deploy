#!/usr/bin/env bash

# SPDX-FileCopyrightText: 2023-2026 Michael Serajnik <https://github.com/mserajnik>
# SPDX-License-Identifier: AGPL-3.0-or-later

# Sets up the databases on the first start, and acknowledges the image's
# migration edits, which a fresh install already has.

set -euo pipefail

# shellcheck source=docker/database/db-functions.sh
source "/opt/scripts/db-functions.sh"

clear_database_ready
clear_change_sentinels
mark_initializing

if [[ "${VMANGOS_PROCESS_CUSTOM_SQL:-0}" = "1" ]]; then
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

ensure_maintenance_db_exists
parse_migration_edits

for i in "${!MIGRATION_EDIT_TARGETS[@]}"; do
  acknowledge_correction "${MIGRATION_EDIT_TARGETS[i]}" "${MIGRATION_EDIT_COMMITS[i]}"
done

mark_initialized

if [[ "${VMANGOS_PROCESS_CUSTOM_SQL:-0}" = "1" ]]; then
  process_custom_sql "/sql/custom"
fi

mark_database_ready
