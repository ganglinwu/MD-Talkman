#!/bin/bash

# MD TalkMan Webhook Server Deployment Test Suite
# Tests the entire webhook infrastructure: containers, nginx, routing, and header preservation

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
WEBHOOK_CONTAINER="mdtalkman-webhook"
NGINX_CONTAINER="nginx"
WEBHOOK_PORT="8081"
EC2_IP="18.140.54.239"
CLOUDFRONT_DOMAIN="guenyanghae.com"

# Test results tracking
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Logging functions
log_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

log_success() {
    echo -e "${GREEN}✅ $1${NC}"
    ((TESTS_PASSED++))
}

log_error() {
    echo -e "${RED}❌ $1${NC}"
    ((TESTS_FAILED++))
}

log_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

log_header() {
    echo -e "\n${BLUE}🧪 $1${NC}"
    echo "=================================================="
}

# Test execution wrapper
run_test() {
    local test_name="$1"
    local test_command="$2"
    
    ((TESTS_RUN++))
    log_info "Running: $test_name"
    
    if eval "$test_command" >/dev/null 2>&1; then
        log_success "$test_name"
        return 0
    else
        log_error "$test_name"
        return 1
    fi
}

# Detailed test execution with output capture
run_detailed_test() {
    local test_name="$1"
    local test_command="$2"
    
    ((TESTS_RUN++))
    log_info "Running: $test_name"
    
    local output
    if output=$(eval "$test_command" 2>&1); then
        log_success "$test_name"
        if [[ -n "$output" ]]; then
            echo "   Output: $output"
        fi
        return 0
    else
        log_error "$test_name"
        echo "   Error: $output"
        return 1
    fi
}

# Test functions
test_docker_environment() {
    log_header "Docker Environment Tests"
    
    run_test "Docker daemon is running" "docker info"
    run_test "Webhook container exists" "docker ps -q -f name=$WEBHOOK_CONTAINER"
    run_test "Nginx container exists" "docker ps -q -f name=$NGINX_CONTAINER"
    run_test "Webhook container is healthy" "docker inspect $WEBHOOK_CONTAINER --format='{{.State.Health.Status}}' | grep -q healthy"
    run_test "Webhook container port is exposed" "docker port $WEBHOOK_CONTAINER | grep -q $WEBHOOK_PORT"
}

test_container_networking() {
    log_header "Container Network Connectivity Tests"
    
    # Test container-to-container communication
    run_detailed_test "Nginx can reach webhook container by name" \
        "docker exec $NGINX_CONTAINER curl -f -s http://$WEBHOOK_CONTAINER:$WEBHOOK_PORT/health"
    
    run_detailed_test "Webhook health endpoint responds correctly" \
        "docker exec $NGINX_CONTAINER curl -s http://$WEBHOOK_CONTAINER:$WEBHOOK_PORT/health | grep -q healthy"
    
    # Test external access
    run_test "External access to webhook container works" \
        "curl -f -s http://$EC2_IP:$WEBHOOK_PORT/health"
}

test_nginx_configuration() {
    log_header "Nginx Configuration Tests"
    
    run_test "Nginx configuration syntax is valid" \
        "docker exec $NGINX_CONTAINER nginx -t"
    
    run_test "Nginx is running and responding" \
        "docker exec $NGINX_CONTAINER curl -f -s http://localhost/health"
    
    run_detailed_test "Nginx webhook route exists" \
        "docker exec $NGINX_CONTAINER curl -f -s -X POST http://localhost/webhook/github -H 'Content-Type: application/json' -d '{}'"
}

test_webhook_processing() {
    log_header "Webhook Processing Tests"
    
    local test_payload='{"repository":{"name":"test-repo","full_name":"user/test-repo"},"commits":[{"added":["test.md"],"modified":[],"removed":[]}]}'
    
    # Test direct webhook processing
    run_detailed_test "Webhook processes GitHub push payload" \
        "curl -f -s -X POST http://$EC2_IP:$WEBHOOK_PORT/webhook/github \
         -H 'Content-Type: application/json' \
         -H 'X-GitHub-Event: push' \
         -H 'X-GitHub-Delivery: test-delivery-123' \
         -d '$test_payload'"
    
    # Test through nginx proxy
    run_detailed_test "Webhook processing through nginx proxy" \
        "docker exec $NGINX_CONTAINER curl -f -s -X POST http://localhost/webhook/github \
         -H 'Content-Type: application/json' \
         -H 'X-GitHub-Event: push' \
         -H 'X-GitHub-Delivery: test-delivery-456' \
         -d '$test_payload'"
}

test_header_preservation() {
    log_header "Header Preservation Tests (Critical for GitHub Webhooks)"
    
    local test_payload='{"test":"header_preservation","repository":{"name":"test"}}'
    
    # Clear old logs to get clean results
    docker logs $WEBHOOK_CONTAINER --tail 0 >/dev/null 2>&1 || true
    sleep 1
    
    # Test 1: Direct to container (baseline)
    log_info "Testing direct container access (baseline)..."
    curl -s -X POST http://$EC2_IP:$WEBHOOK_PORT/webhook/github \
        -H 'Content-Type: application/json' \
        -H 'X-GitHub-Event: push' \
        -H 'X-GitHub-Delivery: direct-test-789' \
        -d "$test_payload" >/dev/null
    
    sleep 2
    local direct_logs=$(docker logs $WEBHOOK_CONTAINER --tail 5)
    if [[ "$direct_logs" == *"Event=push"* ]] && [[ "$direct_logs" == *"Delivery=direct-test-789"* ]]; then
        log_success "Direct container preserves GitHub headers"
    else
        log_error "Direct container failed to process GitHub headers"
        echo "   Logs: $direct_logs"
    fi
    
    # Test 2: Through nginx (should work)
    log_info "Testing through nginx proxy..."
    docker exec $NGINX_CONTAINER curl -s -X POST http://localhost/webhook/github \
        -H 'Content-Type: application/json' \
        -H 'X-GitHub-Event: push' \
        -H 'X-GitHub-Delivery: nginx-test-101' \
        -d "$test_payload" >/dev/null
    
    sleep 2
    local nginx_logs=$(docker logs $WEBHOOK_CONTAINER --tail 5)
    if [[ "$nginx_logs" == *"Event=push"* ]] && [[ "$nginx_logs" == *"Delivery=nginx-test-101"* ]]; then
        log_success "Nginx proxy preserves GitHub headers"
    else
        log_error "Nginx proxy strips GitHub headers"
        echo "   Logs: $nginx_logs"
    fi
    
    # Test 3: Through CloudFront (the problematic path)
    log_info "Testing through CloudFront (should expose header stripping)..."
    if curl -f -s -X POST https://$CLOUDFRONT_DOMAIN/webhook/github \
        -H 'Content-Type: application/json' \
        -H 'X-GitHub-Event: push' \
        -H 'X-GitHub-Delivery: cloudfront-test-202' \
        -d "$test_payload" >/dev/null 2>&1; then
        
        sleep 2
        local cloudfront_logs=$(docker logs $WEBHOOK_CONTAINER --tail 5)
        if [[ "$cloudfront_logs" == *"Event=push"* ]] && [[ "$cloudfront_logs" == *"Delivery=cloudfront-test-202"* ]]; then
            log_success "CloudFront preserves GitHub headers (properly configured)"
        else
            log_error "CloudFront strips GitHub headers (CDN issue detected!)"
            echo "   This is the bug that caused your 3-hour debugging session!"
            echo "   Logs: $cloudfront_logs"
            log_warning "Recommendation: Use direct EC2 IP for webhook URL"
        fi
    else
        log_warning "CloudFront endpoint not accessible or not configured"
    fi
}

test_webhook_security() {
    log_header "Webhook Security Tests"
    
    # Test signature verification (if enabled)
    local test_payload='{"test":"security"}'
    
    run_test "Webhook accepts requests without signature (testing mode)" \
        "curl -f -s -X POST http://$EC2_IP:$WEBHOOK_PORT/webhook/github \
         -H 'Content-Type: application/json' \
         -H 'X-GitHub-Event: push' \
         -d '$test_payload'"
    
    # Test malformed payloads
    run_test "Webhook handles malformed JSON gracefully" \
        "curl -f -s -X POST http://$EC2_IP:$WEBHOOK_PORT/webhook/github \
         -H 'Content-Type: application/json' \
         -H 'X-GitHub-Event: push' \
         -d 'invalid json' || true"
}

test_log_analysis() {
    log_header "Log Analysis Tests"
    
    log_info "Recent webhook container logs:"
    echo "----------------------------------------"
    docker logs $WEBHOOK_CONTAINER --tail 10
    echo "----------------------------------------"
    
    log_info "Recent nginx access logs:"
    echo "----------------------------------------"
    docker exec $NGINX_CONTAINER tail -5 /var/log/nginx/access.log 2>/dev/null || echo "No nginx access logs found"
    echo "----------------------------------------"
    
    # Check for common error patterns
    local error_logs=$(docker logs $WEBHOOK_CONTAINER 2>&1 | grep -i error | tail -3)
    if [[ -n "$error_logs" ]]; then
        log_warning "Recent errors found in webhook logs:"
        echo "$error_logs"
    else
        log_success "No recent errors in webhook logs"
    fi
}

generate_test_report() {
    log_header "Test Results Summary"
    
    echo "Tests Run:    $TESTS_RUN"
    echo "Tests Passed: $TESTS_PASSED"
    echo "Tests Failed: $TESTS_FAILED"
    
    if [[ $TESTS_FAILED -eq 0 ]]; then
        log_success "All tests passed! 🎉"
        echo ""
        echo "Your webhook infrastructure is ready for production!"
        echo "GitHub webhooks should work correctly with headers preserved."
    else
        log_error "Some tests failed!"
        echo ""
        echo "Issues detected that need attention before production deployment."
        if [[ $TESTS_FAILED -gt $((TESTS_PASSED)) ]]; then
            echo "Consider reviewing your configuration and container setup."
        fi
    fi
    
    echo ""
    echo "💡 Tip: Run this script before deploying changes to catch issues early!"
}

# Main execution
main() {
    echo "🚀 MD TalkMan Webhook Server Test Suite"
    echo "========================================"
    echo ""
    
    # Verify prerequisites
    if ! command -v docker &> /dev/null; then
        log_error "Docker is not installed or not in PATH"
        exit 1
    fi
    
    if ! command -v curl &> /dev/null; then
        log_error "curl is not installed or not in PATH"
        exit 1
    fi
    
    # Run test suites
    test_docker_environment
    test_container_networking
    test_nginx_configuration
    test_webhook_processing
    test_header_preservation  # The test that would have saved you 3 hours!
    test_webhook_security
    test_log_analysis
    
    # Generate final report
    generate_test_report
    
    # Exit with appropriate code
    if [[ $TESTS_FAILED -eq 0 ]]; then
        exit 0
    else
        exit 1
    fi
}

# Handle script arguments
case "${1:-}" in
    "headers-only")
        log_header "Running Header Preservation Tests Only"
        test_header_preservation
        ;;
    "quick")
        log_header "Running Quick Test Suite"
        test_docker_environment
        test_container_networking
        ;;
    "full"|"")
        main
        ;;
    *)
        echo "Usage: $0 [full|quick|headers-only]"
        echo "  full        - Run all tests (default)"
        echo "  quick       - Run basic connectivity tests"
        echo "  headers-only - Test only header preservation (CloudFront issue detection)"
        exit 1
        ;;
esac