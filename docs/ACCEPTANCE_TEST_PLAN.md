# BoltzApp GPU Acceptance Test Plan

## Purpose

This document describes the acceptance testing procedure for validating BoltzApp deployment on GPU machines with Apptainer/Singularity containers. The primary focus is testing the **App-Boltz.pl** BV-BRC service script.

---

## Prerequisites

### Hardware
- **GPU**: NVIDIA H100 (80GB) or A100 (40GB/80GB)
- **Memory**: 64GB+ system RAM
- **Storage**: 50GB+ free space

### Software
- Apptainer/Singularity installed
- Network access (for MSA server, optional)

### Files Required
- `boltz-bvbrc.sif` - Apptainer container image
- `.patric_token` - BV-BRC authentication token (for workspace tests)

---

## Test Script

**Location:** `tests/gpu_acceptance_test.sh`

### Usage

```bash
# Full test suite with workspace integration (~30-40 min)
./gpu_acceptance_test.sh <container.sif> --with-token ~/.patric_token

# Quick mode - container validation only (~2 min)
./gpu_acceptance_test.sh <container.sif> --quick

# Skip MSA server (faster predictions, less accurate)
./gpu_acceptance_test.sh <container.sif> --skip-msa

# Custom output directory
./gpu_acceptance_test.sh <container.sif> --output-dir /path/to/results
```

### Options

| Option | Description |
|--------|-------------|
| `--with-token <path>` | Path to `.patric_token` for workspace tests |
| `--quick` | Skip prediction tests (container validation only) |
| `--skip-msa` | Disable MSA server (faster but less accurate) |
| `--output-dir <path>` | Directory for test outputs (default: `./gpu_test_output`) |

---

## Test Categories

### 1. GPU Access Tests (~1 min)

Validates GPU availability and CUDA functionality.

| Test | Pass Criteria |
|------|---------------|
| nvidia-smi accessible | Returns valid GPU info |
| GPU type detection | H100 or A100 detected |
| GPU memory | >= 40GB available |
| PyTorch CUDA | `torch.cuda.is_available()` returns True |

### 2. Container Integrity Tests (~1 min)

Validates container structure and dependencies.

| Test | Pass Criteria |
|------|---------------|
| Container file | Exists and readable |
| Boltz CLI | `boltz --help` succeeds |
| Perl runtime | Version 5.40+ available |
| Python runtime | Version 3.11+ available |
| BV-BRC modules | `Bio::KBase::AppService::AppScript` loads |
| Service script | `/kb/module/service-scripts/App-Boltz.pl` exists |
| App spec | `/kb/module/app_specs/Boltz.json` exists |

### 3. App-Boltz.pl Service Script Tests (MAIN FOCUS) (~15-25 min)

Tests the complete BV-BRC service workflow via App-Boltz.pl.

**Workflow validated:**
1. Parameter parsing from JSON
2. Input file handling (local fallback mode)
3. Format detection (YAML/FASTA)
4. Boltz execution with correct flags
5. Output file generation

| Test | Input | Pass Criteria |
|------|-------|---------------|
| Simple protein | `simple_protein.yaml` | `.cif` file generated, confidence scores present |
| Multimer | `multimer.yaml` | Multi-chain output, all chains present |
| FASTA format | `simple_protein.fasta` | Format auto-detected, prediction succeeds |

### 4. Preflight Resource Estimation (~30 sec)

Tests the `--preflight` mode of App-Boltz.pl.

| Test | Pass Criteria |
|------|---------------|
| JSON output | Valid JSON returned |
| CPU estimate | `"cpu"` field present |
| Memory estimate | `"memory"` field present |
| GPU policy | `"gpu": 1` in policy |

### 5. Workspace Connectivity Tests (~1 min)

Tests BV-BRC workspace integration (requires token).

| Test | Pass Criteria |
|------|---------------|
| Token file | Exists at specified path |
| p3-login | Authentication succeeds |
| p3-ls | Workspace listing returns |

### 6. Direct Boltz CLI Tests (Optional) (~5 min)

Baseline comparison running `boltz predict` directly.

| Test | Pass Criteria |
|------|---------------|
| Direct prediction | Same output as App-Boltz.pl |

### 7. Performance Baseline (~30 sec)

Records timing and resource metrics.

| Metric | Expected (H100) |
|--------|-----------------|
| Simple protein runtime | < 10 minutes |
| Total test suite | < 40 minutes |

---

## Test Data

**Location:** `test_data/`

| File | Description | Size |
|------|-------------|------|
| `simple_protein.yaml` | Single chain protein (~60 residues) | Small |
| `simple_protein.fasta` | Same protein in FASTA format | Small |
| `multimer.yaml` | Homodimer + SAH ligands | Medium |
| `protein_ligand.yaml` | Protein + SAH with affinity | Medium |

---

## Output Files

**Location:** `gpu_test_output/` (configurable)

```
gpu_test_output/
├── gpu_acceptance_results.log      # Main results log
├── preflight_output.json           # Preflight JSON output
├── test_params.json                # Test parameters used
├── appboltz_simple_protein/
│   ├── params.json                 # Generated params for this test
│   ├── appboltz.log                # App-Boltz.pl execution log
│   └── predictions/                # Boltz output
│       └── *.cif                   # Structure files
├── appboltz_multimer/
│   └── ...
├── appboltz_fasta_format/
│   └── ...
└── direct_simple_protein/
    ├── prediction.log              # Direct boltz CLI log
    └── predictions/
```

---

## Success Criteria

### Full Pass
- All GPU tests pass
- All container integrity tests pass
- All App-Boltz.pl prediction tests complete with valid output
- Preflight returns valid JSON with GPU policy
- (If token provided) Workspace connectivity works

### Acceptable Pass
- Warnings for non-critical tests (e.g., missing confidence files)
- Workspace tests skipped (no token)

### Fail
- Any GPU access failure
- Any container integrity failure
- Any App-Boltz.pl prediction failure
- Preflight returns invalid JSON

---

## Execution Workflow

### 1. Prepare Container

```bash
# Option A: Pull from Docker Hub
cd boltzApp/container
singularity build boltz-bvbrc.sif docker://dxkb/boltz-bvbrc:latest-gpu

# Option B: Build from standalone definition
singularity build -f boltz-bvbrc.sif boltz-bvbrc-standalone.def
```

### 2. Run Tests

```bash
cd boltzApp/tests
./gpu_acceptance_test.sh ../container/boltz-bvbrc.sif --with-token ~/.patric_token
```

### 3. Review Results

```bash
# Summary
cat gpu_test_output/gpu_acceptance_results.log

# Check for failures
grep "FAIL" gpu_test_output/gpu_acceptance_results.log

# View App-Boltz.pl execution details
cat gpu_test_output/appboltz_simple_protein/appboltz.log
```

---

## Troubleshooting

### GPU Not Detected

```
[FAIL] nvidia-smi not accessible
```

**Solutions:**
- Ensure `--nv` flag is supported by your Apptainer version
- Check NVIDIA drivers: `nvidia-smi` on host
- Verify GPU is not in exclusive mode

### Perl Module Errors

```
[WARN] Perl module missing: Bio::KBase::AppService::AppScript
```

**Solutions:**
- Rebuild container from latest definition
- Check PERL5LIB environment variable in container

### MSA Server Timeout

```
[FAIL] App-Boltz.pl failed
```

**Solutions:**
- Use `--skip-msa` flag for offline testing
- Check network connectivity to `api.colabfold.com`
- Pre-cache model weights before testing

### Workspace Authentication Failed

```
[WARN] Workspace authentication status unclear
```

**Solutions:**
- Verify token file is valid: `cat ~/.patric_token`
- Check token expiration
- Test manually: `p3-login --status`

---

## Related Documentation

- [INPUT_FORMATS.md](./INPUT_FORMATS.md) - Boltz input format specifications
- [BOLTZ_INPUTS.md](./BOLTZ_INPUTS.md) - Complete input reference
- [MSA_SERVER.md](./MSA_SERVER.md) - MSA server documentation
- [tests/README.md](../tests/README.md) - Test infrastructure overview
