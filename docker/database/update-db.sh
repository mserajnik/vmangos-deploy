#!/bin/sh

# vmangos-deploy
# Copyright (C) 2023-present  Michael Serajnik  https://github.com/mserajnik

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
  echo "[vmangos-deploy]: world-new.sql exists, re-generating world database..." && \
  mariadb -u root -p$MYSQL_ROOT_PASSWORD mangos < /sql/regenerate-world-db.sql && \
  mariadb -u root -p$MYSQL_ROOT_PASSWORD mangos < /sql/world-new.sql

echo "[vmangos-deploy]: Importing database updates..."
[ -e /sql/migrations/world_db_updates.sql ] && \
  mariadb -u root -p$MYSQL_ROOT_PASSWORD mangos < /sql/migrations/world_db_updates.sql
[ -e /sql/migrations/characters_db_updates.sql ] && \
  mariadb -u root -p$MYSQL_ROOT_PASSWORD characters < /sql/migrations/characters_db_updates.sql
[ -e /sql/migrations/logon_db_updates.sql ] && \
  mariadb -u root -p$MYSQL_ROOT_PASSWORD realmd < /sql/migrations/logon_db_updates.sql
[ -e /sql/migrations/logs_db_updates.sql ] && \
  mariadb -u root -p$MYSQL_ROOT_PASSWORD logs < /sql/migrations/logs_db_updates.sql
