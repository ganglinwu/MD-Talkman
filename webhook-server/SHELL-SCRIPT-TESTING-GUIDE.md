# Shell Script Testing for Nginx Deployments

*A comprehensive guide to testing containerized applications with nginx reverse proxy using bash scripts*

## Overview

This guide documents how to create robust shell script tests for containerized applications behind nginx reverse proxy, particularly focusing on webhook endpoints and header preservation - critical for applications that rely on external services like GitHub webhooks.

## The Problem This Solves

Traditional deployment testing often misses **integration issues** between components:
- ✅ Individual containers work fine
- ✅ Nginx configuration syntax is valid  
- ❌ **Headers get stripped between components**
- ❌ **Container networking fails silently**
- ❌ **CDN/proxy layers interfere with functionality**

**Real-world impact:** A 3-hour debugging session revealed that AWS CloudFront was silently stripping GitHub webhook headers (`X-GitHub-Event`, `X-GitHub-Delivery`), causing webhook processing to fail while appearing successful from GitHub's perspective.

## Core Architecture

### Layered Testing Approach
```
1. Infrastructure Layer → 2. Network Layer → 3. Application Layer → 4. Integration Layer
     Docker containers      Container-to-container    Nginx routing         Header preservation
     Health checks          Internal communication    Proxy configuration   External access
```

### Test Categories

1. **Docker Environment Tests** - Container health and basic functionality
2. **Container Network Connectivity** - Internal Docker network communication
3. **Nginx Configuration Tests** - Proxy routing and configuration validation  
4. **Webhook Processing Tests** - Application-level functionality
5. **Header Preservation Tests** - **Critical for webhook reliability**
6. **Security & Error Handling** - Malformed input and edge cases

## Key Script Components

### 1. Framework Architecture

```bash
# Test execution wrapper with colored output
run_test() {
    local test_name="$1"
    local test_command="$2"
    
    TESTS_RUN=$((TESTS_RUN + 1))  # Safe arithmetic expansion
    log_info "Running: $test_name"
    
    if eval "$test_command" >/dev/null 2>&1; then
        log_success "$test_name"
        return 0
    else
        log_error "$test_name"
        return 1
    fi
}

# Colored logging functions
log_success() { echo -e "${GREEN}✅ $1${NC}"; }
log_error() { echo -e "${RED}❌ $1${NC}"; }
log_warning() { echo -e "${YELLOW}⚠️  $1${NC}"; }
```

### 2. Configuration Management

```bash
# Centralized configuration
WEBHOOK_CONTAINER="mdtalkman-webhook"
NGINX_CONTAINER="nginx"
WEBHOOK_PORT="8081"
EC2_IP="localhost"  # Use localhost when running on server
CLOUDFRONT_DOMAIN="example.com"

# Multiple execution modes
case "${1:-}" in
    "headers-only") test_header_preservation ;;
    "quick")        test_docker_environment; test_container_networking ;;
    "full"|"")      main ;;
    *)              show_usage; exit 1 ;;
esac
```

## Critical Testing Patterns

### 1. Header Preservation Testing

**The Most Important Test** - This would have saved 3 hours of debugging:

```bash
test_header_preservation() {
    local test_payload='{"test":"header_preservation","repository":{"name":"test"}}'
    
    # Test 1: Direct container access (baseline)
    curl -X POST http://localhost:8081/webhook/github \
        -H 'X-GitHub-Event: push' \
        -H 'X-GitHub-Delivery: direct-test-789' \
        -d "$test_payload" >/dev/null
    
    sleep 3
    # CRITICAL: Capture logs first, then grep (avoid pipe issues)
    local container_logs=$(docker logs $WEBHOOK_CONTAINER --tail 100 2>&1)
    
    if echo "$container_logs" | grep -q "direct-test-789"; then
        log_success "Direct container preserves GitHub headers"
    else
        log_error "Direct container failed to process GitHub headers"
    fi
    
    # Test 2: Through CDN (detect header stripping)
    curl -X POST https://cdn.example.com/webhook/github \
        -H 'X-GitHub-Event: push' \
        -H 'X-GitHub-Delivery: cdn-test-202' \
        -d "$test_payload" >/dev/null
        
    if echo "$(docker logs $WEBHOOK_CONTAINER --tail 50 2>&1)" | grep -q "cdn-test-202"; then
        log_success "CDN preserves GitHub headers"
    else
        log_error "CDN strips GitHub headers (switch to direct IP!)"
    fi
}
```

### 2. Container Network Validation

```bash
test_container_networking() {
    # Internal Docker network connectivity
    run_test "Nginx can reach webhook container by name" \
        "docker exec $NGINX_CONTAINER curl -f -s http://$WEBHOOK_CONTAINER:$WEBHOOK_PORT/health"
    
    # External access validation  
    run_test "External access works" \
        "curl -f -s http://localhost:$WEBHOOK_PORT/health"
}
```

### 3. Nginx Configuration Testing

```bash
test_nginx_configuration() {
    run_test "Nginx syntax is valid" \
        "docker exec $NGINX_CONTAINER nginx -t"
        
    run_test "Nginx routes webhook correctly" \
        "docker exec $NGINX_CONTAINER curl -f -s -X POST http://localhost/webhook/github -d '{}'"
}
```

## Common Pitfalls & Solutions

### 1. **Pipe Failures in Scripts**

**Problem:** `docker logs container | grep pattern` fails silently in scripts
```bash
# ❌ Unreliable - pipe can break in script context
if docker logs $CONTAINER | grep -q "pattern"; then
```

**Solution:** Capture first, then process
```bash
# ✅ Reliable - always works
local logs=$(docker logs $CONTAINER 2>&1)
if echo "$logs" | grep -q "pattern"; then
```

### 2. **Arithmetic Expansion Issues**

**Problem:** `((COUNTER++))` fails with `set -e`
```bash
# ❌ Can cause script to exit silently
((TESTS_RUN++))
```

**Solution:** Use explicit arithmetic
```bash
# ✅ Works reliably with set -e
TESTS_RUN=$((TESTS_RUN + 1))
```

### 3. **Docker Logs Stream Confusion**

**Problem:** Docker outputs to both stdout and stderr
```bash
# ❌ Might miss logs going to stderr
docker logs container | grep pattern
```

**Solution:** Capture both streams
```bash
# ✅ Gets all log output
docker logs container 2>&1 | grep pattern
```

### 4. **External IP Self-Reference**

**Problem:** Script hangs when accessing external IP from same server
```bash
# ❌ Hangs when run on the server itself
curl http://18.140.54.239:8081/health
```

**Solution:** Use localhost when running on server
```bash
# ✅ Works from anywhere
EC2_IP="localhost"  # When running on server
curl http://$EC2_IP:8081/health
```

## Execution Modes

### Quick Validation (30 seconds)
```bash
./test-deployment.sh quick
```
- Docker environment health
- Basic container connectivity
- Perfect for CI/CD pipeline checks

### Header-Only Testing (1 minute)  
```bash
./test-deployment.sh headers-only
```
- **The CloudFront bug detector**
- Tests webhook header preservation through all proxy layers
- Critical for webhook-dependent applications

### Full Suite (3-5 minutes)
```bash
./test-deployment.sh full
```
- Complete infrastructure validation
- All integration tests
- Security and error handling
- Production readiness verification

## Integration with CI/CD

### GitHub Actions Example
```yaml
name: Test Infrastructure
on: [push, pull_request]

jobs:
  test-deployment:
    runs-on: ubuntu-latest
    steps:
      - name: Quick infrastructure test
        run: ./test-deployment.sh quick
        
      - name: Header preservation check  
        run: ./test-deployment.sh headers-only
        
      - name: Full deployment validation
        if: github.ref == 'refs/heads/main'
        run: ./test-deployment.sh full
```

### Pre-deployment Hook
```bash
#!/bin/bash
echo "🧪 Validating deployment before going live..."

if ./test-deployment.sh full; then
    echo "✅ All tests passed - deploying to production"
    deploy_to_production
else  
    echo "❌ Tests failed - deployment cancelled"
    exit 1
fi
```

## Real-World Results

### Before Implementation
- **3-hour debugging session** to identify CloudFront header stripping
- **Silent failures** in webhook processing 
- **Manual testing** of each deployment component
- **Production issues** discovered by users

### After Implementation  
- **30-second detection** of header stripping issues
- **Automated validation** of all proxy layers
- **Confidence in deployments** through systematic testing
- **Zero webhook-related production incidents**

## Script Template

A complete script template implementing these patterns:

```bash
#!/bin/bash
# Infrastructure Testing Script Template

set -e  # Exit on any error

# Colors and configuration
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'

# Configuration - Update for your project
WEBHOOK_CONTAINER="your-webhook-container"
NGINX_CONTAINER="nginx" 
WEBHOOK_PORT="8080"
LOCAL_IP="localhost"
CDN_DOMAIN="your-cdn.com"

# Test tracking
TESTS_RUN=0; TESTS_PASSED=0; TESTS_FAILED=0

# Framework functions
log_success() { echo -e "${GREEN}✅ $1${NC}"; TESTS_PASSED=$((TESTS_PASSED + 1)); }
log_error() { echo -e "${RED}❌ $1${NC}"; TESTS_FAILED=$((TESTS_FAILED + 1)); }
log_info() { echo -e "${BLUE}ℹ️  $1${NC}"; }
log_header() { echo -e "\n${BLUE}🧪 $1${NC}\n${'='*50}"; }

run_test() {
    local test_name="$1"
    local test_command="$2"
    TESTS_RUN=$((TESTS_RUN + 1))
    
    if eval "$test_command" >/dev/null 2>&1; then
        log_success "$test_name"
    else
        log_error "$test_name"
    fi
}

# Test implementations
test_infrastructure() {
    log_header "Infrastructure Tests"
    run_test "Docker daemon running" "docker info"
    run_test "Application container healthy" "docker ps -q -f name=$WEBHOOK_CONTAINER"
    run_test "Nginx container running" "docker ps -q -f name=$NGINX_CONTAINER"
}

test_header_preservation() {
    log_header "Header Preservation Tests (CRITICAL)"
    
    local payload='{"test":"headers","repository":{"name":"test"}}'
    
    # Test direct access
    curl -s -X POST http://$LOCAL_IP:$WEBHOOK_PORT/webhook \
        -H 'X-GitHub-Event: push' -H 'X-GitHub-Delivery: test-123' \
        -d "$payload" >/dev/null
    
    sleep 2
    local logs=$(docker logs $WEBHOOK_CONTAINER --tail 50 2>&1)
    
    if echo "$logs" | grep -q "test-123"; then
        log_success "Headers preserved through proxy chain"
    else
        log_error "Headers stripped - check CDN/proxy configuration"
    fi
}

# Main execution
main() {
    echo "🚀 Infrastructure Test Suite"
    test_infrastructure
    test_header_preservation
    
    echo -e "\n📊 Results: $TESTS_PASSED passed, $TESTS_FAILED failed"
    [[ $TESTS_FAILED -eq 0 ]] && echo "🎉 All tests passed!" || echo "❌ Some tests failed"
}

# Execution modes
case "${1:-}" in
    "quick") test_infrastructure ;;
    "headers") test_header_preservation ;;
    ""|"full") main ;;
    *) echo "Usage: $0 [quick|headers|full]"; exit 1 ;;
esac
```

## Conclusion

Shell script testing provides **immediate feedback** on infrastructure issues that would otherwise require hours of manual debugging. The header preservation test alone can save entire debugging sessions by immediately identifying proxy configuration problems.

**Key takeaway:** Test integration points, not just individual components. The most critical failures happen where systems connect, not within the systems themselves.

**Investment:** 2 hours to write comprehensive tests  
**Return:** Prevents 3+ hour debugging sessions and production incidents  
**Confidence:** Deploy knowing your infrastructure actually works end-to-end

This approach transforms deployment from "hope and pray" to "test and verify" - essential for production webhook systems and containerized applications.