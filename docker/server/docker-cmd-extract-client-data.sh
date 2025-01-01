#!/bin/sh

# vmangos-deploy
# Copyright (C) 2023-2025  Michael Serajnik  https://github.com/mserajnik

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

client_data_dir="/opt/vmangos/storage/client-data"
extracted_data_dir="/opt/vmangos/storage/extracted-data"
extractors_dir="/opt/vmangos/bin/Extractors"
client_version_dir="$extracted_data_dir/$VMANGOS_CLIENT_VERSION"

if [ ! -d "$client_data_dir" ]; then
  echo "[vmangos-deploy]: Client data bind mount is missing, aborting extraction" >&2
  exit 1
fi

if [ ! -d "$extracted_data_dir" ]; then
  echo "[vmangos-deploy]: Extracted data bind mount is missing, aborting extraction" >&2
  exit 1
fi

cd "$client_data_dir"

if [ ! -d "./Data" ]; then
  echo "[vmangos-deploy]: Client data is missing, aborting extraction" >&2
  exit 1
fi

# Remove potentially existing data
rm -rf ./Buildings ./Cameras ./dbc ./maps ./mmaps ./vmaps

"$extractors_dir/MapExtractor"
"$extractors_dir/VMapExtractor"
"$extractors_dir/VMapAssembler"
"$extractors_dir/mmap_extract.py" \
  --configInputPath "$extractors_dir/config.json" \
  --offMeshInput "$extractors_dir/offmesh.txt"

# This data isn't used; we delete it to avoid confusion
rm -rf ./Buildings ./Cameras

# Remove potentially existing extracted data
rm -rf "$extracted_data_dir/*"

mkdir -p "$client_version_dir"
mv ./dbc "$client_version_dir/"
mv ./maps ./mmaps ./vmaps "$extracted_data_dir/"
