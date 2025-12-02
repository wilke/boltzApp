# AppService Implementation Plan: Boltz & Chai-Lab

**Created**: 2025-12-02
**Status**: Planning
**Goal**: Create BV-BRC AppServices for Boltz (biomolecular interaction prediction) and Chai-Lab (molecular structure prediction)

---

## Executive Summary

This plan creates two BV-BRC AppServices by:
1. Building base Docker images for each tool (GPU/CPU variants)
2. Creating BV-BRC runtime layer images on top of base images
3. Implementing app_specs, service-scripts, and test data
4. Converting to Apptainer definitions for production deployment

### Architecture Overview

```
┌─────────────────────────────────────────────────────────────┐
│                    Docker Image Layers                       │
├─────────────────────────────────────────────────────────────┤
│  Layer 3: dxkb/boltz-bvbrc:latest-gpu                       │
│           (BV-BRC runtime + Perl + Workspace support)        │
├─────────────────────────────────────────────────────────────┤
│  Layer 2: dxkb/boltz:latest-gpu                             │
│           (Boltz + Python + CUDA)                            │
├─────────────────────────────────────────────────────────────┤
│  Layer 1: nvidia/cuda:12.1.0-runtime-ubuntu22.04            │
└─────────────────────────────────────────────────────────────┘
```

---

## Work Stream Organization

### Legend
- **[GPU]** - Requires GPU machine (via SSH)
- **[LOCAL]** - Can run on local machine (no GPU needed)
- **[DEP:X]** - Depends on task X completing first

---

## Phase 1: Documentation & Foundation (All LOCAL)

### Stream A: MSA Server Documentation
**Agent 1 - No dependencies**

| Task ID | Description | Location | Effort |
|---------|-------------|----------|--------|
| A1 | Create MSA server documentation explaining ColabFold MMseqs2 | `/docs/MSA_SERVER.md` | 1 hour |
| A2 | Document API endpoints and authentication options | Same file | 30 min |
| A3 | Compare boltz vs chai-lab MSA integration patterns | Same file | 30 min |

**Deliverables**:
- `boltzApp/docs/MSA_SERVER.md`
- `ChaiApp/docs/MSA_SERVER.md` (symlink or copy)

---

### Stream B: Input Format Documentation
**Agent 2 - No dependencies**

| Task ID | Description | Location | Effort |
|---------|-------------|----------|--------|
| B1 | Document Boltz YAML format with examples | `boltzApp/docs/INPUT_FORMATS.md` | 1 hour |
| B2 | Document Boltz FASTA format (deprecated) | Same file | 30 min |
| B3 | Document Chai-Lab FASTA format | `ChaiApp/docs/INPUT_FORMATS.md` | 30 min |
| B4 | Document Chai-Lab JSON constraints/restraints | Same file | 1 hour |
| B5 | Create comparison table YAML vs JSON formats | Both files | 30 min |

**Deliverables**:
- `boltzApp/docs/INPUT_FORMATS.md`
- `ChaiApp/docs/INPUT_FORMATS.md`

---

### Stream C: Test Data Creation
**Agent 3 - No dependencies**

| Task ID | Description | Location | Effort |
|---------|-------------|----------|--------|
| C1 | Create simple protein FASTA test file | `*/test_data/` | 15 min |
| C2 | Create protein+ligand YAML for Boltz | `boltzApp/test_data/` | 30 min |
| C3 | Create multimer YAML for Boltz | `boltzApp/test_data/` | 30 min |
| C4 | Create params.json for BV-BRC testing | `*/tests/` | 30 min |
| C5 | Create validation scripts | `*/tests/` | 1 hour |

**Deliverables**:
```
boltzApp/
├── test_data/
│   ├── simple_protein.fasta
│   ├── simple_protein.yaml
│   ├── protein_ligand.yaml
│   └── multimer.yaml
└── tests/
    ├── params.json
    └── validate_output.sh

ChaiApp/
├── test_data/
│   ├── simple_protein.fasta
│   ├── multimer.fasta
│   └── constraints.json
└── tests/
    ├── params.json
    └── validate_output.sh
```

---

### Stream D: App Specs JSON
**Agent 4 - No dependencies**

| Task ID | Description | Location | Effort |
|---------|-------------|----------|--------|
| D1 | Create Boltz.json app specification | `boltzApp/app_specs/Boltz.json` | 1 hour |
| D2 | Create ChaiLab.json app specification | `ChaiApp/app_specs/ChaiLab.json` | 1 hour |
| D3 | Define resource requirements (CPU/GPU/memory) | Both files | 30 min |
| D4 | Define parameter schemas | Both files | 30 min |

**App Spec Template** (for reference):
```json
{
    "id": "Boltz",
    "script": "App-Boltz",
    "label": "Boltz Biomolecular Structure Prediction",
    "description": "Predict biomolecular structures using Boltz-2",
    "parameters": [
        {
            "id": "input_file",
            "type": "wsfile",
            "required": 1,
            "label": "Input file (YAML or FASTA)"
        },
        {
            "id": "use_msa_server",
            "type": "bool",
            "default": true,
            "label": "Use MSA server for automatic MSA generation"
        },
        {
            "id": "diffusion_samples",
            "type": "int",
            "default": 1,
            "label": "Number of structure samples to generate"
        },
        {
            "id": "recycling_steps",
            "type": "int",
            "default": 3,
            "label": "Number of recycling steps"
        },
        {
            "id": "output_format",
            "type": "enum",
            "enum": ["mmcif", "pdb"],
            "default": "mmcif",
            "label": "Output structure format"
        }
    ],
    "default_memory": "64G",
    "default_cpu": 8,
    "default_runtime": 7200
}
```

---

## Phase 2: Docker Images (Mixed GPU/LOCAL)

### Stream E: Boltz Base Docker Image
**Agent 1 - LOCAL first, then [GPU] for testing**

| Task ID | Description | GPU? | Depends | Effort |
|---------|-------------|------|---------|--------|
| E1 | Review/update existing Dockerfile.boltz | LOCAL | - | 30 min |
| E2 | Build dxkb/boltz:latest-gpu locally | LOCAL | E1 | 15 min |
| E3 | Build dxkb/boltz:latest-cpu locally | LOCAL | E1 | 15 min |
| E4 | Push images to DockerHub | LOCAL | E2,E3 | 10 min |
| E5 | Test GPU image on remote machine | **GPU** | E4 | 30 min |
| E6 | Run prediction test with sample data | **GPU** | E5,C2 | 30 min |

**Commands**:
```bash
# E2: Build GPU image
cd /Users/me/Development/dxkb/boltzApp/container
docker build -t dxkb/boltz:latest-gpu --target gpu -f Dockerfile.boltz .

# E3: Build CPU image
docker build -t dxkb/boltz:latest-cpu --target cpu -f Dockerfile.boltz .

# E4: Push to DockerHub
docker push dxkb/boltz:latest-gpu
docker push dxkb/boltz:latest-cpu

# E5-E6: On GPU machine
docker run --gpus all -v $(pwd)/test_data:/data -v $(pwd)/output:/output \
  dxkb/boltz:latest-gpu predict /data/simple_protein.yaml --out_dir /output --use_msa_server
```

---

### Stream F: Chai-Lab Base Docker Image
**Agent 2 - LOCAL first, then [GPU] for testing**

| Task ID | Description | GPU? | Depends | Effort |
|---------|-------------|------|---------|--------|
| F1 | Create Dockerfile.chai based on upstream | LOCAL | - | 1 hour |
| F2 | Create docker-compose.yml for chai-lab | LOCAL | F1 | 30 min |
| F3 | Create DOCKER.md documentation | LOCAL | F1 | 30 min |
| F4 | Build dxkb/chai-lab:latest-gpu locally | LOCAL | F1 | 15 min |
| F5 | Push image to DockerHub | LOCAL | F4 | 10 min |
| F6 | Test GPU image on remote machine | **GPU** | F5 | 30 min |
| F7 | Run prediction test with sample data | **GPU** | F6,C1 | 30 min |

**Dockerfile.chai template**:
```dockerfile
# Dockerfile for Chai-Lab - Molecular Structure Prediction
ARG CUDA_VERSION=12.1.0
ARG PYTHON_VERSION=3.10

FROM nvidia/cuda:${CUDA_VERSION}-runtime-ubuntu22.04 AS gpu

ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=UTC

# Install Python and system dependencies
RUN apt-get update && apt-get install -y \
    python3.10 python3.10-dev python3-pip \
    git wget kalign \
    && rm -rf /var/lib/apt/lists/*

# Install chai-lab
RUN pip3 install chai_lab==0.6.1

# Create directories
RUN mkdir -p /data /output /cache

ENV CHAI_DOWNLOADS_DIR=/cache
ENV PYTHONUNBUFFERED=1

WORKDIR /data

ENTRYPOINT ["chai-lab"]
CMD ["--help"]
```

---

### Stream G: BV-BRC Runtime Layer - Boltz
**Agent 3 - LOCAL, [DEP:E4]**

| Task ID | Description | GPU? | Depends | Effort |
|---------|-------------|------|---------|--------|
| G1 | Create Dockerfile.boltz-bvbrc | LOCAL | E4 | 1.5 hours |
| G2 | Add Perl and core dependencies | LOCAL | G1 | 30 min |
| G3 | Add BV-BRC workspace/app support modules | LOCAL | G2 | 1 hour |
| G4 | Build dxkb/boltz-bvbrc:latest-gpu | LOCAL | G3 | 15 min |
| G5 | Push to DockerHub | LOCAL | G4 | 10 min |
| G6 | Test BV-BRC integration on GPU machine | **GPU** | G5,D1 | 1 hour |

**Dockerfile.boltz-bvbrc template**:
```dockerfile
# BV-BRC Runtime Layer for Boltz
FROM dxkb/boltz:latest-gpu AS bvbrc

# Install Perl and BV-BRC dependencies
RUN apt-get update && apt-get install -y \
    perl libfindbin-libs-perl libjson-perl libwww-perl \
    libio-socket-ssl-perl libfile-slurp-perl make git \
    && rm -rf /var/lib/apt/lists/*

# Clone BV-BRC core modules
RUN git clone --depth 1 https://github.com/BV-BRC/p3_core.git /bvbrc/p3_core && \
    git clone --depth 1 https://github.com/BV-BRC/Workspace.git /bvbrc/Workspace && \
    git clone --depth 1 https://github.com/BV-BRC/app_service.git /bvbrc/app_service && \
    git clone --depth 1 https://github.com/BV-BRC/p3_auth.git /bvbrc/p3_auth

# Set up Perl library paths
ENV PERL5LIB=/bvbrc/app_service/lib:/bvbrc/Workspace/lib:/bvbrc/p3_core/lib:/bvbrc/p3_auth/lib
ENV KB_TOP=/kb/deployment
ENV KB_RUNTIME=/usr

# Copy service scripts and app specs
COPY service-scripts/ /kb/module/service-scripts/
COPY app_specs/ /kb/module/app_specs/
COPY scripts/ /kb/module/scripts/

# Make scripts executable
RUN chmod +x /kb/module/service-scripts/*.pl /kb/module/scripts/*

WORKDIR /data

# Can run either boltz directly or BV-BRC service
ENTRYPOINT ["/bin/bash", "-c"]
CMD ["boltz --help"]
```

---

### Stream H: BV-BRC Runtime Layer - Chai-Lab
**Agent 4 - LOCAL, [DEP:F5]**

| Task ID | Description | GPU? | Depends | Effort |
|---------|-------------|------|---------|--------|
| H1 | Create Dockerfile.chai-bvbrc | LOCAL | F5 | 1.5 hours |
| H2 | Add Perl and core dependencies | LOCAL | H1 | 30 min |
| H3 | Add BV-BRC workspace/app support modules | LOCAL | H2 | 1 hour |
| H4 | Build dxkb/chai-lab-bvbrc:latest-gpu | LOCAL | H3 | 15 min |
| H5 | Push to DockerHub | LOCAL | H4 | 10 min |
| H6 | Test BV-BRC integration on GPU machine | **GPU** | H5,D2 | 1 hour |

---

## Phase 3: Service Scripts (All LOCAL)

### Stream I: Boltz Service Script
**Agent 1 - [DEP:D1]**

| Task ID | Description | Depends | Effort |
|---------|-------------|---------|--------|
| I1 | Create App-Boltz.pl service script | D1 | 2 hours |
| I2 | Implement preflight() for resource estimation | I1 | 1 hour |
| I3 | Implement run_boltz() main function | I1 | 2 hours |
| I4 | Add YAML/FASTA input detection | I3 | 30 min |
| I5 | Add MSA server option handling | I3 | 30 min |
| I6 | Add workspace download/upload | I3 | 1 hour |

**App-Boltz.pl structure**:
```perl
#!/usr/bin/env perl
use strict;
use warnings;
use Bio::KBase::AppService::AppScript;
use JSON;
use File::Slurp;

my $script = Bio::KBase::AppService::AppScript->new(\&run_boltz, \&preflight);
$script->run(\@ARGV);

sub preflight {
    my($app, $app_def, $raw_params, $params) = @_;

    # Estimate resources based on input
    my $memory = "64G";  # Default for GPU
    my $runtime = 7200;  # 2 hours default

    return {
        cpu => 8,
        memory => $memory,
        runtime => $runtime,
        storage => "50G",
        policy => { gpu => 1 }  # Request GPU
    };
}

sub run_boltz {
    my($app, $app_def, $raw_params, $params) = @_;

    # 1. Download input from workspace
    # 2. Detect YAML vs FASTA format
    # 3. Build boltz command
    # 4. Execute prediction
    # 5. Upload results to workspace
}
```

---

### Stream J: Chai-Lab Service Script
**Agent 2 - [DEP:D2]**

| Task ID | Description | Depends | Effort |
|---------|-------------|---------|--------|
| J1 | Create App-ChaiLab.pl service script | D2 | 2 hours |
| J2 | Implement preflight() for resource estimation | J1 | 1 hour |
| J3 | Implement run_chailab() main function | J1 | 2 hours |
| J4 | Add FASTA input handling | J3 | 30 min |
| J5 | Add MSA/template server options | J3 | 30 min |
| J6 | Add workspace download/upload | J3 | 1 hour |

---

## Phase 4: Apptainer Definitions (LOCAL build, GPU test)

### Stream K: Boltz Apptainer
**Agent 3 - [DEP:G5]**

| Task ID | Description | GPU? | Depends | Effort |
|---------|-------------|------|---------|--------|
| K1 | Create boltz-bvbrc.def from Docker | LOCAL | G5 | 1 hour |
| K2 | Build .sif image locally | LOCAL | K1 | 30 min |
| K3 | Test Apptainer image on GPU machine | **GPU** | K2 | 1 hour |
| K4 | Run full integration test | **GPU** | K3,I6 | 1 hour |

**boltz-bvbrc.def template**:
```singularity
Bootstrap: docker
From: dxkb/boltz-bvbrc:latest-gpu

%labels
    Author BV-BRC
    Application Boltz
    Version 2.2.1

%environment
    export PERL5LIB=/bvbrc/app_service/lib:/bvbrc/Workspace/lib:/bvbrc/p3_core/lib:/bvbrc/p3_auth/lib
    export BOLTZ_CACHE=/cache
    export PATH=/kb/module/scripts:$PATH

%runscript
    case "$1" in
        App-Boltz*)
            exec perl /kb/module/service-scripts/App-Boltz.pl "$@"
            ;;
        boltz)
            shift
            exec boltz "$@"
            ;;
        *)
            exec "$@"
            ;;
    esac

%test
    boltz --version
    perl -e 'use Bio::KBase::AppService::AppScript; print "BV-BRC OK\n"'
```

---

### Stream L: Chai-Lab Apptainer
**Agent 4 - [DEP:H5]**

| Task ID | Description | GPU? | Depends | Effort |
|---------|-------------|------|---------|--------|
| L1 | Create chai-lab-bvbrc.def from Docker | LOCAL | H5 | 1 hour |
| L2 | Build .sif image locally | LOCAL | L1 | 30 min |
| L3 | Test Apptainer image on GPU machine | **GPU** | L2 | 1 hour |
| L4 | Run full integration test | **GPU** | L3,J6 | 1 hour |

---

## Dependency Graph

```
Phase 1 (Parallel - No Dependencies)
├── Stream A: MSA Docs ─────────────────────────────────────────────┐
├── Stream B: Input Format Docs ────────────────────────────────────┤
├── Stream C: Test Data ────────────────────────────────────────────┤
└── Stream D: App Specs ────────────────────────────────────────────┤
                                                                    │
Phase 2 (Docker Images)                                             │
├── Stream E: Boltz Base ──────────┬─► E4 (push) ───────────────────┤
│                                  │                                │
├── Stream F: Chai Base ───────────┼─► F5 (push) ───────────────────┤
│                                  │                                │
├── Stream G: Boltz BV-BRC ────────┘──► G5 (push) ──────────────────┤
│   [DEP:E4]                                                        │
└── Stream H: Chai BV-BRC ────────────► H5 (push) ──────────────────┤
    [DEP:F5]                                                        │
                                                                    │
Phase 3 (Service Scripts)                                           │
├── Stream I: App-Boltz.pl ◄────────────────────────────────────────┤
│   [DEP:D1]                                                        │
└── Stream J: App-ChaiLab.pl ◄──────────────────────────────────────┘
    [DEP:D2]

Phase 4 (Apptainer)
├── Stream K: Boltz Apptainer [DEP:G5,I6]
└── Stream L: Chai Apptainer [DEP:H5,J6]
```

---

## Agent Assignment Matrix

### Optimal 4-Agent Parallel Execution

| Time Block | Agent 1 | Agent 2 | Agent 3 | Agent 4 |
|------------|---------|---------|---------|---------|
| Block 1 | A1-A3: MSA Docs | B1-B5: Input Docs | C1-C5: Test Data | D1-D4: App Specs |
| Block 2 | E1-E4: Boltz Docker | F1-F5: Chai Docker | (wait for E4) | (wait for F5) |
| Block 3 | **[GPU]** E5-E6: Test | **[GPU]** F6-F7: Test | G1-G5: Boltz BV-BRC | H1-H5: Chai BV-BRC |
| Block 4 | I1-I6: App-Boltz.pl | J1-J6: App-ChaiLab.pl | **[GPU]** G6: BV-BRC Test | **[GPU]** H6: BV-BRC Test |
| Block 5 | K1-K2: Boltz Apptainer | L1-L2: Chai Apptainer | **[GPU]** K3-K4: Test | **[GPU]** L3-L4: Test |

---

## GPU Task Summary

Tasks that **must run on GPU machine** (via SSH):

| Task | Description | Duration | Prerequisites |
|------|-------------|----------|---------------|
| E5 | Test Boltz GPU Docker | 30 min | E4 |
| E6 | Run Boltz prediction test | 30 min | E5, C2 |
| F6 | Test Chai GPU Docker | 30 min | F5 |
| F7 | Run Chai prediction test | 30 min | F6, C1 |
| G6 | Test Boltz BV-BRC integration | 1 hour | G5, D1 |
| H6 | Test Chai BV-BRC integration | 1 hour | H5, D2 |
| K3-K4 | Boltz Apptainer tests | 2 hours | K2, I6 |
| L3-L4 | Chai Apptainer tests | 2 hours | L2, J6 |

**Total GPU time**: ~8 hours (can be parallelized with 2 GPU nodes)

---

## File Structure Summary

### boltzApp Final Structure
```
/Users/me/Development/dxkb/boltzApp/
├── Makefile
├── README.md
├── CLAUDE.md
├── app_specs/
│   └── Boltz.json
├── container/
│   ├── Dockerfile.boltz          # Base image (existing)
│   ├── Dockerfile.boltz-bvbrc    # BV-BRC layer (new)
│   ├── boltz-bvbrc.def           # Apptainer (new)
│   ├── docker-compose.yml        # (existing)
│   └── DOCKER.md                 # (existing)
├── docs/
│   ├── MSA_SERVER.md             # (new)
│   └── INPUT_FORMATS.md          # (new)
├── lib/
│   └── README
├── scripts/
│   ├── README
│   └── boltz-wrapper             # (new)
├── service-scripts/
│   ├── README
│   └── App-Boltz.pl              # (new)
├── test_data/
│   ├── simple_protein.fasta      # (new)
│   ├── simple_protein.yaml       # (new)
│   ├── protein_ligand.yaml       # (new)
│   └── multimer.yaml             # (new)
└── tests/
    ├── params.json               # (new)
    └── validate_output.sh        # (new)
```

### ChaiApp Final Structure
```
/Users/me/Development/dxkb/ChaiApp/
├── Makefile
├── README.md
├── CLAUDE.md
├── app_specs/
│   └── ChaiLab.json              # (new)
├── container/
│   ├── Dockerfile.chai           # Base image (new)
│   ├── Dockerfile.chai-bvbrc     # BV-BRC layer (new)
│   ├── chai-lab-bvbrc.def        # Apptainer (new)
│   ├── docker-compose.yml        # (new)
│   └── DOCKER.md                 # (new)
├── docs/
│   ├── MSA_SERVER.md             # (new)
│   └── INPUT_FORMATS.md          # (new)
├── lib/
│   └── README
├── scripts/
│   ├── README
│   └── chai-wrapper              # (new)
├── service-scripts/
│   ├── README
│   └── App-ChaiLab.pl            # (new)
├── test_data/
│   ├── simple_protein.fasta      # (new)
│   ├── multimer.fasta            # (new)
│   └── constraints.json          # (new)
└── tests/
    ├── params.json               # (new)
    └── validate_output.sh        # (new)
```

---

## Quick Start Commands

### For Agent 1 (Boltz focus):
```bash
cd /Users/me/Development/dxkb/boltzApp

# Phase 1: Documentation
mkdir -p docs && touch docs/MSA_SERVER.md

# Phase 2: Build Docker
cd container && docker build -t dxkb/boltz:latest-gpu --target gpu -f Dockerfile.boltz .
docker push dxkb/boltz:latest-gpu
```

### For Agent 2 (Chai focus):
```bash
cd /Users/me/Development/dxkb/ChaiApp

# Phase 1: Documentation
mkdir -p docs && touch docs/INPUT_FORMATS.md

# Phase 2: Create and build Docker
mkdir -p container && touch container/Dockerfile.chai
```

### For GPU testing (SSH to GPU machine):
```bash
# Pull and test
docker pull dxkb/boltz:latest-gpu
docker run --gpus all -v /path/to/test_data:/data -v /path/to/output:/output \
  dxkb/boltz:latest-gpu predict /data/test.yaml --out_dir /output --use_msa_server
```

---

## Success Criteria

- [ ] Both base Docker images build and push successfully
- [ ] Both BV-BRC layer images build and push successfully
- [ ] Predictions run successfully on GPU machine
- [ ] App specs validate against BV-BRC schema
- [ ] Service scripts execute without errors
- [ ] Apptainer images build from Docker images
- [ ] Full integration tests pass on GPU machine
- [ ] Documentation is complete and accurate
