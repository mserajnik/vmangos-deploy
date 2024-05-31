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
# https://github.com/MariaDB/mariadb-docker/blob/4e20774a56c8fb93cec9ee9d4a5b476bc0f8dd0d/11.4/docker-entrypoint.sh
# and might need to get adjusted when the original script gets updated.
# Formatting, comments and commented out code from the original script have
# been preserved, where possible, to make it easier to compare this script to
# the original.

set -eo pipefail

source "$(which docker-entrypoint.sh)"

# This is a temporary copy of the `§docker_mariadb_upgrade()` function from the
# original entrypoint script. It has the `--upgrade-system-tables` option
# removed from the `mariadb-upgrade` command because we also want to upgrade
# user tables. Once https://github.com/MariaDB/mariadb-docker/pull/567 gets
# merged this function can be removed and the original function can be used
# again.
docker_mariadb_upgrade_including_user_tables() {
  if [ -z "$MARIADB_AUTO_UPGRADE" ] \
    || [ "$MARIADB_AUTO_UPGRADE" = 0 ]; then
    mysql_note "MariaDB upgrade (mariadb-upgrade or creating healthcheck users) required, but skipped due to \$MARIADB_AUTO_UPGRADE setting"
    return
  fi
  mysql_note "Starting temporary server"
  docker_temp_server_start "$@" --skip-grant-tables \
    --loose-innodb_buffer_pool_dump_at_shutdown=0 \
    --skip-slave-start
  mysql_note "Temporary server started."

  docker_mariadb_backup_system

  if [ ! -f "$DATADIR"/.my-healthcheck.cnf ]; then
    mysql_note "Creating healthcheck users"
    local createHealthCheckUsers
    createHealthCheckUsers=$(create_healthcheck_users)
    docker_process_sql --dont-use-mysql-root-password --binary-mode <<-EOSQL
    -- Healthcheck users shouldn't be replicated
    SET @@SESSION.SQL_LOG_BIN=0;
                -- we need the SQL_MODE NO_BACKSLASH_ESCAPES mode to be clear for the password to be set
    SET @@SESSION.SQL_MODE=REPLACE(@@SESSION.SQL_MODE, 'NO_BACKSLASH_ESCAPES', '');
    FLUSH PRIVILEGES;
    $createHealthCheckUsers
EOSQL
    mysql_note "Stopping temporary server"
    docker_temp_server_stop
    mysql_note "Temporary server stopped"

    if _check_if_upgrade_is_needed; then
      # need a restart as FLUSH PRIVILEGES isn't reversable
      mysql_note "Restarting temporary server for upgrade"
      docker_temp_server_start "$@" --skip-grant-tables \
        --loose-innodb_buffer_pool_dump_at_shutdown=0 \
        --skip-slave-start
    else
      return 0
    fi
  fi

  mysql_note "Starting mariadb-upgrade"
  mariadb-upgrade
  mysql_note "Finished mariadb-upgrade"

  mysql_note "Stopping temporary server"
  docker_temp_server_stop
  mysql_note "Temporary server stopped"
}

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
    docker_mariadb_upgrade_including_user_tables "$@"
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
  docker_mariadb_upgrade_including_user_tables "$@"
fi

exec "$@"
