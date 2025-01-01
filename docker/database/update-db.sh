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

[ -e /sql/world-new.sql ] && \
  echo "[vmangos-deploy]: /sql/world-new.sql exists, re-creating world database" && \
  mariadb -u root -p$MARIADB_ROOT_PASSWORD -e \
    "DROP DATABASE IF EXISTS \`mangos\`; \
    CREATE DATABASE \`mangos\` DEFAULT CHARSET utf8 COLLATE utf8_general_ci; \
    GRANT ALL ON \`mangos\`.* TO '$MARIADB_USER'@'%'; \
    FLUSH PRIVILEGES;" && \
  mariadb -u root -p$MARIADB_ROOT_PASSWORD mangos < /sql/world-new.sql

echo "[vmangos-deploy]: Importing database updates if available"
[ -e /sql/migrations/world_db_updates.sql ] && \
  mariadb -u root -p$MARIADB_ROOT_PASSWORD mangos < /sql/migrations/world_db_updates.sql
[ -e /sql/migrations/characters_db_updates.sql ] && \
  mariadb -u root -p$MARIADB_ROOT_PASSWORD characters < /sql/migrations/characters_db_updates.sql
[ -e /sql/migrations/logon_db_updates.sql ] && \
  mariadb -u root -p$MARIADB_ROOT_PASSWORD realmd < /sql/migrations/logon_db_updates.sql
[ -e /sql/migrations/logs_db_updates.sql ] && \
  mariadb -u root -p$MARIADB_ROOT_PASSWORD logs < /sql/migrations/logs_db_updates.sql
