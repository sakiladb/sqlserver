# check=skip=SecretsUsedInArgOrEnv
# ^ The *_PASSWORD values below are the public, documented Sakila fixture
#   credential (p_ssW0rd) — these are throwaway test-fixture images with a
#   fixed, published password, not a secret. This lint rule is skipped.

# SQL Server version to build.
#
# MSSQL_VERSION is the base-image tag (e.g. 2019-latest, 2022-latest);
# MSSQL_YEAR is the matching product year (2019, 2022) used to select the
# full-text package repo. The CI release workflow overrides both per release,
# deriving them from the git tag (v2019.0.0 -> 2019). Defaults = newest, for
# convenient local `docker build` (note: requires a native amd64 host —
# mssql-server-fts cannot be installed on older bases under emulation).
ARG MSSQL_VERSION=2022-latest
ARG MSSQL_YEAR=2022

# ---------------------------------------------------------------------------
# builder stage: load Sakila + full-text index, dump sakila.bak
# ---------------------------------------------------------------------------
FROM mcr.microsoft.com/mssql/server:${MSSQL_VERSION} AS builder
ARG MSSQL_YEAR
ENV ACCEPT_EULA=Y
ENV MSSQL_SA_PASSWORD=p_ssW0rd
ENV MSSQL_PID=Developer

USER root
COPY install-fts.sh /usr/local/bin/install-fts.sh
RUN chmod +x /usr/local/bin/install-fts.sh && install-fts.sh "${MSSQL_YEAR}"
COPY 1-sql-server-sakila-schema.sql \
     2-sql-server-sakila-insert-data.sql \
     4-sql-server-sakila-fulltext.sql /sql/
COPY build-sakila.sh /usr/local/bin/build-sakila.sh
RUN chmod +x /usr/local/bin/build-sakila.sh && chmod -R a+rX /sql

# Run the data load as the engine's own user (mssql), which owns the data dir.
USER mssql
RUN build-sakila.sh

# ---------------------------------------------------------------------------
# final stage: full-text-enabled engine that restores the baked .bak at start
# ---------------------------------------------------------------------------
FROM mcr.microsoft.com/mssql/server:${MSSQL_VERSION}
ARG MSSQL_YEAR
ENV ACCEPT_EULA=Y
ENV MSSQL_SA_PASSWORD=p_ssW0rd
ENV MSSQL_PID=Developer

USER root
COPY install-fts.sh /usr/local/bin/install-fts.sh
RUN chmod +x /usr/local/bin/install-fts.sh && install-fts.sh "${MSSQL_YEAR}"

WORKDIR /sakila
COPY --from=builder /var/opt/mssql/sakila.bak /sakila/sakila.bak
COPY 3-sql-server-sakila-user.sql \
     restore-from-bak.sh entrypoint.sh signal-listener.sh healthcheck.sh /sakila/
RUN chmod -R 777 /sakila

EXPOSE 1433

# Healthy once the restored sakila DB accepts a query. sqlcmd can exit with
# codes Docker reserves, so healthcheck.sh normalizes any failure to 1. The
# start-period is generous because the runtime restore takes a few seconds.
HEALTHCHECK --interval=10s --timeout=10s --start-period=90s --retries=12 \
  CMD /sakila/healthcheck.sh

# Run as the engine's own user, and trap SIGINT/SIGTERM to forward them to
# sqlservr (clean `docker stop` / Ctrl+C). signal-listener.sh launches
# entrypoint.sh, which kicks off the background restore and starts sqlservr.
USER mssql
ENTRYPOINT ["/bin/bash", "/sakila/signal-listener.sh"]
