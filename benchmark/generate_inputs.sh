#!/bin/bash
#
# Generate test input files for Boltz benchmarking
#

INPUT_DIR="${1:-./inputs}"
mkdir -p "$INPUT_DIR"

# Generate random protein sequence of given length
generate_sequence() {
    local length=$1
    local amino_acids="ACDEFGHIKLMNPQRSTVWY"
    local seq=""
    for ((i=0; i<length; i++)); do
        seq+="${amino_acids:RANDOM%20:1}"
    done
    echo "$seq"
}

# Protein lengths to test
LENGTHS=(50 100 150 200 300 400 500 750 1000)

# Generate single protein files for each length
echo "Generating single protein inputs..."
for len in "${LENGTHS[@]}"; do
    seq=$(generate_sequence $len)
    cat > "$INPUT_DIR/protein_len${len}_batch1.yaml" << EOF
version: 1
sequences:
  - protein:
      id: A
      sequence: $seq
EOF
    echo "  Created: protein_len${len}_batch1.yaml (${len} residues)"
done

# Generate batch inputs (multimers)
echo ""
echo "Generating batch protein inputs..."
BATCH_SIZES=(2 4 8)
BATCH_LENGTHS=(50 100 200 300)

for len in "${BATCH_LENGTHS[@]}"; do
    for batch in "${BATCH_SIZES[@]}"; do
        output_file="$INPUT_DIR/protein_len${len}_batch${batch}.yaml"
        echo "version: 1" > "$output_file"
        echo "sequences:" >> "$output_file"

        chain_ids=("A" "B" "C" "D" "E" "F" "G" "H")
        for ((i=0; i<batch; i++)); do
            seq=$(generate_sequence $len)
            cat >> "$output_file" << EOF
  - protein:
      id: ${chain_ids[$i]}
      sequence: $seq
EOF
        done
        total=$((len * batch))
        echo "  Created: protein_len${len}_batch${batch}.yaml (${total} total residues)"
    done
done

echo ""
echo "Input files generated in: $INPUT_DIR"
ls -la "$INPUT_DIR"
