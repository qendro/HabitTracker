#!/bin/bash
set -e

# Check email configuration on Gigalixir
# This script verifies that all required environment variables are set

echo "=========================================="
echo "Checking Email Configuration"
echo "=========================================="
echo ""

# Check if required variables are set
if [ -z "$APP_NAME" ]; then
    echo "Error: APP_NAME not set"
    exit 1
fi

# Setup credentials
source /app/docker/scripts/gigalixir-setup.sh

echo ""
echo "Current configuration for $APP_NAME:"
echo "=========================================="
gigalixir config -a "$APP_NAME"

echo ""
echo "=========================================="
echo "Checking Required Variables:"
echo "=========================================="

# Check each required variable
check_var() {
    local var_name=$1
    if gigalixir config -a "$APP_NAME" | grep -q "^$var_name"; then
        echo "✓ $var_name is set"
    else
        echo "✗ $var_name is NOT set"
    fi
}

check_var "RESEND_API_KEY"
check_var "SENDER_EMAIL"
check_var "APP_URL"
check_var "PHX_HOST"
check_var "DATABASE_URL"
check_var "SECRET_KEY_BASE"

echo ""
echo "=========================================="
echo "Checking Oban Jobs:"
echo "=========================================="
echo "Connecting to remote console to check Oban status..."
echo ""
echo "Run this command manually to check Oban:"
echo "  gigalixir ps:remote_console -a $APP_NAME"
echo ""
echo "Then in the console, run:"
echo "  Oban.check_queue(queue: :emails)"
echo "  Oban.check_queue(queue: :default)"
echo ""
