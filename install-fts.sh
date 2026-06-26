#!/usr/bin/env bash
# Install SQL Server full-text search (mssql-server-fts) for this engine.
#
# The package lives in the *version-specific* mssql-server product repo
# (NOT the generic packages.microsoft.com/.../prod repo), and it pulls the
# mssql-server deb at the matching version. Used in BOTH the builder stage
# (so the full-text catalog/index can be created at build time) and the final
# stage (so the restored index can be queried at runtime).
#
# Usage: install-fts.sh <mssql-year>   e.g. install-fts.sh 2019
set -euo pipefail

YEAR="${1:?usage: install-fts.sh <mssql-year, e.g. 2019>}"
UBUNTU_VER="$(. /etc/os-release && echo "$VERSION_ID")"
UBUNTU_CODENAME="$(. /etc/os-release && echo "$VERSION_CODENAME")"

echo "Installing mssql-server-fts (mssql ${YEAR}, ubuntu ${UBUNTU_VER}/${UBUNTU_CODENAME})"
echo "deb [arch=amd64] https://packages.microsoft.com/ubuntu/${UBUNTU_VER}/mssql-server-${YEAR} ${UBUNTU_CODENAME} main" \
  > "/etc/apt/sources.list.d/mssql-server-${YEAR}.list"

apt-get update
ACCEPT_EULA=Y apt-get install -y --no-install-recommends mssql-server-fts
rm -rf /var/lib/apt/lists/*
