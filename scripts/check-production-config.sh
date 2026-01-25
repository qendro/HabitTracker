#!/bin/bash
# Check current production configuration on Gigalixir

set -e

echo "=========================================="
echo "Production Configuration Check"
echo "=========================================="
echo ""

# Load credentials
if [ ! -f .env.gigalixir ]; then
    echo "ERROR: .env.gigalixir file not found!"
    exit 1
fi

source .env.gigalixir

echo "App: $APP_NAME"
echo ""
echo "Checking current configuration..."
echo ""

docker compose -f docker/docker-compose.gigalixir.yml run --rm gigalixir bash -c "
  gigalixir login -e $GIGALIXIR_EMAIL -p $GIGALIXIR_API_KEY -y && \
  echo '===========================================' && \
  echo 'Current Environment Variables:' && \
  echo '===========================================' && \
  gigalixir config -a $APP_NAME && \
  echo '' && \
  echo '===========================================' && \
  echo 'App Status:' && \
  echo '===========================================' && \
  gigalixir ps -a $APP_NAME && \
  echo '' && \
  echo '===========================================' && \
  echo 'Database Info:' && \
  echo '===========================================' && \
  gigalixir pg -a $APP_NAME
"

echo ""
echo "=========================================="
echo "Configuration Check Complete"
echo "=========================================="
echo ""
echo "Look for POOL_SIZE in the environment variables above."
echo "It should be set to 2 for Gigalixir free tier."
echo ""
echo "If POOL_SIZE is missing or set to 1, run:"
echo "  make gigalixir-fix-db"
echo ""
