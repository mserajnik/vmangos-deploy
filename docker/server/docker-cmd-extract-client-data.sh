#!/bin/sh

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

eval $(fixuid -q)

client_data_dir="/opt/vmangos/storage/client-data"
extracted_data_dir="/opt/vmangos/storage/extracted-data"
extractors_dir="/opt/vmangos/bin/Extractors"
client_version_dir="$extracted_data_dir/$VMANGOS_CLIENT_VERSION"

# The `--force` flag can be used to skip the confirmation prompt when
# previously extracted data is found. This is particularly useful for
# automation where the user is not able to interact with the prompt.
force=false

while [ "$#" -gt 0 ]; do
  case "$1" in
    -f|--force)
      # If user passes `-f` or `--force`, set 'force' to true
      force=true
      shift
      ;;
    *)
      shift
      ;;
  esac
done

if [ ! -d "$client_data_dir" ] || [ ! -d "$client_data_dir/Data" ]; then
  echo "[vmangos-deploy]: ERROR: Client data not found in '$client_data_dir', aborting extraction" >&2
  exit 1
fi

if [ ! -d "$extracted_data_dir" ]; then
  echo "[vmangos-deploy]: ERROR: Extracted data target directory '$extracted_data_dir' doesn't exist, aborting extraction" >&2
  exit 1
fi

cd "$client_data_dir"

if [ "$force" = false ]; then
  if [ -d "$extracted_data_dir/maps" ] || [ -d "$extracted_data_dir/mmaps" ] || [ -d "$extracted_data_dir/vmaps" ] || [ -d "$client_version_dir" ]; then
    echo "[vmangos-deploy]: Previously extracted data has been found in '$extracted_data_dir'; continue with the extraction (which will overwrite the old data)? [Y/n]"

    read -r choice
    choice=$(echo "${choice:-y}" | tr -d '[:space:]')
    if [ "$choice" = "n" ] || [ "$choice" = "N" ]; then
      echo "[vmangos-deploy]: Aborting extraction"
      exit 1
    fi
  fi
fi

# Remove any potentially previously extracted data from the client directory
rm -rf ./Buildings ./Cameras ./dbc ./maps ./mmaps ./vmaps

"$extractors_dir/MapExtractor"
"$extractors_dir/VMapExtractor"
"$extractors_dir/VMapAssembler"
"$extractors_dir/mmap_extract.py" \
  --configInputPath "$extractors_dir/config.json" \
  --offMeshInput "$extractors_dir/offmesh.txt"

# Delete extracted data that is no longer needed after processing it to avoid
# confusion
rm -rf ./Buildings ./Cameras

# Remove any potentially already existing data from the extracted data
# directory before moving the new data there
rm -rf "$extracted_data_dir"/*

mkdir -p "$client_version_dir"
mv ./dbc "$client_version_dir/"
mv ./maps ./mmaps ./vmaps "$extracted_data_dir/"
