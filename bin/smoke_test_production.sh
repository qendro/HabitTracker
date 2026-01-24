#!/bin/bash
# Production Smoke Test Script for Habit Tracker
# This script runs automated smoke tests against the production environment

set -e  # Exit on error

echo "=========================================="
echo "Habit Tracker - Production Smoke Tests"
echo "=========================================="
echo ""

# Configuration
APP_NAME="habit-tracker-prod"
BASE_URL="https://$APP_NAME.gigalixirapp.com"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Test counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Helper functions
print_success() {
    echo -e "${GREEN}✓ $1${NC}"
    TESTS_PASSED=$((TESTS_PASSED + 1))
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
    TESTS_FAILED=$((TESTS_FAILED + 1))
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

print_info() {
    echo "ℹ $1"
}

run_test() {
    TESTS_RUN=$((TESTS_RUN + 1))
    echo ""
    print_info "Test $TESTS_RUN: $1"
}

# Check if curl is installed
if ! command -v curl &> /dev/null; then
    print_error "curl is not installed"
    exit 1
fi

# Production warning
echo ""
print_warning "⚠️  PRODUCTION SMOKE TESTS ⚠️"
echo "These tests will run against the PRODUCTION environment."
echo "They are read-only and will not modify any data."
echo ""
read -p "Continue? (y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    print_info "Tests cancelled"
    exit 0
fi

echo ""
print_info "Running smoke tests against: $BASE_URL"
echo ""

# Test 1: Health endpoint
run_test "Health endpoint responding"
if curl -f -s "$BASE_URL/health" > /dev/null; then
    RESPONSE=$(curl -s "$BASE_URL/health")
    if echo "$RESPONSE" | grep -q "healthy"; then
        print_success "Health endpoint is healthy"
    else
        print_error "Health endpoint returned unexpected response"
    fi
else
    print_error "Health endpoint is not responding"
fi

# Test 2: Homepage loads
run_test "Homepage loads"
if curl -f -s "$BASE_URL/" > /dev/null; then
    print_success "Homepage loads successfully"
else
    print_error "Homepage failed to load"
fi

# Test 3: Registration page loads
run_test "Registration page loads"
if curl -f -s "$BASE_URL/users/register" > /dev/null; then
    print_success "Registration page loads"
else
    print_error "Registration page failed to load"
fi

# Test 4: Login page loads
run_test "Login page loads"
if curl -f -s "$BASE_URL/users/log_in" > /dev/null; then
    print_success "Login page loads"
else
    print_error "Login page failed to load"
fi

# Test 5: Admin login page loads
run_test "Admin login page loads"
if curl -f -s "$BASE_URL/admin/login" > /dev/null; then
    print_success "Admin login page loads"
else
    print_error "Admin login page failed to load"
fi

# Test 6: SSL certificate is valid
run_test "SSL certificate is valid"
if curl -f -s --head "$BASE_URL" | grep -q "HTTP/2 200"; then
    print_success "SSL certificate is valid"
else
    print_warning "Could not verify SSL certificate"
fi

# Test 7: Static assets load
run_test "Static assets load"
if curl -f -s "$BASE_URL/assets/app.css" > /dev/null; then
    print_success "CSS assets load"
else
    print_error "CSS assets failed to load"
fi

if curl -f -s "$BASE_URL/assets/app.js" > /dev/null; then
    print_success "JS assets load"
else
    print_error "JS assets failed to load"
fi

# Test 8: Database connection (via health endpoint)
run_test "Database connection working"
HEALTH_RESPONSE=$(curl -s "$BASE_URL/health")
if echo "$HEALTH_RESPONSE" | grep -q "healthy"; then
    print_success "Database connection is working"
else
    print_error "Database connection may be failing"
fi

# Test 9: Response time is acceptable
run_test "Response time is acceptable"
START_TIME=$(date +%s%N)
curl -f -s "$BASE_URL/" > /dev/null
END_TIME=$(date +%s%N)
RESPONSE_TIME=$(( (END_TIME - START_TIME) / 1000000 ))

if [ $RESPONSE_TIME -lt 2000 ]; then
    print_success "Response time is good (${RESPONSE_TIME}ms)"
elif [ $RESPONSE_TIME -lt 5000 ]; then
    print_warning "Response time is acceptable but slow (${RESPONSE_TIME}ms)"
else
    print_error "Response time is too slow (${RESPONSE_TIME}ms)"
fi

# Test 10: Security headers present
run_test "Security headers present"
HEADERS=$(curl -s -I "$BASE_URL/")

if echo "$HEADERS" | grep -qi "x-frame-options"; then
    print_success "X-Frame-Options header present"
else
    print_warning "X-Frame-Options header missing"
fi

if echo "$HEADERS" | grep -qi "x-content-type-options"; then
    print_success "X-Content-Type-Options header present"
else
    print_warning "X-Content-Type-Options header missing"
fi

if echo "$HEADERS" | grep -qi "strict-transport-security"; then
    print_success "Strict-Transport-Security header present"
else
    print_warning "Strict-Transport-Security header missing"
fi

# Display results
echo ""
echo "=========================================="
echo "Smoke Test Results"
echo "=========================================="
echo ""
echo "Tests Run:    $TESTS_RUN"
echo -e "Tests Passed: ${GREEN}$TESTS_PASSED${NC}"
echo -e "Tests Failed: ${RED}$TESTS_FAILED${NC}"
echo ""

if [ $TESTS_FAILED -eq 0 ]; then
    print_success "All smoke tests passed!"
    echo ""
    echo "Next steps:"
    echo "  1. Test critical user flows manually"
    echo "  2. Create admin account"
    echo "  3. Monitor logs for errors"
    echo "  4. Set up uptime monitoring"
    echo "  5. Configure custom domain (if applicable)"
    echo ""
    exit 0
else
    print_error "Some smoke tests failed"
    echo ""
    echo "Please investigate the failures before proceeding:"
    echo "  - Check application logs: gigalixir logs -a $APP_NAME"
    echo "  - Verify environment variables: gigalixir config -a $APP_NAME"
    echo "  - Check application status: gigalixir ps -a $APP_NAME"
    echo ""
    exit 1
fi
