#!/usr/bin/env bash
# This script can be used to regenerate the sakila.bak backup file
# from the SQL scripts. This only needs to be done if the SQL needs
# to change for some reason (which shouldn't happen).
#
# This script requires that sqlcmd is installed locally.
# https://learn.microsoft.com/en-us/sql/tools/sqlcmd-utility
#
# The process is:
#
# - Concat the relevant SQL scripts together into ./init-db-full.sql
# - Start a new sqlserver container
# - Use sqlcmd to run that script against the DB
# - Then use sqlcmd to generate "sakila.bak" (in the container)
# - Copy "sakila.bak" from container to local filesystem
# - Kill the container.
#
# You should then commit the updated "sakila.bak" to git, and then
# republish the docker images as needed.

set -e
set -x

export SQLCMDPASSWORD="p_ssW0rd"
container_version="2017-CU31-ubuntu-18.04"
container_name="sqlserver-$(echo $RANDOM | md5sum | head -c 8)"

docker run -d \
  -v $(pwd):/sakila \
  -e 'ACCEPT_EULA=1' \
  -e 'MSSQL_PID=Developer' \
  -e SA_PASSWORD="$SQLCMDPASSWORD" \
  -p 1433:1433
  --name "$container_name" mcr.microsoft.com/mssql/server:$container_version

docker exec -it -u0 "$container_name" /sakila/install-sqlcmd.sh
docker exec -it "$container_name" /sakila/create-db-and-bak-from-sql-scripts.sh


printf "\n\nBuilding backup in container...\n"

#sqlcmd -S localhost -U sa -Q "BACKUP DATABASE [sakila] TO DISK = N'/sakila/sakila.bak' WITH NOFORMAT, NOINIT, NAME = 'sakila', SKIP, NOREWIND, NOUNLOAD, STATS = 10"
sqlcmd -S localhost -U sa -Q "BACKUP DATABASE [sakila] TO DISK = N'/sakila/sakila.bak' WITH FORMAT;"

printf "\nCopying backup from container to local filesystem: %s\n\n" $(pwd)/sakila.bak

docker cp "$container_name":/sakila/sakila.bak ./sakila.bak

echo "Stopping container: $container_name"
docker rm -f "$container_name"

printf "\nSuccess!\n"
