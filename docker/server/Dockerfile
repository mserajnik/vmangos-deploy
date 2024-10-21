# vmangos-deploy
# Copyright (C) 2023-2024  Michael Serajnik  https://github.com/mserajnik

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
ARG VMANGOS_CLIENT_VERSION=5875
ARG VMANGOS_USE_ANTICHEAT=0
ARG VMANGOS_OWNER=vmangos
ARG VMANGOS_REPOSITORY=core
ARG VMANGOS_REVISION=development
ARG VMANGOS_USER_ID=1000
ARG VMANGOS_GROUP_ID=1000
ARG VMANGOS_USER_NAME=vmangos
ARG VMANGOS_GROUP_NAME=vmangos

FROM ubuntu:24.04 AS build

ARG DEBIAN_FRONTEND
ARG VMANGOS_CLIENT_VERSION
ARG VMANGOS_USE_ANTICHEAT
ARG VMANGOS_OWNER
ARG VMANGOS_REPOSITORY
ARG VMANGOS_REVISION

RUN \
  apt update -y && \
  apt install -y \
    build-essential \
    cmake \
    git \
    libace-dev \
    libmysqlclient-dev \
    libssl-dev \
    libtbb-dev \
    zlib1g-dev && \
  git clone https://github.com/${VMANGOS_OWNER}/${VMANGOS_REPOSITORY}.git /core && \
  cd /core && \
  git checkout ${VMANGOS_REVISION} && \
  mkdir -p \
    /opt/vmangos/config \
    /opt/vmangos/storage/data \
    /opt/vmangos/storage/honor \
    /opt/vmangos/storage/logs && \
  mkdir /core/build && \
  cd /core/build && \
  cmake \
    -DSUPPORTED_CLIENT_BUILD=${VMANGOS_CLIENT_VERSION} \
    -DUSE_STD_MALLOC=0 \
    -DBUILD_FOR_HOST_CPU=0 \
    -DTBB_DEBUG=0 \
    -DUSE_ANTICHEAT=${VMANGOS_USE_ANTICHEAT} \
    -DUSE_SCRIPTS=1 \
    -DUSE_EXTRACTORS=1 \
    -DUSE_LIBCURL=0 \
    -DDEBUG_SYMBOLS=0 \
    -DCMAKE_INSTALL_PREFIX=/opt/vmangos ../ && \
  make -j$(nproc) && \
  make install && \
  rm -rf /core && \
  apt clean -y && \
  rm -rf /var/lib/apt/lists/*

FROM ubuntu:24.04

ARG DEBIAN_FRONTEND
ARG TARGETARCH
ARG VMANGOS_CLIENT_VERSION
ARG VMANGOS_USER_ID
ARG VMANGOS_GROUP_ID
ARG VMANGOS_USER_NAME
ARG VMANGOS_GROUP_NAME

# Force the Python stdout and stderr streams to be unbuffered so we can see the
# output from the mmap_extract.py script while it is running
ENV PYTHONUNBUFFERED=1
ENV VMANGOS_CLIENT_VERSION=${VMANGOS_CLIENT_VERSION}

RUN \
  apt update -y && \
  apt install -y \
    curl \
    libace-7.1.2 \
    libmysqlclient21 \
    libssl3 \
    libtbb12 \
    netcat-openbsd \
    python3 \
    python-is-python3 \
    zlib1g && \
  # The Ubuntu 24.04 LTS Docker image has a user called `ubuntu` with UID 1000
  # and GID 1000 by default. Since we allow configuration of the name, UID and
  # GID of the user and group that should be used in the container, we need to
  # either rename the existing user and group or create a new user and group
  # with the specified name, UID and GID.
  existing_group=$(getent group ${VMANGOS_GROUP_ID}) || true && \
  existing_user=$(getent passwd ${VMANGOS_USER_ID}) || true && \
  if [ -n "$existing_group" ]; then \
    old_groupname=$(echo "$existing_group" | cut -d: -f1) && \
    groupmod -n ${VMANGOS_GROUP_NAME} "$old_groupname"; \
  else \
    groupadd -g ${VMANGOS_GROUP_ID} ${VMANGOS_GROUP_NAME}; \
  fi && \
  if [ -n "$existing_user" ]; then \
    old_username=$(echo "$existing_user" | cut -d: -f1) && \
    usermod -l ${VMANGOS_USER_NAME} -d "/home/${VMANGOS_USER_NAME}" "$old_username" && \
    mv "/home/${old_username}" "/home/${VMANGOS_USER_NAME}"; \
  else \
    useradd -u ${VMANGOS_USER_ID} -g ${VMANGOS_GROUP_NAME} -d "/home/${VMANGOS_USER_NAME}" -s /bin/sh -m ${VMANGOS_USER_NAME}; \
  fi && \
  # See https://github.com/boxboat/fixuid
  curl -SsL https://github.com/boxboat/fixuid/releases/download/v0.6.0/fixuid-0.6.0-linux-${TARGETARCH}.tar.gz | tar -C /usr/local/bin -xzf - && \
  chown root:root /usr/local/bin/fixuid && \
  chmod 4755 /usr/local/bin/fixuid && \
  mkdir -p /etc/fixuid && \
  printf "user: ${VMANGOS_USER_NAME}\ngroup: ${VMANGOS_GROUP_NAME}\n" > /etc/fixuid/config.yml && \
  apt remove -y curl && \
  apt autoremove -y && \
  apt clean -y && \
  rm -rf /var/lib/apt/lists/*

COPY --from=build --chown=${VMANGOS_USER_NAME}:${VMANGOS_GROUP_NAME} /opt /opt

# See https://github.com/ufoscout/docker-compose-wait
COPY --from=ghcr.io/ufoscout/docker-compose-wait:latest /wait /usr/local/bin/wait-for-db

COPY ./docker/server/docker-cmd-mangosd.sh /usr/local/bin/mangosd
COPY ./docker/server/docker-cmd-realmd.sh /usr/local/bin/realmd
COPY ./docker/server/docker-cmd-extract-client-data.sh /usr/local/bin/extract-client-data

RUN \
  chmod +x /opt/vmangos/bin/* && \
  find /opt/vmangos/bin/Extractors/ -type f ! -regex ".*\.\(json\|txt\)$" -exec chmod +x {} + && \
  chmod +x /usr/local/bin/mangosd && \
  chmod +x /usr/local/bin/realmd && \
  chmod +x /usr/local/bin/extract-client-data

USER ${VMANGOS_USER_NAME}:${VMANGOS_GROUP_NAME}

CMD ["mangosd"]
