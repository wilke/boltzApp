#!/bin/bash
#
# Extract MSA files from previous runs and create inputs with pre-computed MSA paths
#

set -e

OUTPUT_DIR="./output"
MSA_DIR="./msa_cache"
INPUT_DIR="./inputs_with_msa"

mkdir -p "$MSA_DIR" "$INPUT_DIR"

echo "Extracting MSA files from previous benchmark runs..."

# Find and copy MSA CSV files for single-chain proteins
for run_dir in "$OUTPUT_DIR"/protein_len*_batch1_*/; do
    if [ -d "$run_dir" ]; then
        test_name=$(basename "$run_dir" | sed 's/_20.*//')

        # Find the MSA CSV file
        csv_file=$(find "$run_dir" -name "${test_name}_0.csv" 2>/dev/null | head -1)

        if [ -n "$csv_file" ] && [ -f "$csv_file" ]; then
            cp "$csv_file" "$MSA_DIR/${test_name}.csv"
            echo "  Extracted: ${test_name}.csv"
        fi
    fi
done

# Find and copy MSA CSV files for multi-chain proteins
for run_dir in "$OUTPUT_DIR"/protein_len*_batch[2-9]_*/; do
    if [ -d "$run_dir" ]; then
        test_name=$(basename "$run_dir" | sed 's/_20.*//')

        # For multi-chain, we need multiple CSV files (one per chain)
        csv_files=$(find "$run_dir" -name "${test_name}_*.csv" 2>/dev/null | sort)

        if [ -n "$csv_files" ]; then
            for csv in $csv_files; do
                csv_basename=$(basename "$csv")
                cp "$csv" "$MSA_DIR/$csv_basename"
                echo "  Extracted: $csv_basename"
            done
        fi
    fi
done

echo ""
echo "Creating input files with pre-computed MSA references..."

# Function to extract sequence from original YAML
extract_sequence() {
    local yaml_file="$1"
    grep -A1 "sequence:" "$yaml_file" | tail -1 | tr -d ' '
}

# Function to extract chain id
extract_chain_id() {
    local yaml_file="$1"
    grep "id:" "$yaml_file" | head -1 | sed 's/.*id: //' | tr -d ' []'
}

# Create single-chain inputs with MSA
for orig_yaml in ./inputs/protein_len*_batch1.yaml; do
    if [ -f "$orig_yaml" ]; then
        test_name=$(basename "$orig_yaml" .yaml)
        msa_file="$MSA_DIR/${test_name}.csv"

        if [ -f "$msa_file" ]; then
            # Extract sequence from original
            sequence=$(grep "sequence:" "$orig_yaml" | sed 's/.*sequence: //')

            # Create new YAML with MSA reference
            cat > "$INPUT_DIR/${test_name}.yaml" << EOF
version: 1
sequences:
  - protein:
      id: A
      sequence: $sequence
      msa: /msa/${test_name}.csv
EOF
            echo "  Created: ${test_name}.yaml with MSA"
        fi
    fi
done

# Create multi-chain inputs with MSA (more complex)
for orig_yaml in ./inputs/protein_len*_batch[2-9].yaml; do
    if [ -f "$orig_yaml" ]; then
        test_name=$(basename "$orig_yaml" .yaml)

        # Check if we have the MSA files
        msa_0="$MSA_DIR/${test_name}_0.csv"
        if [ -f "$msa_0" ]; then
            # Parse the original YAML and add MSA references
            # This is more complex for multi-chain

            # For now, create the structure manually
            batch=$(echo "$test_name" | grep -oP 'batch\K\d+')
            length=$(echo "$test_name" | grep -oP 'len\K\d+')

            echo "version: 1" > "$INPUT_DIR/${test_name}.yaml"
            echo "sequences:" >> "$INPUT_DIR/${test_name}.yaml"

            chain_ids=("A" "B" "C" "D" "E" "F" "G" "H")
            for ((i=0; i<batch; i++)); do
                # Extract sequence for this chain from original
                chain_idx=$((i+1))
                sequence=$(grep -A2 "id: ${chain_ids[$i]}" "$orig_yaml" | grep "sequence:" | sed 's/.*sequence: //')

                if [ -z "$sequence" ]; then
                    # Try alternative parsing
                    sequence=$(sed -n "$((4 + i*3))p" "$orig_yaml" | sed 's/.*sequence: //')
                fi

                msa_file="/msa/${test_name}_${i}.csv"

                cat >> "$INPUT_DIR/${test_name}.yaml" << EOF
  - protein:
      id: ${chain_ids[$i]}
      sequence: $sequence
      msa: $msa_file
EOF
            done
            echo "  Created: ${test_name}.yaml with MSA (${batch} chains)"
        fi
    fi
done

echo ""
echo "MSA cache directory: $MSA_DIR"
echo "Input files with MSA: $INPUT_DIR"
ls -la "$MSA_DIR"
echo ""
ls -la "$INPUT_DIR"
