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

echo "[vmangos-deploy]: Creating databases"
mariadb -u root -p$MARIADB_ROOT_PASSWORD -e \
  "CREATE DATABASE IF NOT EXISTS \`mangos\` DEFAULT CHARSET utf8 COLLATE utf8_general_ci; \
  CREATE DATABASE IF NOT EXISTS \`characters\` DEFAULT CHARSET utf8 COLLATE utf8_general_ci; \
  CREATE DATABASE IF NOT EXISTS \`realmd\` DEFAULT CHARSET utf8 COLLATE utf8_general_ci; \
  CREATE DATABASE IF NOT EXISTS \`logs\` DEFAULT CHARSET utf8 COLLATE utf8_general_ci;"

echo "[vmangos-deploy]: Granting permissions to database user $MARIADB_USER"
mariadb -u root -p$MARIADB_ROOT_PASSWORD -e \
  "GRANT ALL ON \`mangos\`.* TO '$MARIADB_USER'@'%'; \
  GRANT ALL ON \`characters\`.* TO '$MARIADB_USER'@'%'; \
  GRANT ALL ON \`realmd\`.* TO '$MARIADB_USER'@'%'; \
  GRANT ALL ON \`logs\`.* TO '$MARIADB_USER'@'%'; \
  FLUSH PRIVILEGES;"

echo "[vmangos-deploy]: Importing databases"

echo "[vmangos-deploy]: Importing world database"
mariadb -u root -p$MARIADB_ROOT_PASSWORD mangos < /sql/world.sql

echo "[vmangos-deploy]: Importing characters database"
mariadb -u root -p$MARIADB_ROOT_PASSWORD characters < /sql/characters.sql

echo "[vmangos-deploy]: Importing logon database"
mariadb -u root -p$MARIADB_ROOT_PASSWORD realmd < /sql/logon.sql

echo "[vmangos-deploy]: Importing logs database"
mariadb -u root -p$MARIADB_ROOT_PASSWORD logs < /sql/logs.sql

echo "[vmangos-deploy]: Importing database updates if available"
[ -e /sql/migrations/world_db_updates.sql ] && \
  mariadb -u root -p$MARIADB_ROOT_PASSWORD mangos < /sql/migrations/world_db_updates.sql
[ -e /sql/migrations/characters_db_updates.sql ] && \
  mariadb -u root -p$MARIADB_ROOT_PASSWORD characters < /sql/migrations/characters_db_updates.sql
[ -e /sql/migrations/logon_db_updates.sql ] && \
  mariadb -u root -p$MARIADB_ROOT_PASSWORD realmd < /sql/migrations/logon_db_updates.sql
[ -e /sql/migrations/logs_db_updates.sql ] && \
  mariadb -u root -p$MARIADB_ROOT_PASSWORD logs < /sql/migrations/logs_db_updates.sql

echo "[vmangos-deploy]: Configuring default realm"
mariadb -u root -p$MARIADB_ROOT_PASSWORD -e \
  "INSERT INTO \`realmd\`.\`realmlist\` (\`name\`, \`address\`, \`port\`, \`icon\`, \`timezone\`, \`allowedSecurityLevel\`) VALUES ('$VMANGOS_REALMLIST_NAME', '$VMANGOS_REALMLIST_ADDRESS', '$VMANGOS_REALMLIST_PORT', '$VMANGOS_REALMLIST_ICON', '$VMANGOS_REALMLIST_TIMEZONE', '$VMANGOS_REALMLIST_ALLOWED_SECURITY_LEVEL');"

echo "[vmangos-deploy]: Database creation complete"
