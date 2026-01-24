#!/bin/bash
# Deploy to Gigalixir
# Run this script inside the Gigalixir Docker container

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo "=========================================="
echo "Deploying to Gigalixir"
echo "=========================================="
echo ""

# Setup credentials
source /app/docker/scripts/gigalixir-setup.sh

# Check if app exists
echo ""
echo "Checking app status..."
if ! gigalixir apps | grep -q "$APP_NAME"; then
    echo -e "${RED}Error: App '$APP_NAME' does not exist${NC}"
    echo "Create it first with: ./docker/scripts/create-app.sh"
    exit 1
fi

echo -e "${GREEN}✓ App '$APP_NAME' exists${NC}"

# Check git status
if ! git diff-index --quiet HEAD -- 2>/dev/null; then
    echo -e "${YELLOW}Warning: You have uncommitted changes${NC}"
    read -p "Continue anyway? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# Deploy
echo ""
echo "Deploying to Gigalixir..."
git push gigalixir master:main

# Wait for deployment
echo ""
echo "Waiting for deployment to complete..."
sleep 15

# Check status
echo ""
echo "Checking app status..."
gigalixir ps -a "$APP_NAME"

# Test health endpoint
echo ""
echo "Testing health endpoint..."
sleep 5
curl -s "https://$APP_NAME.gigalixirapp.com/health" || echo "Health check failed"

echo ""
echo "=========================================="
echo -e "${GREEN}✓ Deployment Complete!${NC}"
echo "=========================================="
echo ""
echo "App URL: https://$APP_NAME.gigalixirapp.com"
echo ""
echo "Useful commands:"
echo "  View logs:    docker compose -f docker/docker-compose.gigalixir.yml run --rm gigalixir gigalixir logs -a $APP_NAME"
echo "  Check status: docker compose -f docker/docker-compose.gigalixir.yml run --rm gigalixir gigalixir ps -a $APP_NAME"
echo "  Run console:  docker compose -f docker/docker-compose.gigalixir.yml run --rm gigalixir gigalixir ps:remote_console -a $APP_NAME"
echo ""
