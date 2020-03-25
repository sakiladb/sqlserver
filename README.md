# sakiladb/sqlserver

Microsoft [SQL Server](https://hub.docker.com/_/microsoft-mssql-server) docker
image preloaded with the [Sakila](https://dev.mysql.com/doc/sakila/en/) example
database (by way of [jooq](https://www.jooq.org/sakila)). See on
[Docker Hub](https://hub.docker.com/r/sakiladb/sqlserver).

By default these are created:
- database: `sakila`
- username / password: `sakila` / `p_ssW0rd`



```shell script
docker run -p 5432:5432 -d sakiladb/sqlserver:latest
```

Or use a specific version of SQL Server (see all available image tags
on [Docker Hub](https://hub.docker.com/r/sakiladb/sqlserver/tags).)

```shell script
docker run -p 5432:5432 -d sakiladb/sqlserver:2017-CU19
```


Note that it may take some time for the container to boot up.

If you have [sqlcmd](https://docs.microsoft.com/en-us/sql/tools/sqlcmd-utility) installed
locally, verify that all is well:

```shell script
$ sqlcmd -S localhost -U sakila -P p_ssW0rd -d sakila -Q 'select * from actor'
 actor_id | first_name |  last_name   |     last_update
----------+------------+--------------+---------------------
        1 | PENELOPE   | GUINESS      | 2006-02-15 04:34:33
        2 | NICK       | WAHLBERG     | 2006-02-15 04:34:33
        3 | ED         | CHASE        | 2006-02-15 04:34:33
        4 | JENNIFER   | DAVIS        | 2006-02-15 04:34:33
        5 | JOHNNY     | LOLLOBRIGIDA | 2006-02-15 04:34:33
```
