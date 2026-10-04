#!/usr/bin/env bash

# SPDX-FileCopyrightText: 2023-2026 Michael Serajnik <https://github.com/mserajnik>
# SPDX-License-Identifier: AGPL-3.0-or-later

# Confirms the migration edits the user applied. A halted start then continues.

set -eu

# A restart during a pause leaves the sentinel behind, so also require a
# running `update-db.sh`.
if [[ ! -f /tmp/vmangos-changes-pending ]] ||
  ! pgrep -f '/always-initdb.d/update-db.sh' >/dev/null; then
  echo "[vmangos-deploy]: ERROR: vmangos-deploy is not currently waiting for confirmation." >&2
  exit 1
fi

# `docker compose exec` runs as root, but the start runs as the database user,
# which has to rename the file in sticky `/tmp`. Move the file into place only
# once it has that owner.
acknowledged="$(mktemp /tmp/vmangos-changes-acknowledged.XXXXXX)"
trap 'rm -f "$acknowledged"' EXIT

if ! chown --reference=/tmp/vmangos-changes-pending "$acknowledged"; then
  echo "[vmangos-deploy]: ERROR: Failed to hand the confirmation to the database user. Run this command as root or as the database user." >&2
  exit 1
fi

rm -f /tmp/vmangos-changes-consumed
mv "$acknowledged" /tmp/vmangos-changes-acknowledged

# Wait for the receipt, because a later start also deletes the file.
waited=0
while [[ ! -f /tmp/vmangos-changes-consumed ]] && [[ "$waited" -lt 30 ]]; do
  sleep 1
  waited=$((waited + 1))
done

if [[ ! -f /tmp/vmangos-changes-consumed ]]; then
  rm -f /tmp/vmangos-changes-acknowledged
  echo "[vmangos-deploy]: ERROR: The confirmation was not picked up within 30 seconds. Check the container logs, then run this command again." >&2
  exit 1
fi

echo "[vmangos-deploy]: Confirmation recorded. The start continues."
