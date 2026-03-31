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

if [[ -z "${BADGES_FTP_HOST:-}" || -z "${BADGES_FTP_USERNAME:-}" || -z "${BADGES_FTP_PASSWORD:-}" ]]; then
  echo "Badge FTP secrets are missing, skipping upload"
  exit 0
fi

require_env COMMIT_HASH

short_hash="${COMMIT_HASH:0:7}"
timestamp="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

cat > commit-badge.json <<EOF
{
  "schemaVersion": 1,
  "label": "Latest built VMaNGOS commit",
  "message": "$short_hash",
  "color": "blue"
}
EOF

cat > date-badge.json <<EOF
{
  "schemaVersion": 1,
  "label": "Latest build date",
  "message": "$timestamp",
  "color": "orange"
}
EOF

curl --fail --silent --show-error \
  -T "{commit-badge.json,date-badge.json}" \
  --user "$BADGES_FTP_USERNAME:$BADGES_FTP_PASSWORD" \
  "ftp://$BADGES_FTP_HOST/"
