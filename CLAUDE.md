# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

BoltzApp is a BV-BRC (Bacterial and Viral Bioinformatics Resource Center) module that wraps the Boltz-2 biomolecular structure prediction tool. It provides an AppService interface for running Boltz predictions through the BV-BRC infrastructure.

**Boltz** is a state-of-the-art deep learning model for predicting 3D structures of biomolecular complexes including proteins, DNA, RNA, and small molecule ligands.

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│  Layer 3: dxkb/boltz-bvbrc:latest-gpu                   │
│           (BV-BRC runtime + Perl modules)               │
├─────────────────────────────────────────────────────────┤
│  Layer 2: dxkb/boltz:latest-gpu                         │
│           (Boltz + Python + CUDA)                       │
├─────────────────────────────────────────────────────────┤
│  Layer 1: nvidia/cuda:12.1.0-runtime-ubuntu22.04        │
└─────────────────────────────────────────────────────────┘
```

Key components:
- **service-scripts/App-Boltz.pl**: BV-BRC AppService entry point with `preflight()` and `run_boltz()` callbacks
- **app_specs/Boltz.json**: Service parameter definitions and resource requirements
- **cwl/boltz.cwl**: CWL workflow definition for pipeline integration
- **container/Dockerfile.boltz**: Base Boltz image (GPU/CPU variants)
- **container/Dockerfile.boltz-bvbrc**: BV-BRC runtime layer with Perl and workspace support
- **container/boltz-bvbrc.def**: Apptainer/Singularity definition for HPC deployment

## Building and Running

### Docker Images

```bash
# Build base GPU image
cd container
docker build -t dxkb/boltz:latest-gpu --target gpu -f Dockerfile.boltz .

# Build BV-BRC integrated image
docker build --platform linux/amd64 -t dxkb/boltz-bvbrc:latest-gpu -f Dockerfile.boltz-bvbrc .

# Run prediction
docker run --gpus all -v $(pwd)/data:/data -v $(pwd)/output:/output \
  dxkb/boltz-bvbrc:latest-gpu boltz predict /data/input.yaml --use_msa_server

# Run as BV-BRC service
docker run --gpus all -v $(pwd)/data:/data dxkb/boltz-bvbrc:latest-gpu App-Boltz params.json
```

### Apptainer/Singularity (HPC)

```bash
# Build from Docker image
singularity build boltz-bvbrc.sif docker://dxkb/boltz-bvbrc:latest-gpu

# Run with GPU
singularity run --nv boltz-bvbrc.sif boltz predict input.yaml --use_msa_server
```

### Testing

```bash
# Validate prediction output
./tests/validate_output.sh /path/to/output

# Test with sample data
docker run --gpus all -v $(pwd)/test_data:/data -v $(pwd)/output:/output \
  dxkb/boltz-bvbrc:latest-gpu boltz predict /data/simple_protein.yaml --use_msa_server
```

## Input Formats

Boltz accepts two input formats:

1. **YAML** (recommended): Full feature support including constraints, templates, and affinity prediction
2. **FASTA** (deprecated): Limited features, maintained for backward compatibility

See `docs/INPUT_FORMATS.md` for detailed format specifications.

## Key Parameters

| Parameter | Default | Description |
|-----------|---------|-------------|
| `--use_msa_server` | - | Use ColabFold MSA server (recommended) |
| `--diffusion_samples` | 1 | Number of structure samples |
| `--recycling_steps` | 3 | Model recycling iterations |
| `--output_format` | mmcif | Output format (mmcif or pdb) |
| `--accelerator` | gpu | Compute device (gpu or cpu) |

## BV-BRC Module Structure

This follows the standard BV-BRC dev_container module layout:
- `app_specs/`: Service parameter JSON definitions
- `service-scripts/`: AppService entry point scripts (Perl)
- `lib/`: Module libraries
- `scripts/`: Utility scripts
- `test_data/`: Sample input files for testing
- `tests/`: Validation scripts

## Resource Requirements

- **GPU**: A100 recommended (64GB VRAM for large complexes)
- **Memory**: 64GB minimum, 96GB for affinity prediction
- **Storage**: 50GB for model weights and outputs
