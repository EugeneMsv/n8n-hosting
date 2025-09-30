#!/bin/bash

SCRIPT_DIR="$(dirname "$0")"

# Fail fast on errors
set -e
## Remove existing installation o
bash "$SCRIPT_DIR/stop_local_compose.sh"

echo "📂 Changing to withPostgres directory..."
cd ./docker-compose/withPostgres


## Update images
docker compose -f docker-compose.yml  pull --ignore-pull-failures

## Start mysql
docker compose -f docker-compose.yml -p n8n-platform up -d

# To enable logs:
docker compose -p n8n-platform logs -f -t
