# sakiladb/sqlserver

A Microsoft [SQL Server](https://hub.docker.com/_/microsoft-mssql-server) Docker image preloaded with the
[Sakila](https://dev.mysql.com/doc/sakila/en/) sample database (via [jOOQ](https://www.jooq.org/sakila)).
One of the [`sakiladb`](https://github.com/sakiladb) image family.

These images exist primarily as test fixtures for [`sq`](https://github.com/neilotoole/sq), a
command-line tool for querying SQL databases and structured data — but they are free for anyone to use.

Available on [Docker Hub](https://hub.docker.com/r/sakiladb/sqlserver) and
[GitHub Container Registry](https://github.com/sakiladb/sqlserver/pkgs/container/sqlserver).

## Quick start

```shell
docker run -p 1433:1433 -d sakiladb/sqlserver:latest
```

The image declares a Docker
[`HEALTHCHECK`](https://docs.docker.com/reference/dockerfile/#healthcheck), so you can wait for
readiness rather than guessing. SQL Server restores the baked Sakila backup at container start, so its
status becomes `healthy` after a few seconds, once the database is accepting queries:

```shell
docker run -p 1433:1433 -d --name sakila sakiladb/sqlserver:latest
until [ "$(docker inspect -f '{{.State.Health.Status}}' sakila)" = healthy ]; do sleep 1; done
```

In Docker Compose, gate dependents with `depends_on: { condition: service_healthy }`.

## Connection

| Setting    | Value       |
|------------|-------------|
| host       | `localhost` |
| port       | `1433`      |
| database   | `sakila`    |
| user       | `sakila`    |
| password   | `p_ssW0rd`  |

With [`sqlcmd`](https://learn.microsoft.com/en-us/sql/tools/sqlcmd-utility):

```shell
$ sqlcmd -S localhost -U sakila -P p_ssW0rd -d sakila -Q 'SELECT TOP 5 actor_id, first_name, last_name FROM actor'
```

Or with [`sq`](https://github.com/neilotoole/sq) ([install](https://sq.io/docs/install)):

```shell
$ sq add 'sqlserver://sakila:p_ssW0rd@localhost:1433?database=sakila' --handle @sakila_ms
$ sq '@sakila_ms.actor | .[0:5]'
```

## What's inside

The standard Sakila sample database — **16 tables and 7 views**, all owned by the `sakila` user.
[`sq inspect`](https://sq.io/docs/inspect) reports `16` tables and `7` views, the same object set as
every other sakiladb variant.

| Tables (16) | Views (7) |
|------------|-----------|
| actor, address, category, city, country, customer, film, film_actor, film_category, film_text, inventory, language, payment, rental, staff, store | actor_info, customer_list, film_list, nicer_but_slower_film_list, sales_by_film_category, sales_by_store, staff_list |

`film_text` is a populated table with **working full-text search**, added as a SQL Server full-text
index *under* the table (so the column set stays identical to every other variant):

```sql
SELECT title FROM film_text WHERE CONTAINS((title, description), 'astronaut');
```

## Differences from other sakila variants

Every sakiladb variant exposes the **same Sakila fixture** — the same 16 tables and 7 views, with the
same data — so [`sq`](https://github.com/neilotoole/sq) can assert a uniform schema across all of them.
A couple of SQL Server representation details:

- **Full-text search uses `CONTAINS(...)`** (the SQL Server analogue of postgres `@@` / MySQL
  `MATCH … AGAINST`). The index sits under the plain `film_text` table, invisible to the schema.
- **The data is restored at container start** (from a backup baked into the image), so the container
  takes a few seconds to become `healthy` — wait on the `HEALTHCHECK` rather than connecting immediately.

## Available versions

Each SQL Server version is published as its own image tag. `latest` tracks the newest version
(currently 2022).

| SQL Server | sakiladb Release | Architecture | Docker Hub                           | GitHub Container Registry                    |
|-----------:|------------------|--------------|--------------------------------------|----------------------------------------------|
|       2022 | `v2022.0.1`      | `amd64`      | `sakiladb/sqlserver:2022`, `:latest` | `ghcr.io/sakiladb/sqlserver:2022`, `:latest` |
|       2019 | `v2019.0.4`      | `amd64`      | `sakiladb/sqlserver:2019`            | `ghcr.io/sakiladb/sqlserver:2019`            |

**sakiladb Release** is the git tag the current image was built from (see
[releases](https://github.com/sakiladb/sqlserver/releases)). Its version is `v{YEAR}.{MINOR}.{PATCH}`:
the **year** tracks the SQL Server version, while **minor**/**patch** track sakiladb's own revisions.

SQL Server base images are **amd64-only**, so these images are `amd64`-only. Every version is published to
both [Docker Hub](https://hub.docker.com/r/sakiladb/sqlserver) and
[GitHub Container Registry](https://github.com/sakiladb/sqlserver/pkgs/container/sqlserver), and signed
with [cosign](https://github.com/sigstore/cosign).

> **SQL Server 2017** (`:2017`) is retired: its newest base image is on EOL Ubuntu 18.04, which can no
> longer install the full-text-search package, so it cannot reach full-text parity with the family. The
> older `:2017` image remains pullable via its immutable `v2017.0.x` tags.

## Releasing a new version

Maintainers: releases are tag-driven. Pushing a semver tag `vYEAR.0.x` builds and publishes that SQL
Server version — the version is derived from the tag, so there are no per-version branches. See
[CLAUDE.md](./CLAUDE.md) for the full, repeatable procedure.

## Changelog

### 2026-06-26

- **Restored faithful original data** (`v2019.0.4`, `v2022.0.1`) — the Sakila data is now byte-identical
  to the original MySQL Sakila: restored the Unicode accents stripped from international place names
  (e.g. `Réunion`, `Coruña`), the real `address.phone` numbers, and the full `address.district` column.
- **Modernized as a consistent sakiladb fixture.** Reconciled the schema to the canonical
  [`sakiladb/mysql`](https://hub.docker.com/r/sakiladb/mysql): `film_list` now aggregates the cast (was
  one row per film-actor); added `actor_info` and `nicer_but_slower_film_list` (**16 tables + 7 views**);
  `film_text` is populated with working full-text search (`CONTAINS('astronaut')` = 78); `customer.active`
  is `BIT` (matching `staff.active`); and `customer_list` / `staff_list` use the canonical `zip code`.
- **Tag-driven, multi-registry build.** Version derived from the git tag, data + full-text index
  generated at build time, mirrored to GitHub Container Registry, cosign-signed, with a Docker
  `HEALTHCHECK`. `latest` now tracks **2022**.
- **SQL Server 2017 retired** (its EOL Ubuntu 18.04 base cannot install full-text search).

## License

[BSD 2-Clause](./LICENSE).
