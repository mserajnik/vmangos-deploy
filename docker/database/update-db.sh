#!/usr/bin/env bash

# SPDX-FileCopyrightText: 2023-2026 Michael Serajnik <https://github.com/mserajnik>
# SPDX-License-Identifier: AGPL-3.0-or-later

# Runs on every subsequent container start (via `/always-initdb.d`) to apply
# pending migrations and act on baked migration edit metadata, either
# re-creating the world database or halting startup until the user runs
# `vmangos-confirm-changes`.

set -euo pipefail

# shellcheck source=docker/database/db-functions.sh
source "/opt/scripts/db-functions.sh"

clear_database_ready
clear_change_sentinels

if [ "${VMANGOS_ENABLE_AUTOMATIC_WORLD_DB_CORRECTIONS:-0}" = "1" ]; then
  vmangos_log "[x] Automatic world database corrections are enabled."
else
  vmangos_log "[ ] Automatic world database corrections are disabled."
fi

if [ "${VMANGOS_HALT_ON_MIGRATION_EDITS:-0}" = "1" ]; then
  vmangos_log "[x] Halting on migration edits is enabled."
else
  vmangos_log "[ ] Halting on migration edits is disabled."
fi

if [ "${VMANGOS_PROCESS_CUSTOM_SQL:-0}" = "1" ]; then
  vmangos_log "[x] Custom SQL processing is enabled."
else
  vmangos_log "[ ] Custom SQL processing is disabled."
fi

ensure_maintenance_db_exists
drop_legacy_world_db_corrections_table
parse_migration_edits

process_world_correction "$MIGRATION_EDIT_WORLD"
process_userstate_correction "characters" "$MIGRATION_EDIT_CHARACTERS"
process_userstate_correction "realmd" "$MIGRATION_EDIT_REALMD"
process_userstate_correction "logs" "$MIGRATION_EDIT_LOGS"

if [ "${#PENDING_DB_NAMES[@]}" -gt 0 ]; then
  print_correction_abort_message
  wait_for_change_ack

  i=0
  while [ "$i" -lt "${#PENDING_DB_NAMES[@]}" ]; do
    acknowledge_correction "${PENDING_DB_NAMES[$i]}" "${PENDING_DB_COMMIT_HASHES[$i]}"
    i=$((i + 1))
  done

  vmangos_log "Migration edits acknowledged; continuing startup."
fi

# Skipped when `process_world_correction` already ran `import_updates` against
# a freshly re-created world database above.
if [ "${WORLD_DB_MIGRATIONS_APPLIED:-0}" != "1" ]; then
  import_updates "mangos" "/sql/migrations/world_db_updates.sql"
fi
import_updates "characters" "/sql/migrations/characters_db_updates.sql"
import_updates "realmd" "/sql/migrations/logon_db_updates.sql"
import_updates "logs" "/sql/migrations/logs_db_updates.sql"

if [ "${VMANGOS_PROCESS_CUSTOM_SQL:-0}" = "1" ]; then
  process_custom_sql "/sql/custom"
fi

configure_realm

mark_database_ready
