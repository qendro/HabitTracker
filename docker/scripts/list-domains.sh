#!/bin/bash
# List Configured Domains on Gigalixir
# Run this script inside the Gigalixir Docker container

set -e

# Setup credentials
source /app/docker/scripts/gigalixir-setup.sh

echo "=========================================="
echo "Configured Domains for $APP_NAME"
echo "=========================================="
echo ""

gigalixir domains -a "$APP_NAME"

echo ""
echo "To add a domain: make gigalixir-domain"
echo "To remove a domain: make gigalixir-shell"
echo "  then run: gigalixir domains:remove APP_NAME DOMAIN"
