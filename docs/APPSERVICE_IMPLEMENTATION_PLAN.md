# AppService Implementation Plan: Boltz

**Created**: 2025-12-02
**Updated**: 2025-12-10
**Status**: ✅ Complete

---

## Summary

BV-BRC AppService for Boltz biomolecular structure prediction is now complete and deployed.

### Deliverables

| Component | Status | Location |
|-----------|--------|----------|
| Base Docker image | ✅ | `dxkb/boltz:20251204.0` |
| BV-BRC integrated image | ✅ | `dxkb/boltz:bvbrc`, `dxkb/boltz:bvbrc-20251209.0` |
| App specification | ✅ | `app_specs/Boltz.json` |
| Service script | ✅ | `service-scripts/App-Boltz.pl` |
| Apptainer definitions | ✅ | `container/boltz-bvbrc.def`, `boltz-bvbrc-standalone.def` |
| Test suite | ✅ | `tests/test_docker_container.sh` (52 tests) |
| Benchmarks | ✅ | `benchmark/results/benchmark_report_20251204.md` |
| Documentation | ✅ | `docs/INPUT_FORMATS.md`, `docs/MSA_SERVER.md` |

### Architecture

```
┌─────────────────────────────────────────────────────────┐
│  Layer 3: dxkb/boltz:bvbrc                              │
│           (BV-BRC runtime from dxkb/dev_container)      │
├─────────────────────────────────────────────────────────┤
│  Layer 2: dxkb/boltz:20251204.0                         │
│           (Boltz v2.2.1 + Python 3.11 + CUDA 12.1)      │
├─────────────────────────────────────────────────────────┤
│  Layer 1: nvidia/cuda:12.1.0-runtime-ubuntu22.04        │
└─────────────────────────────────────────────────────────┘
```

### Key Features

- **Boltz v2.2.1**: State-of-the-art biomolecular structure prediction
- **GPU Support**: NVIDIA CUDA 12.1 with A100/H100 optimization
- **BV-BRC Integration**: Full workspace connectivity, preflight resource estimation
- **Perl 5.40.2**: Standardized runtime from `dxkb/dev_container`
- **142 p3 CLI commands**: Full BV-BRC toolset available

---

## Implementation History

### Phase 1: Documentation & Foundation (Complete)
- Created MSA server documentation
- Created input format documentation (YAML/FASTA)
- Created test data files
- Created app specification JSON

### Phase 2: Docker Images (Complete)
- Built base Boltz image with GPU/CPU variants
- Built BV-BRC runtime layer using dev_container overlay
- Pushed images to Docker Hub

### Phase 3: Service Scripts (Complete)
- Implemented `App-Boltz.pl` with preflight and run callbacks
- Added workspace file handling
- Added YAML/FASTA format detection

### Phase 4: Testing & Deployment (Complete)
- Created comprehensive test suite (52 tests)
- Ran GPU benchmarks on H100
- Created Apptainer definitions for HPC deployment
- Documented container provenance

---

## Container Images

| Image | Size | Description |
|-------|------|-------------|
| `dxkb/boltz:20251204.0` | ~8 GB | Base Boltz + Python + CUDA |
| `dxkb/boltz:bvbrc` | ~10 GB | + BV-BRC Perl runtime |
| `dxkb/boltz:bvbrc-20251209.0` | ~10 GB | Tagged release |

### Build Commands

```bash
# Build base image
docker build --platform linux/amd64 -t dxkb/boltz:latest-gpu \
  --target gpu -f container/Dockerfile.boltz .

# Build BV-BRC image
docker build --platform linux/amd64 -t dxkb/boltz:bvbrc \
  -f container/Dockerfile.boltz-bvbrc .

# Build Apptainer for HPC
singularity build boltz-bvbrc.sif docker://dxkb/boltz:bvbrc
```

---

## Testing

Run the test suite:

```bash
# Basic tests
./tests/test_docker_container.sh dxkb/boltz:bvbrc

# With workspace authentication
./tests/test_docker_container.sh dxkb/boltz:bvbrc --with-token ~/.patric_token
```

---

## Related Projects

- **ChaiApp**: Similar implementation for Chai-Lab (separate repository)
- **CEPI/containers**: Base container build system (`dxkb/dev_container`)
