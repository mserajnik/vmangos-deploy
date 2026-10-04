# shellcheck shell=sh

# SPDX-FileCopyrightText: 2023-2026 Michael Serajnik <https://github.com/mserajnik>
# SPDX-License-Identifier: AGPL-3.0-or-later

# Assigns the UID and GID from `VMANGOS_UID` and `VMANGOS_GID` to the `vmangos`
# user, then runs the sourcing wrapper again as that user.

if [ "$(id -u)" = "0" ]; then
  uid="${VMANGOS_UID:-1000}"
  gid="${VMANGOS_GID:-1000}"

  # `usermod` also changes the owner of the files in the home directory. The
  # bind mounts keep their owner, so the UID and GID have to match it.
  if [ "$(id -g vmangos)" != "$gid" ]; then
    # `-o` accepts a GID that a group in the image already uses, such as `100`.
    groupmod -o -g "$gid" vmangos
  fi
  if [ "$(id -u vmangos)" != "$uid" ]; then
    usermod -u "$uid" vmangos
  fi

  export HOME=/home/vmangos VMANGOS_PRIVILEGES_DROPPED=1
  exec setpriv --reuid="$uid" --regid="$gid" --clear-groups --inh-caps=-all "$0" "$@"
elif [ -z "${VMANGOS_PRIVILEGES_DROPPED:-}" ]; then
  echo "[vmangos-deploy]: ERROR: The container has to start as root. Replace 'user' with 'VMANGOS_UID' and 'VMANGOS_GID' in its service in your 'compose.yaml', as 'compose.yaml.example' shows." >&2
  exit 1
fi
