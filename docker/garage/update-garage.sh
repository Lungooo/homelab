#!/usr/bin/env bash

PATH=/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin

# REST API endpoint for the specific file contents
API_URL="https://api.github.com/repos/Lungooo/homelab/contents/docker/garage/compose.yaml?ref=main"
WORK_DIR="/volume1/docker/garage"

cd "$WORK_DIR" || { echo "Failed to change directory to $WORK_DIR"; exit 1; }

# Download raw file content directly using GitHub API while passing stored ETag
HTTP_STATUS=$(curl -s -L \
  -H "Accept: application/vnd.github.raw+json" \
  -H "User-Agent: Synology-Garage-Updater" \
  --etag-compare .etag \
  --etag-save .etag \
  -w "%{http_code}" \
  -o compose.yaml \
  "$API_URL")

if [ "$HTTP_STATUS" -eq 200 ]; then
  echo "Update found: File changed on GitHub. Downloaded new version."
  docker compose down || { echo "Failed to stop Docker containers"; exit 1; }
  sleep 2
  docker compose pull || { echo "Failed to pull Docker images"; exit 1; }
  docker compose up -d || { echo "Failed to start Docker containers"; exit 1; }

elif [ "$HTTP_STATUS" -eq 304 ]; then
  echo "No changes: The remote file content matches local ETag."
  exit 0

else
  echo "Error: Unexpected HTTP status code $HTTP_STATUS"
  exit 1
fi
