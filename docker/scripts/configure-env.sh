#!/bin/bash
set -e

# Configure production environment variables on Gigalixir
# This script sets all required environment variables for email functionality

echo "=========================================="
echo "Configuring Gigalixir Environment"
echo "=========================================="
echo ""

# Check if required variables are set
if [ -z "$GIGALIXIR_EMAIL" ] || [ -z "$GIGALIXIR_API_KEY" ] || [ -z "$APP_NAME" ]; then
    echo "Error: Required environment variables not set"
    echo "Please ensure .env.gigalixir contains:"
    echo "  - GIGALIXIR_EMAIL"
    echo "  - GIGALIXIR_API_KEY"
    echo "  - APP_NAME"
    exit 1
fi

# Login to Gigalixir
echo "Logging in to Gigalixir..."
gigalixir login -e "$GIGALIXIR_EMAIL" -p "$GIGALIXIR_API_KEY" -y

# Set Resend API Key
if [ -n "$RESEND_API_KEY" ]; then
    echo "Setting RESEND_API_KEY..."
    gigalixir config:set -a "$APP_NAME" RESEND_API_KEY="$RESEND_API_KEY"
else
    echo "Warning: RESEND_API_KEY not set in .env.gigalixir"
fi

# Set Sender Email
echo "Setting SENDER_EMAIL..."
SENDER_EMAIL="${SENDER_EMAIL:-noreply@habbits.xyz}"
gigalixir config:set -a "$APP_NAME" SENDER_EMAIL="$SENDER_EMAIL"

# Set App URL
echo "Setting APP_URL..."
APP_URL="${APP_URL:-https://habbits.xyz}"
gigalixir config:set -a "$APP_NAME" APP_URL="$APP_URL"

# Set PHX_HOST if not already set
echo "Setting PHX_HOST..."
PHX_HOST="${PHX_HOST:-habbits.xyz}"
gigalixir config:set -a "$APP_NAME" PHX_HOST="$PHX_HOST"

echo ""
echo "=========================================="
echo "Configuration Complete!"
echo "=========================================="
echo ""
echo "Current configuration:"
gigalixir config -a "$APP_NAME"
echo ""
echo "Note: App will restart automatically to apply changes"
