#!/bin/bash
# Setup Custom Domain on Gigalixir
# Run this script inside the Gigalixir Docker container

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo "=========================================="
echo "Setup Custom Domain"
echo "=========================================="
echo ""

# Setup credentials
source /app/docker/scripts/gigalixir-setup.sh

# Get domain from user
echo "Enter your custom domain (e.g., habbits.xyz):"
read -r CUSTOM_DOMAIN

if [ -z "$CUSTOM_DOMAIN" ]; then
    echo "Error: Domain cannot be empty"
    exit 1
fi

echo ""
echo -e "${BLUE}Setting up domain: $CUSTOM_DOMAIN${NC}"
echo ""

# Add domain to Gigalixir
echo "Adding domain to Gigalixir..."
gigalixir domains:add "$APP_NAME" "$CUSTOM_DOMAIN"

# Add www subdomain
echo ""
echo "Adding www subdomain..."
gigalixir domains:add "$APP_NAME" "www.$CUSTOM_DOMAIN"

# Update environment variables
echo ""
echo "Updating environment variables..."
gigalixir config:set -a "$APP_NAME" PHX_HOST="$CUSTOM_DOMAIN"
gigalixir config:set -a "$APP_NAME" APP_URL="https://$CUSTOM_DOMAIN"
gigalixir config:set -a "$APP_NAME" SENDER_EMAIL="noreply@$CUSTOM_DOMAIN"

# Show DNS configuration
echo ""
echo "=========================================="
echo -e "${GREEN}✓ Domain Configuration Complete!${NC}"
echo "=========================================="
echo ""
echo -e "${YELLOW}IMPORTANT: Configure your DNS settings${NC}"
echo ""
echo "Add these DNS records at your domain registrar:"
echo ""
echo "1. Root domain (@):"
echo "   Type:  CNAME"
echo "   Name:  @"
echo "   Value: $APP_NAME.gigalixirapp.com"
echo "   TTL:   3600"
echo ""
echo "2. WWW subdomain:"
echo "   Type:  CNAME"
echo "   Name:  www"
echo "   Value: $APP_NAME.gigalixirapp.com"
echo "   TTL:   3600"
echo ""
echo -e "${BLUE}Note: Some registrars don't allow CNAME for root domain.${NC}"
echo "If that's the case, use these A records instead:"
echo ""
echo "Get the IP address:"
echo "  nslookup $APP_NAME.gigalixirapp.com"
echo ""
echo "Then create:"
echo "   Type:  A"
echo "   Name:  @"
echo "   Value: [IP address from nslookup]"
echo "   TTL:   3600"
echo ""
echo "=========================================="
echo ""
echo "After DNS propagation (can take up to 48 hours):"
echo "  - Your app will be available at: https://$CUSTOM_DOMAIN"
echo "  - SSL certificate will be automatically provisioned"
echo ""
echo "Check DNS propagation:"
echo "  nslookup $CUSTOM_DOMAIN"
echo ""
echo "Check domain status:"
echo "  make gigalixir-domains"
echo ""
echo "Restart app after DNS is configured:"
echo "  make gigalixir-restart"
echo ""
