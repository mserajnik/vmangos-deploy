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

ARG DEBIAN_FRONTEND=noninteractive
ARG VMANGOS_WORLD=world_full_14_june_2021
ARG VMANGOS_REVISION=development

FROM mariadb:11 AS setup

ARG DEBIAN_FRONTEND
ARG VMANGOS_WORLD
ARG VMANGOS_REVISION

RUN \
  apt update -y && \
  apt install -y \
    git \
    p7zip-full && \
  git clone https://github.com/vmangos/core.git /core && \
  cd /core && \
  git checkout ${VMANGOS_REVISION} && \
  git clone https://github.com/brotalnia/database.git /database && \
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
  7z e ${VMANGOS_WORLD}.7z && \
  mv ${VMANGOS_WORLD}.sql /sql/world.sql && \
  rm -rf /core /database && \
  apt remove -y \
    git \
    p7zip-full

FROM mariadb:11

COPY --from=setup /sql /sql

COPY ./docker/database/generate-db-1.sql /docker-entrypoint-initdb.d
COPY ./docker/database/generate-db-2.sh /docker-entrypoint-initdb.d
RUN chmod +x /docker-entrypoint-initdb.d/generate-db-2.sh

RUN mkdir /always-initdb.d
COPY ./docker/database/update-db.sh /always-initdb.d
RUN chmod +x /always-initdb.d/update-db.sh

COPY ./docker/database/regenerate-world-db.sql /sql/regenerate-world-db.sql

COPY ./docker/database/docker-entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
CMD ["mariadbd"]
