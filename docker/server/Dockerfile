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
ARG VMANGOS_CLIENT_VERSION=5875
ARG VMANGOS_USE_ANTICHEAT=0
ARG VMANGOS_REVISION=development
ARG VMANGOS_USER_ID=1000
ARG VMANGOS_GROUP_ID=1000

FROM ubuntu:22.04 AS build

ARG DEBIAN_FRONTEND
ARG VMANGOS_CLIENT_VERSION
ARG VMANGOS_USE_ANTICHEAT
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
    openssl \
    zlib1g-dev

RUN \
  git clone https://github.com/vmangos/core.git /core && \
  cd /core && \
  git checkout ${VMANGOS_REVISION} && \
  mkdir -p \
    /opt/vmangos/config \
    /opt/vmangos/mmap-config \
    /opt/vmangos/storage && \
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
    -DCMAKE_INSTALL_PREFIX=/opt/vmangos ../ && \
  make -j$(nproc) && \
  make install && \
  mv /core/contrib/mmap/config.json /opt/vmangos/mmap-config && \
  mv /core/contrib/mmap/offmesh.txt /opt/vmangos/mmap-config && \
  rm -rf /core

FROM ubuntu:22.04

ARG DEBIAN_FRONTEND
ARG TARGETARCH
ARG VMANGOS_CLIENT_VERSION
ARG VMANGOS_REVISION
ARG VMANGOS_USER_ID
ARG VMANGOS_GROUP_ID

ENV VMANGOS_CLIENT_VERSION=${VMANGOS_CLIENT_VERSION}

# See https://github.com/boxboat/fixuid
RUN \
  apt update -y && \
  apt install -y curl && \
  addgroup --gid ${VMANGOS_GROUP_ID} docker && \
  adduser --uid ${VMANGOS_USER_ID} --ingroup docker --home /home/docker --shell /bin/sh --disabled-password --gecos "" docker && \
  USER=docker && \
  GROUP=docker && \
  curl -SsL https://github.com/boxboat/fixuid/releases/download/v0.6.0/fixuid-0.6.0-linux-${TARGETARCH}.tar.gz | tar -C /usr/local/bin -xzf - && \
  chown root:root /usr/local/bin/fixuid && \
  chmod 4755 /usr/local/bin/fixuid && \
  mkdir -p /etc/fixuid && \
  printf "user: ${USER}\ngroup: ${GROUP}\n" > /etc/fixuid/config.yml && \
  apt remove -y curl

COPY --from=build --chown=docker:docker /opt /opt
RUN chmod +x /opt/vmangos/bin/*

RUN \
  apt update -y && \
  apt install -y \
    libace-dev \
    libmysqlclient-dev \
    libssl-dev \
    libtbb-dev \
    openssl \
    zlib1g-dev

# See https://github.com/ufoscout/docker-compose-wait
COPY --from=ghcr.io/ufoscout/docker-compose-wait:latest /wait /usr/local/bin/wait-for-db

COPY ./docker/server/docker-cmd-mangosd.sh /usr/local/bin/mangosd
COPY ./docker/server/docker-cmd-realmd.sh /usr/local/bin/realmd
COPY ./docker/server/docker-cmd-extract-client-data.sh /usr/local/bin/extract-client-data
RUN \
  chmod +x /usr/local/bin/mangosd && \
  chmod +x /usr/local/bin/realmd && \
  chmod +x /usr/local/bin/extract-client-data

USER docker:docker

CMD ["mangosd"]
