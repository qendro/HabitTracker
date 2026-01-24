#!/bin/bash
# View Gigalixir App Logs
# Run this script inside the Gigalixir Docker container

set -e

# Setup credentials
source /app/docker/scripts/gigalixir-setup.sh

echo "Viewing logs for $APP_NAME..."
echo "Press Ctrl+C to exit"
echo ""

gigalixir logs -a "$APP_NAME"
