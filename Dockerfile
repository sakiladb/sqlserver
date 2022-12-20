FROM mcr.microsoft.com/mssql/server:2017-CU31-ubuntu-18.04 AS sakila-base
ENV ACCEPT_EULA="Y"
ENV SA_PASSWORD="p_ssW0rd"
ENV MSSQL_SA_PASSWORD="p_ssW0rd"
ENV MSSQL_PID="Developer"


RUN mkdir -p /sakila
WORKDIR /sakila
COPY . /sakila
RUN chmod -R 777 /sakila

# Install sqlcmd, because it's not pre-installed.
RUN apt update -y
RUN apt install -y sudo curl git gnupg2 software-properties-common
RUN curl https://packages.microsoft.com/keys/microsoft.asc | sudo apt-key add -
RUN add-apt-repository "$(wget -qO- https://packages.microsoft.com/config/ubuntu/18.04/prod.list)"
RUN apt-get update -y
RUN apt-get install -y sqlcmd


EXPOSE 1433

# See: https://dev.to/mdemblani/docker-container-uncaught-kill-signal-10l6
COPY ./signal-listener.sh /sakila/run.sh

# Entrypoint overload to catch the ctrl+c and stop signals
ENTRYPOINT ["/bin/bash", "/sakila/run.sh"]
