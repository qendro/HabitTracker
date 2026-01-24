#!/bin/bash
# Set Pool Size for Gigalixir Free Tier
# Free tier has limited database connections

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "=========================================="
echo "Setting Pool Size for Free Tier"
echo "=========================================="
echo ""

# Setup credentials
source /app/docker/scripts/gigalixir-setup.sh

echo ""
echo "Setting POOL_SIZE to 2 (free tier limit)..."
gigalixir config:set POOL_SIZE=2 -a "$APP_NAME"

echo ""
echo -e "${GREEN}✓ Pool size configured${NC}"
echo ""
echo "Restarting app to apply changes..."
gigalixir ps:restart -a "$APP_NAME"

echo ""
echo -e "${GREEN}✓ App restarted${NC}"
echo ""
echo "Wait 30 seconds for app to stabilize, then run migrations:"
echo "  make gigalixir-migrate"
