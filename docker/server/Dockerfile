# SPDX-FileCopyrightText: 2023-2026 Michael Serajnik <https://github.com/mserajnik>
# SPDX-License-Identifier: AGPL-3.0-or-later

ARG DEBIAN_FRONTEND=noninteractive
ARG VMANGOS_REPOSITORY_URL=https://github.com/vmangos/core.git
ARG VMANGOS_REVISION=development
ARG VMANGOS_CLIENT_VERSION=5875
ARG VMANGOS_FAIL_ON_PATCH_ERROR=0

FROM ubuntu:26.04 AS build

ARG DEBIAN_FRONTEND
ARG VMANGOS_REPOSITORY_URL
ARG VMANGOS_REVISION
ARG VMANGOS_CLIENT_VERSION
ARG VMANGOS_FAIL_ON_PATCH_ERROR

COPY ./docker/patches /build/patches

RUN \
  apt update && \
  apt install -y --no-install-recommends \
    build-essential \
    ca-certificates \
    cmake \
    git \
    libcurl4-openssl-dev \
    libmysqlclient-dev \
    libssl-dev \
    zlib1g-dev && \
  git clone "$VMANGOS_REPOSITORY_URL" /build/core && \
  cd /build/core && \
  git checkout "$VMANGOS_REVISION" && \
  patch_count=0 && \
  for patch in /build/patches/*.patch; do \
    if [ -f "$patch" ]; then \
      echo "Applying patch '$patch'."; \
      if ! git apply "$patch"; then \
        echo "Failed to apply patch '$patch'."; \
        if [ "$VMANGOS_FAIL_ON_PATCH_ERROR" = "1" ]; then \
          exit 1; \
        fi; \
      fi; \
      patch_count=$((patch_count + 1)); \
    fi; \
  done && \
  if [ "$patch_count" -eq 0 ]; then \
    echo "No patches found."; \
  fi && \
  mkdir -p \
    /opt/vmangos/config \
    /opt/vmangos/storage/honor \
    /opt/vmangos/storage/logs && \
  mkdir /build/core/build && \
  cd /build/core/build && \
  cmake \
    -DCMAKE_INSTALL_PREFIX=/opt/vmangos ../ \
    -DCMAKE_INTERPROCEDURAL_OPTIMIZATION=ON \
    -DBUILD_FOR_HOST_CPU=0 \
    -DBUILD_EXTRACTORS=1 \
    -DENABLE_MAILSENDER=1 \
    -DENABLE_CPPTRACE=0 \
    -DSUPPORTED_CLIENT_BUILD="$VMANGOS_CLIENT_VERSION" \
    -DDEBUG_SYMBOLS=0 && \
  make -j"$(nproc)" && \
  make install

FROM ubuntu:26.04

ARG DEBIAN_FRONTEND
ARG VMANGOS_CLIENT_VERSION

# Show the output of `mmap_extract.py` while it runs.
ENV PYTHONUNBUFFERED=1
ENV VMANGOS_CLIENT_VERSION=$VMANGOS_CLIENT_VERSION

RUN \
  apt update && \
  apt install -y --no-install-recommends \
    ca-certificates \
    libcurl4t64 \
    libmysqlclient24 \
    libssl3t64 \
    netcat-openbsd \
    python-is-python3 \
    python3 \
    tzdata \
    zlib1g && \
  # The image's `ubuntu` user already has UID and GID 1000.
  groupmod -n vmangos ubuntu && \
  usermod -l vmangos -d /home/vmangos -m ubuntu && \
  apt autoremove -y && \
  apt clean -y && \
  rm -rf /var/lib/apt/lists/*

# The configuration files come from a bind mount.
COPY --from=build --exclude=vmangos/etc* --chown=vmangos:vmangos /opt /opt

COPY ./docker/check-deploy-version.sh /usr/local/lib/vmangos-deploy/check-deploy-version.sh
COPY ./docker/server/drop-privileges.sh /usr/local/lib/vmangos-deploy/drop-privileges.sh
COPY --chmod=755 ./docker/server/docker-cmd-mangosd.sh /usr/local/bin/mangosd
COPY --chmod=755 ./docker/server/docker-cmd-realmd.sh /usr/local/bin/realmd
COPY --chmod=755 ./docker/server/docker-cmd-extract-client-data.sh /usr/local/bin/extract-client-data
COPY --chmod=755 ./docker/server/docker-cmd-check-deploy-version.sh /usr/local/bin/check-deploy-version
# Ubuntu keeps package license information under `/usr/share/doc`.
COPY ./docker/docker-notice.txt /usr/share/doc/vmangos-deploy/NOTICE

# Upstream installs `mmap_extract.py` without the executable bit.
RUN chmod +x /opt/vmangos/bin/Extractors/mmap_extract.py

WORKDIR /home/vmangos
CMD ["mangosd"]
