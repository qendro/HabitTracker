#!/bin/bash
# Check Gigalixir App Status
# Run this script inside the Gigalixir Docker container

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Setup credentials
source /app/docker/scripts/gigalixir-setup.sh

echo "=========================================="
echo "App Status: $APP_NAME"
echo "=========================================="
echo ""

# App status
echo "App Status:"
gigalixir ps -a "$APP_NAME"

echo ""
echo "Database Status:"
gigalixir pg -a "$APP_NAME"

echo ""
echo "Environment Variables:"
gigalixir config -a "$APP_NAME"

echo ""
echo "Health Check:"
curl -s "https://$APP_NAME.gigalixirapp.com/health" | python3 -m json.tool || echo "Health check failed"

echo ""
echo "=========================================="
echo "App URL: https://$APP_NAME.gigalixirapp.com"
echo "=========================================="
