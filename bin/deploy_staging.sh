#!/bin/bash
# Staging Deployment Script for Habit Tracker
# This script automates the deployment process to Gigalixir staging environment

set -e  # Exit on error

echo "=========================================="
echo "Habit Tracker - Staging Deployment"
echo "=========================================="
echo ""

# Configuration
APP_NAME="habit-tracker-staging"
GIT_REMOTE="gigalixir-staging"
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
    read -p "Do you want to create a free database? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        print_info "Creating database..."
        gigalixir pg:create --free -a "$APP_NAME"
        print_success "Database created"
        sleep 5  # Wait for database to be ready
    else
        print_error "Database is required for deployment"
        exit 1
    fi
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
    print_warning "You have uncommitted changes"
    read -p "Do you want to continue anyway? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_error "Deployment cancelled"
        exit 1
    fi
fi

# Check environment variables
print_info "Checking required environment variables..."
REQUIRED_VARS=("SECRET_KEY_BASE" "PHX_HOST")
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
                    print_info "Setting PHX_HOST to $APP_NAME.gigalixirapp.com..."
                    gigalixir config:set -a "$APP_NAME" PHX_HOST="$APP_NAME.gigalixirapp.com"
                    print_success "PHX_HOST set"
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

# Optional environment variables
print_info "Checking optional environment variables..."
OPTIONAL_VARS=("RESEND_API_KEY" "SENDER_EMAIL" "SENTRY_DSN" "POOL_SIZE")

for var in "${OPTIONAL_VARS[@]}"; do
    if ! gigalixir config -a "$APP_NAME" | grep -q "$var"; then
        print_warning "Optional variable $var is not set"
    fi
done

# Run pre-deployment checks
echo ""
print_info "Running pre-deployment checks..."

# Check if tests pass
print_info "Running tests..."
if mix test --max-failures 1; then
    print_success "Tests passed"
else
    print_error "Tests failed"
    read -p "Do you want to continue anyway? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_error "Deployment cancelled"
        exit 1
    fi
fi

# Check if code compiles
print_info "Checking compilation..."
if mix compile --warnings-as-errors; then
    print_success "Code compiles without warnings"
else
    print_error "Compilation failed or has warnings"
    read -p "Do you want to continue anyway? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_error "Deployment cancelled"
        exit 1
    fi
fi

# Deploy to staging
echo ""
print_info "Deploying to staging..."
print_info "This may take several minutes..."

if git push "$GIT_REMOTE" "$BRANCH"; then
    print_success "Code pushed to Gigalixir"
else
    print_error "Failed to push code"
    exit 1
fi

# Wait for deployment to complete
print_info "Waiting for deployment to complete..."
sleep 10

# Check application status
print_info "Checking application status..."
if gigalixir ps -a "$APP_NAME" | grep -q "Healthy"; then
    print_success "Application is healthy"
else
    print_warning "Application may not be healthy yet"
    print_info "Check logs with: gigalixir logs -a $APP_NAME"
fi

# Test health endpoint
echo ""
print_info "Testing health endpoint..."
HEALTH_URL="https://$APP_NAME.gigalixirapp.com/health"
if curl -f -s "$HEALTH_URL" > /dev/null; then
    print_success "Health endpoint is responding"
    echo "Response: $(curl -s "$HEALTH_URL")"
else
    print_warning "Health endpoint is not responding yet"
    print_info "It may take a few more minutes for the app to start"
fi

# Display deployment information
echo ""
echo "=========================================="
echo "Deployment Complete!"
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
echo ""
echo "Next steps:"
echo "  1. Run smoke tests (see bin/smoke_test_staging.sh)"
echo "  2. Create admin account (see ADMIN_SETUP.md)"
echo "  3. Test critical user flows"
echo "  4. Monitor logs for errors"
echo ""
