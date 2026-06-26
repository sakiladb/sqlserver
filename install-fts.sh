#!/usr/bin/env bash
# Install SQL Server full-text search (mssql-server-fts) for this engine.
#
# The package lives in the *version-specific* mssql-server product repo
# (NOT the generic packages.microsoft.com/.../prod repo). Used in BOTH the
# builder stage (so the full-text catalog/index can be created at build time)
# and the final stage (so the restored index can be queried at runtime).
#
# mssql-server-fts depends on the mssql-server deb, but the SQL Server binaries
# are already baked into the base image (not dpkg-managed). A plain
# `apt-get install mssql-server-fts` would therefore re-download and unpack the
# whole ~1.9 GB mssql-server deb on top of the base — doubling the image size,
# and producing a layer so large that Docker Hub rejects the push. So download
# just the fts deb and install only its files, with the mssql-server dependency
# check skipped (its files already exist).
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

# Download the fts deb only (not its mssql-server dependency), then install its
# files with the dependency check skipped — the mssql-server binaries are
# already present in the base image.
tmp="$(mktemp -d)"
( cd "$tmp" && ACCEPT_EULA=Y apt-get download mssql-server-fts )
ACCEPT_EULA=Y dpkg -i --ignore-depends=mssql-server "$tmp"/mssql-server-fts_*.deb

rm -rf "$tmp" /var/lib/apt/lists/*
