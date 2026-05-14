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

# Assembles the final multi-arch image index from the separately built `amd64`
# and `arm64` manifests and pushes it to GHCR under each requested tag.

set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source-path=SCRIPTDIR
source "$script_dir/helpers.sh"

require_env IMAGE
require_env TAGS
require_env DIGEST_AMD64
require_env DIGEST_ARM64

# shellcheck disable=SC2153
image="$(trim "$IMAGE")"
# shellcheck disable=SC2153
tags_csv="$(trim "$TAGS")"
# shellcheck disable=SC2153
digest_amd64="$(trim "$DIGEST_AMD64")"
# shellcheck disable=SC2153
digest_arm64="$(trim "$DIGEST_ARM64")"

declare -a command=()
declare -a tags=()
declare -a index_annotations=()

IFS=',' read -r -a tags <<<"$tags_csv"

while IFS= read -r line; do
  if [[ -n "$line" ]]; then
    index_annotations+=("$line")
  fi
done <<<"${INDEX_ANNOTATIONS:-}"

command=(docker buildx imagetools create)

for tag in "${tags[@]}"; do
  command+=(--tag "$tag")
done

for annotation in "${index_annotations[@]}"; do
  command+=(--annotation "$annotation")
done

command+=(
  "$image@$digest_amd64"
  "$image@$digest_arm64"
)

printf 'Creating multi-platform image index for %s...\n' "$image"
"${command[@]}"
