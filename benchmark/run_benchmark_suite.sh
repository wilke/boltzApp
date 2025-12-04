#!/bin/bash
#
# Boltz Performance Benchmark Suite
# Collects runtime, disk, and memory metrics for various input sizes
#
# Usage: ./run_benchmark_suite.sh [--quick] [--gpu-id N]
#

set -e

# Configuration
CONTAINER="${CONTAINER:-/homes/wilke/images/boltz_latest-gpu.sif}"
GPU_ID="${GPU_ID:-4}"
CACHE_DIR="${CACHE_DIR:-$HOME/.boltz_cache}"
INPUT_DIR="./inputs"
OUTPUT_DIR="./output"
RESULTS_DIR="./results"

QUICK_MODE=0

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --quick)
            QUICK_MODE=1
            shift
            ;;
        --gpu-id)
            GPU_ID="$2"
            shift 2
            ;;
        -h|--help)
            echo "Usage: $0 [OPTIONS]"
            echo "  --quick       Quick mode (fewer tests)"
            echo "  --gpu-id N    GPU device ID (default: 4)"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Create directories
mkdir -p "$OUTPUT_DIR" "$RESULTS_DIR" "$CACHE_DIR"

# Timestamp for this run
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
RESULTS_CSV="$RESULTS_DIR/benchmark_${TIMESTAMP}.csv"
SUMMARY_MD="$RESULTS_DIR/benchmark_${TIMESTAMP}.md"

# Test configurations
if [ "$QUICK_MODE" -eq 1 ]; then
    TESTS=(
        "protein_len50_batch1:50:1"
        "protein_len100_batch1:100:1"
        "protein_len200_batch1:200:1"
    )
else
    TESTS=(
        "protein_len50_batch1:50:1"
        "protein_len100_batch1:100:1"
        "protein_len150_batch1:150:1"
        "protein_len200_batch1:200:1"
        "protein_len300_batch1:300:1"
        "protein_len400_batch1:400:1"
        "protein_len500_batch1:500:1"
        "protein_len50_batch2:50:2"
        "protein_len100_batch2:100:2"
        "protein_len200_batch2:200:2"
        "protein_len50_batch4:50:4"
        "protein_len100_batch4:100:4"
    )
fi

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"
}

# Get GPU info
get_gpu_info() {
    nvidia-smi --query-gpu=name,memory.total --format=csv,noheader -i "$GPU_ID" 2>/dev/null | head -1
}

# Monitor GPU memory in background, writing max to file
monitor_gpu() {
    local pid_file="$1"
    local mem_file="$2"
    echo "0" > "$mem_file"

    while [ -f "$pid_file" ]; do
        local mem=$(nvidia-smi --query-gpu=memory.used --format=csv,noheader,nounits -i "$GPU_ID" 2>/dev/null | head -1)
        local current=$(cat "$mem_file")
        if [ -n "$mem" ] && [ "$mem" -gt "$current" ] 2>/dev/null; then
            echo "$mem" > "$mem_file"
        fi
        sleep 0.5
    done
}

# Run a single test
run_test() {
    local test_name="$1"
    local length="$2"
    local batch="$3"
    local total_residues=$((length * batch))

    local input_file="$INPUT_DIR/${test_name}.yaml"
    local test_output="$OUTPUT_DIR/${test_name}_${TIMESTAMP}"

    log "Running: $test_name (length=$length, batch=$batch, total=$total_residues residues)"

    if [ ! -f "$input_file" ]; then
        log "SKIP: Input file not found: $input_file"
        echo "$test_name,$length,$batch,$total_residues,0,0,0,skip" >> "$RESULTS_CSV"
        return
    fi

    rm -rf "$test_output"
    mkdir -p "$test_output"

    # Start GPU memory monitoring
    local pid_file="/tmp/gpu_monitor_$$.pid"
    local mem_file="/tmp/gpu_mem_$$.txt"
    touch "$pid_file"
    monitor_gpu "$pid_file" "$mem_file" &
    local monitor_pid=$!

    # Record start time
    local start_time=$(date +%s.%N)
    local start_gpu_mem=$(nvidia-smi --query-gpu=memory.used --format=csv,noheader,nounits -i "$GPU_ID" 2>/dev/null | head -1)

    # Run prediction
    local status="success"
    local input_dir_abs=$(realpath "$INPUT_DIR")
    local output_abs=$(realpath "$test_output")
    local cache_abs=$(realpath "$CACHE_DIR")

    if CUDA_VISIBLE_DEVICES="$GPU_ID" singularity exec --nv \
        -B "$input_dir_abs":/input \
        -B "$output_abs":/output \
        -B "$cache_abs":/root/.boltz \
        "$CONTAINER" \
        boltz predict "/input/${test_name}.yaml" \
            --out_dir /output \
            --use_msa_server \
            --diffusion_samples 1 \
            --recycling_steps 3 \
            --accelerator gpu \
            > "$test_output/boltz.log" 2>&1; then
        status="success"
    else
        status="failed"
    fi

    # Stop GPU monitoring
    rm -f "$pid_file"
    wait $monitor_pid 2>/dev/null || true

    # Calculate metrics
    local end_time=$(date +%s.%N)
    local runtime=$(echo "$end_time - $start_time" | bc)

    local peak_gpu_mem=$(cat "$mem_file" 2>/dev/null || echo "0")
    local gpu_mem_delta=$((peak_gpu_mem - start_gpu_mem))
    rm -f "$mem_file"

    local disk_mb=$(du -sm "$test_output" 2>/dev/null | cut -f1 || echo "0")

    # Record results
    echo "$test_name,$length,$batch,$total_residues,$runtime,$peak_gpu_mem,$disk_mb,$status" >> "$RESULTS_CSV"

    log "  Completed: runtime=${runtime}s, gpu_mem=${peak_gpu_mem}MB (delta=${gpu_mem_delta}MB), disk=${disk_mb}MB, status=$status"
}

# Generate summary report
generate_summary() {
    local gpu_info=$(get_gpu_info)

    cat > "$SUMMARY_MD" << EOF
# Boltz Performance Benchmark Results

**Date**: $(date '+%Y-%m-%d %H:%M:%S')
**Container**: $CONTAINER
**GPU**: $gpu_info
**GPU ID**: $GPU_ID
**Mode**: $([ "$QUICK_MODE" -eq 1 ] && echo "Quick" || echo "Full")

## Configuration

- Diffusion samples: 1
- Recycling steps: 3
- MSA server: enabled (ColabFold)
- Accelerator: GPU

## Results

| Test Name | Length | Batch | Total Residues | Runtime (s) | Peak GPU Mem (MB) | Disk (MB) | Status |
|-----------|--------|-------|----------------|-------------|-------------------|-----------|--------|
EOF

    # Add data rows
    tail -n +2 "$RESULTS_CSV" | while IFS=',' read -r name length batch residues runtime gpu_mem disk status; do
        printf "| %s | %s | %s | %s | %.1f | %s | %s | %s |\n" \
            "$name" "$length" "$batch" "$residues" "$runtime" "$gpu_mem" "$disk" "$status" >> "$SUMMARY_MD"
    done

    cat >> "$SUMMARY_MD" << EOF

## Analysis

### Runtime Scaling by Protein Length (Single Chain)

| Length | Runtime (s) | Runtime/Residue (ms) |
|--------|-------------|---------------------|
EOF

    # Single chain analysis
    tail -n +2 "$RESULTS_CSV" | grep "batch1" | while IFS=',' read -r name length batch residues runtime gpu_mem disk status; do
        if [ "$status" = "success" ]; then
            local per_residue=$(echo "scale=2; $runtime * 1000 / $residues" | bc)
            printf "| %s | %.1f | %s |\n" "$length" "$runtime" "$per_residue" >> "$SUMMARY_MD"
        fi
    done

    cat >> "$SUMMARY_MD" << EOF

### Memory Scaling by Total Residues

| Total Residues | Peak GPU Memory (MB) |
|----------------|---------------------|
EOF

    tail -n +2 "$RESULTS_CSV" | sort -t',' -k4 -n | while IFS=',' read -r name length batch residues runtime gpu_mem disk status; do
        if [ "$status" = "success" ]; then
            printf "| %s | %s |\n" "$residues" "$gpu_mem" >> "$SUMMARY_MD"
        fi
    done

    cat >> "$SUMMARY_MD" << EOF

## Raw Data

See: [$(basename "$RESULTS_CSV")]($(basename "$RESULTS_CSV"))

## Notes

- Runtime includes MSA server latency (typically 10-30s per query)
- Peak GPU memory measured during prediction
- Disk usage includes all output files (structures, MSA, logs)
EOF

    log "Summary written to: $SUMMARY_MD"
}

# Main execution
main() {
    log "========================================"
    log "Boltz Performance Benchmark Suite"
    log "========================================"
    log "Container: $CONTAINER"
    log "GPU ID: $GPU_ID"
    log "GPU: $(get_gpu_info)"
    log "Mode: $([ "$QUICK_MODE" -eq 1 ] && echo 'Quick' || echo 'Full')"
    log "Tests: ${#TESTS[@]}"
    log "========================================"

    # Initialize results CSV
    echo "test_name,length,batch,total_residues,runtime_sec,peak_gpu_mem_mb,disk_mb,status" > "$RESULTS_CSV"

    # Run tests
    for test in "${TESTS[@]}"; do
        IFS=':' read -r name length batch <<< "$test"
        run_test "$name" "$length" "$batch"
    done

    # Generate summary
    generate_summary

    log "========================================"
    log "Benchmark Complete"
    log "========================================"
    log "Results CSV: $RESULTS_CSV"
    log "Summary: $SUMMARY_MD"
}

main "$@"
