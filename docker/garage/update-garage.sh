#!/usr/bin/env bash

PATH=/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin

COMPOSE_URL="https://raw.githubusercontent.com/Lungooo/homelab/refs/heads/main/docker/garage/compose.yaml"
WORK_DIR="/volume1/docker/garage"

cd "$WORK_DIR" || { echo "Failed to change directory to $WORK_DIR"; exit 1; }

HTTP_STATUS=$(curl -s -L --etag-compare .etag --etag-save .etag -w "%{http_code}" -o compose.yaml "$COMPOSE_URL")

if [ "$HTTP_STATUS" -eq 200 ]; then
  echo "Update found: The file was downloaded successfully."
  docker compose down || { echo "Failed to stop Docker containers"; exit 1; }
  sleep 2
  docker compose pull || { echo "Failed to pull Docker images"; exit 1; }
  docker compose up -d || { echo "Failed to start Docker containers";  exit 1; }

    
elif [ "$HTTP_STATUS" -eq 304 ]; then
  echo "No changes: The file matches the remote version."
  exit 0

else
  echo "Error: Unexpected HTTP status code $HTTP_STATUS"
  exit 1
fi
