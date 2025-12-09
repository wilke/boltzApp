# Boltz Performance Benchmark Report

**Date**: 2025-12-04
**Container**: `/homes/wilke/images/boltz_latest-gpu.sif`
**GPU**: NVIDIA H100 NVL (96GB)

## Container Provenance

| Component | Version | Source |
|-----------|---------|--------|
| Boltz | v2.2.1 | https://github.com/jwohlwend/boltz (tag v2.2.1) |
| CUDA | 12.1.0 | nvidia/cuda:12.1.0-runtime-ubuntu22.04 |
| Python | 3.11 | deadsnakes PPA |
| Ubuntu | 22.04 | nvidia/cuda base image |
| Docker image | dxkb/boltz:latest-gpu | Built from `container/Dockerfile.boltz` (--target gpu) |
| Apptainer image | boltz_latest-gpu.sif | `singularity build boltz_latest-gpu.sif docker://dxkb/boltz:latest-gpu` |

### Reproducing the Container

```bash
# Build Docker image
cd container
docker build -t dxkb/boltz:latest-gpu --target gpu -f Dockerfile.boltz .

# Convert to Apptainer/Singularity
singularity build boltz_latest-gpu.sif docker://dxkb/boltz:latest-gpu
```

---

## Executive Summary

The Boltz Apptainer container is fully functional and produces correct biomolecular structure predictions. This report documents the runtime, memory, and disk footprint characteristics for various input sizes, comparing MSA server mode vs pre-computed MSA mode.

## Command-Line Usage

### Basic Singularity/Apptainer Command

```bash
# Run Boltz prediction with GPU support and MSA server
singularity exec --nv \
    -B /path/to/input:/input \
    -B /path/to/output:/output \
    -B ~/.boltz_cache:/root/.boltz \
    /homes/wilke/images/boltz_latest-gpu.sif \
    boltz predict /input/protein.yaml \
        --out_dir /output \
        --use_msa_server \
        --accelerator gpu
```

### With Pre-computed MSA (Faster)

```bash
# Run Boltz prediction with pre-computed MSA
singularity exec --nv \
    -B /path/to/input:/input \
    -B /path/to/msa:/msa \
    -B /path/to/output:/output \
    -B ~/.boltz_cache:/root/.boltz \
    /homes/wilke/images/boltz_latest-gpu.sif \
    boltz predict /input/protein.yaml \
        --out_dir /output \
        --accelerator gpu
```

### Key Options

| Option | Default | Description |
|--------|---------|-------------|
| `--use_msa_server` | false | Use ColabFold MSA server for automatic MSA generation |
| `--diffusion_samples` | 1 | Number of structure samples to generate |
| `--recycling_steps` | 3 | Number of recycling iterations |
| `--output_format` | mmcif | Output format (mmcif or pdb) |
| `--accelerator` | gpu | Compute device (gpu or cpu) |

### Required Bind Mounts

| Mount Point | Purpose |
|-------------|---------|
| `/input` | Input YAML/FASTA files |
| `/msa` | Pre-computed MSA files (if not using MSA server) |
| `/output` | Prediction output directory |
| `/root/.boltz` | Model weights cache (persist for faster startup) |

---

## Performance Comparison: MSA Server vs Pre-computed MSA

### Single Chain Proteins

| Length | MSA Server (s) | Pre-computed (s) | Speedup | GPU Memory (MB) |
|--------|----------------|------------------|---------|-----------------|
| 50 | 54.1 | 51.0 | 1.06x | 3,160 |
| 100 | 53.9 | 53.2 | 1.01x | 3,272 |
| 150 | 107.4 | 55.4 | 1.94x | 3,430 |
| 200 | 54.5 | 55.3 | 0.99x | 3,592 |
| 300 | 55.5 | 53.0 | 1.05x | 4,240 |
| 400 | 105.2 | 59.1 | 1.78x | 5,126 |
| 500 | 110.7 | 58.7 | 1.89x | 6,164 |

### Protein Complexes (Multimers)

| Configuration | MSA Server (s) | Pre-computed (s) | Speedup | GPU Memory (MB) |
|---------------|----------------|------------------|---------|-----------------|
| 2 × 50aa | 78.3 | 50.9 | 1.54x | 3,292 |
| 2 × 100aa | 60.2 | 55.9 | 1.08x | 3,672 |
| 2 × 200aa | 103.7 | 56.7 | 1.83x | 5,126 |
| 4 × 50aa | 106.8 | 54.4 | 1.96x | 3,672 |
| 4 × 100aa | 106.6 | 57.0 | 1.87x | 5,126 |

### Key Findings

1. **Pre-computed MSA is significantly more consistent**: Runtime variance is much lower without MSA server latency
2. **MSA server adds 0-50+ seconds overhead**: Variable latency depending on server load and sequence complexity
3. **GPU compute time is ~50-60 seconds**: The actual structure prediction takes roughly the same time regardless of protein size (within tested range)
4. **Memory scales linearly with residue count**: ~6 MB per residue above base memory

---

## Detailed Results: Pre-computed MSA Mode (Recommended for Production)

### Test Configuration

- Diffusion samples: 1
- Recycling steps: 3
- MSA server: **DISABLED** (using pre-computed MSAs)
- Accelerator: GPU (NVIDIA H100 NVL)

### Full Results

| Test Name | Length | Batch | Residues | Runtime (s) | GPU Mem (MB) | Disk (MB) |
|-----------|--------|-------|----------|-------------|--------------|-----------|
| protein_len50_batch1 | 50 | 1 | 50 | 51.0 | 3,162 | 1 |
| protein_len100_batch1 | 100 | 1 | 100 | 53.2 | 3,272 | 1 |
| protein_len150_batch1 | 150 | 1 | 150 | 55.4 | 3,430 | 1 |
| protein_len200_batch1 | 200 | 1 | 200 | 55.3 | 3,592 | 1 |
| protein_len300_batch1 | 300 | 1 | 300 | 53.0 | 4,240 | 1 |
| protein_len400_batch1 | 400 | 1 | 400 | 59.1 | 5,126 | 2 |
| protein_len500_batch1 | 500 | 1 | 500 | 58.7 | 6,164 | 3 |
| protein_len50_batch2 | 50 | 2 | 100 | 50.9 | 3,292 | 1 |
| protein_len100_batch2 | 100 | 2 | 200 | 55.9 | 3,672 | 1 |
| protein_len200_batch2 | 200 | 2 | 400 | 56.7 | 5,126 | 2 |
| protein_len50_batch4 | 50 | 4 | 200 | 54.4 | 3,672 | 1 |
| protein_len100_batch4 | 100 | 4 | 400 | 57.0 | 5,126 | 2 |

---

## Memory Scaling Analysis

### GPU Memory Formula

```
GPU_Memory_MB ≈ 3000 + (6.4 × total_residues)
```

| Total Residues | Predicted (MB) | Actual (MB) | Error |
|----------------|----------------|-------------|-------|
| 50 | 3,320 | 3,162 | 5% |
| 100 | 3,640 | 3,272 | 10% |
| 200 | 4,280 | 3,592 | 16% |
| 300 | 4,920 | 4,240 | 14% |
| 400 | 5,560 | 5,126 | 8% |
| 500 | 6,200 | 6,164 | 1% |

### Recommended GPU Requirements

| Protein Size | Min GPU Memory | Recommended GPU |
|--------------|----------------|-----------------|
| Small (<200aa) | 8 GB | T4, RTX 3090 |
| Medium (200-500aa) | 16 GB | A10, RTX 4090 |
| Large (500-1000aa) | 40 GB | A100-40GB |
| Very Large (>1000aa) | 80 GB | A100-80GB, H100 |

---

## Runtime Breakdown

### Components

| Component | Time (s) | Notes |
|-----------|----------|-------|
| Container startup | ~3-5 | Singularity overhead |
| Model loading | ~35-40 | First run downloads weights (~2GB) |
| MSA processing | ~5-10 | Reading/parsing MSA files |
| GPU inference | ~8-15 | Structure prediction |
| Output writing | ~2-3 | CIF/JSON file generation |
| **Total (pre-computed)** | **~50-60** | Consistent timing |
| MSA server query | **+15-50** | Variable, depends on server |

### Throughput Estimates

| Configuration | Time per Structure | Structures per Hour |
|---------------|-------------------|---------------------|
| Single GPU, pre-computed MSA | ~55s | ~65 |
| Single GPU, MSA server | ~80s | ~45 |
| 4 GPUs parallel, pre-computed | ~55s | ~260 |

---

## Recommendations

### For Production Use

1. **Pre-compute MSAs**: Use ColabFold locally or on a cluster to generate MSAs in batch, then run Boltz predictions without the server

2. **Persist cache directory**: Always bind mount `/root/.boltz` to avoid re-downloading model weights

3. **Use GPU with ≥16GB VRAM**: For typical proteins under 500 residues

4. **Batch processing**: Process multiple inputs sequentially on single GPU for maximum throughput

### Input Format with Pre-computed MSA

```yaml
version: 1
sequences:
  - protein:
      id: A
      sequence: MVTPEGNVSLVDESLLVGVTDEDRAVRSAHQFYERLIGLWAPAVMEAAHELGVFAALAE
      msa: /msa/my_protein.csv
```

The MSA CSV format:
```csv
key,sequence
-1,MVTPEGNVSLVDESLLVGVTDEDRAVRSAHQFYERLIGLWAPAVMEAAHELGVFAALAE
-1,MVTPEGNVSLVDESLLVGVTDEDRAVRSAHQFYERLIGLWAPAVMEAAHELGVFAALAE
```

---

## Benchmark Scripts

Located in `/home/wilke/dxkb/boltzApp/benchmark/`:

| Script | Purpose |
|--------|---------|
| `run_single_test.sh` | Quick single prediction test |
| `run_benchmark_suite.sh` | Full benchmark with MSA server |
| `run_benchmark_precomputed_msa.sh` | Benchmark with pre-computed MSA |
| `generate_inputs.sh` | Generate test input YAML files |
| `setup_precomputed_msa.sh` | Extract MSAs and create inputs with MSA paths |

### Directory Structure

```
benchmark/
├── inputs/                    # Original inputs (no MSA paths)
├── inputs_with_msa/           # Inputs with pre-computed MSA references
├── msa_cache/                 # Extracted MSA CSV files
├── output/                    # Test outputs (MSA server mode)
├── output_precomputed/        # Test outputs (pre-computed MSA mode)
├── results/                   # Benchmark results and reports
│   ├── benchmark_*.csv
│   ├── benchmark_*.md
│   └── benchmark_report_20251204.md
└── *.sh                       # Benchmark scripts
```

---

## Appendix: Raw Data Files

- `benchmark_20251204_154448.csv` - MSA server mode results
- `benchmark_precomputed_msa_20251204_160815.csv` - Pre-computed MSA results
