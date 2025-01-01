#!/bin/sh

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

eval $(fixuid -q)

config_file="/opt/vmangos/config/realmd.conf"

if [ ! -f "$config_file" ]; then
  echo "[vmangos-deploy]: Configuration file $config_file is missing, exiting" >&2
  exit 1
fi

wait-for-db && exec /opt/vmangos/bin/realmd -c $config_file
