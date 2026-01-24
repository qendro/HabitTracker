#!/bin/bash
# Restart Gigalixir App

set -e

echo "=========================================="
echo "Restarting App"
echo "=========================================="
echo ""

# Setup credentials
source /app/docker/scripts/gigalixir-setup.sh

echo ""
echo "Restarting $APP_NAME..."
gigalixir ps:restart -a "$APP_NAME"

echo ""
echo "✓ App restarted"
echo ""
echo "Check status with:"
echo "  make gigalixir-status"
