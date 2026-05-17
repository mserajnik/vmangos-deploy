#!/usr/bin/env bash

# SPDX-FileCopyrightText: 2023-2026 Michael Serajnik <https://github.com/mserajnik>
# SPDX-License-Identifier: AGPL-3.0-or-later

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
