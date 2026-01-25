#!/bin/bash
# Fix production database connection issues on Gigalixir

set -e

echo "=========================================="
echo "Fixing Production Database Configuration"
echo "=========================================="
echo ""

# Load credentials
if [ ! -f .env.gigalixir ]; then
    echo "ERROR: .env.gigalixir file not found!"
    exit 1
fi

source .env.gigalixir

echo "App: $APP_NAME"
echo ""

# Set optimal pool size for Gigalixir free tier
echo "Setting POOL_SIZE to 2..."
echo "(Gigalixir free tier has 4 connection limit)"
echo ""

docker compose -f docker/docker-compose.gigalixir.yml run --rm gigalixir bash -c "
  gigalixir login -e $GIGALIXIR_EMAIL -p $GIGALIXIR_API_KEY -y && \
  gigalixir config:set -a $APP_NAME POOL_SIZE=2
"

echo ""
echo "✓ Database pool size configured"
echo ""
echo "Now restarting the application..."
echo ""

docker compose -f docker/docker-compose.gigalixir.yml run --rm gigalixir bash -c "
  gigalixir login -e $GIGALIXIR_EMAIL -p $GIGALIXIR_API_KEY -y && \
  gigalixir ps:restart -a $APP_NAME
"

echo ""
echo "=========================================="
echo "✓ Configuration Complete!"
echo "=========================================="
echo ""
echo "The app should now be able to:"
echo "  - Accept new user registrations"
echo "  - Handle database operations properly"
echo "  - Avoid connection pool exhaustion"
echo ""
echo "Monitor the logs with: make gigalixir-logs"
echo ""
