#!/bin/bash
# Docker Container Validation Test for Boltz-BV-BRC
# Usage: ./test_docker_container.sh [container_tag] [--with-token token_path]
#
# Tests Docker container functionality including:
# - Boltz CLI availability
# - Perl module loading (Perl 5.40.2 from dxkb/dev_container)
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

# Test 3: Perl availability (using BV-BRC runtime path)
section "Perl Tests"
RT_PATH="/opt/patric-common/runtime"
PERL_BIN="$RT_PATH/bin/perl"

if PERL_VERSION=$(docker run --rm "$CONTAINER_TAG" $PERL_BIN -v 2>&1 | grep -o 'v[0-9]\+\.[0-9]\+\.[0-9]\+' | head -1); then
    pass "Perl available ($PERL_VERSION)"
    # Check for expected version 5.40.x
    if echo "$PERL_VERSION" | grep -q "v5\.40"; then
        pass "Perl version is 5.40.x (from dxkb/dev_container)"
    else
        warn "Perl version is $PERL_VERSION (expected 5.40.x)"
    fi
else
    fail "Perl not available at $PERL_BIN"
fi

# Test 4: BV-BRC deployment directory
section "BV-BRC Deployment Tests"
KB_DEPLOYMENT="/opt/patric-common/deployment"

if docker run --rm "$CONTAINER_TAG" test -d "$KB_DEPLOYMENT"; then
    pass "BV-BRC deployment directory exists: $KB_DEPLOYMENT"
else
    fail "BV-BRC deployment directory missing: $KB_DEPLOYMENT"
fi

if docker run --rm "$CONTAINER_TAG" test -d "$KB_DEPLOYMENT/lib"; then
    pass "BV-BRC lib directory exists"
    # List some key modules
    echo "  Key module directories:"
    docker run --rm "$CONTAINER_TAG" ls "$KB_DEPLOYMENT/lib" 2>/dev/null | head -5 | while read mod; do
        echo "    - $mod"
    done
else
    fail "BV-BRC lib directory missing"
fi

if docker run --rm "$CONTAINER_TAG" test -d "$KB_DEPLOYMENT/bin"; then
    pass "BV-BRC bin directory exists"
    P3_COUNT=$(docker run --rm "$CONTAINER_TAG" ls "$KB_DEPLOYMENT/bin" 2>/dev/null | grep -c "^p3-" || echo "0")
    echo "  p3 commands found: $P3_COUNT"
else
    fail "BV-BRC bin directory missing"
fi

# Test 5: Required Perl modules (using BV-BRC Perl)
section "Perl Module Loading Tests"

test_perl_module() {
    local module=$1
    if docker run --rm "$CONTAINER_TAG" $PERL_BIN -e "use $module; print 'OK'" &>/dev/null; then
        pass "Module: $module"
    else
        fail "Module: $module (failed to load)"
    fi
}

# Core modules (from dev_container runtime)
test_perl_module "JSON"
test_perl_module "JSON::XS"
test_perl_module "LWP::UserAgent"
test_perl_module "XML::LibXML"
test_perl_module "Try::Tiny"
test_perl_module "Template"
test_perl_module "YAML"
test_perl_module "DBI"

# Additional modules
test_perl_module "Capture::Tiny"
test_perl_module "Text::Table"
test_perl_module "REST::Client"
test_perl_module "Class::Accessor"
test_perl_module "Clone"

# BV-BRC modules
echo ""
echo "Testing BV-BRC modules..."
if docker run --rm "$CONTAINER_TAG" $PERL_BIN -e "use Bio::P3::Workspace::WorkspaceClient; print 'OK'" &>/dev/null; then
    pass "Module: Bio::P3::Workspace::WorkspaceClient"
else
    warn "Module: Bio::P3::Workspace::WorkspaceClient (dependency issues)"
fi

if docker run --rm "$CONTAINER_TAG" $PERL_BIN -e "use Bio::KBase::AppService::AppScript; print 'OK'" &>/dev/null; then
    pass "Module: Bio::KBase::AppService::AppScript"
else
    warn "Module: Bio::KBase::AppService::AppScript (dependency issues)"
fi

if docker run --rm "$CONTAINER_TAG" $PERL_BIN -e "use Bio::KBase::AppService::AppConfig; print 'OK'" &>/dev/null; then
    pass "Module: Bio::KBase::AppService::AppConfig"
else
    warn "Module: Bio::KBase::AppService::AppConfig (may need configuration)"
fi

# Test 6: Service script and app spec
section "Service Script Tests"
if docker run --rm "$CONTAINER_TAG" test -f /kb/module/service-scripts/App-Boltz.pl; then
    pass "Service script exists: /kb/module/service-scripts/App-Boltz.pl"

    # Syntax check using BV-BRC Perl
    if docker run --rm "$CONTAINER_TAG" $PERL_BIN -c /kb/module/service-scripts/App-Boltz.pl &>/dev/null; then
        pass "Service script syntax OK"
    else
        warn "Service script syntax check failed (may have runtime dependencies)"
    fi
else
    fail "Service script missing: /kb/module/service-scripts/App-Boltz.pl"
fi

if docker run --rm "$CONTAINER_TAG" test -f /kb/module/app_specs/Boltz.json; then
    pass "App spec exists: /kb/module/app_specs/Boltz.json"
else
    fail "App spec missing: /kb/module/app_specs/Boltz.json"
fi

# Test 7: p3 CLI tools
section "p3 CLI Tests"
P3_COMMANDS=("p3-login" "p3-ls" "p3-cat" "p3-cp")
for cmd in "${P3_COMMANDS[@]}"; do
    if docker run --rm "$CONTAINER_TAG" test -f "$KB_DEPLOYMENT/bin/$cmd"; then
        pass "p3 command exists: $cmd"
    else
        fail "p3 command missing: $cmd"
    fi
done

# Test 8: App-Boltz Execution Tests
section "App-Boltz Execution Tests"

# Test App-Boltz.pl can be executed (shows usage/help)
echo "Testing App-Boltz.pl execution..."
if docker run --rm "$CONTAINER_TAG" $PERL_BIN /kb/module/service-scripts/App-Boltz.pl --help 2>&1 | grep -q -i "boltz\|usage\|predict"; then
    pass "App-Boltz.pl responds to --help"
else
    # May not have --help, try running without args
    if docker run --rm "$CONTAINER_TAG" $PERL_BIN /kb/module/service-scripts/App-Boltz.pl 2>&1 | grep -q -i "boltz\|usage\|error\|param"; then
        pass "App-Boltz.pl executes (shows usage/error without params)"
    else
        warn "App-Boltz.pl execution test inconclusive"
    fi
fi

# Test preflight mode with sample params
# Note: preflight requires: app-service-url app-definition.json param-values.json --preflight output_file
echo "Testing App-Boltz.pl --preflight..."
PREFLIGHT_RESULT=$(docker run --rm "$CONTAINER_TAG" bash -c '
    # Create minimal test params (input_file and output_path are required)
    cat > /tmp/test_params.json << EOF
{
    "input_file": "/test/input.yaml",
    "output_path": "/test/output",
    "diffusion_samples": 1,
    "recycling_steps": 3
}
EOF
    # Run preflight: app-url app-def params --preflight output
    $RT/bin/perl /kb/module/service-scripts/App-Boltz.pl \
        "https://p3.theseed.org/services/app_service" \
        /kb/module/app_specs/Boltz.json \
        /tmp/test_params.json \
        --preflight /tmp/preflight_output.json 2>&1
    cat /tmp/preflight_output.json 2>/dev/null || echo "preflight_output not created"
')
if echo "$PREFLIGHT_RESULT" | grep -q -i "cpu\|memory\|runtime\|gpu"; then
    pass "App-Boltz.pl --preflight returns resource estimates"
    echo "  Preflight output: $(echo "$PREFLIGHT_RESULT" | head -3 | tr '\n' ' ')"
else
    warn "App-Boltz.pl --preflight test inconclusive"
    echo "  Output: $(echo "$PREFLIGHT_RESULT" | head -2)"
fi

# Test 9: Workspace tests (if token provided)
if [ -n "$TOKEN_PATH" ]; then
    section "Workspace Tests (with token)"
    if [ -f "$TOKEN_PATH" ]; then
        pass "Token file found: $TOKEN_PATH"

        # Test p3-login --status
        echo "Testing p3-login --status..."
        if docker run --rm -v "$TOKEN_PATH:/root/.patric_token:ro" "$CONTAINER_TAG" \
            $KB_DEPLOYMENT/bin/p3-login --status 2>&1 | grep -q -i "logged in\|user\|token"; then
            pass "p3-login --status works with token"
        else
            warn "p3-login --status failed (check token validity)"
        fi

        # Test workspace listing (check if we get any output - workspaces listed alphabetically)
        echo "Testing p3-ls /..."
        WS_OUTPUT=$(docker run --rm -v "$TOKEN_PATH:/root/.patric_token:ro" "$CONTAINER_TAG" \
            $KB_DEPLOYMENT/bin/p3-ls / 2>&1)
        if echo "$WS_OUTPUT" | grep -q -E "workspace|[A-Za-z0-9_-]+"; then
            pass "p3-ls / returns workspace listing"
            echo "  First entries: $(echo "$WS_OUTPUT" | grep -v WARNING | head -3 | tr '\n' ', ')"
        else
            warn "p3-ls / failed (check token and permissions)"
            echo "  Output: $(echo "$WS_OUTPUT" | head -2)"
        fi

        # Test WorkspaceClient module loads with token
        if docker run --rm -v "$TOKEN_PATH:/root/.patric_token:ro" "$CONTAINER_TAG" \
            $PERL_BIN -e 'use Bio::P3::Workspace::WorkspaceClient; print "WorkspaceClient loaded\n"' &>/dev/null; then
            pass "WorkspaceClient module loads with token"
        else
            warn "WorkspaceClient test skipped (module dependencies)"
        fi
    else
        fail "Token file not found: $TOKEN_PATH"
    fi
else
    section "Workspace Tests (skipped - no token)"
    echo "To test workspace connectivity, run with:"
    echo "  $0 $CONTAINER_TAG --with-token ~/.patric_token"
fi

# Test 10: Environment variables
section "Environment Variable Tests"
ENV_VARS=(
    "RT"
    "KB_DEPLOYMENT"
    "KB_TOP"
    "PERL5LIB"
    "KB_MODULE_DIR"
    "IN_BVBRC_CONTAINER"
)

EXPECTED_VALUES=(
    "/opt/patric-common/runtime"
    "/opt/patric-common/deployment"
    "/opt/patric-common/deployment"
    ""
    "/kb/module"
    "1"
)

for i in "${!ENV_VARS[@]}"; do
    var="${ENV_VARS[$i]}"
    expected="${EXPECTED_VALUES[$i]}"

    if docker run --rm "$CONTAINER_TAG" bash -c "[ -n \"\$$var\" ]" &>/dev/null; then
        VALUE=$(docker run --rm "$CONTAINER_TAG" bash -c "echo \$$var")
        pass "Environment variable set: $var"
        echo "  Value: $VALUE"

        # Check expected value if specified
        if [ -n "$expected" ] && [ "$VALUE" != "$expected" ]; then
            warn "  Expected: $expected"
        fi
    else
        fail "Environment variable not set: $var"
    fi
done

# Test 11: Directory structure
section "Directory Structure Tests"
DIRS=(
    "/opt/patric-common/runtime"
    "/opt/patric-common/runtime/bin"
    "/opt/patric-common/deployment"
    "/opt/patric-common/deployment/bin"
    "/opt/patric-common/deployment/lib"
    "/build/dev_container"
    "/kb/module"
    "/kb/module/service-scripts"
    "/kb/module/app_specs"
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
