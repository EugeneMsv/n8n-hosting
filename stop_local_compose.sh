#!/bin/bash

SCRIPT_DIR="$(dirname "$0")"

cd ./docker-compose/withPostgres
docker compose -f docker-compose.yml -p n8n-platform stop
docker compose -f docker-compose.yml -p n8n-platform rm -f
docker image prune -f

### UNINSTALL EXITED CONTAINERS###
if [[ ! -z $(docker ps -a -f status=exited -q) ]]; then
echo "Uninstalling unused containers..."
docker rm $(docker ps -a -f status=exited -q)
fi
