# SPDX-FileCopyrightText: 2023-2026 Michael Serajnik <https://github.com/mserajnik>
# SPDX-License-Identifier: AGPL-3.0-or-later

ARG DEBIAN_FRONTEND=noninteractive
ARG VMANGOS_REPOSITORY_URL=https://github.com/vmangos/core.git
ARG VMANGOS_REVISION=development
ARG VMANGOS_PATCHES_REPOSITORY_URL
ARG VMANGOS_FAIL_ON_PATCH_ERROR=0
ARG VMANGOS_WORLD_DB_REPOSITORY_URL=https://github.com/brotalnia/database.git
ARG VMANGOS_WORLD_DB_DUMP_NAME=world_full_14_june_2021
ARG VMANGOS_MIGRATION_EDITS=

FROM mariadb:11.8 AS build

ARG DEBIAN_FRONTEND
ARG VMANGOS_REPOSITORY_URL
ARG VMANGOS_REVISION
ARG VMANGOS_PATCHES_REPOSITORY_URL
ARG VMANGOS_FAIL_ON_PATCH_ERROR
ARG VMANGOS_WORLD_DB_REPOSITORY_URL
ARG VMANGOS_WORLD_DB_DUMP_NAME

RUN \
  apt update && \
  apt install -y --no-install-recommends \
    git \
    p7zip-full && \
  git clone "$VMANGOS_REPOSITORY_URL" /build/core && \
  cd /build/core && \
  git checkout "$VMANGOS_REVISION" && \
  if [ -n "$VMANGOS_PATCHES_REPOSITORY_URL" ]; then \
    echo "Cloning and applying patches from $VMANGOS_PATCHES_REPOSITORY_URL"; \
    git clone "$VMANGOS_PATCHES_REPOSITORY_URL" /build/patches && \
    patch_count=0 && \
    for patch in /build/patches/*.patch; do \
      if [ -f "$patch" ]; then \
        echo "Applying patch $patch"; \
        if ! git apply "$patch"; then \
          echo "Failed to apply patch $patch"; \
          if [ "$VMANGOS_FAIL_ON_PATCH_ERROR" = "1" ]; then \
            exit 1; \
          fi; \
        fi; \
        patch_count=$((patch_count + 1)); \
      fi; \
    done; \
    if [ "$patch_count" -eq 0 ]; then \
      echo "No patches found"; \
    fi; \
  else \
    echo "No repository to apply patches from provided"; \
  fi && \
  mkdir -p /sql/custom && \
  mkdir -p /sql/migrations && \
  cd /build/core/sql && \
  mv characters.sql /sql && \
  mv logon.sql /sql && \
  mv logs.sql /sql && \
  cd /build/core/sql/migrations && \
  chmod +x merge.sh && \
  ./merge.sh && \
  mv characters_db_updates.sql /sql/migrations && \
  mv logon_db_updates.sql /sql/migrations && \
  mv logs_db_updates.sql /sql/migrations && \
  mv world_db_updates.sql /sql/migrations && \
  git clone "$VMANGOS_WORLD_DB_REPOSITORY_URL" /build/database && \
  cd /build/database && \
  7z e "$VMANGOS_WORLD_DB_DUMP_NAME.7z" && \
  mv "$VMANGOS_WORLD_DB_DUMP_NAME.sql" /sql/world.sql

FROM mariadb:11.8

ARG VMANGOS_MIGRATION_EDITS

# See https://github.com/MariaDB/mariadb-docker/blob/1b6429ba3544e134715c15f8c56cc6f665f827c9/11.8/docker-entrypoint.sh#L595-L599
ENV MARIADB_AUTO_UPGRADE=1
ENV MARIADB_USER=mangos
ENV MARIADB_PASSWORD=mangos
ENV MARIADB_ROOT_PASSWORD=password
ENV VMANGOS_REALMLIST_NAME=VMaNGOS
ENV VMANGOS_REALMLIST_ADDRESS=127.0.0.1
ENV VMANGOS_REALMLIST_PORT=8085
ENV VMANGOS_REALMLIST_ICON=1
ENV VMANGOS_REALMLIST_TIMEZONE=0
ENV VMANGOS_REALMLIST_ALLOWED_SECURITY_LEVEL=0
ENV VMANGOS_ENABLE_AUTOMATIC_WORLD_DB_CORRECTIONS=1
ENV VMANGOS_HALT_ON_MIGRATION_EDITS=1
ENV VMANGOS_PROCESS_CUSTOM_SQL=1

COPY --from=build /sql /sql

RUN \
  mkdir -p /opt/scripts && \
  mkdir /always-initdb.d && \
  printf '%s\n' "$VMANGOS_MIGRATION_EDITS" >/sql/migration-edits

COPY ./docker/database/db-functions.sh /opt/scripts
COPY --chmod=755 ./docker/database/create-db.sh /docker-entrypoint-initdb.d
COPY --chmod=755 ./docker/database/update-db.sh /always-initdb.d
COPY --chmod=755 ./docker/database/healthcheck.sh /usr/local/bin/vmangos-healthcheck
COPY --chmod=755 ./docker/database/vmangos-confirm-changes.sh /usr/local/bin/vmangos-confirm-changes

COPY --chmod=755 ./docker/database/docker-entrypoint.sh /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
CMD ["mariadbd"]
