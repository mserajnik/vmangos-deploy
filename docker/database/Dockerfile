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

ARG DEBIAN_FRONTEND=noninteractive
ARG VMANGOS_REPOSITORY_URL=https://github.com/vmangos/core.git
ARG VMANGOS_REVISION=development
ARG VMANGOS_PATCHES_REPOSITORY_URL
ARG VMANGOS_WORLD_DB_REPOSITORY_URL=https://github.com/brotalnia/database.git
ARG VMANGOS_WORLD_DB_DUMP_NAME=world_full_14_june_2021
ARG VMANGOS_WORLD_DB_DUMP_NEW_FILE=/sql/world-new.sql

FROM mariadb:11.8 AS setup

ARG DEBIAN_FRONTEND
ARG VMANGOS_REPOSITORY_URL
ARG VMANGOS_REVISION
ARG VMANGOS_PATCHES_REPOSITORY_URL
ARG VMANGOS_WORLD_DB_REPOSITORY_URL
ARG VMANGOS_WORLD_DB_DUMP_NAME

RUN \
  apt update -y && \
  apt install -y --no-install-recommends \
    git \
    p7zip-full && \
  git clone "${VMANGOS_REPOSITORY_URL}" /core && \
  cd /core && \
  git checkout "${VMANGOS_REVISION}" && \
  if [ -n "${VMANGOS_PATCHES_REPOSITORY_URL}" ]; then \
    echo "Cloning and applying patches from ${VMANGOS_PATCHES_REPOSITORY_URL}"; \
    git clone "${VMANGOS_PATCHES_REPOSITORY_URL}" /tmp/patches && \
    patch_count=0 && \
    for patch in /tmp/patches/*.patch; do \
      if [ -f "${patch}" ]; then \
        echo "Applying patch ${patch}"; \
        git apply "${patch}"; \
        patch_count=$((patch_count + 1)); \
      fi; \
    done; \
    if [ ${patch_count} -eq 0 ]; then \
      echo "No patches found"; \
    fi; \
    rm -rf /tmp/patches; \
  else \
    echo "No repository to apply patches from provided"; \
  fi && \
  git clone "${VMANGOS_WORLD_DB_REPOSITORY_URL}" /database && \
  mkdir -p /sql/custom && \
  mkdir -p /sql/migrations && \
  cd /core/sql && \
  mv characters.sql /sql && \
  mv logon.sql /sql && \
  mv logs.sql /sql && \
  cd /core/sql/migrations && \
  chmod +x merge.sh && \
  ./merge.sh && \
  mv characters_db_updates.sql /sql/migrations && \
  mv logon_db_updates.sql /sql/migrations && \
  mv logs_db_updates.sql /sql/migrations && \
  mv world_db_updates.sql /sql/migrations && \
  cd /database && \
  7z e ${VMANGOS_WORLD_DB_DUMP_NAME}.7z && \
  mv ${VMANGOS_WORLD_DB_DUMP_NAME}.sql /sql/world.sql

FROM mariadb:11.8

ARG VMANGOS_WORLD_DB_DUMP_NEW_FILE

# See https://github.com/MariaDB/mariadb-docker/blob/a3c37fa8970080971ffc1b6a2aa7d02b97d6b00e/11.8/docker-entrypoint.sh#L594-L598
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
ENV VMANGOS_WORLD_DB_DUMP_NEW_FILE=${VMANGOS_WORLD_DB_DUMP_NEW_FILE}
ENV VMANGOS_ENABLE_AUTOMATIC_WORLD_DB_CORRECTIONS=1
ENV VMANGOS_PROCESS_CUSTOM_SQL=1

COPY --from=setup /sql /sql

RUN \
  mkdir -p /opt/scripts && \
  mkdir /always-initdb.d

COPY ./docker/database/db-functions.sh /opt/scripts
COPY --chmod=755 ./docker/database/create-db.sh /docker-entrypoint-initdb.d
COPY --chmod=755 ./docker/database/update-db.sh /always-initdb.d

COPY --chmod=755 ./docker/database/docker-entrypoint.sh /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
CMD ["mariadbd"]
