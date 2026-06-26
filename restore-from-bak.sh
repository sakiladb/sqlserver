#!/usr/bin/env bash
# Runtime: started as a background process by entrypoint.sh. Waits for the
# engine, restores the baked /sakila/sakila.bak (generated at build time on the
# same SQL Server version, so no upgrade step), then (re)creates the server-level
# [sakila] login, which is not part of a database backup.
set +e

sleep 2
SQLCMD="/opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P p_ssW0rd -C"

for _ in $(seq 1 60); do
  $SQLCMD -l 2 -Q "RESTORE DATABASE [sakila] FROM DISK=N'/sakila/sakila.bak' WITH REPLACE"
  if [ $? -eq 0 ]; then
    # The [sakila] login is server-level, so it is not in the DB backup; create
    # it after the restore (idempotent across restarts).
    $SQLCMD -i /sakila/3-sql-server-sakila-user.sql
    printf "\n\nSakila DB is online.\n\n"
    break
  fi
  echo "DB is not ready yet..."
  sleep 2
done
