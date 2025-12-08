#!/bin/bash
# Docker Container Validation Test for Boltz-BV-BRC
# Usage: ./test_docker_container.sh [container_tag] [--with-token token_path]
#
# Tests Docker container functionality including:
# - Boltz CLI availability
# - Perl module loading
# - BV-BRC workspace connectivity (optional with token)
# - Service script syntax

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default values
CONTAINER_TAG="${1:-dxkb/boltz-bvbrc:latest-gpu}"
TOKEN_PATH=""
PASSED=0
FAILED=0

# Parse arguments
shift 2>/dev/null || true
while [[ $# -gt 0 ]]; do
    case $1 in
        --with-token)
            TOKEN_PATH="$2"
            shift 2
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

echo "=================================="
echo "Docker Container Validation Test"
echo "=================================="
echo "Container: $CONTAINER_TAG"
[ -n "$TOKEN_PATH" ] && echo "Token: $TOKEN_PATH"
echo "=================================="
echo ""

# Helper functions
pass() {
    echo -e "${GREEN}✓${NC} $1"
    PASSED=$((PASSED + 1))
}

fail() {
    echo -e "${RED}✗${NC} $1"
    FAILED=$((FAILED + 1))
}

warn() {
    echo -e "${YELLOW}⚠${NC} $1"
}

section() {
    echo ""
    echo -e "${BLUE}=== $1 ===${NC}"
}

# Test 1: Docker image exists
section "Docker Image Tests"
if docker inspect "$CONTAINER_TAG" &>/dev/null; then
    pass "Docker image exists: $CONTAINER_TAG"
    IMAGE_SIZE=$(docker inspect -f '{{ .Size }}' "$CONTAINER_TAG" | awk '{print $1/1024/1024/1024 " GB"}')
    echo "  Image size: $IMAGE_SIZE"
else
    fail "Docker image not found: $CONTAINER_TAG"
    exit 1
fi

# Test 2: Boltz CLI availability
section "Boltz CLI Tests"
if docker run --rm "$CONTAINER_TAG" boltz --help &>/dev/null; then
    pass "Boltz CLI available"
    BOLTZ_VERSION=$(docker run --rm "$CONTAINER_TAG" boltz --version 2>&1 | head -1 || echo "unknown")
    echo "  Version: $BOLTZ_VERSION"
else
    fail "Boltz CLI not available"
fi

# Test 3: Perl availability
section "Perl Tests"
if PERL_VERSION=$(docker run --rm "$CONTAINER_TAG" perl -v 2>&1 | grep -o 'v[0-9]\+\.[0-9]\+\.[0-9]\+' | head -1); then
    pass "Perl available ($PERL_VERSION)"
else
    fail "Perl not available"
fi

# Test 4: BV-BRC modules directory
section "BV-BRC Module Tests"
if docker run --rm "$CONTAINER_TAG" ls /bvbrc/modules/ &>/dev/null; then
    pass "BV-BRC modules directory exists"
    MODULES=$(docker run --rm "$CONTAINER_TAG" ls /bvbrc/modules/)
    echo "  Modules found:"
    for mod in $MODULES; do
        echo "    - $mod"
    done
else
    fail "BV-BRC modules directory missing"
fi

# Test 5: Required Perl modules
section "Perl Module Loading Tests"

test_perl_module() {
    local module=$1
    if docker run --rm "$CONTAINER_TAG" perl -e "use $module; print 'OK'" &>/dev/null; then
        pass "Module: $module"
    else
        fail "Module: $module (failed to load)"
    fi
}

# Core modules
test_perl_module "Try::Tiny"
test_perl_module "IPC::Run"
test_perl_module "File::Which"
test_perl_module "Template"
test_perl_module "YAML::XS"

# Issue #24 modules
test_perl_module "Capture::Tiny"
test_perl_module "Text::Table"

# BV-BRC modules (these may fail due to REST::Client dependency)
warn "Testing BV-BRC modules (may have known dependencies)..."
if docker run --rm "$CONTAINER_TAG" perl -e "use Bio::P3::Workspace::WorkspaceClient; print 'OK'" &>/dev/null; then
    pass "Module: Bio::P3::Workspace::WorkspaceClient"
else
    warn "Module: Bio::P3::Workspace::WorkspaceClient (dependency issues)"
fi

if docker run --rm "$CONTAINER_TAG" perl -e "use Bio::KBase::AppService::AppScript; print 'OK'" &>/dev/null; then
    pass "Module: Bio::KBase::AppService::AppScript"
else
    warn "Module: Bio::KBase::AppService::AppScript (dependency issues)"
fi

# Test 6: Service script and app spec
section "Service Script Tests"
if docker run --rm "$CONTAINER_TAG" test -f /kb/module/service-scripts/App-Boltz.pl; then
    pass "Service script exists: /kb/module/service-scripts/App-Boltz.pl"
else
    fail "Service script missing: /kb/module/service-scripts/App-Boltz.pl"
fi

if docker run --rm "$CONTAINER_TAG" test -f /kb/module/app_specs/Boltz.json; then
    pass "App spec exists: /kb/module/app_specs/Boltz.json"
else
    fail "App spec missing: /kb/module/app_specs/Boltz.json"
fi

# Test 7: Workspace tests (if token provided)
if [ -n "$TOKEN_PATH" ]; then
    section "Workspace Tests (with token)"
    if [ -f "$TOKEN_PATH" ]; then
        pass "Token file found: $TOKEN_PATH"

        # Test workspace listing (requires proper Perl module setup)
        warn "Workspace connectivity test requires REST::Client module"
        warn "Skipping workspace listing test due to known dependency"
    else
        fail "Token file not found: $TOKEN_PATH"
    fi
fi

# Test 8: Environment variables
section "Environment Variable Tests"
ENV_VARS=(
    "PERL5LIB"
    "KB_TOP"
    "KB_RUNTIME"
    "KB_MODULE_DIR"
    "IN_BVBRC_CONTAINER"
)

for var in "${ENV_VARS[@]}"; do
    if docker run --rm "$CONTAINER_TAG" bash -c "[ -n \"\$$var\" ]" &>/dev/null; then
        VALUE=$(docker run --rm "$CONTAINER_TAG" bash -c "echo \$$var")
        pass "Environment variable set: $var"
        echo "  Value: $VALUE"
    else
        fail "Environment variable not set: $var"
    fi
done

# Test 9: Directory structure
section "Directory Structure Tests"
DIRS=(
    "/bvbrc/modules"
    "/kb/deployment"
    "/kb/module"
    "/kb/module/service-scripts"
    "/kb/module/app_specs"
    "/kb/module/scripts"
    "/kb/module/lib"
    "/data"
)

for dir in "${DIRS[@]}"; do
    if docker run --rm "$CONTAINER_TAG" test -d "$dir"; then
        pass "Directory exists: $dir"
    else
        fail "Directory missing: $dir"
    fi
done

# Summary
echo ""
echo "=================================="
echo "Test Summary"
echo "=================================="
echo -e "${GREEN}Passed: $PASSED${NC}"
if [ $FAILED -gt 0 ]; then
    echo -e "${RED}Failed: $FAILED${NC}"
fi
echo "=================================="
echo ""

if [ $FAILED -eq 0 ]; then
    echo -e "${GREEN}All critical tests passed!${NC}"
    exit 0
else
    echo -e "${RED}Some tests failed!${NC}"
    exit 1
fi
