.#!/bin/bash

### Docker's version must be at least at 1.9

### REMOVE DANGLING IMAGES
if [[ ! -z $(docker images ps -f dangling=true -q) ]]; then
echo "Removing dangling images..."
docker rmi $(docker images -f dangling=true -q)
fi

### UNINSTALL EXITED CONTAINERS###
if [[ ! -z $(docker ps -a -f status=exited -q) ]]; then
echo "Uninstalling unused containers..."
docker rm $(docker ps -a -f status=exited -q)
fi
 
### DELETE DANGLING VOLUMES###
if [[ ! -z $(docker volume ls -f dangling=true -q) ]]; then
echo "Removing dangling volumes..."
docker volume rm $(docker volume ls -f dangling=true -q)
fi
