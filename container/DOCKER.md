# Docker Usage Guide for Boltz

This guide explains how to use Boltz with Docker for containerized biomolecular interaction prediction.

## Quick Start

### Building the Image

**For GPU (CUDA) support:**
```bash
# Standard build
docker build -t boltz:latest-gpu --target gpu .

# Multi-platform build (e.g., for linux/amd64)
docker buildx build --platform linux/amd64 --load -t boltz:latest-gpu --target gpu .
```

**For CPU-only:**
```bash
# Standard build
docker build -t boltz:latest-cpu --target cpu .

# Multi-platform build
docker buildx build --platform linux/amd64 --load -t boltz:latest-cpu --target cpu .
```

### Using Docker Compose

**GPU version:**
```bash
docker-compose up boltz-gpu
```

**CPU version:**
```bash
docker-compose up boltz-cpu
```

## Running Predictions

### Basic Usage

Place your input YAML files in a `./data` directory, then run:

```bash
# GPU version
docker run --gpus all \
  -v $(pwd)/data:/data \
  -v $(pwd)/output:/output \
  boltz:latest-gpu \
  predict /data/input.yaml --out_dir /output --use_msa_server

# CPU version
docker run \
  -v $(pwd)/data:/data \
  -v $(pwd)/output:/output \
  boltz:latest-cpu \
  predict /data/input.yaml --out_dir /output --use_msa_server
```

### Using Docker Compose

1. Place input files in `./data/`
2. Modify `docker-compose.yml` to set your prediction command
3. Run:

```bash
# Edit docker-compose.yml to change the command, e.g.:
# command: predict /data/input.yaml --out_dir /output --use_msa_server

docker-compose run --rm boltz-gpu
```

### Persistent Cache

The Docker setup uses a named volume `boltz-cache` to persist downloaded model checkpoints and data between runs. This avoids re-downloading large model files.

To clear the cache:
```bash
docker volume rm boltz_boltz-cache
```

## Advanced Options

### Custom CUDA Version

Build with a specific CUDA version:
```bash
docker build \
  --build-arg CUDA_VERSION=12.1.0 \
  --build-arg PYTHON_VERSION=3.11 \
  -t boltz:custom-gpu \
  --target gpu .
```

### Interactive Mode

Run an interactive shell inside the container:
```bash
docker run -it --gpus all \
  -v $(pwd)/data:/data \
  -v $(pwd)/output:/output \
  --entrypoint /bin/bash \
  boltz:latest-gpu
```

Then inside the container:
```bash
boltz predict /data/input.yaml --use_msa_server
```

### Batch Processing

Process multiple YAML files in a directory:
```bash
docker run --gpus all \
  -v $(pwd)/data:/data \
  -v $(pwd)/output:/output \
  boltz:latest-gpu \
  predict /data --out_dir /output --use_msa_server
```

## Volume Mounts

The Docker setup expects the following directories:

- `/data` - Input files (YAML, FASTA, MSA files, templates)
- `/output` - Prediction outputs (structures, confidence metrics)
- `/root/.boltz` - Cache directory for model checkpoints (persisted via volume)

## MSA Server Authentication

If using an MSA server that requires authentication:

```bash
docker run --gpus all \
  -v $(pwd)/data:/data \
  -v $(pwd)/output:/output \
  -e MSA_SERVER_USERNAME=your_username \
  -e MSA_SERVER_PASSWORD=your_password \
  boltz:latest-gpu \
  predict /data/input.yaml \
    --use_msa_server \
    --msa_server_username your_username \
    --msa_server_password your_password
```

## Resource Limits

Limit GPU and memory usage:

```bash
docker run --gpus '"device=0"' \
  --memory="32g" \
  --shm-size="16g" \
  -v $(pwd)/data:/data \
  -v $(pwd)/output:/output \
  boltz:latest-gpu \
  predict /data/input.yaml --out_dir /output
```

## Troubleshooting

### GPU Not Detected

Ensure NVIDIA Container Toolkit is installed:
```bash
# Install nvidia-container-toolkit
sudo apt-get install -y nvidia-container-toolkit
sudo systemctl restart docker
```

Verify GPU access:
```bash
docker run --rm --gpus all nvidia/cuda:12.1.0-base-ubuntu22.04 nvidia-smi
```

### Out of Memory

- Reduce `--max_tokens` or `--max_atoms` parameters
- Use CPU version for smaller predictions
- Increase Docker's memory limit

### Permission Issues

The container runs as root by default. To match your user ID:
```bash
docker run --gpus all \
  --user $(id -u):$(id -g) \
  -v $(pwd)/data:/data \
  -v $(pwd)/output:/output \
  boltz:latest-gpu \
  predict /data/input.yaml --out_dir /output
```

## Examples

See the `examples/` directory for sample input files. To run an example:

```bash
docker run --gpus all \
  -v $(pwd)/examples:/data \
  -v $(pwd)/output:/output \
  boltz:latest-gpu \
  predict /data/prot.yaml --out_dir /output --use_msa_server
```

---

## BV-BRC Integration

The `dxkb/boltz-bvbrc` image includes BV-BRC AppService integration for running Boltz as a BV-BRC service.

### Building the BV-BRC Image

```bash
# From the repository root
docker build --platform linux/amd64 \
  -t dxkb/boltz-bvbrc:latest-gpu \
  -f container/Dockerfile.boltz-bvbrc .
```

### Using Docker Compose

```bash
docker-compose up boltz-bvbrc
```

### Running as BV-BRC Service

```bash
# Run the App-Boltz service script
docker run --gpus all \
  -v $(pwd)/data:/data \
  -v $(pwd)/output:/output \
  -e P3_AUTH_TOKEN="your-token" \
  dxkb/boltz-bvbrc:latest-gpu \
  App-Boltz params.json

# Or run boltz directly
docker run --gpus all \
  -v $(pwd)/data:/data \
  -v $(pwd)/output:/output \
  dxkb/boltz-bvbrc:latest-gpu \
  boltz predict /data/input.yaml --use_msa_server
```

### BV-BRC Environment Variables

The BV-BRC image sets up the following environment:

| Variable | Value | Description |
|----------|-------|-------------|
| `PERL5LIB` | `/bvbrc/modules/...` | Perl library paths for BV-BRC modules |
| `KB_TOP` | `/kb/deployment` | BV-BRC deployment directory |
| `KB_MODULE_DIR` | `/kb/module` | Module directory containing service scripts |
| `IN_BVBRC_CONTAINER` | `1` | Indicator for BV-BRC container environment |

### Included BV-BRC Modules

- `app_service` - AppScript framework
- `Workspace` - Workspace file operations
- `p3_core` - Core BV-BRC utilities
- `p3_auth` - Authentication handling
- `seed_core` - SEED framework utilities
- `seed_gjo` - GJO utilities
