#!/bin/bash

# Run this script every time you want upgrade to the latest version
export GITLAB_VERSION=latest

echo "Running backup"
docker-compose exec gitlab gitlab-rake gitlab:backup:create

echo "Pulling latest image"
docker-compose pull


echo "Running updated image"
docker-compose up -d

echo "Showing logs for next 120 secs"
timeout 120 docker-compose logs -f