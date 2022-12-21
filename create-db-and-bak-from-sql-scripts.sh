#!/usr/bin/env bash
# This script uses sqlcmd to execute the SQL create/load scripts to
# build/load the sakila DB, and then dump a backup to /sakila/sakila.bak.

set -e
export SQLCMDPASSWORD="p_ssW0rd"

cat ./1-sql-server-sakila-schema.sql ./2-sql-server-sakila-insert-data.sql ./3-sql-server-sakila-user.sql > ./init-db-full.sql

printf "\n\nBuilding Sakila DB via SQL scripts....\n\n"
printf "This could take several minutes, and you may see errors that are to be ignored.\n\n";

set +e

# We run this in a loop, because the server might not be available yet
for i in {1..50};
do
  sqlcmd -S localhost -U sa -i ./init-db-full.sql
  if [ $? -eq 0 ]; then
    break
  else
    echo "Waiting..."
    sleep 2
  fi
done

printf "\n\nSakila DB imported\n\n"

set -e


sqlcmd -S localhost -U sa -Q "BACKUP DATABASE [sakila] TO DISK = N'/sakila/sakila.bak' WITH FORMAT;"

printf "Database dumped to /sakila/sakila.bak"
