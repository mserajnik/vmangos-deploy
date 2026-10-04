#!/bin/sh

# SPDX-FileCopyrightText: 2023-2026 Michael Serajnik <https://github.com/mserajnik>
# SPDX-License-Identifier: AGPL-3.0-or-later

# Checks only the deploy version, so an update can test the new images before
# it re-creates any container.

set -eu

# shellcheck source=docker/check-deploy-version.sh
. /usr/local/lib/vmangos-deploy/check-deploy-version.sh

echo "[vmangos-deploy]: This image expects 'VMANGOS_DEPLOY_VERSION=$expected_deploy_version', and the variable matches."
