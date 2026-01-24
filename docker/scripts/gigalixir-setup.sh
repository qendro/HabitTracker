#!/bin/bash
# Gigalixir Setup Script
# Configures Gigalixir credentials inside Docker container

set -e

echo "Setting up Gigalixir credentials..."

# Check if credentials are set
if [ -z "$GIGALIXIR_EMAIL" ] || [ -z "$GIGALIXIR_API_KEY" ]; then
    echo "Error: GIGALIXIR_EMAIL and GIGALIXIR_API_KEY must be set"
    echo "Please set them in .env.gigalixir file"
    exit 1
fi

# Configure .netrc for Gigalixir authentication
mkdir -p ~/.netrc
cat > ~/.netrc << EOF
machine api.gigalixir.com
  login $GIGALIXIR_EMAIL
  password $GIGALIXIR_API_KEY
machine git.gigalixir.com
  login $GIGALIXIR_EMAIL
  password $GIGALIXIR_API_KEY
EOF
chmod 600 ~/.netrc

# Configure git
git config --global user.email "$GIGALIXIR_EMAIL"
git config --global user.name "Habit Tracker Deploy"
git config --global --add safe.directory /app

echo "✓ Gigalixir credentials configured"
echo "✓ Git configured"

# Test connection
echo ""
echo "Testing Gigalixir connection..."
gigalixir account

echo ""
echo "✓ Setup complete!"
