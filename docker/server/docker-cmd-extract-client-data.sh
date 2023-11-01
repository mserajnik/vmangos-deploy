#!/bin/sh

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

eval $(fixuid -q)

if [ ! -d "/opt/vmangos/storage/client-data" ]; then
  echo "[vmangos-deploy]: Client data bind mount missing, aborting extraction." >&2
  exit 1
fi

if [ ! -d "/opt/vmangos/storage/extracted-data" ]; then
  echo "[vmangos-deploy]: Extracted data bind mount missing, aborting extraction." >&2
  exit 1
fi

cd /opt/vmangos/storage/client-data

if [ ! -d "./Data" ]; then
  echo "[vmangos-deploy]: Client data missing, aborting extraction." >&2
  exit 1
fi

# Remove potentially existing data
rm -rf ./Buildings
rm -rf ./Cameras
rm -rf ./dbc
rm -rf ./maps
rm -rf ./mmaps
rm -rf ./vmaps

/opt/vmangos/bin/mapextractor
/opt/vmangos/bin/vmapextractor
/opt/vmangos/bin/vmap_assembler
/opt/vmangos/bin/MoveMapGen --configInputPath /opt/vmangos/mmap-config/config.json --offMeshInput /opt/vmangos/mmap-config/offmesh.txt

# This data isn't used; we delete it to avoid confusion
rm -rf ./Buildings
rm -rf ./Cameras

# Remove potentially existing extracted data
rm -rf /opt/vmangos/storage/extracted-data/*

mkdir -p "/opt/vmangos/storage/extracted-data/$VMANGOS_CLIENT_VERSION"
mv ./dbc "/opt/vmangos/storage/extracted-data/$VMANGOS_CLIENT_VERSION/"
mv ./maps /opt/vmangos/storage/extracted-data/
mv ./mmaps /opt/vmangos/storage/extracted-data/
mv ./vmaps /opt/vmangos/storage/extracted-data/
