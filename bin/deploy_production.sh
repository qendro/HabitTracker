#!/bin/bash
# Production Deployment Script for Habit Tracker
# This script automates the deployment process to Gigalixir production environment

set -e  # Exit on error

echo "=========================================="
echo "Habit Tracker - Production Deployment"
echo "=========================================="
echo ""

# Configuration
APP_NAME="habit-tracker-prod"
GIT_REMOTE="gigalixir"
BRANCH="main"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Helper functions
print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

print_info() {
    echo "ℹ $1"
}

# Check if Gigalixir CLI is installed
if ! command -v gigalixir &> /dev/null; then
    print_error "Gigalixir CLI is not installed"
    echo "Install it with: pip3 install gigalixir --user"
    exit 1
fi
print_success "Gigalixir CLI is installed"

# Check if logged in to Gigalixir
if ! gigalixir account &> /dev/null; then
    print_error "Not logged in to Gigalixir"
    echo "Login with: gigalixir login"
    exit 1
fi
print_success "Logged in to Gigalixir"

# Production safety check
echo ""
print_warning "⚠️  PRODUCTION DEPLOYMENT WARNING ⚠️"
echo "You are about to deploy to PRODUCTION environment."
echo "This will affect real users and live data."
echo ""
read -p "Have you tested this in staging? (yes/no) " -r
echo
if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
    print_error "Please test in staging first before deploying to production"
    exit 1
fi

read -p "Are you sure you want to deploy to PRODUCTION? (yes/no) " -r
echo
if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
    print_error "Deployment cancelled"
    exit 1
fi

# Check if app exists
if ! gigalixir apps | grep -q "$APP_NAME"; then
    print_warning "App '$APP_NAME' does not exist"
    read -p "Do you want to create it? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        print_info "Creating app '$APP_NAME'..."
        gigalixir create "$APP_NAME"
        print_success "App created"
    else
        print_error "Deployment cancelled"
        exit 1
    fi
else
    print_success "App '$APP_NAME' exists"
fi

# Check if database exists
print_info "Checking database status..."
if ! gigalixir pg -a "$APP_NAME" &> /dev/null; then
    print_warning "No database found for '$APP_NAME'"
    echo ""
    echo "Database tier options:"
    echo "  1) Standard (4 GB) - Recommended for production"
    echo "  2) Free (0.6 GB) - Not recommended for production"
    echo ""
    read -p "Select database tier (1 or 2): " -n 1 -r
    echo
    case $REPLY in
        1)
            print_info "Creating standard database (4 GB)..."
            gigalixir pg:create --size=4 -a "$APP_NAME"
            print_success "Database created"
            ;;
        2)
            print_warning "Creating free database (not recommended for production)..."
            gigalixir pg:create --free -a "$APP_NAME"
            print_success "Database created"
            ;;
        *)
            print_error "Invalid selection"
            exit 1
            ;;
    esac
    sleep 5  # Wait for database to be ready
else
    print_success "Database exists"
fi

# Check if git remote exists
if ! git remote | grep -q "$GIT_REMOTE"; then
    print_warning "Git remote '$GIT_REMOTE' does not exist"
    print_info "Adding git remote..."
    REMOTE_URL=$(gigalixir apps:info -a "$APP_NAME" | grep "Git URL" | awk '{print $3}')
    if [ -z "$REMOTE_URL" ]; then
        # Fallback to standard format
        REMOTE_URL="https://git.gigalixir.com/$APP_NAME.git"
    fi
    git remote add "$GIT_REMOTE" "$REMOTE_URL"
    print_success "Git remote added"
else
    print_success "Git remote '$GIT_REMOTE' exists"
fi

# Check for uncommitted changes
if ! git diff-index --quiet HEAD --; then
    print_error "You have uncommitted changes"
    echo "Please commit or stash your changes before deploying to production"
    exit 1
fi
print_success "No uncommitted changes"

# Check environment variables
print_info "Checking required environment variables..."
REQUIRED_VARS=("SECRET_KEY_BASE" "PHX_HOST" "APP_URL" "POOL_SIZE")
MISSING_VARS=()

for var in "${REQUIRED_VARS[@]}"; do
    if ! gigalixir config -a "$APP_NAME" | grep -q "$var"; then
        MISSING_VARS+=("$var")
    fi
done

if [ ${#MISSING_VARS[@]} -ne 0 ]; then
    print_warning "Missing environment variables: ${MISSING_VARS[*]}"
    read -p "Do you want to configure them now? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        for var in "${MISSING_VARS[@]}"; do
            case $var in
                SECRET_KEY_BASE)
                    print_info "Generating SECRET_KEY_BASE..."
                    SECRET=$(mix phx.gen.secret)
                    gigalixir config:set -a "$APP_NAME" SECRET_KEY_BASE="$SECRET"
                    print_success "SECRET_KEY_BASE set"
                    ;;
                PHX_HOST)
                    print_info "Setting PHX_HOST..."
                    read -p "Enter your domain (e.g., habittracker.com or $APP_NAME.gigalixirapp.com): " DOMAIN
                    gigalixir config:set -a "$APP_NAME" PHX_HOST="$DOMAIN"
                    print_success "PHX_HOST set to $DOMAIN"
                    ;;
                APP_URL)
                    print_info "Setting APP_URL..."
                    read -p "Enter your full app URL (e.g., https://habittracker.com): " URL
                    gigalixir config:set -a "$APP_NAME" APP_URL="$URL"
                    print_success "APP_URL set to $URL"
                    ;;
                POOL_SIZE)
                    print_info "Setting POOL_SIZE to 10..."
                    gigalixir config:set -a "$APP_NAME" POOL_SIZE="10"
                    print_success "POOL_SIZE set"
                    ;;
            esac
        done
    else
        print_error "Environment variables must be configured before deployment"
        exit 1
    fi
else
    print_success "All required environment variables are set"
fi

# Check critical optional environment variables
print_info "Checking critical optional environment variables..."
CRITICAL_OPTIONAL=("RESEND_API_KEY" "SENDER_EMAIL" "SENTRY_DSN")
MISSING_CRITICAL=()

for var in "${CRITICAL_OPTIONAL[@]}"; do
    if ! gigalixir config -a "$APP_NAME" | grep -q "$var"; then
        MISSING_CRITICAL+=("$var")
    fi
done

if [ ${#MISSING_CRITICAL[@]} -ne 0 ]; then
    print_warning "Missing critical optional variables: ${MISSING_CRITICAL[*]}"
    echo "These are highly recommended for production:"
    echo "  - RESEND_API_KEY: Required for email functionality"
    echo "  - SENDER_EMAIL: Required for email functionality"
    echo "  - SENTRY_DSN: Required for error tracking"
    read -p "Do you want to continue without these? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_error "Deployment cancelled"
        exit 1
    fi
fi

# Run pre-deployment checks
echo ""
print_info "Running pre-deployment checks..."

# Check if tests pass
print_info "Running tests..."
if mix test --max-failures 1; then
    print_success "Tests passed"
else
    print_error "Tests failed"
    echo "Production deployment requires all tests to pass"
    exit 1
fi

# Check if code compiles
print_info "Checking compilation..."
if mix compile --warnings-as-errors; then
    print_success "Code compiles without warnings"
else
    print_error "Compilation failed or has warnings"
    echo "Production deployment requires clean compilation"
    exit 1
fi

# Final confirmation
echo ""
print_warning "FINAL CONFIRMATION"
echo "You are about to deploy to PRODUCTION:"
echo "  App: $APP_NAME"
echo "  Branch: $BRANCH"
echo "  URL: https://$APP_NAME.gigalixirapp.com"
echo ""
read -p "Type 'DEPLOY' to confirm: " -r
echo
if [[ ! $REPLY == "DEPLOY" ]]; then
    print_error "Deployment cancelled"
    exit 1
fi

# Deploy to production
echo ""
print_info "Deploying to production..."
print_info "This may take several minutes..."

if git push "$GIT_REMOTE" "$BRANCH"; then
    print_success "Code pushed to Gigalixir"
else
    print_error "Failed to push code"
    exit 1
fi

# Wait for deployment to complete
print_info "Waiting for deployment to complete..."
sleep 15

# Check application status
print_info "Checking application status..."
MAX_RETRIES=6
RETRY_COUNT=0
while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
    if gigalixir ps -a "$APP_NAME" | grep -q "Healthy"; then
        print_success "Application is healthy"
        break
    else
        RETRY_COUNT=$((RETRY_COUNT + 1))
        if [ $RETRY_COUNT -lt $MAX_RETRIES ]; then
            print_info "Waiting for app to become healthy... (attempt $RETRY_COUNT/$MAX_RETRIES)"
            sleep 10
        else
            print_warning "Application may not be healthy yet"
            print_info "Check logs with: gigalixir logs -a $APP_NAME"
        fi
    fi
done

# Test health endpoint
echo ""
print_info "Testing health endpoint..."
HEALTH_URL="https://$APP_NAME.gigalixirapp.com/health"
MAX_RETRIES=6
RETRY_COUNT=0
while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
    if curl -f -s "$HEALTH_URL" > /dev/null; then
        print_success "Health endpoint is responding"
        echo "Response: $(curl -s "$HEALTH_URL")"
        break
    else
        RETRY_COUNT=$((RETRY_COUNT + 1))
        if [ $RETRY_COUNT -lt $MAX_RETRIES ]; then
            print_info "Waiting for health endpoint... (attempt $RETRY_COUNT/$MAX_RETRIES)"
            sleep 10
        else
            print_error "Health endpoint is not responding"
            print_info "Check logs with: gigalixir logs -a $APP_NAME"
            exit 1
        fi
    fi
done

# Display deployment information
echo ""
echo "=========================================="
echo "✅ Production Deployment Complete!"
echo "=========================================="
echo ""
echo "Application URL: https://$APP_NAME.gigalixirapp.com"
echo "Health Check: https://$APP_NAME.gigalixirapp.com/health"
echo ""
echo "Useful commands:"
echo "  View logs:        gigalixir logs -a $APP_NAME"
echo "  Check status:     gigalixir ps -a $APP_NAME"
echo "  View config:      gigalixir config -a $APP_NAME"
echo "  Run migrations:   gigalixir run -a $APP_NAME -- bin/habit_tracker eval 'HabitTracker.Release.migrate()'"
echo "  Remote console:   gigalixir ps:remote_console -a $APP_NAME"
echo "  Rollback:         gigalixir releases:rollback -a $APP_NAME"
echo ""
echo "⚠️  CRITICAL NEXT STEPS:"
echo "  1. Verify health endpoint is responding"
echo "  2. Test user registration and login"
echo "  3. Test habit creation and logging"
echo "  4. Create admin account (see ADMIN_SETUP.md)"
echo "  5. Monitor error rates in Sentry"
echo "  6. Set up uptime monitoring (UptimeRobot, Pingdom, etc.)"
echo "  7. Configure custom domain (if applicable)"
echo "  8. Test email delivery (registration, password reset)"
echo "  9. Monitor logs for the first hour"
echo "  10. Document any issues or observations"
echo ""
print_success "Production deployment successful!"
echo ""
