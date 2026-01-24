#!/bin/bash
# Restart Gigalixir App
# Run this script inside the Gigalixir Docker container

set -e

# Colors
GREEN='\033[0;32m'
NC='\033[0m'

# Setup credentials
source /app/docker/scripts/gigalixir-setup.sh

echo "Restarting $APP_NAME..."
gigalixir ps:restart -a "$APP_NAME"

echo ""
echo -e "${GREEN}✓ App restarted${NC}"
echo ""
echo "Check status with: make gigalixir-status"
