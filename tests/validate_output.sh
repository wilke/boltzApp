#!/bin/bash
# Validate Boltz prediction output
# Usage: ./validate_output.sh <output_directory>

set -e

OUTPUT_DIR="${1:-.}"

echo "Validating Boltz output in: $OUTPUT_DIR"

# Check for required output files
check_file() {
    if [ -f "$1" ]; then
        echo "[OK] Found: $1"
        return 0
    else
        echo "[FAIL] Missing: $1"
        return 1
    fi
}

ERRORS=0

# Check predictions directory exists
if [ ! -d "$OUTPUT_DIR/predictions" ]; then
    echo "[FAIL] predictions/ directory not found"
    ERRORS=$((ERRORS + 1))
else
    echo "[OK] predictions/ directory exists"

    # Find prediction subdirectories
    for pred_dir in "$OUTPUT_DIR/predictions"/*/; do
        if [ -d "$pred_dir" ]; then
            pred_name=$(basename "$pred_dir")
            echo "Checking prediction: $pred_name"

            # Check for structure file (CIF or PDB)
            CIF_FILES=$(find "$pred_dir" -name "*.cif" 2>/dev/null | wc -l)
            PDB_FILES=$(find "$pred_dir" -name "*.pdb" 2>/dev/null | wc -l)

            if [ "$CIF_FILES" -gt 0 ] || [ "$PDB_FILES" -gt 0 ]; then
                echo "  [OK] Structure file(s) found: $CIF_FILES CIF, $PDB_FILES PDB"
            else
                echo "  [FAIL] No structure files found"
                ERRORS=$((ERRORS + 1))
            fi

            # Check for confidence file
            CONF_FILES=$(find "$pred_dir" -name "confidence_*.json" 2>/dev/null | wc -l)
            if [ "$CONF_FILES" -gt 0 ]; then
                echo "  [OK] Confidence file(s) found: $CONF_FILES"
            else
                echo "  [WARN] No confidence files found"
            fi

            # Check for pLDDT scores
            PLDDT_FILES=$(find "$pred_dir" -name "plddt_*.npz" 2>/dev/null | wc -l)
            if [ "$PLDDT_FILES" -gt 0 ]; then
                echo "  [OK] pLDDT file(s) found: $PLDDT_FILES"
            else
                echo "  [WARN] No pLDDT files found"
            fi
        fi
    done
fi

# Check processed directory
if [ -d "$OUTPUT_DIR/processed" ]; then
    echo "[OK] processed/ directory exists"
else
    echo "[WARN] processed/ directory not found (may be expected)"
fi

# Summary
echo ""
echo "================================"
if [ $ERRORS -eq 0 ]; then
    echo "Validation PASSED"
    exit 0
else
    echo "Validation FAILED with $ERRORS error(s)"
    exit 1
fi
