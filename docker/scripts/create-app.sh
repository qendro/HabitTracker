#!/bin/bash
# Create Gigalixir App and Database
# Run this script inside the Gigalixir Docker container

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo "=========================================="
echo "Creating Gigalixir App"
echo "=========================================="
echo ""

# Setup credentials
source /app/docker/scripts/gigalixir-setup.sh

# Check if app already exists
echo ""
echo "Checking if app exists..."
if gigalixir apps | grep -q "$APP_NAME"; then
    echo -e "${YELLOW}App '$APP_NAME' already exists${NC}"
    read -p "Continue with existing app? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
else
    # Create app
    echo "Creating app '$APP_NAME'..."
    gigalixir create -n "$APP_NAME"
    echo -e "${GREEN}✓ App created${NC}"
fi

# Check if database exists
echo ""
echo "Checking database..."
if gigalixir pg -a "$APP_NAME" | grep -q "AVAILABLE"; then
    echo -e "${GREEN}✓ Database already exists${NC}"
else
    echo "Creating database..."
    echo "Note: Free tier database is not suitable for production"
    gigalixir pg:create --free -a "$APP_NAME" <<< "y"
    echo -e "${GREEN}✓ Database created${NC}"
    sleep 5
fi

# Generate and set environment variables
echo ""
echo "Configuring environment variables..."

# Generate SECRET_KEY_BASE
SECRET_KEY_BASE=$(openssl rand -base64 64 | tr -d '\n')

# Set all required variables
gigalixir config:set -a "$APP_NAME" SECRET_KEY_BASE="$SECRET_KEY_BASE"
gigalixir config:set -a "$APP_NAME" PHX_HOST="$APP_NAME.gigalixirapp.com"
gigalixir config:set -a "$APP_NAME" APP_URL="https://$APP_NAME.gigalixirapp.com"
gigalixir config:set -a "$APP_NAME" POOL_SIZE="10"
gigalixir config:set -a "$APP_NAME" SENDER_EMAIL="noreply@$APP_NAME.gigalixirapp.com"

echo -e "${GREEN}✓ Environment variables configured${NC}"

# Show current config
echo ""
echo "Current configuration:"
gigalixir config -a "$APP_NAME"

echo ""
echo "=========================================="
echo -e "${GREEN}✓ Setup Complete!${NC}"
echo "=========================================="
echo ""
echo "Next steps:"
echo "  1. Deploy your app:     docker compose -f docker/docker-compose.gigalixir.yml run --rm gigalixir /app/docker/scripts/deploy.sh"
echo "  2. Run migrations:      docker compose -f docker/docker-compose.gigalixir.yml run --rm gigalixir /app/docker/scripts/migrate.sh"
echo "  3. Create admin:        docker compose -f docker/docker-compose.gigalixir.yml run --rm gigalixir /app/docker/scripts/create-admin.sh"
echo ""
