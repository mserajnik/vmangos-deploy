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
ARG VMANGOS_OWNER=vmangos
ARG VMANGOS_REPOSITORY=core
ARG VMANGOS_REVISION=development
ARG VMANGOS_DB_OWNER=brotalnia
ARG VMANGOS_DB_REPOSITORY=database
ARG VMANGOS_DB_DUMP=world_full_14_june_2021

FROM mariadb:11.4 AS setup

ARG DEBIAN_FRONTEND
ARG VMANGOS_OWNER
ARG VMANGOS_REPOSITORY
ARG VMANGOS_REVISION
ARG VMANGOS_DB_OWNER
ARG VMANGOS_DB_REPOSITORY
ARG VMANGOS_DB_DUMP

RUN \
  apt update -y && \
  apt install -y \
    git \
    p7zip-full && \
  git clone https://github.com/${VMANGOS_OWNER}/${VMANGOS_REPOSITORY}.git /core && \
  cd /core && \
  git checkout ${VMANGOS_REVISION} && \
  git clone https://github.com/${VMANGOS_DB_OWNER}/${VMANGOS_DB_REPOSITORY}.git /database && \
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
  7z e ${VMANGOS_DB_DUMP}.7z && \
  mv ${VMANGOS_DB_DUMP}.sql /sql/world.sql && \
  rm -rf /core /database && \
  apt remove -y \
    git \
    p7zip-full && \
  apt autoremove -y && \
  apt clean -y && \
  rm -rf /var/lib/apt/lists/*

FROM mariadb:11.4

ENV MARIADB_USER=mangos
ENV MARIADB_PASSWORD=mangos
ENV MARIADB_ROOT_PASSWORD=password
ENV VMANGOS_REALMLIST_NAME=VMaNGOS
ENV VMANGOS_REALMLIST_ADDRESS=127.0.0.1
ENV VMANGOS_REALMLIST_PORT=8085
ENV VMANGOS_REALMLIST_ICON=1
ENV VMANGOS_REALMLIST_TIMEZONE=0
ENV VMANGOS_REALMLIST_ALLOWED_SECURITY_LEVEL=0
# See https://github.com/MariaDB/mariadb-docker/blob/64252135052f269ed2bb57134ad73537e93b7ab6/11.4/docker-entrypoint.sh#L594-L598
ENV MARIADB_AUTO_UPGRADE=1

COPY --from=setup /sql /sql

COPY ./docker/database/create-db.sh /docker-entrypoint-initdb.d

RUN mkdir /always-initdb.d
COPY ./docker/database/update-db.sh /always-initdb.d

COPY ./docker/database/docker-entrypoint.sh /entrypoint.sh

RUN \
  chmod +x /docker-entrypoint-initdb.d/create-db.sh && \
  chmod +x /always-initdb.d/update-db.sh && \
  chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
CMD ["mariadbd"]
