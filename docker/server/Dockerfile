# SPDX-FileCopyrightText: 2023-2026 Michael Serajnik <https://github.com/mserajnik>
# SPDX-License-Identifier: AGPL-3.0-or-later

ARG DEBIAN_FRONTEND=noninteractive
ARG VMANGOS_REPOSITORY_URL=https://github.com/vmangos/core.git
ARG VMANGOS_REVISION=development
ARG VMANGOS_CLIENT_VERSION=5875
ARG VMANGOS_PATCHES_REPOSITORY_URL
ARG VMANGOS_FAIL_ON_PATCH_ERROR=0
ARG VMANGOS_USER_ID=1000
ARG VMANGOS_GROUP_ID=1000
ARG VMANGOS_USER_NAME=vmangos
ARG VMANGOS_GROUP_NAME=vmangos

FROM ubuntu:26.04 AS build

ARG DEBIAN_FRONTEND
ARG VMANGOS_REPOSITORY_URL
ARG VMANGOS_REVISION
ARG VMANGOS_CLIENT_VERSION
ARG VMANGOS_PATCHES_REPOSITORY_URL
ARG VMANGOS_FAIL_ON_PATCH_ERROR

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
  mkdir -p \
    /opt/vmangos/config \
    /opt/vmangos/storage/data \
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

ARG TARGETARCH
ARG DEBIAN_FRONTEND
ARG VMANGOS_CLIENT_VERSION
ARG VMANGOS_USER_ID
ARG VMANGOS_GROUP_ID
ARG VMANGOS_USER_NAME
ARG VMANGOS_GROUP_NAME

# Force the Python stdout and stderr streams to be unbuffered so we can see the
# output from the `mmap_extract.py` script while it is running.
ENV PYTHONUNBUFFERED=1
ENV VMANGOS_CLIENT_VERSION=$VMANGOS_CLIENT_VERSION

RUN \
  apt update && \
  apt install -y --no-install-recommends \
    ca-certificates \
    curl \
    libcurl4t64 \
    libmysqlclient24 \
    libssl3t64 \
    netcat-openbsd \
    python-is-python3 \
    python3 \
    zlib1g && \
  # The Ubuntu 26.04 LTS Docker image has a user called `ubuntu` with UID 1000
  # and GID 1000 by default. Since we allow configuration of the name, UID and
  # GID of the user and group that should be used in the container, we need to
  # either rename the existing user and group or create a new user and group
  # with the specified name, UID and GID.
  cd /tmp && \
  existing_group=$(getent group "$VMANGOS_GROUP_ID") || true && \
  existing_user=$(getent passwd "$VMANGOS_USER_ID") || true && \
  if [ -n "$existing_group" ]; then \
    old_groupname=${existing_group%%:*} && \
    groupmod -n "$VMANGOS_GROUP_NAME" "$old_groupname"; \
  else \
    groupadd -g "$VMANGOS_GROUP_ID" "$VMANGOS_GROUP_NAME"; \
  fi && \
  if [ -n "$existing_user" ]; then \
    old_username=${existing_user%%:*} && \
    usermod -l "$VMANGOS_USER_NAME" -d "/home/$VMANGOS_USER_NAME" "$old_username" && \
    mv "/home/$old_username" "/home/$VMANGOS_USER_NAME"; \
  else \
    useradd -l -u "$VMANGOS_USER_ID" -g "$VMANGOS_GROUP_NAME" -d "/home/$VMANGOS_USER_NAME" -s /bin/sh -m "$VMANGOS_USER_NAME"; \
  fi && \
  # See https://github.com/boxboat/fixuid
  curl -SsL "https://github.com/boxboat/fixuid/releases/download/v0.6.0/fixuid-0.6.0-linux-$TARGETARCH.tar.gz" -o /tmp/fixuid.tar.gz && \
  tar -C /usr/local/bin -xzf /tmp/fixuid.tar.gz && \
  rm /tmp/fixuid.tar.gz && \
  chown root:root /usr/local/bin/fixuid && \
  chmod 4755 /usr/local/bin/fixuid && \
  mkdir -p /etc/fixuid && \
  printf 'user: %s\ngroup: %s\n' "$VMANGOS_USER_NAME" "$VMANGOS_GROUP_NAME" > /etc/fixuid/config.yml && \
  apt remove -y \
    curl && \
  apt autoremove -y && \
  apt clean -y && \
  rm -rf /var/lib/apt/lists/*

# The `etc` directory is not needed at runtime since we provide the
# configuration files via a bind mount.
COPY --from=build --exclude=vmangos/etc* --chown=$VMANGOS_USER_NAME:$VMANGOS_GROUP_NAME /opt /opt

COPY --chmod=755 ./docker/server/docker-cmd-mangosd.sh /usr/local/bin/mangosd
COPY --chmod=755 ./docker/server/docker-cmd-realmd.sh /usr/local/bin/realmd
COPY --chmod=755 ./docker/server/docker-cmd-extract-client-data.sh /usr/local/bin/extract-client-data

RUN \
  chmod +x /opt/vmangos/bin/* && \
  find /opt/vmangos/bin/Extractors/ -type f ! -regex '.*\.\(json\|txt\)$' -exec chmod +x {} +

USER $VMANGOS_USER_NAME
WORKDIR "/home/$VMANGOS_USER_NAME"
CMD ["mangosd"]
