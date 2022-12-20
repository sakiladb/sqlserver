#!/usr/bin/env bash
# This script is executed as a background process by entrypoint.sh.
# It attempts to load/restore the backup in /sakila/sakila.bak into the DB.
# The server can take a while to start, so we execute the sqlcmd in
# a loop.

set +e

sleep 2

export SQLCMDPASSWORD="p_ssW0rd"

for i in {1..50};
do
    sqlcmd -S localhost -U sa -Q "RESTORE DATABASE [sakila] FROM DISK=N'/sakila/sakila.bak'"

    if [ $? -eq 0 ]
    then
        # It seems to be necessary to explicitly set up the login
        # again after backup.
        sqlcmd -S localhost -U sa -i ./3-sql-server-sakila-user.sql

        printf "\n\nSakila DB is online.\n\n"

        break
    else
        echo "DB is not ready yet..."
        sleep 2
    fi
done
