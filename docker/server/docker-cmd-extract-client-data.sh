#!/bin/sh

# SPDX-FileCopyrightText: 2023-2026 Michael Serajnik <https://github.com/mserajnik>
# SPDX-License-Identifier: AGPL-3.0-or-later

# Runs the client data extractors. `--force` skips the prompt about existing
# data.

set -eu

# shellcheck source=docker/check-deploy-version.sh
. /usr/local/lib/vmangos-deploy/check-deploy-version.sh
# shellcheck source=docker/server/drop-privileges.sh
. /usr/local/lib/vmangos-deploy/drop-privileges.sh

client_data_dir="/opt/vmangos/storage/client-data"
extracted_data_dir="/opt/vmangos/storage/data"
extractors_dir="/opt/vmangos/bin/Extractors"
client_version_dir="$extracted_data_dir/$VMANGOS_CLIENT_VERSION"

force=false

while [ "$#" -gt 0 ]; do
  case "$1" in
    -f | --force)
      force=true
      shift
      ;;
    *)
      shift
      ;;
  esac
done

if [ ! -d "$client_data_dir" ] || [ ! -d "$client_data_dir/Data" ]; then
  echo "[vmangos-deploy]: ERROR: '$client_data_dir' has no 'Data' directory. Copy the contents of your client directory there." >&2
  exit 1
fi

if [ ! -d "$extracted_data_dir" ]; then
  echo "[vmangos-deploy]: ERROR: The extracted data directory '$extracted_data_dir' does not exist. Mount your extracted data directory there in your 'compose.yaml', as 'compose.yaml.example' shows." >&2
  exit 1
fi

# The extractors write into the working directory.
cd "$client_data_dir"

if [ "$force" = false ]; then
  if [ -d "$extracted_data_dir/maps" ] || [ -d "$extracted_data_dir/mmaps" ] || [ -d "$extracted_data_dir/vmaps" ] || [ -d "$client_version_dir" ]; then
    echo "[vmangos-deploy]: Previously extracted data has been found in '$extracted_data_dir'. Continue with the extraction, which will overwrite the old data? [Y/n]"

    if ! read -r choice; then
      choice="y"
    fi
    choice=$(echo "${choice:-y}" | tr -d '[:space:]')
    if [ "$choice" = "n" ] || [ "$choice" = "N" ]; then
      echo "[vmangos-deploy]: The old data stays in place."
      exit 1
    fi
  fi
fi

# Remove the output of an earlier run.
rm -rf ./Buildings ./Cameras ./dbc ./maps ./mmaps ./vmaps

if ! {
  "$extractors_dir/MapExtractor" --silent &&
    "$extractors_dir/VMapExtractor" --silent &&
    "$extractors_dir/VMapAssembler" --silent &&
    "$extractors_dir/mmap_extract.py" \
      --configInputPath "$extractors_dir/config.json" \
      --offMeshInput "$extractors_dir/offmesh.txt"
}; then
  echo "[vmangos-deploy]: ERROR: The extraction failed. See the errors above." >&2
  exit 1
fi

# Remove what the server does not need.
rm -rf ./Buildings ./Cameras

# Replace only what the extractors produce, so files such as `.gitkeep` stay.
rm -rf \
  "$client_version_dir" \
  "$extracted_data_dir/maps" \
  "$extracted_data_dir/mmaps" \
  "$extracted_data_dir/vmaps"

# `dbc/` moves last. After an interrupted move, the DBC files are missing, and
# the server refuses to start.
mv ./maps ./mmaps ./vmaps "$extracted_data_dir/"
mkdir -p "$client_version_dir"
mv ./dbc "$client_version_dir/"
