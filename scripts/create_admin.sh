#!/bin/bash
# Script to create an admin account for HabitTracker
# Usage: ./scripts/create_admin.sh [email] [password]

set -e

# If no arguments provided, prompt for them
if [ -z "$1" ]; then
  read -p "Enter admin email: " ADMIN_EMAIL
else
  ADMIN_EMAIL=$1
fi

if [ -z "$2" ]; then
  read -sp "Enter admin password: " ADMIN_PASSWORD
  echo ""
else
  ADMIN_PASSWORD=$2
fi

if [ -z "$ADMIN_EMAIL" ] || [ -z "$ADMIN_PASSWORD" ]; then
  echo "Error: Email and password are required"
  echo "Usage: ./scripts/create_admin.sh [email] [password]"
  exit 1
fi

echo "Creating admin account for: $ADMIN_EMAIL"

# Check if running with Docker
if command -v docker &> /dev/null && docker compose -f docker/docker-compose.yml ps 2>/dev/null | grep -q "web"; then
  docker compose -f docker/docker-compose.yml exec web mix create_admin "$ADMIN_EMAIL" "$ADMIN_PASSWORD"
else
  mix create_admin "$ADMIN_EMAIL" "$ADMIN_PASSWORD"
fi

echo ""
echo "You can now log in at: http://localhost:4000/admin/login"
