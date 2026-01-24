#!/bin/bash
# Run Database Migrations on Gigalixir
# Run this script inside the Gigalixir Docker container

set -e

# Colors
GREEN='\033[0;32m'
NC='\033[0m'

echo "=========================================="
echo "Running Database Migrations"
echo "=========================================="
echo ""

# Setup credentials
source /app/docker/scripts/gigalixir-setup.sh

echo ""
echo "Running migrations on $APP_NAME..."
gigalixir run -a "$APP_NAME" -- /app/bin/habit_tracker eval 'HabitTracker.Release.migrate()'

echo ""
echo -e "${GREEN}✓ Migrations started${NC}"
echo ""
echo "Check logs with:"
echo "  docker compose -f docker/docker-compose.gigalixir.yml run --rm gigalixir gigalixir logs -a $APP_NAME"
