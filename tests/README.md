# BoltzApp Test Suite

This directory contains validation and testing scripts for the BoltzApp BV-BRC module.

## Test Scripts

### 1. Docker Container Validation (`test_docker_container.sh`)

Comprehensive validation of Docker container functionality.

**Usage:**
```bash
./test_docker_container.sh [container_tag] [--with-token token_path]
```

**Examples:**
```bash
# Basic validation
./test_docker_container.sh dxkb/boltz-bvbrc:latest-gpu

# With workspace token testing
./test_docker_container.sh dxkb/boltz-bvbrc:latest-gpu --with-token ~/.patric_token
```

**Tests:**
- Docker image exists and size
- Boltz CLI availability and version
- Perl installation and version
- BV-BRC modules directory structure
- Required Perl modules loading:
  - Core: Try::Tiny, IPC::Run, File::Which, Template, YAML::XS
  - Issue #24: Capture::Tiny, Text::Table
  - BV-BRC: WorkspaceClient, AppScript
- Service script and app spec existence
- Environment variables configuration
- Directory structure validation

### 2. Apptainer/Singularity Container Validation (`test_apptainer_container.sh`)

Comprehensive validation of Apptainer/Singularity container functionality.

**Usage:**
```bash
./test_apptainer_container.sh <container.sif> [--with-token token_path]
```

**Examples:**
```bash
# Basic validation
./test_apptainer_container.sh /path/to/boltz-bvbrc.sif

# With workspace token testing
./test_apptainer_container.sh /path/to/boltz-bvbrc.sif --with-token ~/.patric_token
```

**Tests:**
- Container file exists and size
- Singularity/Apptainer runtime detection
- Boltz CLI availability and version
- Perl installation and version
- BV-BRC modules directory structure
- Required Perl modules loading
- Service script and app spec existence
- Workspace connectivity (with token)
- Environment variables configuration
- Directory structure validation

### 3. Output Validation (`validate_output.sh`)

Validates Boltz prediction output structure and required files.

**Usage:**
```bash
./validate_output.sh <output_directory>
```

**Checks:**
- `predictions/` directory exists
- Structure files (.cif or .pdb) present
- Confidence files (confidence_*.json)
- pLDDT score files (plddt_*.npz)
- `processed/` directory (optional)

## Test Data

The `test_data/` directory contains sample input files for testing predictions:

- YAML format inputs
- FASTA format inputs (deprecated)
- Multi-chain protein examples
- Protein-ligand complex examples

## Quick Start

### Test Docker Container
```bash
# Run all Docker container tests
cd tests
./test_docker_container.sh dxkb/boltz-bvbrc:latest-gpu
```

### Test Apptainer Container
```bash
# Run all Apptainer container tests
cd tests
./test_apptainer_container.sh /path/to/container.sif
```

### Test Prediction Output
```bash
# Validate prediction results
cd tests
./validate_output.sh /path/to/output/directory
```

## Exit Codes

All test scripts use standard exit codes:
- `0`: All tests passed
- `1`: One or more tests failed

## Issue Resolution

### Issue #24 - Missing Perl Modules
The Docker container validation script specifically tests for:
- `Capture::Tiny` - Required by Bio::KBase::AppService::AppScript
- `Text::Table` - Required by Bio::P3::Workspace::ScriptHelpers

These modules were added to `container/Dockerfile.boltz-bvbrc` to resolve missing dependency errors.

### Issue #5 - Container Testing
Both Docker and Apptainer validation scripts provide comprehensive testing for:
- Runtime environment setup
- Module availability
- Service integration
- Workspace connectivity

## Contributing

When adding new tests:
1. Follow the existing pattern of section-based testing
2. Use color-coded output (pass/fail/warn)
3. Provide clear error messages
4. Update this README with new test descriptions

## Related Documentation

- Container build instructions: `container/DOCKER.md`
- Input format specifications: `docs/INPUT_FORMATS.md`
- BV-BRC integration guide: `CLAUDE.md`
