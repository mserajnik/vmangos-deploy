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

if [ -e "$VMANGOS_WORLD_DB_DUMP_NEW_FILE" ]; then
  echo "[vmangos-deploy]: $VMANGOS_WORLD_DB_DUMP_NEW_FILE exists, re-creating world database"
  drop_database "mangos"
  create_database "mangos"
  grant_permissions "mangos"
  import_dump "mangos" "$VMANGOS_WORLD_DB_DUMP_NEW_FILE"
fi

import_updates "mangos" "/sql/migrations/world_db_updates.sql"
import_updates "characters" "/sql/migrations/characters_db_updates.sql"
import_updates "realmd" "/sql/migrations/logon_db_updates.sql"
import_updates "logs" "/sql/migrations/logs_db_updates.sql"
