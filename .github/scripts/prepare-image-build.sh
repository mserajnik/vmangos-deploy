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

set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$script_dir/helpers.sh"

require_env WORKFLOW_MODE
require_env IMAGE_KIND
require_env ARCHITECTURES
require_env OCI_ANNOTATION_AUTHORS
require_env OCI_ANNOTATION_URL
require_env OCI_ANNOTATION_DOCUMENTATION
require_env OCI_ANNOTATION_SOURCE
require_env OCI_ANNOTATION_VENDOR
require_env OCI_ANNOTATION_LICENSES

timestamp="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
architectures="$(trim "$ARCHITECTURES")"

declare -a tags=()
declare -a mode_metadata_entries=()
declare -a label_only_entries=()
declare -a metadata_entries=()
declare -a label_lines=()
declare -a manifest_annotation_lines=()
declare -a index_annotation_lines=()
declare -a build_args=()

build_amd64="false"
build_arm64="false"
is_multi_arch="false"
title=""
description=""
base_name=""
ref_name=""
image_name=""
dockerfile=""

normalize_tag_fragment() {
  local label="$1"
  local value="$2"
  local normalized_value=""

  normalized_value="$(sanitize_docker_tag_fragment "$value")"

  if [[ "$normalized_value" != "$value" ]]; then
    echo "Normalized $label tag fragment '$value' to '$normalized_value'"
  fi

  printf '%s' "$normalized_value"
}

case "$architectures" in
  both|"Both amd64 and arm64")
    build_amd64="true"
    build_arm64="true"
    is_multi_arch="true"
    ;;
  amd64|"amd64 only")
    build_amd64="true"
    ;;
  arm64|"arm64 only")
    build_arm64="true"
    ;;
  *)
    fail "Unsupported architectures value '$architectures'"
    ;;
esac

require_env REGISTRY

case "$IMAGE_KIND" in
  server)
    require_env IMAGE_NAME_SERVER
    image_name="$IMAGE_NAME_SERVER"
    dockerfile="./docker/server/Dockerfile"
    ;;
  database)
    require_env IMAGE_NAME_DATABASE
    image_name="$IMAGE_NAME_DATABASE"
    dockerfile="./docker/database/Dockerfile"
    ;;
  *)
    fail "Unsupported image kind '$IMAGE_KIND'"
    ;;
esac

image="$REGISTRY/$image_name"

case "$WORKFLOW_MODE:$IMAGE_KIND" in
  default:server)
    require_env COMMIT_HASH
    require_env CLIENT_VERSION
    require_env OCI_ANNOTATION_SERVER_TITLE
    require_env OCI_ANNOTATION_SERVER_DESCRIPTION
    require_env OCI_ANNOTATION_SERVER_BASE_NAME

    title="$OCI_ANNOTATION_SERVER_TITLE"
    description="$OCI_ANNOTATION_SERVER_DESCRIPTION"
    base_name="$OCI_ANNOTATION_SERVER_BASE_NAME"
    ref_name="$image:$CLIENT_VERSION-$COMMIT_HASH"

    if [[ "$CLIENT_VERSION" == "5875" ]]; then
      tags+=("$image:latest")
    fi

    tags+=(
      "$image:$CLIENT_VERSION"
      "$image:$CLIENT_VERSION-$COMMIT_HASH"
    )

    build_args+=(
      "VMANGOS_REVISION=$COMMIT_HASH"
      "VMANGOS_CLIENT_VERSION=$CLIENT_VERSION"
      "VMANGOS_PATCHES_REPOSITORY_URL=$VMANGOS_PATCHES_REPOSITORY_URL"
      "VMANGOS_FAIL_ON_PATCH_ERROR=1"
    )

    mode_metadata_entries+=(
      "version=$COMMIT_HASH"
      "revision=$COMMIT_HASH"
    )
    ;;
  default:database)
    require_env COMMIT_HASH
    require_env OCI_ANNOTATION_DATABASE_TITLE
    require_env OCI_ANNOTATION_DATABASE_DESCRIPTION
    require_env OCI_ANNOTATION_DATABASE_BASE_NAME

    title="$OCI_ANNOTATION_DATABASE_TITLE"
    description="$OCI_ANNOTATION_DATABASE_DESCRIPTION"
    base_name="$OCI_ANNOTATION_DATABASE_BASE_NAME"
    ref_name="$image:$COMMIT_HASH"

    tags+=(
      "$image:latest"
      "$image:$COMMIT_HASH"
    )

    build_args+=(
      "VMANGOS_REVISION=$COMMIT_HASH"
      "VMANGOS_PATCHES_REPOSITORY_URL=$VMANGOS_PATCHES_REPOSITORY_URL"
      "VMANGOS_FAIL_ON_PATCH_ERROR=1"
    )

    mode_metadata_entries+=(
      "version=$COMMIT_HASH"
      "revision=$COMMIT_HASH"
    )
    ;;
  custom:server)
    require_env REPOSITORY_OWNER
    require_env REPOSITORY_NAME
    require_env REVISION
    require_env CLIENT_VERSION
    require_env OCI_ANNOTATION_SERVER_TITLE
    require_env OCI_ANNOTATION_SERVER_DESCRIPTION
    require_env OCI_ANNOTATION_SERVER_BASE_NAME

    title="$OCI_ANNOTATION_SERVER_TITLE"
    description="$OCI_ANNOTATION_SERVER_DESCRIPTION"
    base_name="$OCI_ANNOTATION_SERVER_BASE_NAME"

    custom_name="$(trim "${CUSTOM_NAME:-}")"

    if [[ -n "$custom_name" ]]; then
      sanitized_custom_name="$(normalize_tag_fragment "custom" "$custom_name")"
      ref_name="$image:$sanitized_custom_name-$CLIENT_VERSION"
    else
      sanitized_revision="$(normalize_tag_fragment "revision" "$REVISION")"
      ref_name="$image:$REPOSITORY_OWNER-$REPOSITORY_NAME-$sanitized_revision-$CLIENT_VERSION"
    fi

    tags+=("$ref_name")

    build_args+=(
      "VMANGOS_REPOSITORY_URL=${VMANGOS_REPOSITORY_URL:-}"
      "VMANGOS_REVISION=$REVISION"
      "VMANGOS_CLIENT_VERSION=$CLIENT_VERSION"
      "VMANGOS_PATCHES_REPOSITORY_URL=${VMANGOS_PATCHES_REPOSITORY_URL:-}"
    )
    ;;
  custom:database)
    require_env REPOSITORY_OWNER
    require_env REPOSITORY_NAME
    require_env REVISION
    require_env OCI_ANNOTATION_DATABASE_TITLE
    require_env OCI_ANNOTATION_DATABASE_DESCRIPTION
    require_env OCI_ANNOTATION_DATABASE_BASE_NAME

    title="$OCI_ANNOTATION_DATABASE_TITLE"
    description="$OCI_ANNOTATION_DATABASE_DESCRIPTION"
    base_name="$OCI_ANNOTATION_DATABASE_BASE_NAME"

    custom_name="$(trim "${CUSTOM_NAME:-}")"

    if [[ -n "$custom_name" ]]; then
      sanitized_custom_name="$(normalize_tag_fragment "custom" "$custom_name")"
      ref_name="$image:$sanitized_custom_name"
    else
      sanitized_revision="$(normalize_tag_fragment "revision" "$REVISION")"
      ref_name="$image:$REPOSITORY_OWNER-$REPOSITORY_NAME-$sanitized_revision"
    fi

    tags+=("$ref_name")

    build_args+=(
      "VMANGOS_REPOSITORY_URL=${VMANGOS_REPOSITORY_URL:-}"
      "VMANGOS_REVISION=$REVISION"
      "VMANGOS_PATCHES_REPOSITORY_URL=${VMANGOS_PATCHES_REPOSITORY_URL:-}"
      "VMANGOS_WORLD_DB_REPOSITORY_URL=${VMANGOS_WORLD_DB_REPOSITORY_URL:-}"
      "VMANGOS_WORLD_DB_DUMP_NAME=${VMANGOS_WORLD_DB_DUMP_NAME:-}"
    )
    ;;
  *)
    fail "Unsupported workflow/image combination '$WORKFLOW_MODE:$IMAGE_KIND'"
    ;;
esac

if [[ "$WORKFLOW_MODE" == "custom" ]]; then
  # Custom images do not define an OCI version, so clear the inherited base
  # image version label without adding a matching manifest/index annotation.
  label_only_entries+=("version=")
fi

metadata_entries=(
  "created=$timestamp"
  "authors=$OCI_ANNOTATION_AUTHORS"
  "url=$OCI_ANNOTATION_URL"
  "documentation=$OCI_ANNOTATION_DOCUMENTATION"
  "source=$OCI_ANNOTATION_SOURCE"
)

if ((${#mode_metadata_entries[@]} > 0)); then
  metadata_entries+=("${mode_metadata_entries[@]}")
fi

metadata_entries+=(
  "vendor=$OCI_ANNOTATION_VENDOR"
  "licenses=$OCI_ANNOTATION_LICENSES"
  "ref.name=$ref_name"
  "title=$title"
  "description=$description"
  "base.name=$base_name"
)

for entry in "${metadata_entries[@]}"; do
  key="${entry%%=*}"
  value="${entry#*=}"

  label_lines+=("org.opencontainers.image.$key=$value")
  manifest_annotation_lines+=("manifest:org.opencontainers.image.$key=$value")

  if [[ "$is_multi_arch" == "true" ]]; then
    index_annotation_lines+=("index:org.opencontainers.image.$key=$value")
  fi
done

if ((${#label_only_entries[@]} > 0)); then
  for entry in "${label_only_entries[@]}"; do
    key="${entry%%=*}"
    value="${entry#*=}"

    label_lines+=("org.opencontainers.image.$key=$value")
  done
fi

printf -v tags_output '%s,' "${tags[@]}"
tags_output="${tags_output%,}"

printf -v manifest_annotations_output '%s\n' "${manifest_annotation_lines[@]}"
manifest_annotations_output="${manifest_annotations_output%$'\n'}"

if ((${#index_annotation_lines[@]} > 0)); then
  printf -v index_annotations_output '%s\n' "${index_annotation_lines[@]}"
  index_annotations_output="${index_annotations_output%$'\n'}"
else
  index_annotations_output=""
fi

printf -v labels_output '%s\n' "${label_lines[@]}"
labels_output="${labels_output%$'\n'}"

printf -v build_args_output '%s\n' "${build_args[@]}"
build_args_output="${build_args_output%$'\n'}"

write_output image "$image"
write_output package_name "${image_name##*/}"
write_output dockerfile "$dockerfile"
write_output build_amd64 "$build_amd64"
write_output build_arm64 "$build_arm64"
write_output is_multi_arch "$is_multi_arch"
write_output tags "$tags_output"
write_multiline_output build_args "$build_args_output"
write_multiline_output manifest_annotations "$manifest_annotations_output"
write_multiline_output index_annotations "$index_annotations_output"
write_multiline_output labels "$labels_output"
