#!/bin/bash
# GPU Acceptance Test Suite for BoltzApp
# Target: H100 GPU with Apptainer/Singularity
#
# MAIN FOCUS: Testing App-Boltz.pl - the BV-BRC service script
#
# Usage: ./gpu_acceptance_test.sh <container.sif> [options]
#
# Options:
#   --with-token <path>   Path to .patric_token for workspace tests
#   --quick               Skip actual predictions (container validation only)
#   --skip-msa            Disable MSA server (faster but less accurate)
#   --output-dir <path>   Directory for test outputs (default: ./gpu_test_output)
#
# Tests performed:
#   1. GPU access and CUDA detection
#   2. Container integrity (Boltz CLI, Perl, BV-BRC modules)
#   3. App-Boltz.pl service script execution (MAIN FOCUS)
#      - Parameter parsing from JSON
#      - Input file handling (local fallback mode)
#      - Format detection (YAML/FASTA)
#      - Boltz execution with correct flags
#      - Output file generation
#   4. Preflight resource estimation validation
#   5. Workspace connectivity (if token provided)
#   6. Direct boltz CLI comparison (optional)
#   7. Performance baseline recording
#
# Exit codes:
#   0 - All tests passed
#   1 - One or more tests failed

set -o pipefail

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Test counters
PASSED=0
FAILED=0
WARNED=0
SKIPPED=0

# Configuration
CONTAINER_PATH=""
TOKEN_PATH=""
QUICK_MODE=false
SKIP_MSA=false
OUTPUT_DIR="./gpu_test_output"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEST_DATA_DIR="$SCRIPT_DIR/../test_data"
LOG_FILE=""
START_TIME=""

# Helper functions
pass() {
    echo -e "${GREEN}[PASS]${NC} $1"
    PASSED=$((PASSED + 1))
    echo "[PASS] $1" >> "$LOG_FILE"
}

fail() {
    echo -e "${RED}[FAIL]${NC} $1"
    FAILED=$((FAILED + 1))
    echo "[FAIL] $1" >> "$LOG_FILE"
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
    WARNED=$((WARNED + 1))
    echo "[WARN] $1" >> "$LOG_FILE"
}

skip() {
    echo -e "${CYAN}[SKIP]${NC} $1"
    SKIPPED=$((SKIPPED + 1))
    echo "[SKIP] $1" >> "$LOG_FILE"
}

section() {
    echo ""
    echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}  $1${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
    echo "" >> "$LOG_FILE"
    echo "=== $1 ===" >> "$LOG_FILE"
}

log() {
    echo "$1" >> "$LOG_FILE"
}

usage() {
    echo "Usage: $0 <container.sif> [options]"
    echo ""
    echo "Options:"
    echo "  --with-token <path>   Path to .patric_token for workspace tests"
    echo "  --quick               Skip actual predictions (container validation only)"
    echo "  --skip-msa            Disable MSA server (faster but less accurate)"
    echo "  --output-dir <path>   Directory for test outputs (default: ./gpu_test_output)"
    echo "  --help                Show this help message"
    exit 1
}

# Parse arguments
parse_args() {
    if [ $# -eq 0 ]; then
        usage
    fi

    CONTAINER_PATH="$1"
    shift

    while [[ $# -gt 0 ]]; do
        case $1 in
            --with-token)
                TOKEN_PATH="$2"
                shift 2
                ;;
            --quick)
                QUICK_MODE=true
                shift
                ;;
            --skip-msa)
                SKIP_MSA=true
                shift
                ;;
            --output-dir)
                OUTPUT_DIR="$2"
                shift 2
                ;;
            --help)
                usage
                ;;
            *)
                echo "Unknown option: $1"
                usage
                ;;
        esac
    done
}

# Detect container runtime (singularity or apptainer)
detect_runtime() {
    if command -v apptainer &>/dev/null; then
        CONTAINER_CMD="apptainer"
    elif command -v singularity &>/dev/null; then
        CONTAINER_CMD="singularity"
    else
        fail "Neither singularity nor apptainer command found"
        exit 1
    fi
    pass "Container runtime detected: $CONTAINER_CMD"
}

# Setup test environment
setup_environment() {
    section "Setup"

    START_TIME=$(date +%s)
    mkdir -p "$OUTPUT_DIR"
    LOG_FILE="$OUTPUT_DIR/gpu_acceptance_results.log"

    # Initialize log file
    echo "GPU Acceptance Test Results" > "$LOG_FILE"
    echo "============================" >> "$LOG_FILE"
    echo "Date: $(date)" >> "$LOG_FILE"
    echo "Container: $CONTAINER_PATH" >> "$LOG_FILE"
    echo "Quick mode: $QUICK_MODE" >> "$LOG_FILE"
    echo "Skip MSA: $SKIP_MSA" >> "$LOG_FILE"
    [ -n "$TOKEN_PATH" ] && echo "Token: $TOKEN_PATH" >> "$LOG_FILE"
    echo "" >> "$LOG_FILE"

    echo "Output directory: $OUTPUT_DIR"
    echo "Log file: $LOG_FILE"
    pass "Test environment initialized"
}

# Test GPU access
test_gpu_access() {
    section "GPU Access Tests"

    # Test nvidia-smi accessibility
    if $CONTAINER_CMD exec --nv "$CONTAINER_PATH" nvidia-smi &>/dev/null; then
        pass "nvidia-smi accessible in container"

        # Get GPU info
        GPU_INFO=$($CONTAINER_CMD exec --nv "$CONTAINER_PATH" nvidia-smi --query-gpu=name,memory.total --format=csv,noheader 2>/dev/null || echo "unknown")
        echo "  GPU: $GPU_INFO"
        log "GPU Info: $GPU_INFO"

        # Check for H100
        if echo "$GPU_INFO" | grep -qi "H100"; then
            pass "H100 GPU detected"
        elif echo "$GPU_INFO" | grep -qi "A100"; then
            pass "A100 GPU detected (expected H100)"
        else
            warn "Expected H100 GPU, found: $GPU_INFO"
        fi

        # Check GPU memory
        GPU_MEM=$($CONTAINER_CMD exec --nv "$CONTAINER_PATH" nvidia-smi --query-gpu=memory.total --format=csv,noheader,nounits 2>/dev/null | head -1 || echo "0")
        if [ "${GPU_MEM:-0}" -ge 40000 ]; then
            pass "GPU memory sufficient: ${GPU_MEM}MB"
        else
            warn "GPU memory may be insufficient: ${GPU_MEM}MB (recommended: 40GB+)"
        fi
    else
        fail "nvidia-smi not accessible (GPU not available or --nv flag not working)"
        return 1
    fi

    # Test CUDA library
    if $CONTAINER_CMD exec --nv "$CONTAINER_PATH" python3 -c "import torch; print(f'CUDA available: {torch.cuda.is_available()}')" 2>/dev/null | grep -q "True"; then
        pass "PyTorch CUDA support functional"
        CUDA_VERSION=$($CONTAINER_CMD exec --nv "$CONTAINER_PATH" python3 -c "import torch; print(torch.version.cuda)" 2>/dev/null || echo "unknown")
        echo "  CUDA version: $CUDA_VERSION"
        log "CUDA version: $CUDA_VERSION"
    else
        fail "PyTorch CUDA support not functional"
    fi
}

# Test container integrity
test_container_integrity() {
    section "Container Integrity Tests"

    # Check container exists
    if [ ! -f "$CONTAINER_PATH" ]; then
        fail "Container file not found: $CONTAINER_PATH"
        return 1
    fi
    pass "Container file exists"

    CONTAINER_SIZE=$(du -h "$CONTAINER_PATH" | cut -f1)
    echo "  Container size: $CONTAINER_SIZE"
    log "Container size: $CONTAINER_SIZE"

    # Test Boltz CLI
    if $CONTAINER_CMD exec "$CONTAINER_PATH" boltz --help &>/dev/null; then
        pass "Boltz CLI available"
        BOLTZ_VERSION=$($CONTAINER_CMD exec "$CONTAINER_PATH" boltz --version 2>&1 | head -1 || echo "unknown")
        echo "  Boltz version: $BOLTZ_VERSION"
        log "Boltz version: $BOLTZ_VERSION"
    else
        fail "Boltz CLI not available"
    fi

    # Test Perl
    if PERL_VERSION=$($CONTAINER_CMD exec "$CONTAINER_PATH" perl -v 2>&1 | grep -o 'v[0-9]\+\.[0-9]\+\.[0-9]\+' | head -1); then
        pass "Perl available ($PERL_VERSION)"
    else
        fail "Perl not available"
    fi

    # Test Python
    if PYTHON_VERSION=$($CONTAINER_CMD exec "$CONTAINER_PATH" python3 --version 2>&1); then
        pass "Python available ($PYTHON_VERSION)"
    else
        fail "Python not available"
    fi

    # Test key Perl modules
    local modules=("Bio::KBase::AppService::AppScript" "Try::Tiny" "JSON" "File::Slurp")
    for mod in "${modules[@]}"; do
        if $CONTAINER_CMD exec "$CONTAINER_PATH" perl -e "use $mod; print 'OK'" &>/dev/null; then
            pass "Perl module: $mod"
        else
            warn "Perl module missing: $mod"
        fi
    done

    # Test service script exists
    if $CONTAINER_CMD exec "$CONTAINER_PATH" test -f /kb/module/service-scripts/App-Boltz.pl; then
        pass "Service script exists: App-Boltz.pl"
    else
        fail "Service script missing: App-Boltz.pl"
    fi

    # Test app spec exists
    if $CONTAINER_CMD exec "$CONTAINER_PATH" test -f /kb/module/app_specs/Boltz.json; then
        pass "App spec exists: Boltz.json"
    else
        fail "App spec missing: Boltz.json"
    fi
}

# Run a single prediction test via App-Boltz.pl (BV-BRC service script)
run_appboltz_test() {
    local test_name="$1"
    local input_file="$2"
    local test_output_dir="$OUTPUT_DIR/$test_name"
    local use_msa="$3"

    echo ""
    echo -e "${CYAN}Running App-Boltz.pl: $test_name${NC}"

    mkdir -p "$test_output_dir"

    # Create params.json for this test
    local params_file="$test_output_dir/params.json"
    local use_msa_val="true"
    if [ "$use_msa" != "true" ] || [ "$SKIP_MSA" = "true" ]; then
        use_msa_val="false"
    fi

    # Note: App-Boltz.pl uses local file fallback when workspace API unavailable
    # input_file path must be accessible inside container
    cat > "$params_file" << EOF
{
    "input_file": "/data/$(basename "$input_file")",
    "output_path": "/output",
    "use_msa_server": $use_msa_val,
    "diffusion_samples": 1,
    "recycling_steps": 3,
    "output_format": "mmcif",
    "accelerator": "gpu"
}
EOF

    echo "  Parameters: $params_file"
    cat "$params_file"

    # Run App-Boltz.pl with timing
    local pred_start=$(date +%s)

    # Set TMPDIR inside container for working directories
    if $CONTAINER_CMD exec --nv \
        -B "$TEST_DATA_DIR:/data:ro" \
        -B "$test_output_dir:/output" \
        -B "$params_file:/params.json:ro" \
        --env TMPDIR=/tmp \
        "$CONTAINER_PATH" \
        perl /kb/module/service-scripts/App-Boltz.pl /params.json \
        2>&1 | tee "$test_output_dir/appboltz.log"; then

        local pred_end=$(date +%s)
        local pred_time=$((pred_end - pred_start))

        pass "$test_name App-Boltz.pl completed (${pred_time}s)"
        log "$test_name runtime: ${pred_time}s"

        # Validate output
        validate_prediction_output "$test_name" "$test_output_dir"
    else
        fail "$test_name App-Boltz.pl failed"
        log "$test_name: FAILED"
        echo "  Check log: $test_output_dir/appboltz.log"
    fi
}

# Run a single Boltz prediction test (direct CLI - for comparison)
run_prediction_test() {
    local test_name="$1"
    local input_file="$2"
    local test_output_dir="$OUTPUT_DIR/$test_name"
    local use_msa="$3"

    echo ""
    echo -e "${CYAN}Running boltz predict (direct): $test_name${NC}"

    mkdir -p "$test_output_dir"

    # Build command
    local msa_flag=""
    if [ "$use_msa" = "true" ] && [ "$SKIP_MSA" = "false" ]; then
        msa_flag="--use_msa_server"
    fi

    # Run prediction with timing
    local pred_start=$(date +%s)

    if $CONTAINER_CMD exec --nv \
        -B "$TEST_DATA_DIR:/data:ro" \
        -B "$test_output_dir:/output" \
        "$CONTAINER_PATH" \
        boltz predict /data/$(basename "$input_file") \
        --out_dir /output \
        --diffusion_samples 1 \
        --recycling_steps 3 \
        $msa_flag \
        2>&1 | tee "$test_output_dir/prediction.log"; then

        local pred_end=$(date +%s)
        local pred_time=$((pred_end - pred_start))

        pass "$test_name prediction completed (${pred_time}s)"
        log "$test_name runtime: ${pred_time}s"

        # Validate output
        validate_prediction_output "$test_name" "$test_output_dir"
    else
        fail "$test_name prediction failed"
        log "$test_name: FAILED"
    fi
}

# Validate prediction output
validate_prediction_output() {
    local test_name="$1"
    local output_dir="$2"

    # Check for predictions directory
    if [ -d "$output_dir/predictions" ]; then
        pass "$test_name: predictions/ directory exists"
    else
        fail "$test_name: predictions/ directory missing"
        return 1
    fi

    # Check for structure files
    local cif_count=$(find "$output_dir" -name "*.cif" 2>/dev/null | wc -l)
    local pdb_count=$(find "$output_dir" -name "*.pdb" 2>/dev/null | wc -l)

    if [ "$cif_count" -gt 0 ] || [ "$pdb_count" -gt 0 ]; then
        pass "$test_name: Structure file(s) found ($cif_count CIF, $pdb_count PDB)"
    else
        fail "$test_name: No structure files found"
    fi

    # Check for confidence files
    local conf_count=$(find "$output_dir" -name "confidence_*.json" 2>/dev/null | wc -l)
    if [ "$conf_count" -gt 0 ]; then
        pass "$test_name: Confidence file(s) found ($conf_count)"
    else
        warn "$test_name: No confidence files found"
    fi
}

# Test App-Boltz.pl service script (MAIN FOCUS)
test_appboltz_predictions() {
    section "App-Boltz.pl Service Script Tests (Main Focus)"

    if [ "$QUICK_MODE" = "true" ]; then
        skip "App-Boltz.pl prediction tests (--quick mode)"
        return 0
    fi

    # Check test data exists
    if [ ! -d "$TEST_DATA_DIR" ]; then
        fail "Test data directory not found: $TEST_DATA_DIR"
        return 1
    fi

    echo "Testing App-Boltz.pl - the BV-BRC service script wrapper"
    echo "This validates the full service workflow:"
    echo "  1. Parameter parsing from JSON"
    echo "  2. Input file handling (local fallback mode)"
    echo "  3. Format detection (YAML/FASTA)"
    echo "  4. Boltz execution with correct flags"
    echo "  5. Output file generation"
    echo ""

    # Test 1: Simple protein via App-Boltz.pl
    if [ -f "$TEST_DATA_DIR/simple_protein.yaml" ]; then
        run_appboltz_test "appboltz_simple_protein" "$TEST_DATA_DIR/simple_protein.yaml" "true"
    else
        warn "Test file missing: simple_protein.yaml"
    fi

    # Test 2: Multimer via App-Boltz.pl
    if [ -f "$TEST_DATA_DIR/multimer.yaml" ]; then
        run_appboltz_test "appboltz_multimer" "$TEST_DATA_DIR/multimer.yaml" "true"
    else
        warn "Test file missing: multimer.yaml"
    fi

    # Test 3: FASTA format via App-Boltz.pl (tests format detection)
    if [ -f "$TEST_DATA_DIR/simple_protein.fasta" ]; then
        run_appboltz_test "appboltz_fasta_format" "$TEST_DATA_DIR/simple_protein.fasta" "true"
    else
        warn "Test file missing: simple_protein.fasta"
    fi
}

# Test direct boltz CLI (optional comparison)
test_boltz_direct() {
    section "Direct Boltz CLI Tests (Optional Comparison)"

    if [ "$QUICK_MODE" = "true" ]; then
        skip "Direct Boltz CLI tests (--quick mode)"
        return 0
    fi

    echo "Running direct 'boltz predict' for comparison with App-Boltz.pl"
    echo ""

    # Single direct test for baseline comparison
    if [ -f "$TEST_DATA_DIR/simple_protein.yaml" ]; then
        run_prediction_test "direct_simple_protein" "$TEST_DATA_DIR/simple_protein.yaml" "true"
    fi
}

# Test BV-BRC service script
test_appservice_integration() {
    section "BV-BRC AppService Integration Tests"

    # Create test params file
    local params_file="$OUTPUT_DIR/test_params.json"
    cat > "$params_file" << 'EOF'
{
    "input_file": "/data/simple_protein.yaml",
    "output_path": "/output",
    "use_msa_server": true,
    "diffusion_samples": 1,
    "recycling_steps": 3,
    "output_format": "mmcif"
}
EOF

    # Test preflight
    echo "Testing preflight resource estimation..."

    local preflight_output="$OUTPUT_DIR/preflight_output.json"
    if $CONTAINER_CMD exec \
        -B "$params_file:/params.json:ro" \
        "$CONTAINER_PATH" \
        perl /kb/module/service-scripts/App-Boltz.pl --preflight /params.json \
        2>/dev/null > "$preflight_output"; then

        # Validate JSON output
        if python3 -c "import json; json.load(open('$preflight_output'))" 2>/dev/null; then
            pass "Preflight returns valid JSON"

            # Check for expected fields
            if grep -q '"cpu"' "$preflight_output" && grep -q '"memory"' "$preflight_output"; then
                pass "Preflight contains resource estimates"
                cat "$preflight_output"
            else
                warn "Preflight JSON missing expected fields"
            fi

            # Check for GPU policy
            if grep -q '"gpu"' "$preflight_output"; then
                pass "Preflight includes GPU policy"
            else
                warn "Preflight missing GPU policy"
            fi
        else
            fail "Preflight output is not valid JSON"
        fi
    else
        fail "Preflight execution failed"
    fi
}

# Test workspace connectivity
test_workspace_connectivity() {
    section "Workspace Connectivity Tests"

    if [ -z "$TOKEN_PATH" ]; then
        skip "Workspace tests (no token provided, use --with-token)"
        return 0
    fi

    if [ ! -f "$TOKEN_PATH" ]; then
        fail "Token file not found: $TOKEN_PATH"
        return 1
    fi
    pass "Token file exists: $TOKEN_PATH"

    # Test p3-login
    echo "Testing workspace authentication..."
    if $CONTAINER_CMD exec \
        -B "$TOKEN_PATH:/root/.patric_token:ro" \
        "$CONTAINER_PATH" \
        p3-login --status 2>&1 | grep -qi "logged in\|authenticated\|valid"; then
        pass "Workspace authentication successful"
    else
        warn "Workspace authentication status unclear (may still work)"
    fi

    # Test p3-ls
    echo "Testing workspace listing..."
    if $CONTAINER_CMD exec \
        -B "$TOKEN_PATH:/root/.patric_token:ro" \
        "$CONTAINER_PATH" \
        p3-ls 2>&1 | head -5; then
        pass "Workspace listing works"
    else
        warn "Workspace listing failed (check token and network)"
    fi
}

# Record performance baseline
record_performance_baseline() {
    section "Performance Baseline"

    local end_time=$(date +%s)
    local total_time=$((end_time - START_TIME))

    echo "Total test runtime: ${total_time}s"
    log "Total runtime: ${total_time}s"

    # GPU utilization snapshot
    if $CONTAINER_CMD exec --nv "$CONTAINER_PATH" nvidia-smi --query-gpu=utilization.gpu,utilization.memory,temperature.gpu --format=csv,noheader 2>/dev/null; then
        echo "  (GPU utilization at test completion)"
    fi

    # Memory usage
    echo ""
    echo "Peak memory from prediction logs:"
    for log in "$OUTPUT_DIR"/*/prediction.log; do
        if [ -f "$log" ]; then
            local test_name=$(dirname "$log" | xargs basename)
            echo "  $test_name: $(grep -i "memory\|peak" "$log" 2>/dev/null | tail -1 || echo "N/A")"
        fi
    done

    pass "Performance baseline recorded"
}

# Generate final report
generate_report() {
    section "Test Summary"

    local total=$((PASSED + FAILED + WARNED + SKIPPED))

    echo ""
    echo "=================================="
    echo "       ACCEPTANCE TEST RESULTS    "
    echo "=================================="
    echo -e "${GREEN}Passed:  $PASSED${NC}"
    echo -e "${RED}Failed:  $FAILED${NC}"
    echo -e "${YELLOW}Warned:  $WARNED${NC}"
    echo -e "${CYAN}Skipped: $SKIPPED${NC}"
    echo "=================================="
    echo "Total:   $total"
    echo "=================================="

    # Log summary
    echo "" >> "$LOG_FILE"
    echo "================================" >> "$LOG_FILE"
    echo "SUMMARY" >> "$LOG_FILE"
    echo "Passed:  $PASSED" >> "$LOG_FILE"
    echo "Failed:  $FAILED" >> "$LOG_FILE"
    echo "Warned:  $WARNED" >> "$LOG_FILE"
    echo "Skipped: $SKIPPED" >> "$LOG_FILE"
    echo "================================" >> "$LOG_FILE"

    echo ""
    echo "Results saved to: $LOG_FILE"

    if [ $FAILED -eq 0 ]; then
        echo ""
        echo -e "${GREEN}All critical tests passed!${NC}"
        return 0
    else
        echo ""
        echo -e "${RED}Some tests failed. Review log for details.${NC}"
        return 1
    fi
}

# Main execution
main() {
    parse_args "$@"

    echo ""
    echo "╔════════════════════════════════════════════════════════════════╗"
    echo "║       BoltzApp GPU Acceptance Test Suite                       ║"
    echo "║       Target: H100 GPU with Apptainer                          ║"
    echo "╚════════════════════════════════════════════════════════════════╝"
    echo ""
    echo "Container: $CONTAINER_PATH"
    echo "Quick mode: $QUICK_MODE"
    [ -n "$TOKEN_PATH" ] && echo "Token: $TOKEN_PATH"
    echo ""

    setup_environment
    detect_runtime
    test_gpu_access
    test_container_integrity
    test_appboltz_predictions      # MAIN FOCUS: App-Boltz.pl service script
    test_appservice_integration    # Preflight and parameter validation
    test_workspace_connectivity
    test_boltz_direct              # Optional: direct CLI comparison
    record_performance_baseline
    generate_report

    exit $?
}

main "$@"
