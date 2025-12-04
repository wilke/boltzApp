#!/bin/bash
#
# Quick single test for Boltz container validation
# Usage: ./run_single_test.sh [input_file] [output_dir]
#

CONTAINER="${CONTAINER:-/homes/wilke/images/boltz_latest-gpu.sif}"
INPUT_FILE="${1:-./inputs/protein_len50_batch1.yaml}"
OUTPUT_DIR="${2:-./output/single_test}"
GPU_ID="${GPU_ID:-0}"
CACHE_DIR="${CACHE_DIR:-$HOME/.boltz_cache}"

echo "========================================"
echo "Boltz Single Test"
echo "========================================"
echo "Container: $CONTAINER"
echo "Input: $INPUT_FILE"
echo "Output: $OUTPUT_DIR"
echo "GPU: $GPU_ID"
echo "Cache: $CACHE_DIR"
echo "========================================"

# Create output and cache directories
rm -rf "$OUTPUT_DIR"
mkdir -p "$OUTPUT_DIR"
mkdir -p "$CACHE_DIR"

# Get absolute paths
INPUT_DIR=$(dirname "$(realpath "$INPUT_FILE")")
INPUT_NAME=$(basename "$INPUT_FILE")
OUTPUT_DIR_ABS=$(realpath "$OUTPUT_DIR")
CACHE_DIR_ABS=$(realpath "$CACHE_DIR")

echo ""
echo "Starting prediction at $(date)"
echo ""

# Record start time
START_TIME=$(date +%s)

# Run prediction with cache bind mount
CUDA_VISIBLE_DEVICES="$GPU_ID" singularity exec --nv \
    -B "$INPUT_DIR":/input \
    -B "$OUTPUT_DIR_ABS":/output \
    -B "$CACHE_DIR_ABS":/root/.boltz \
    "$CONTAINER" \
    boltz predict "/input/$INPUT_NAME" \
        --out_dir /output \
        --use_msa_server \
        --diffusion_samples 1 \
        --recycling_steps 3 \
        --accelerator gpu \
        2>&1 | tee "$OUTPUT_DIR_ABS/boltz.log"

EXIT_CODE=${PIPESTATUS[0]}

# Record end time
END_TIME=$(date +%s)
RUNTIME=$((END_TIME - START_TIME))

echo ""
echo "========================================"
echo "Test Complete"
echo "========================================"
echo "Exit code: $EXIT_CODE"
echo "Runtime: ${RUNTIME} seconds"
echo "Output files:"
ls -la "$OUTPUT_DIR"

# Check for prediction output
if [ -d "$OUTPUT_DIR/predictions" ]; then
    echo ""
    echo "Prediction directory contents:"
    find "$OUTPUT_DIR/predictions" -type f -exec ls -lh {} \;
fi

echo ""
echo "Disk usage: $(du -sh "$OUTPUT_DIR" | cut -f1)"
