#!/usr/bin/env bash
# Build-time only (builder stage). Starts the SQL Server engine in the
# background, loads the Sakila schema + data, populates film_text and its
# full-text index, then dumps /var/opt/mssql/sakila.bak for the final stage to
# restore at container start. The background engine is killed when this script
# (and thus the build step) finishes.
set -euo pipefail

PW="${MSSQL_SA_PASSWORD:?MSSQL_SA_PASSWORD must be set}"
# -b makes sqlcmd exit non-zero on any SQL error (off by default), so a failed
# load fails the build instead of silently producing an empty .bak.
SQLCMD=(/opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P "$PW" -C -b)

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

# Load schema + data + full-text as ONE script: the schema's `USE sakila`
# carries through to the data and full-text steps (separate sqlcmd sessions
# would default to the master database, silently loading nothing into sakila).
echo "Loading schema + data + full-text..."
cat /sql/1-sql-server-sakila-schema.sql \
    /sql/2-sql-server-sakila-insert-data.sql \
    /sql/4-sql-server-sakila-fulltext.sql > /tmp/init-db-full.sql
# -f 65001 = read the input as UTF-8. The data file now carries real Unicode
# (restored international names like Réunion, Coruña); without this sqlcmd would
# read the UTF-8 bytes as the default codepage and mangle the accents.
"${SQLCMD[@]}" -f 65001 -i /tmp/init-db-full.sql

# Safety net: assert the data actually loaded into sakila before backing up.
rows="$("${SQLCMD[@]}" -d sakila -h -1 -W -Q "SET NOCOUNT ON; SELECT COUNT(*) FROM film_text" | tr -d '[:space:]')"
if [ "$rows" != "1000" ]; then
  echo "ERROR: film_text has '${rows}' rows (expected 1000) — data load failed"
  exit 1
fi
echo "Data loaded: film_text has ${rows} rows."

# Wait for the full-text index to finish populating before backing up, so the
# index ships fully built in the .bak (PopulateStatus 0 = idle/complete).
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
