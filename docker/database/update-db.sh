#!/bin/sh

# vmangos-deploy
# Copyright (C) 2023-2025  Michael Serajnik  https://github.com/mserajnik

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

. "/opt/scripts/db-functions.sh"

if [ "${VMANGOS_ENABLE_AUTOMATIC_WORLD_DB_CORRECTIONS:-0}" = "1" ]; then
  echo "[vmangos-deploy]: [x] Automatic world database corrections are enabled"
else
  echo "[vmangos-deploy]: [ ] Automatic world database corrections are disabled"
fi

if [ "${VMANGOS_PROCESS_CUSTOM_SQL:-0}" = "1" ]; then
  echo "[vmangos-deploy]: [x] Custom SQL processing is enabled"
else
  echo "[vmangos-deploy]: [ ] Custom SQL processing is disabled"
fi

if [ "${VMANGOS_ENABLE_AUTOMATIC_WORLD_DB_CORRECTIONS:-0}" = "1" ]; then
  create_database "maintenance" true
  grant_permissions "maintenance" true
  create_world_db_corrections_table
  populate_world_db_corrections_table

  result=$(check_if_world_db_correction_is_required)
  requires_correction=$(echo "$result" | cut -d'|' -f1)
  reason=$(echo "$result" | cut -d'|' -f2)

  if [ "$requires_correction" = "true" ]; then
    echo "[vmangos-deploy]: World database correction required because of $reason, re-creating world database"

    drop_database "mangos"
    create_database "mangos"
    grant_permissions "mangos"
    import_dump "mangos" "/sql/world.sql"
    mark_world_db_corrections_as_applied
  fi
else
  echo "[vmangos-deploy]: Automatic world database corrections are disabled"

  drop_database "maintenance" true
fi

if [ -e "$VMANGOS_WORLD_DB_DUMP_NEW_FILE" ]; then
  echo "[vmangos-deploy]: '$VMANGOS_WORLD_DB_DUMP_NEW_FILE' exists, re-creating world database"

  drop_database "mangos"
  create_database "mangos"
  grant_permissions "mangos"
  import_dump "mangos" "$VMANGOS_WORLD_DB_DUMP_NEW_FILE"
fi

import_updates "mangos" "/sql/migrations/world_db_updates.sql"
import_updates "characters" "/sql/migrations/characters_db_updates.sql"
import_updates "realmd" "/sql/migrations/logon_db_updates.sql"
import_updates "logs" "/sql/migrations/logs_db_updates.sql"

if [ "${VMANGOS_PROCESS_CUSTOM_SQL:-0}" = "1" ]; then
  process_custom_sql "/sql/custom"
fi
