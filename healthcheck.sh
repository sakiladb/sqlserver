#!/usr/bin/env bash
# Docker HEALTHCHECK probe. Healthy once the restored sakila DB accepts a query
# as the sakila user (i.e. the runtime restore in restore-from-bak.sh has
# completed and the login is set up). sqlcmd can exit with codes Docker
# reserves (2/3), so normalize any failure to exit 1.
#
# The sakila login/password are hardcoded (the family readiness convention);
# they are created by 3-sql-server-sakila-user.sql after the restore.
/opt/mssql-tools18/bin/sqlcmd -S localhost -U sakila -P p_ssW0rd -C -d sakila -l 3 \
  -Q "SELECT 1" >/dev/null 2>&1 || exit 1
