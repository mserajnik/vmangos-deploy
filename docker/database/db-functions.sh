#!/usr/bin/env bash

# SPDX-FileCopyrightText: 2023-2026 Michael Serajnik <https://github.com/mserajnik>
# SPDX-License-Identifier: AGPL-3.0-or-later

# Shared helpers sourced by `create-db.sh` and `update-db.sh`: database CRUD,
# migration edit acknowledgement, halt and confirm sentinels, and the world
# database `variables` capture and restore stopgap.

vmangos_log() {
  echo "[vmangos-deploy]: $*"
}

vmangos_fail() {
  echo "[vmangos-deploy]: ERROR: $*" >&2
  exit 1
}

sql_escape() {
  printf '%s' "$1" | sed "s/'/''/g"
}

mark_database_ready() {
  touch /tmp/vmangos-database-ready
}

clear_database_ready() {
  rm -f /tmp/vmangos-database-ready
}

clear_change_sentinels() {
  rm -f /tmp/vmangos-changes-pending /tmp/vmangos-changes-acknowledged
}

create_database() {
  local db_name="$1"
  local silent="${2:-false}"

  if [ "$silent" = false ]; then
    vmangos_log "Creating database '$db_name'..."
  fi

  mariadb -u root -p"$MARIADB_ROOT_PASSWORD" -e \
    "CREATE DATABASE IF NOT EXISTS \`$db_name\` DEFAULT CHARSET utf8 COLLATE utf8_general_ci;"
}

drop_database() {
  local db_name="$1"
  local silent="${2:-false}"

  if [ "$silent" = false ]; then
    vmangos_log "Dropping database '$db_name'..."
  fi

  mariadb -u root -p"$MARIADB_ROOT_PASSWORD" -e \
    "DROP DATABASE IF EXISTS \`$db_name\`;"
}

grant_permissions() {
  local db_name="$1"
  local silent="${2:-false}"

  if [ "$silent" = false ]; then
    vmangos_log "Granting permissions to database user '$MARIADB_USER' for database '$db_name'..."
  fi

  mariadb -u root -p"$MARIADB_ROOT_PASSWORD" -e \
    "CREATE USER IF NOT EXISTS '$MARIADB_USER'@'%' IDENTIFIED BY '$MARIADB_PASSWORD'; \
    GRANT ALL ON \`$db_name\`.* TO '$MARIADB_USER'@'%'; \
    FLUSH PRIVILEGES;"
}

import_data() {
  local db_name="$1"
  local file="$2"

  mariadb -u root -p"$MARIADB_ROOT_PASSWORD" "$db_name" <"$file"
  return $?
}

import_dump() {
  local db_name="$1"
  local dump_file="$2"

  vmangos_log "Importing initial data for database '$db_name'..."

  import_data "$db_name" "$dump_file"
  return $?
}

import_updates() {
  local db_name="$1"
  local update_file="$2"

  if [ ! -e "$update_file" ]; then
    # The update file not existing is not an error, so we return 0 (success)
    # here.
    return 0
  fi

  vmangos_log "Importing potential updates for database '$db_name'..."

  import_data "$db_name" "$update_file"
  return $?
}

configure_realm() {
  local realm_name
  local realm_address

  realm_name="$(sql_escape "$VMANGOS_REALMLIST_NAME")"
  realm_address="$(sql_escape "$VMANGOS_REALMLIST_ADDRESS")"
  vmangos_log "Configuring realm '$VMANGOS_REALMLIST_NAME'..."

  mariadb -u root -p"$MARIADB_ROOT_PASSWORD" "realmd" -e \
    "INSERT INTO \`realmlist\` \
       (\`id\`, \`name\`, \`address\`, \`port\`, \`icon\`, \`timezone\`, \`allowedSecurityLevel\`) \
     VALUES \
       (1, '$realm_name', '$realm_address', '$VMANGOS_REALMLIST_PORT', '$VMANGOS_REALMLIST_ICON', '$VMANGOS_REALMLIST_TIMEZONE', '$VMANGOS_REALMLIST_ALLOWED_SECURITY_LEVEL') \
     ON DUPLICATE KEY UPDATE \
       \`name\` = VALUES(\`name\`), \
       \`address\` = VALUES(\`address\`), \
       \`port\` = VALUES(\`port\`), \
       \`icon\` = VALUES(\`icon\`), \
       \`timezone\` = VALUES(\`timezone\`), \
       \`allowedSecurityLevel\` = VALUES(\`allowedSecurityLevel\`);"
}

table_exists() {
  local db_name="$1"
  local table_name="$2"
  local count

  count="$(mariadb -u root -p"$MARIADB_ROOT_PASSWORD" -N -s -e \
    "SELECT COUNT(*) FROM \`information_schema\`.\`TABLES\` \
    WHERE \`TABLE_SCHEMA\` = '$(sql_escape "$db_name")' \
    AND \`TABLE_NAME\` = '$(sql_escape "$table_name")';")"

  [ "$count" -gt 0 ]
}

ensure_maintenance_db_exists() {
  create_database "maintenance" true
  grant_permissions "maintenance" true

  mariadb -u root -p"$MARIADB_ROOT_PASSWORD" "maintenance" -e \
    "CREATE TABLE IF NOT EXISTS \`migration_corrections\` ( \
      \`db_name\` VARCHAR(64) NOT NULL, \
      \`commit_hash\` CHAR(40) NOT NULL, \
      \`acknowledged_at\` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP, \
      PRIMARY KEY (\`db_name\`, \`commit_hash\`) \
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8;"

  # One-time rename of the legacy `commit_sha` column to `commit_hash` for
  # installs that were created before the renaming. TODO: removable once we can
  # assume all existing installs have run with the new column name.
  mariadb -u root -p"$MARIADB_ROOT_PASSWORD" "maintenance" -e \
    "ALTER TABLE \`migration_corrections\` \
     CHANGE COLUMN IF EXISTS \`commit_sha\` \`commit_hash\` CHAR(40) NOT NULL;"
}

# One-time cleanup for installs that were created under the legacy
# `world_db_corrections` mechanism. Removable once we can assume all existing
# installs have started at least once with the new image.
drop_legacy_world_db_corrections_table() {
  if table_exists "maintenance" "world_db_corrections"; then
    vmangos_log "Dropping legacy 'world_db_corrections' table..."
    mariadb -u root -p"$MARIADB_ROOT_PASSWORD" "maintenance" -e \
      "DROP TABLE \`world_db_corrections\`;"
  fi
}

# The `VMANGOS_MIGRATION_EDITS` build argument is baked into
# `/sql/migration-edits` at image build time; manual builds leave the file
# empty and all four globals stay empty, which makes every per-database
# correction a no-op.
#
# Leaks the four `MIGRATION_EDIT_*` globals to the parent script by design;
# `update-db.sh` and `create-db.sh` consume them after sourcing.
# shellcheck disable=SC2034
parse_migration_edits() {
  MIGRATION_EDIT_WORLD=""
  MIGRATION_EDIT_CHARACTERS=""
  MIGRATION_EDIT_REALMD=""
  MIGRATION_EDIT_LOGS=""

  local file="/sql/migration-edits"
  if [ ! -f "$file" ]; then
    return 0
  fi

  local raw
  raw="$(head -n1 "$file" | tr -d '\r\n')"
  raw="${raw#"${raw%%[![:space:]]*}"}"
  raw="${raw%"${raw##*[![:space:]]}"}"

  if [ -z "$raw" ]; then
    return 0
  fi

  local pair key value
  local saved_ifs="$IFS"
  IFS='|'
  for pair in $raw; do
    IFS="$saved_ifs"
    key="${pair%%:*}"
    value="${pair#*:}"
    case "$key" in
      world) MIGRATION_EDIT_WORLD="$value" ;;
      characters) MIGRATION_EDIT_CHARACTERS="$value" ;;
      realmd) MIGRATION_EDIT_REALMD="$value" ;;
      logs) MIGRATION_EDIT_LOGS="$value" ;;
    esac
    IFS='|'
  done
  IFS="$saved_ifs"
}

correction_acknowledged() {
  local db_name="$1"
  local commit_hash="$2"
  local count

  count="$(mariadb -u root -p"$MARIADB_ROOT_PASSWORD" "maintenance" -N -s -e \
    "SELECT COUNT(*) FROM \`migration_corrections\` \
    WHERE \`db_name\` = '$(sql_escape "$db_name")' \
    AND \`commit_hash\` = '$(sql_escape "$commit_hash")';")"

  [ "$count" -gt 0 ]
}

acknowledge_correction() {
  local db_name="$1"
  local commit_hash="$2"

  mariadb -u root -p"$MARIADB_ROOT_PASSWORD" "maintenance" -e \
    "INSERT IGNORE INTO \`migration_corrections\` (\`db_name\`, \`commit_hash\`) \
    VALUES ('$(sql_escape "$db_name")', '$(sql_escape "$commit_hash")');"
}

# Stopgap until vmangos/core#2825 moves the `variables` table to the
# `characters` database; until then we capture it across the world database
# re-creation so hardcoded event progress survives.
capture_world_variables() {
  if ! table_exists "mangos" "variables"; then
    return 0
  fi

  # A captured dump from an earlier run means the previous startup did not
  # complete successfully (we remove the file at the end of a successful
  # restore). Bail out here so the user can inspect and recover it before any
  # further capture overwrites it.
  if [ -s /tmp/vmangos-world-variables.sql ]; then
    vmangos_fail "An unconsumed 'variables' dump from a previous run exists at '/tmp/vmangos-world-variables.sql'. Inspect it and remove it manually before restarting."
  fi

  vmangos_log "Capturing world database 'variables' table..."

  mariadb-dump --no-create-info --replace -u root -p"$MARIADB_ROOT_PASSWORD" \
    "mangos" "variables" >/tmp/vmangos-world-variables.sql
}

restore_world_variables() {
  if [ ! -s /tmp/vmangos-world-variables.sql ]; then
    return 0
  fi

  vmangos_log "Restoring world database 'variables' table..."

  mariadb -u root -p"$MARIADB_ROOT_PASSWORD" "mangos" \
    </tmp/vmangos-world-variables.sql
  rm -f /tmp/vmangos-world-variables.sql
}

PENDING_DB_NAMES=()
PENDING_DB_COMMIT_HASHES=()

# Set to 1 by `process_world_correction` after it has re-created the world
# database (including applying migrations on the fresh dump), so `update-db.sh`
# knows it does not need to run `import_updates` again.
# shellcheck disable=SC2034
WORLD_DB_MIGRATIONS_APPLIED=0

process_world_correction() {
  local commit_hash="$1"

  if [ -z "$commit_hash" ]; then
    return 0
  fi

  if correction_acknowledged "world" "$commit_hash"; then
    return 0
  fi

  local enable_auto="${VMANGOS_ENABLE_AUTOMATIC_WORLD_DB_CORRECTIONS:-0}"
  local halt_on_edits="${VMANGOS_HALT_ON_MIGRATION_EDITS:-0}"

  if [ "$enable_auto" = "1" ]; then
    vmangos_log "Re-creating world database to apply migration edit (vmangos/core@${commit_hash:0:7})..."
    capture_world_variables
    drop_database "mangos"
    create_database "mangos"
    grant_permissions "mangos"
    import_dump "mangos" "/sql/world.sql"
    import_updates "mangos" "/sql/migrations/world_db_updates.sql"
    # shellcheck disable=SC2034
    WORLD_DB_MIGRATIONS_APPLIED=1
    restore_world_variables
    acknowledge_correction "world" "$commit_hash"
    return 0
  fi

  if [ "$halt_on_edits" = "1" ]; then
    PENDING_DB_NAMES+=("world")
    PENDING_DB_COMMIT_HASHES+=("$commit_hash")
    return 0
  fi

  # We deliberately do not record an acknowledgement here so the warning
  # repeats on every start until the user takes action.
  vmangos_log "WARNING: Migration edit detected for world database (vmangos/core@${commit_hash:0:7}) but both 'VMANGOS_ENABLE_AUTOMATIC_WORLD_DB_CORRECTIONS' and 'VMANGOS_HALT_ON_MIGRATION_EDITS' are disabled; continuing without applying or acknowledging." >&2
}

process_userstate_correction() {
  local db_name="$1"
  local commit_hash="$2"

  if [ -z "$commit_hash" ]; then
    return 0
  fi

  if correction_acknowledged "$db_name" "$commit_hash"; then
    return 0
  fi

  local halt_on_edits="${VMANGOS_HALT_ON_MIGRATION_EDITS:-0}"

  if [ "$halt_on_edits" = "1" ]; then
    PENDING_DB_NAMES+=("$db_name")
    PENDING_DB_COMMIT_HASHES+=("$commit_hash")
    return 0
  fi

  # We deliberately do not record an acknowledgement here so the warning
  # repeats on every start until the user takes action.
  vmangos_log "WARNING: Migration edit detected for '$db_name' database (vmangos/core@${commit_hash:0:7}) but 'VMANGOS_HALT_ON_MIGRATION_EDITS' is disabled; continuing without acknowledging." >&2
}

print_correction_abort_message() {
  cat >&2 <<'EOF'
[vmangos-deploy]: ERROR: Migration edits detected in VMaNGOS that affect the
following databases. vmangos-deploy will not apply these changes for you
because they could overwrite data you (or your players) generated. Startup is
halted; no databases have been modified.

Affected databases:
EOF

  local i=0
  local name
  local commit_hash
  while [ "$i" -lt "${#PENDING_DB_NAMES[@]}" ]; do
    name="${PENDING_DB_NAMES[$i]}"
    commit_hash="${PENDING_DB_COMMIT_HASHES[$i]}"
    printf '  - %s\n' "$name" >&2
    printf '    https://github.com/vmangos/core/commit/%s\n' "$commit_hash" >&2
    i=$((i + 1))
  done

  cat >&2 <<'EOF'

For each affected database:

  1. Open the GitHub link above to see what changed.
  2. Apply the equivalent SQL to the running database yourself:
       docker compose exec database mariadb -u root -p <database>
     (mariadb will prompt for the password; it matches your
     `MARIADB_ROOT_PASSWORD` setting in `compose.yaml`.)
  3. When you have applied the changes, confirm by running on the host:
       docker compose exec database vmangos-confirm-changes

To abort instead, run on the host:
  docker compose down

While the container is paused, MariaDB is reachable inside the container via
the internal socket. TCP access on port 3306 is not available during the pause.
VMaNGOS stays offline. Nothing restarts on its own; take as long as you need.

Note: When you confirm, vmangos-deploy treats the listed commits as applied and
continues. It does not check your database to verify that the changes you made
match what the commits describe. If your manual fix is incorrect or incomplete,
the database will be in an inconsistent state and VMaNGOS may fail to start.
The responsibility for matching what the commits do is yours; vmangos-deploy
provides no further support for resolving these issues.
EOF
}

wait_for_change_ack() {
  touch /tmp/vmangos-changes-pending

  while [ ! -f /tmp/vmangos-changes-acknowledged ]; do
    sleep 5
  done

  rm -f /tmp/vmangos-changes-pending /tmp/vmangos-changes-acknowledged
}

process_custom_sql() {
  local file_directory="$1"
  local file_count

  if [ ! -d "$file_directory" ]; then
    vmangos_log "WARNING: Custom SQL file directory '$file_directory' does not exist." >&2
    return 0
  fi

  file_count=$(find "$file_directory" -name "*.sql" -type f | wc -l)
  vmangos_log "Found $file_count custom SQL file(s) to process."

  if [ "$file_count" -gt 0 ]; then
    find "$file_directory" -name "*.sql" -type f | sort | while read -r sql_file; do
      vmangos_log "Processing custom SQL file '$(basename "$sql_file")'..."

      if ! import_data "mangos" "$sql_file"; then
        vmangos_log "ERROR: Failed to process custom SQL file '$(basename "$sql_file")'." >&2
      fi
    done
  fi
}
