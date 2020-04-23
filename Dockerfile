FROM mcr.microsoft.com/mssql/server:2017-CU19-ubuntu-16.04 AS sakila-base
ENV ACCEPT_EULA="Y"
ENV SA_PASSWORD="p_ssW0rd"

COPY ./entrypoint.sh /entrypoint.sh

COPY ./1-sql-server-sakila-schema.sql /step_1.sql
COPY ./2-sql-server-sakila-insert-data.sql /step_2.sql
COPY ./3-sql-server-sakila-user.sql /step_3.sql

CMD /bin/bash /entrypoint.sh