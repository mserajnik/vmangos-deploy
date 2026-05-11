#!/usr/bin/env bash

# vmangos-deploy
# Copyright (C) 2023-2026  Michael Serajnik  https://github.com/mserajnik

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

# Confirms manually applied migration edits so `update-db.sh` can continue.
# Refuses to run unless the pending sentinel exists, so accidental
# invocations during normal operation are no-ops.

set -eu

if [ ! -f /tmp/vmangos-changes-pending ]; then
  echo "[vmangos-deploy]: ERROR: vmangos-deploy is not currently waiting for confirmation. Nothing to do." >&2
  exit 1
fi

touch /tmp/vmangos-changes-acknowledged

# `docker compose exec` defaults to root, but the bootstrap runs as the
# database user and removes both sentinels when it sees the ack. Match
# ownership to the pending sentinel so the bootstrap can remove the ack
# file from sticky `/tmp`.
chown --reference=/tmp/vmangos-changes-pending /tmp/vmangos-changes-acknowledged

echo "[vmangos-deploy]: Confirmation recorded; startup will continue."
