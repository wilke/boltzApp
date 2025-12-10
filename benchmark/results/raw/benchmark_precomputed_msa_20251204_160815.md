# Boltz Performance Benchmark Results - Pre-computed MSA

**Date**: 2025-12-04 16:19:17
**Container**: /homes/wilke/images/boltz_latest-gpu.sif
**GPU**: NVIDIA H100 NVL, 95830 MiB
**GPU ID**: 4
**Mode**: Full
**MSA Mode**: Pre-computed (No MSA server)

## Configuration

- Diffusion samples: 1
- Recycling steps: 3
- MSA server: **DISABLED** (using pre-computed MSAs)
- Accelerator: GPU

## Results

| Test Name | Length | Batch | Total Residues | Runtime (s) | Peak GPU Mem (MB) | Disk (MB) | Status |
|-----------|--------|-------|----------------|-------------|-------------------|-----------|--------|
| protein_len50_batch1 | 50 | 1 | 50 | 51.0 | 3162 | 1 | success |
| protein_len100_batch1 | 100 | 1 | 100 | 53.2 | 3272 | 1 | success |
| protein_len150_batch1 | 150 | 1 | 150 | 55.4 | 3430 | 1 | success |
| protein_len200_batch1 | 200 | 1 | 200 | 55.3 | 3592 | 1 | success |
| protein_len300_batch1 | 300 | 1 | 300 | 53.0 | 4240 | 1 | success |
| protein_len400_batch1 | 400 | 1 | 400 | 59.1 | 5126 | 2 | success |
| protein_len500_batch1 | 500 | 1 | 500 | 58.7 | 6164 | 3 | success |
| protein_len50_batch2 | 50 | 2 | 100 | 50.9 | 3292 | 1 | success |
| protein_len100_batch2 | 100 | 2 | 200 | 55.9 | 3672 | 1 | success |
| protein_len200_batch2 | 200 | 2 | 400 | 56.7 | 5126 | 2 | success |
| protein_len50_batch4 | 50 | 4 | 200 | 54.4 | 3672 | 1 | success |
| protein_len100_batch4 | 100 | 4 | 400 | 57.0 | 5126 | 2 | success |

## Analysis

### Runtime Scaling by Protein Length (Single Chain)

| Length | Runtime (s) | Runtime/Residue (ms) |
|--------|-------------|---------------------|
| 50 | 51.0 | 1020.36 |
| 100 | 53.2 | 531.61 |
| 150 | 55.4 | 369.38 |
| 200 | 55.3 | 276.35 |
| 300 | 53.0 | 176.60 |
| 400 | 59.1 | 147.69 |
| 500 | 58.7 | 117.36 |

### Memory Scaling by Total Residues

| Total Residues | Peak GPU Memory (MB) |
|----------------|---------------------|
| 50 | 3162 |
| 100 | 3292 |
| 100 | 3272 |
| 150 | 3430 |
| 200 | 3672 |
| 200 | 3592 |
| 200 | 3672 |
| 300 | 4240 |
| 400 | 5126 |
| 400 | 5126 |
| 400 | 5126 |
| 500 | 6164 |

## Comparison: MSA Server vs Pre-computed MSA

This benchmark measures **pure GPU inference time** without MSA server latency.
Compare with the MSA server benchmark to see the overhead of MSA generation.

## Raw Data

See: [benchmark_precomputed_msa_20251204_160815.csv](benchmark_precomputed_msa_20251204_160815.csv)

## Notes

- Runtime does NOT include MSA server latency (pre-computed MSAs used)
- Peak GPU memory measured during prediction
- Disk usage includes all output files (structures, MSA, logs)
