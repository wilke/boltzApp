#!/bin/bash
#
# Boltz Performance Benchmark Script
# Measures runtime, memory, and disk footprint for various input sizes
#
# Usage: ./boltz_benchmark.sh [OPTIONS]
#   --container PATH   Path to Apptainer/Singularity image (default: /homes/wilke/images/boltz_latest-gpu.sif)
#   --output-dir PATH  Directory for benchmark results (default: ./results)
#   --gpu-id INT       GPU device ID to use (default: 0)
#   --skip-generate    Skip input file generation (use existing files)
#   --quick            Run quick benchmark (fewer tests)
#

set -e

# Default configuration
CONTAINER="${CONTAINER:-/homes/wilke/images/boltz_latest-gpu.sif}"
OUTPUT_DIR="${OUTPUT_DIR:-./results}"
GPU_ID="${GPU_ID:-0}"
INPUT_DIR="./inputs"
CACHE_DIR="${CACHE_DIR:-$HOME/.boltz_cache}"
SKIP_GENERATE=0
QUICK_MODE=0

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --container)
            CONTAINER="$2"
            shift 2
            ;;
        --output-dir)
            OUTPUT_DIR="$2"
            shift 2
            ;;
        --gpu-id)
            GPU_ID="$2"
            shift 2
            ;;
        --skip-generate)
            SKIP_GENERATE=1
            shift
            ;;
        --quick)
            QUICK_MODE=1
            shift
            ;;
        -h|--help)
            echo "Usage: $0 [OPTIONS]"
            echo "  --container PATH   Path to Apptainer image"
            echo "  --output-dir PATH  Directory for results"
            echo "  --gpu-id INT       GPU device ID"
            echo "  --skip-generate    Skip input file generation"
            echo "  --quick            Quick mode (fewer tests)"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Benchmark parameters
if [ "$QUICK_MODE" -eq 1 ]; then
    # Quick mode: fewer, smaller tests
    PROTEIN_LENGTHS=(50 100 200)
    BATCH_SIZES=(1 2)
else
    # Full benchmark: comprehensive testing
    PROTEIN_LENGTHS=(50 100 150 200 300 400 500)
    BATCH_SIZES=(1 2 4 8)
fi

# Create directories
mkdir -p "$OUTPUT_DIR" "$INPUT_DIR" "$CACHE_DIR"

# Results file
RESULTS_FILE="$OUTPUT_DIR/benchmark_results_$(date +%Y%m%d_%H%M%S).csv"
SUMMARY_FILE="$OUTPUT_DIR/benchmark_summary_$(date +%Y%m%d_%H%M%S).md"

# Initialize results CSV
echo "test_name,protein_length,batch_size,total_residues,runtime_seconds,peak_gpu_mem_mb,peak_cpu_mem_mb,disk_output_mb,status" > "$RESULTS_FILE"

# Log function
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"
}

# Generate random protein sequence of given length
generate_protein_sequence() {
    local length=$1
    local amino_acids="ACDEFGHIKLMNPQRSTVWY"
    local seq=""
    for ((i=0; i<length; i++)); do
        seq+="${amino_acids:RANDOM%20:1}"
    done
    echo "$seq"
}

# Generate YAML input file for single protein
generate_single_protein_yaml() {
    local length=$1
    local output_file=$2
    local seq=$(generate_protein_sequence $length)

    cat > "$output_file" << EOF
version: 1
sequences:
  - protein:
      id: A
      sequence: $seq
EOF
}

# Generate YAML input file for batch of proteins (multimer)
generate_batch_yaml() {
    local length=$1
    local batch_size=$2
    local output_file=$3

    echo "version: 1" > "$output_file"
    echo "sequences:" >> "$output_file"

    local chain_ids=("A" "B" "C" "D" "E" "F" "G" "H" "I" "J" "K" "L")
    for ((i=0; i<batch_size; i++)); do
        local seq=$(generate_protein_sequence $length)
        local chain_id="${chain_ids[$i]}"
        cat >> "$output_file" << EOF
  - protein:
      id: $chain_id
      sequence: $seq
EOF
    done
}

# Monitor GPU memory usage in background
monitor_gpu_memory() {
    local pid_file=$1
    local log_file=$2
    local gpu_id=$3

    echo 0 > "$log_file"
    while [ -f "$pid_file" ]; do
        local mem=$(nvidia-smi --query-gpu=memory.used --format=csv,noheader,nounits -i "$gpu_id" 2>/dev/null | head -1)
        local current_max=$(cat "$log_file")
        if [ -n "$mem" ] && [ "$mem" -gt "$current_max" ] 2>/dev/null; then
            echo "$mem" > "$log_file"
        fi
        sleep 1
    done
}

# Run single benchmark
run_benchmark() {
    local test_name=$1
    local input_file=$2
    local protein_length=$3
    local batch_size=$4
    local total_residues=$((protein_length * batch_size))

    log "Running: $test_name (length=$protein_length, batch=$batch_size, total_residues=$total_residues)"

    local test_output="$OUTPUT_DIR/${test_name}"
    rm -rf "$test_output"
    mkdir -p "$test_output"

    # Set up GPU memory monitoring
    local gpu_monitor_pid_file="/tmp/gpu_monitor_$$.pid"
    local gpu_mem_file="/tmp/gpu_mem_$$.log"
    touch "$gpu_monitor_pid_file"
    monitor_gpu_memory "$gpu_monitor_pid_file" "$gpu_mem_file" "$GPU_ID" &
    local monitor_pid=$!

    # Record start time and initial memory
    local start_time=$(date +%s.%N)
    local start_mem=$(ps -o rss= $$ 2>/dev/null || echo 0)

    # Run Boltz prediction
    local status="success"
    local runtime=0

    if CUDA_VISIBLE_DEVICES="$GPU_ID" singularity exec --nv \
        -B "$INPUT_DIR":/input \
        -B "$test_output":/output \
        -B "$CACHE_DIR":/root/.boltz \
        "$CONTAINER" \
        boltz predict /input/$(basename "$input_file") \
            --out_dir /output \
            --use_msa_server \
            --diffusion_samples 1 \
            --recycling_steps 3 \
            --accelerator gpu \
            2>&1 | tee "$test_output/boltz.log"; then
        status="success"
    else
        status="failed"
    fi

    # Stop GPU memory monitoring
    rm -f "$gpu_monitor_pid_file"
    wait $monitor_pid 2>/dev/null || true

    # Calculate metrics
    local end_time=$(date +%s.%N)
    runtime=$(echo "$end_time - $start_time" | bc)

    local peak_gpu_mem=$(cat "$gpu_mem_file" 2>/dev/null || echo 0)
    rm -f "$gpu_mem_file"

    # Get peak CPU memory from process (approximate)
    local peak_cpu_mem=0
    if [ -f "$test_output/boltz.log" ]; then
        # Try to extract memory info from logs if available
        peak_cpu_mem=$(grep -oP 'Memory: \K[0-9]+' "$test_output/boltz.log" 2>/dev/null | tail -1 || echo 0)
    fi

    # Calculate output disk usage
    local disk_output_mb=$(du -sm "$test_output" 2>/dev/null | cut -f1 || echo 0)

    # Record results
    echo "$test_name,$protein_length,$batch_size,$total_residues,$runtime,$peak_gpu_mem,$peak_cpu_mem,$disk_output_mb,$status" >> "$RESULTS_FILE"

    log "Completed: $test_name (runtime=${runtime}s, gpu_mem=${peak_gpu_mem}MB, disk=${disk_output_mb}MB, status=$status)"
}

# Generate input files
generate_inputs() {
    log "Generating input files..."

    for length in "${PROTEIN_LENGTHS[@]}"; do
        # Single protein
        local single_file="$INPUT_DIR/protein_len${length}_batch1.yaml"
        if [ ! -f "$single_file" ] || [ "$SKIP_GENERATE" -eq 0 ]; then
            generate_single_protein_yaml "$length" "$single_file"
            log "Generated: $single_file"
        fi

        # Batch proteins (multimers)
        for batch in "${BATCH_SIZES[@]}"; do
            if [ "$batch" -gt 1 ]; then
                local batch_file="$INPUT_DIR/protein_len${length}_batch${batch}.yaml"
                if [ ! -f "$batch_file" ] || [ "$SKIP_GENERATE" -eq 0 ]; then
                    generate_batch_yaml "$length" "$batch" "$batch_file"
                    log "Generated: $batch_file"
                fi
            fi
        done
    done
}

# Generate summary report
generate_summary() {
    log "Generating summary report..."

    cat > "$SUMMARY_FILE" << EOF
# Boltz Performance Benchmark Results

**Date**: $(date '+%Y-%m-%d %H:%M:%S')
**Container**: $CONTAINER
**GPU**: $(nvidia-smi --query-gpu=name --format=csv,noheader -i "$GPU_ID" 2>/dev/null || echo "Unknown")
**Mode**: $([ "$QUICK_MODE" -eq 1 ] && echo "Quick" || echo "Full")

## Test Configuration

- Protein lengths tested: ${PROTEIN_LENGTHS[*]}
- Batch sizes tested: ${BATCH_SIZES[*]}
- Diffusion samples: 1
- Recycling steps: 3
- MSA server: enabled

## Results Summary

| Test | Length | Batch | Residues | Runtime (s) | GPU Mem (MB) | Disk (MB) | Status |
|------|--------|-------|----------|-------------|--------------|-----------|--------|
EOF

    # Add data rows from CSV (skip header)
    tail -n +2 "$RESULTS_FILE" | while IFS=',' read -r name length batch residues runtime gpu_mem cpu_mem disk status; do
        printf "| %s | %s | %s | %s | %.1f | %s | %s | %s |\n" \
            "$name" "$length" "$batch" "$residues" "$runtime" "$gpu_mem" "$disk" "$status" >> "$SUMMARY_FILE"
    done

    cat >> "$SUMMARY_FILE" << EOF

## Analysis

### Runtime vs Protein Size

EOF

    # Calculate average runtime per residue for each length
    echo "| Length | Avg Runtime (s) | Avg Runtime/Residue (ms) |" >> "$SUMMARY_FILE"
    echo "|--------|-----------------|--------------------------|" >> "$SUMMARY_FILE"

    for length in "${PROTEIN_LENGTHS[@]}"; do
        local avg_runtime=$(awk -F',' -v len="$length" 'NR>1 && $2==len && $4==len {sum+=$5; count++} END {if(count>0) printf "%.1f", sum/count; else print "N/A"}' "$RESULTS_FILE")
        local avg_per_residue=$(awk -F',' -v len="$length" 'NR>1 && $2==len && $4==len {sum+=($5*1000/$4); count++} END {if(count>0) printf "%.2f", sum/count; else print "N/A"}' "$RESULTS_FILE")
        echo "| $length | $avg_runtime | $avg_per_residue |" >> "$SUMMARY_FILE"
    done

    cat >> "$SUMMARY_FILE" << EOF

### Scaling with Batch Size

EOF

    echo "| Batch Size | Avg Runtime (s) | Avg GPU Mem (MB) |" >> "$SUMMARY_FILE"
    echo "|------------|-----------------|------------------|" >> "$SUMMARY_FILE"

    for batch in "${BATCH_SIZES[@]}"; do
        local avg_runtime=$(awk -F',' -v b="$batch" 'NR>1 && $3==b {sum+=$5; count++} END {if(count>0) printf "%.1f", sum/count; else print "N/A"}' "$RESULTS_FILE")
        local avg_gpu_mem=$(awk -F',' -v b="$batch" 'NR>1 && $3==b {sum+=$6; count++} END {if(count>0) printf "%.0f", sum/count; else print "N/A"}' "$RESULTS_FILE")
        echo "| $batch | $avg_runtime | $avg_gpu_mem |" >> "$SUMMARY_FILE"
    done

    cat >> "$SUMMARY_FILE" << EOF

## Raw Data

See: $(basename "$RESULTS_FILE")
EOF

    log "Summary written to: $SUMMARY_FILE"
}

# Main execution
main() {
    log "Starting Boltz Performance Benchmark"
    log "Container: $CONTAINER"
    log "Output directory: $OUTPUT_DIR"
    log "GPU ID: $GPU_ID"

    # Verify container exists
    if [ ! -f "$CONTAINER" ]; then
        echo "ERROR: Container not found: $CONTAINER"
        exit 1
    fi

    # Verify GPU access
    if ! nvidia-smi -i "$GPU_ID" &>/dev/null; then
        echo "ERROR: GPU $GPU_ID not accessible"
        exit 1
    fi

    # Generate input files
    if [ "$SKIP_GENERATE" -eq 0 ]; then
        generate_inputs
    fi

    # Run benchmarks
    log "Starting benchmark runs..."

    for length in "${PROTEIN_LENGTHS[@]}"; do
        for batch in "${BATCH_SIZES[@]}"; do
            local input_file="$INPUT_DIR/protein_len${length}_batch${batch}.yaml"
            local test_name="len${length}_batch${batch}"

            if [ -f "$input_file" ]; then
                run_benchmark "$test_name" "$input_file" "$length" "$batch"
            else
                log "SKIP: Input file not found: $input_file"
            fi
        done
    done

    # Generate summary
    generate_summary

    log "Benchmark complete!"
    log "Results: $RESULTS_FILE"
    log "Summary: $SUMMARY_FILE"
}

# Run main
main "$@"
