#!/bin/bash
# Fix database connection pool size for Gigalixir free tier

echo "Fixing database connection pool size..."
echo ""
echo "Gigalixir free tier PostgreSQL has a connection limit of 4."
echo "Your app needs to reduce POOL_SIZE to avoid exhausting connections."
echo ""
echo "Run this command:"
echo ""
echo "docker compose -f docker/docker-compose.gigalixir.yml run --rm gigalixir bash -c '"
echo "  gigalixir login -e habbits.xyz@gmail.com -p 1250baa7-4cf6-4a8c-9546-ce151a1e061c -y && "
echo "  gigalixir config:set -a habit-tracker-prod POOL_SIZE=2"
echo "'"
echo ""
echo "This will set the connection pool to 2, leaving room for migrations and other operations."
