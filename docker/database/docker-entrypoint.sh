#!/usr/bin/env bash

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

# This entrypoint script is based on
# https://github.com/MariaDB/mariadb-docker/blob/f64d0cd1176b78c8a42a219fdf0b5c54a12b3c6d/11.2/docker-entrypoint.sh
# and might need to get adjusted when the original script gets updated.

set -eo pipefail

source "$(which docker-entrypoint.sh)"

mysql_note "Custom entrypoint script for MariaDB Server ${MARIADB_VERSION} started."

mysql_check_config "$@"
# Load various environment variables
docker_setup_env "$@"
docker_create_db_directories

# If container is started as root user, restart as dedicated mysql user
if [ "$(id -u)" = "0" ]; then
  mysql_note "Switching to dedicated user 'mysql'"
  exec gosu mysql "${BASH_SOURCE[0]}" "$@"
fi

# there's no database, so it needs to be initialized
if [ -z "$DATABASE_ALREADY_EXISTS" ]; then
  docker_verify_minimum_env

  docker_mariadb_init "$@"
# run always-run hooks if they exist
elif test -n "$(shopt -s nullglob; echo /always-initdb.d/*)"; then
  # MDEV-27636 mariadb_upgrade --check-if-upgrade-is-needed cannot be run offline
  #if mariadb-upgrade --check-if-upgrade-is-needed; then
  if _check_if_upgrade_is_needed; then
    docker_mariadb_upgrade "$@"
  fi

  mysql_note "Starting temporary server"
  docker_temp_server_start "$@"
  mysql_note "Temporary server started."

  docker_process_init_files /always-initdb.d/*

  mysql_note "Stopping temporary server"
  docker_temp_server_stop
  mysql_note "Temporary server stopped"

  echo
  mysql_note "MariaDB init process done. Ready for start up."
  echo
# MDEV-27636 mariadb_upgrade --check-if-upgrade-is-needed cannot be run offline
#elif mariadb-upgrade --check-if-upgrade-is-needed; then
elif _check_if_upgrade_is_needed; then
  docker_mariadb_upgrade "$@"
fi

exec "$@"
