# CLAUDE.md

Maintainer guide for **`sakiladb/sqlserver`** — a Microsoft SQL Server Docker image preloaded with the
[Sakila](https://dev.mysql.com/doc/sakila/en/) sample database (via [jOOQ](https://www.jooq.org/sakila)),
published to [Docker Hub](https://hub.docker.com/r/sakiladb/sqlserver) and
[GitHub Container Registry](https://github.com/sakiladb/sqlserver/pkgs/container/sqlserver).

> One of the [`sakiladb`](https://github.com/sakiladb) image family (`postgres`, `mysql`, `mariadb`,
> `sqlserver`, `oracle`, `clickhouse`, `rqlite`). The release machinery in
> [How releases work](#how-releases-work) is **shared across the family** (the reference template
> lives in [`sakiladb/postgres`](https://github.com/sakiladb/postgres)); the build details in
> [How the image is built](#how-the-image-is-built) are **SQL Server-specific**.

## Purpose

These images exist primarily as **test fixtures for the [`sq`](https://github.com/neilotoole/sq) CLI**.
`sq`'s suite runs against every variant and asserts a uniform Sakila schema, so each image must expose
the **same object set: 16 tables + 7 views**. Treat that as a hard consistency contract.

Because the schema is coupled to `sq`'s tests, **a schema change here is a cross-repo change**: `sq`'s
expectations (`testh/sakila/sakila.go`, `libsq/driver/driver_test.go`, `cli/cmd_inspect_test.go`) must
be updated in lockstep or its suite breaks against the new image.

## The dataset

The standard Sakila database, preloaded and owned by the `sakila` user: **16 tables + 7 views**, kept
consistent with the rest of the family. SQL Server's jOOQ port arrived under-built, so several things
were reconciled to the canonical `sakiladb/mysql` (all verified byte-identical to postgres/mysql):

- **`film_list` aggregates the cast.** The jOOQ port's `film_list` did *not* aggregate — it emitted one
  row per film-actor (5462 rows). It now uses `STRING_AGG(... ) WITHIN GROUP (ORDER BY first_name,
  last_name, actor_id)` for one row per film (997), deterministic and byte-identical to the family.
- **`actor_info` + `nicer_but_slower_film_list` added** (they were absent / a commented-out MySQL stub),
  taking the view count from 5 to 7. `actor_info` is the hard one: SQL Server `STRING_AGG` has no
  `DISTINCT` and the view is doubly-correlated, so it uses **`OUTER APPLY`** (per actor) over a derived
  table (per category) with a nested `STRING_AGG`. Both views order their aggregates deterministically.
- **`film_text` is populated + full-text-indexed.** It shipped empty; it is now populated from `film`
  and given a SQL Server **full-text index** (see below), so `CONTAINS((title, description),
  'astronaut')` returns 78 — parity with the GIN / `FULLTEXT` indexes elsewhere. Its `film_id` was
  widened `SMALLINT`→`INT` and `description` `TEXT`→`VARCHAR(MAX)` (`TEXT` is deprecated and warns under
  full-text change tracking).
- **`customer.active` is `BIT`** (was `CHAR(1)`), matching `staff.active` and MySQL's boolean intent.
  The data's `'1'`/`'0'` literals convert cleanly.
- **`customer_list` / `staff_list` use `[zip code]`** (the canonical spaced identifier), not `zip_code`.

Stored procedures and triggers are intentionally **omitted** — faithful to jOOQ's SQL Server port, which
never implemented them, and they are `sq`-invisible (sq counts tables + views, not routines).

## How the image is built

*(SQL Server-specific.)* Unlike postgres (which bakes the data directory directly), SQL Server's data is
shipped as a native **backup** that is **generated at build time** and **restored at container start**.
`Dockerfile` is a two-stage build; the base image is parameterized by `ARG MSSQL_VERSION` (the base-image
tag, e.g. `2019-latest`) and `ARG MSSQL_YEAR` (the product year, e.g. `2019`), which the release workflow
sets per build:

1. **`builder` stage** — installs full-text search (`install-fts.sh`), then `build-sakila.sh` starts the
   engine, loads the schema + data + full-text index, and dumps `/var/opt/mssql/sakila.bak`.
2. **final stage** — installs full-text search again (the runtime engine needs it to serve the restored
   index), copies the baked `sakila.bak`, and restores it at start via `restore-from-bak.sh`.

| File | Role |
|------|------|
| `1-sql-server-sakila-schema.sql` | Schema: tables, views, indexes (build-time). |
| `2-sql-server-sakila-insert-data.sql` | Data (`Insert into …`) (build-time). |
| `4-sql-server-sakila-fulltext.sql` | Populate `film_text` + full-text catalog/index (build-time, after data). |
| `3-sql-server-sakila-user.sql` | (Re)create the server-level `sakila` login after restore (**runtime**, every start — logins are not in a DB backup). |

> **Build gotcha (load order / DB context).** The data file has no `USE sakila`, so the three build-time
> SQL files **must be concatenated into one script** (`build-sakila.sh`) — the schema's `USE sakila`
> carries through to the data + full-text steps. Run as separate `sqlcmd` sessions they default to
> `master` and silently load nothing. `sqlcmd` also does **not** fail on SQL errors unless given `-b`, so
> `build-sakila.sh` uses `-b` and asserts `film_text` = 1000 rows before backing up (a green build with
> an empty database is otherwise possible).

### Full-text search

`mssql-server-fts` is **not** in the generic `packages.microsoft.com/.../prod` repo; it lives in the
**version-specific `mssql-server-<year>` product repo** and pulls the `mssql-server` deb at the matching
version (`install-fts.sh` adds the repo and installs it, in both stages). The full-text catalog/index are
created at build time so they ship inside `sakila.bak`.

### Readiness (HEALTHCHECK)

The final stage declares a `HEALTHCHECK` (`healthcheck.sh` → `sqlcmd -U sakila -d sakila -Q "SELECT 1"`),
so the container reports `healthy` once the **runtime restore** has completed and the `sakila` login
exists (~15–20s; SQL Server restores at start rather than booting pre-baked like postgres). `sqlcmd` can
exit with codes Docker reserves (2/3), so the probe normalizes any failure to exit 1. The `sakila`
credentials are hardcoded (the final stage does not carry the build `MSSQL_*` env beyond the password).

> **Family convention:** every `sakiladb` image declares a `HEALTHCHECK` using its engine's native probe.
> The probe differs per engine; the readiness *contract* (`healthy` = ready to serve) is uniform.

## How releases work

*(Shared across the `sakiladb` family — see [`sakiladb/postgres`](https://github.com/sakiladb/postgres)'s
CLAUDE.md for the full description.)* Releases are **tag-driven**: a single `master` branch, and pushing a
semver tag `vN.0.x` publishes SQL Server N. The version (year) is read from the tag — the "Determine SQL
Server version" step derives it (`v2022.0.0` → `2022`), passes it as `MSSQL_VERSION`/`MSSQL_YEAR` build
args, and the `Dockerfile` builds the matching base. Images push to **both Docker Hub and GHCR**, are
**cosign-signed**, and **`latest`** is emitted only when the tag's year equals `LATEST_VERSION` in the
workflow (currently `2022`), so tag-push order is irrelevant.

### Versions & architecture

- **Published: `2019` and `2022`.** `latest` → `2022`.
- **SQL Server 2017 is retired.** Its newest base image is on **EOL Ubuntu 18.04**, whose `apt` can no
  longer install `mssql-server-fts` — so it cannot reach full-text parity. The immutable `v2017.0.x` tags
  preserve the old (pre-full-text) image.
- **amd64-only.** Microsoft's SQL Server base images are not published for arm64, so the workflow builds
  `linux/amd64` only. (Do **not** blind-copy postgres's multi-arch.)

### Recipe: release / republish a version

```bash
git switch master && git pull
git tag -l 'v2022.*'                          # find the next unused patch
git tag v2022.0.0 && git push origin v2022.0.0   # builds & publishes `2022` (+ `latest`, since 2022 == LATEST_VERSION)
git tag v2019.0.3 && git push origin v2019.0.3   # builds & publishes `2019` (`latest` untouched)
```

Push tags **one at a time** (pushing several in one `git push` suppresses the per-tag workflow events).
After releasing: pull the image, confirm the schema (16 tables + 7 views, `film_text` = 1000,
`CONTAINS('astronaut')` = 78), and update the README "Available versions" table + Changelog.

## Conventions

- **Credentials:** database / user / password = `sakila` / `sakila` / `p_ssW0rd`.
- **Tags:** Docker tag is the year (`2019`, `2022`); `latest` on the newest. Git tags are
  `v{YEAR}.{MINOR}.{PATCH}` — the year tracks the SQL Server version, minor/patch track sakiladb's own
  revisions (in practice only the patch moves: `v2019.0.2` → `v2019.0.3`).
- **No AI attribution** in commits, tags, PRs, or any other content.
