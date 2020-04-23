# sakiladb/sqlserver

Microsoft [SQL Server](https://hub.docker.com/_/microsoft-mssql-server) docker
image preloaded with the [Sakila](https://dev.mysql.com/doc/sakila/en/) example
database (by way of [jooq](https://www.jooq.org/sakila)).
See on
[Docker Hub](https://hub.docker.com/r/sakiladb/sqlserver).

By default these are created:
- database: `sakila`
- username / password: `sakila` / `p_ssW0rd`



```shell script
docker run -p 1433:1433 -d sakiladb/sqlserver:latest
```

Or use a specific version of SQL Server: see all available image tags
on [Docker Hub](https://hub.docker.com/r/sakiladb/sqlserver/tags). For example:

```shell script
docker run -p 1433:1433 -d sakiladb/sqlserver:2017
```


Note that it may take some time for the container to boot up. Eventually the container's
docker logs will show:

```
sakiladb/sqlserver has successfully initialized.
```

Note that even after this message is logged, it may take another few moments for
it to become available (due to a final server restart etc).

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
