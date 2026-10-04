#!/usr/bin/env bash

# SPDX-FileCopyrightText: MariaDB Docker contributors <https://github.com/MariaDB/mariadb-docker>
# SPDX-FileCopyrightText: 2023-2026 Michael Serajnik <https://github.com/mserajnik>
# SPDX-License-Identifier: GPL-2.0-only

# Based on the MariaDB entrypoint below. Its formatting, comments, and
# commented-out code stay, so the two remain easy to compare.
# https://github.com/MariaDB/mariadb-docker/blob/063eb10da092170beea08d2c629b6eb79d28cceb/12.3/docker-entrypoint.sh

set -eo pipefail

# shellcheck disable=SC1090
source "$(which docker-entrypoint.sh)"

# A copy of the original `docker_mariadb_upgrade()` without
# `--upgrade-system-tables`, so `mariadb-upgrade` upgrades the user tables too.
docker_mariadb_upgrade_including_user_tables() {
  if [ -z "$MARIADB_AUTO_UPGRADE" ] \
    || [ "$MARIADB_AUTO_UPGRADE" = 0 ]; then
    mysql_note "MariaDB upgrade (mariadb-upgrade or creating healthcheck users) required, but skipped due to \$MARIADB_AUTO_UPGRADE setting"
    return
  fi
  mysql_note "Starting temporary server"
  docker_temp_server_start "$@" --skip-grant-tables \
    --loose-innodb_buffer_pool_dump_at_shutdown=0
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
      # need a restart as FLUSH PRIVILEGES isn't reversible
      mysql_note "Restarting temporary server for upgrade"
      docker_temp_server_start "$@" --skip-grant-tables \
        --loose-innodb_buffer_pool_dump_at_shutdown=0
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

# if command starts with an option, prepend mariadbd
if [ "${1:0:1}" = '-' ]; then
  set -- mariadbd "$@"
fi

#ENDOFSUBSTITUTIONS
# skip setup if they aren't running mysqld or want an option that stops mysqld
if [ "$1" = 'mariadbd' ] || [ "$1" = 'mysqld' ] && ! _mysql_want_help "$@"; then
  mysql_note "Custom entrypoint script for MariaDB Server ${MARIADB_VERSION} started."
  # Outside the hook run, a stop ends the start once the running command
  # finishes. PID 1 ignores a signal it has no handler for.
  trap 'exit 143' TERM

  # shellcheck source=docker/check-deploy-version.sh
  . /usr/local/lib/vmangos-deploy/check-deploy-version.sh

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

    # A stop lets the running hook step finish and then shuts the temporary
    # server down cleanly. The hooks run in the background, because a trap runs
    # only between commands and PID 1 ignores a signal it has no handler for.
    trap 'pkill -P "$hooks_pid" || :; wait "$hooks_pid" || :; docker_temp_server_stop; exit 143' TERM
    docker_process_init_files /always-initdb.d/* &
    hooks_pid=$!
    wait "$hooks_pid"
    trap 'exit 143' TERM

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
  for password_var in ROOT_ REPLICATION_ ''; do
    unset MARIADB_${password_var}PASSWORD MARIADB_${password_var}PASSWORD_HASH \
      MYSQL_${password_var}PASSWORD \
      MARIADB_${password_var}FILE MYSQL_${password_var}FILE
  done
  unset MYSQL_ROOT_HOST MYSQL_ROOT_HOST_FILE \
    MARIADB_ROOT_HOST MARIADB_ROOT_HOST_FILE
fi
exec "$@"
