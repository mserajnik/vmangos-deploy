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

create_database() {
  local db_name="$1"
  echo "[vmangos-deploy]: Creating database $db_name"
  mariadb -u root -p"$MARIADB_ROOT_PASSWORD" -e \
    "CREATE DATABASE IF NOT EXISTS \`$db_name\` DEFAULT CHARSET utf8 COLLATE utf8_general_ci;"
}

drop_database() {
  local db_name="$1"
  echo "[vmangos-deploy]: Dropping database $db_name"
  mariadb -u root -p"$MARIADB_ROOT_PASSWORD" -e \
    "DROP DATABASE IF EXISTS \`$db_name\`;"
}

grant_permissions() {
  local db_name="$1"
  echo "[vmangos-deploy]: Granting permissions to database user $MARIADB_USER for database $db_name"
  mariadb -u root -p"$MARIADB_ROOT_PASSWORD" -e \
    "GRANT ALL ON \`$db_name\`.* TO '$MARIADB_USER'@'%'; \
    FLUSH PRIVILEGES;"
}

import_data() {
  local db_name="$1"
  local file="$2"
  mariadb -u root -p"$MARIADB_ROOT_PASSWORD" "$db_name" < "$file"
}

import_dump() {
  local db_name="$1"
  local dump_file="$2"
  echo "[vmangos-deploy]: Importing initial data for database $db_name"
  import_data "$db_name" "$dump_file"
}

import_updates() {
  local db_name="$1"
  local update_file="$2"
  if [ -e "$update_file" ]; then
    echo "[vmangos-deploy]: Importing potential updates for database $db_name"
    import_data "$db_name" "$update_file"
  fi
}

configure_realm() {
  echo "[vmangos-deploy]: Configuring realm $VMANGOS_REALMLIST_NAME"
  mariadb -u root -p"$MARIADB_ROOT_PASSWORD" realmd -e \
    "INSERT INTO \`realmlist\` (\`name\`, \`address\`, \`port\`, \`icon\`, \`timezone\`, \`allowedSecurityLevel\`) VALUES ('$VMANGOS_REALMLIST_NAME', '$VMANGOS_REALMLIST_ADDRESS', '$VMANGOS_REALMLIST_PORT', '$VMANGOS_REALMLIST_ICON', '$VMANGOS_REALMLIST_TIMEZONE', '$VMANGOS_REALMLIST_ALLOWED_SECURITY_LEVEL');"
}
