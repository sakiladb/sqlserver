#!/usr/bin/env bash
# Build-time only (builder stage). Starts the SQL Server engine in the
# background, loads the Sakila schema + data, populates film_text and its
# full-text index, then dumps /var/opt/mssql/sakila.bak for the final stage to
# restore at container start. The background engine is killed when this script
# (and thus the build step) finishes.
set -euo pipefail

PW="${MSSQL_SA_PASSWORD:?MSSQL_SA_PASSWORD must be set}"
SQLCMD=(/opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P "$PW" -C)

echo "Starting SQL Server engine (build-time)..."
/opt/mssql/bin/sqlservr &
SVPID=$!

# Wait until the engine accepts connections.
ready=
for _ in $(seq 1 90); do
  if "${SQLCMD[@]}" -l 1 -Q "SELECT 1" >/dev/null 2>&1; then ready=1; break; fi
  sleep 2
done
[ -n "$ready" ] || { echo "engine did not become ready"; exit 1; }

echo "Loading schema + data..."
"${SQLCMD[@]}" -i /sql/1-sql-server-sakila-schema.sql
"${SQLCMD[@]}" -i /sql/2-sql-server-sakila-insert-data.sql

echo "Populating film_text + full-text index..."
"${SQLCMD[@]}" -d sakila -i /sql/4-sql-server-sakila-fulltext.sql

# Wait for the full-text index to finish populating, so it ships fully built in
# the .bak (PopulateStatus 0 = idle/complete).
for _ in $(seq 1 60); do
  st="$("${SQLCMD[@]}" -d sakila -h -1 -W -Q "SET NOCOUNT ON; SELECT FULLTEXTCATALOGPROPERTY('sakila_ft','PopulateStatus')" 2>/dev/null | tr -d '[:space:]')"
  [ "$st" = "0" ] && break
  sleep 2
done

echo "Backing up to /var/opt/mssql/sakila.bak..."
"${SQLCMD[@]}" -Q "BACKUP DATABASE [sakila] TO DISK=N'/var/opt/mssql/sakila.bak' WITH FORMAT, INIT"

kill "$SVPID" 2>/dev/null || true
wait "$SVPID" 2>/dev/null || true
echo "Build-time Sakila backup generated."
