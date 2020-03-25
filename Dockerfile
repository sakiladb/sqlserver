FROM mcr.microsoft.com/mssql/server:2017-CU19-ubuntu-16.04 AS sakila-base
ENV ACCEPT_EULA="Y"
ENV SA_PASSWORD="p_ssW0rd"

COPY ./entrypoint.sh /entrypoint.sh

COPY ./sql-server-sakila-schema.sql /step_1.sql
COPY ./sql-server-sakila-insert-data.sql /step_2.sql
COPY ./sql-server-sakila-user.sql /step_3.sql

CMD /bin/bash /entrypoint.sh