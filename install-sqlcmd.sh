#!/usr/bin/env bash

set -e

apt update -y
apt install -y sudo curl wget git gnupg2 software-properties-common
curl https://packages.microsoft.com/keys/microsoft.asc | sudo apt-key add -
add-apt-repository "$(wget -qO- https://packages.microsoft.com/config/ubuntu/18.04/prod.list)"
apt-get update -y
apt-get install -y sqlcmd
