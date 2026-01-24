#!/bin/bash
# Smoke Test Script for Staging Environment
# This script runs basic smoke tests against the staging deployment

set -e

# Configuration
APP_NAME="habit-tracker-staging"
BASE_URL="https://$APP_NAME.gigalixirapp.com"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Test counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Helper functions
print_success() {
    echo -e "${GREEN}✓ $1${NC}"
    ((TESTS_PASSED++))
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
    ((TESTS_FAILED++))
}

print_info() {
    echo -e "${BLUE}ℹ $1${NC}"
}

print_test() {
    echo -e "${YELLOW}→ $1${NC}"
    ((TESTS_RUN++))
}

# Test functions
test_health_endpoint() {
    print_test "Testing health endpoint"
    
    response=$(curl -s -w "\n%{http_code}" "$BASE_URL/health")
    http_code=$(echo "$response" | tail -n1)
    body=$(echo "$response" | head -n-1)
    
    if [ "$http_code" = "200" ]; then
        print_success "Health endpoint returned 200 OK"
        echo "  Response: $body"
    else
        print_error "Health endpoint returned $http_code"
        echo "  Response: $body"
    fi
}

test_homepage() {
    print_test "Testing homepage"
    
    http_code=$(curl -s -o /dev/null -w "%{http_code}" "$BASE_URL/")
    
    if [ "$http_code" = "200" ]; then
        print_success "Homepage is accessible"
    else
        print_error "Homepage returned $http_code"
    fi
}

test_registration_page() {
    print_test "Testing registration page"
    
    http_code=$(curl -s -o /dev/null -w "%{http_code}" "$BASE_URL/users/register")
    
    if [ "$http_code" = "200" ]; then
        print_success "Registration page is accessible"
    else
        print_error "Registration page returned $http_code"
    fi
}

test_login_page() {
    print_test "Testing login page"
    
    http_code=$(curl -s -o /dev/null -w "%{http_code}" "$BASE_URL/users/log_in")
    
    if [ "$http_code" = "200" ]; then
        print_success "Login page is accessible"
    else
        print_error "Login page returned $http_code"
    fi
}

test_admin_login_page() {
    print_test "Testing admin login page"
    
    http_code=$(curl -s -o /dev/null -w "%{http_code}" "$BASE_URL/admin/login")
    
    if [ "$http_code" = "200" ]; then
        print_success "Admin login page is accessible"
    else
        print_error "Admin login page returned $http_code"
    fi
}

test_ssl_certificate() {
    print_test "Testing SSL certificate"
    
    if curl -s --head "$BASE_URL" | grep -q "HTTP/2 200\|HTTP/1.1 200"; then
        print_success "SSL certificate is valid"
    else
        print_error "SSL certificate issue detected"
    fi
}

test_static_assets() {
    print_test "Testing static assets"
    
    # Test if CSS is loading
    http_code=$(curl -s -o /dev/null -w "%{http_code}" "$BASE_URL/assets/app.css")
    
    if [ "$http_code" = "200" ]; then
        print_success "Static assets are loading"
    else
        print_error "Static assets returned $http_code"
    fi
}

test_database_connection() {
    print_test "Testing database connection"
    
    # The health endpoint should verify database connectivity
    response=$(curl -s "$BASE_URL/health")
    
    if echo "$response" | grep -q "healthy\|ok"; then
        print_success "Database connection is working"
    else
        print_error "Database connection may be failing"
    fi
}

test_response_time() {
    print_test "Testing response time"
    
    response_time=$(curl -s -o /dev/null -w "%{time_total}" "$BASE_URL/")
    
    # Convert to milliseconds for easier reading
    response_time_ms=$(echo "$response_time * 1000" | bc)
    
    if (( $(echo "$response_time < 2.0" | bc -l) )); then
        print_success "Response time is acceptable (${response_time_ms}ms)"
    else
        print_error "Response time is slow (${response_time_ms}ms)"
    fi
}

test_security_headers() {
    print_test "Testing security headers"
    
    headers=$(curl -s -I "$BASE_URL/")
    
    if echo "$headers" | grep -q "x-frame-options\|X-Frame-Options"; then
        print_success "Security headers are present"
    else
        print_error "Security headers may be missing"
    fi
}

# Main execution
echo "=========================================="
echo "Habit Tracker - Staging Smoke Tests"
echo "=========================================="
echo ""
echo "Testing: $BASE_URL"
echo ""

# Run all tests
test_health_endpoint
test_homepage
test_registration_page
test_login_page
test_admin_login_page
test_ssl_certificate
test_static_assets
test_database_connection
test_response_time
test_security_headers

# Print summary
echo ""
echo "=========================================="
echo "Test Summary"
echo "=========================================="
echo "Tests Run:    $TESTS_RUN"
echo -e "Tests Passed: ${GREEN}$TESTS_PASSED${NC}"
echo -e "Tests Failed: ${RED}$TESTS_FAILED${NC}"
echo ""

if [ $TESTS_FAILED -eq 0 ]; then
    echo -e "${GREEN}All smoke tests passed!${NC}"
    echo ""
    echo "Next steps:"
    echo "  1. Create a test user account"
    echo "  2. Test habit creation and logging"
    echo "  3. Test admin functionality"
    echo "  4. Monitor application logs"
    echo "  5. Check Sentry for errors (if configured)"
    echo ""
    exit 0
else
    echo -e "${RED}Some tests failed. Please investigate.${NC}"
    echo ""
    echo "Troubleshooting:"
    echo "  View logs:    gigalixir logs -a $APP_NAME"
    echo "  Check status: gigalixir ps -a $APP_NAME"
    echo "  Check config: gigalixir config -a $APP_NAME"
    echo ""
    exit 1
fi
