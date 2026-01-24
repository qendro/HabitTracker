#!/bin/bash
# Create Admin Account on Gigalixir
# Run this script inside the Gigalixir Docker container

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "=========================================="
echo "Create Admin Account"
echo "=========================================="
echo ""

# Setup credentials
source /app/docker/scripts/gigalixir-setup.sh

# Prompt for admin credentials
echo "Enter admin email (default: admin@habbits.xyz):"
read -r ADMIN_EMAIL
ADMIN_EMAIL=${ADMIN_EMAIL:-admin@habbits.xyz}

echo "Enter admin password (minimum 8 characters):"
read -rs ADMIN_PASSWORD

if [ -z "$ADMIN_PASSWORD" ]; then
    echo -e "${YELLOW}Error: Password cannot be empty${NC}"
    exit 1
fi

echo ""
echo "Creating admin account..."
gigalixir run -a "$APP_NAME" -- /app/bin/habit_tracker eval "HabitTracker.Admin.register_admin(%{email: \"$ADMIN_EMAIL\", password: \"$ADMIN_PASSWORD\"})"

echo ""
echo -e "${GREEN}✓ Admin account creation started${NC}"
echo ""
echo "Admin credentials:"
echo "  Email: $ADMIN_EMAIL"
echo "  Password: [hidden]"
echo ""
echo "Login at: https://$APP_NAME.gigalixirapp.com/admin/login"
echo ""
echo "Check logs with:"
echo "  docker compose -f docker/docker-compose.gigalixir.yml run --rm gigalixir gigalixir logs -a $APP_NAME"
