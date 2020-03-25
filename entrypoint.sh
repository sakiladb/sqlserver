#!/bin/bash

# cat all the files together to make our logic simpler
cat /step_1.sql /step_2.sql /step_3.sql > /db_init.sql

# Run init-script with long timeout - and make it run in the background
/opt/mssql-tools/bin/sqlcmd -S localhost -l 60 -U sa -P p_ssW0rd -i /db_init.sql &
# Start SQL server
/opt/mssql/bin/sqlservr