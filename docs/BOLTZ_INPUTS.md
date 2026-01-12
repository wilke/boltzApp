# Boltz Input Reference

This document describes all inputs for Boltz-2 biomolecular structure prediction, categorized by their nature: **constant/infrastructure** inputs vs **variable/user-provided** inputs.

---

## Input Categories Overview

| Category | Type | Examples |
|----------|------|----------|
| **Infrastructure (Constant)** | Model weights, databases, servers | Boltz weights, MSA server URL |
| **Required (Variable)** | User must provide | Input YAML/FASTA, output path |
| **Optional (Variable)** | User may provide | MSAs, templates, constraints |
| **Runtime Parameters** | User-configurable settings | Samples, recycling steps, output format |

---

## 1. Infrastructure/Constant Inputs

These are **pre-configured resources** that remain constant across runs. Users do not need to provide these.

### 1.1 Model Weights (~8GB)

| Component | Description | Location | Source |
|-----------|-------------|----------|--------|
| Boltz-2 weights | Neural network parameters | `~/.boltz/` or `$BOLTZ_CACHE` | Auto-downloaded on first run |
| CCD dictionary | Chemical Component Dictionary | Included with weights | wwPDB |

**Notes:**
- Weights are automatically downloaded on first run
- Cache location configurable via `BOLTZ_CACHE` environment variable
- Size: ~8GB total
- Includes support for all standard CCD ligand codes

### 1.2 External Servers (Optional but Recommended)

| Server | URL | Purpose | Required |
|--------|-----|---------|----------|
| ColabFold MSA Server | `https://api.colabfold.com` | Generate MSAs from sequence databases | No (improves accuracy) |

**Server Requirements:**
- Network access required when using `--use_msa_server`
- Rate limits apply to public servers
- Self-hosting option available for high-throughput

### 1.3 System Dependencies

| Dependency | Purpose | Container Location |
|------------|---------|-------------------|
| Python 3.11 | Runtime | `/opt/venv/` |
| CUDA 12.1+ | GPU acceleration | System |
| PyTorch 2.x | Deep learning framework | Installed via pip |

### 1.4 GPU Requirements

| GPU Type | VRAM | Suitable For |
|----------|------|--------------|
| A100 80GB | 80GB | Large complexes, affinity prediction |
| A100 40GB | 40GB | Medium complexes, multiple chains |
| H100 | 80GB | Fastest inference |
| A10/A30 | 24GB | Small proteins, single chains |
| RTX 4090 | 24GB | Development, small complexes |

---

## 2. Required Variable Inputs

These **must be provided by the user** for each prediction job.

### 2.1 Input File (Required)

The primary input describing molecules to predict. Boltz supports two formats:

| Format | Extension | Features | Recommended |
|--------|-----------|----------|-------------|
| **YAML** | `.yaml`, `.yml` | Full feature support | Yes |
| **FASTA** | `.fasta`, `.fa` | Limited features | No (deprecated) |

#### YAML Format (Recommended)

**Basic Structure:**
```yaml
version: 1
sequences:
  - ENTITY_TYPE:
      id: CHAIN_ID
      sequence: SEQUENCE
constraints: []    # optional
templates: []      # optional
properties: []     # optional
```

**Supported Entity Types:**

| Entity Type | Required Fields | Optional Fields | Example |
|-------------|-----------------|-----------------|---------|
| `protein` | `id`, `sequence` | `msa`, `modifications`, `cyclic` | Amino acid chain |
| `dna` | `id`, `sequence` | `modifications`, `cyclic` | DNA strand |
| `rna` | `id`, `sequence` | `modifications`, `cyclic` | RNA strand |
| `ligand` | `id`, `smiles` OR `ccd` | - | Small molecule |

**Examples:**

**Single protein:**
```yaml
version: 1
sequences:
  - protein:
      id: A
      sequence: MVTPEGNVSLVDESLLVGVTDEDRAVRSAHQFYERLIGLWAPAVMEAAHELGVFAALAE
```

**Protein homodimer (identical chains):**
```yaml
version: 1
sequences:
  - protein:
      id: [A, B]  # Two identical chains
      sequence: MVTPEGNVSLVDESLLVGVTDEDRAVRSAHQFYERLIGLWAPAVMEAAHELGVFAALAE
```

**Protein-ligand complex (SMILES):**
```yaml
version: 1
sequences:
  - protein:
      id: A
      sequence: MVTPEGNVSLVDESLLVGVTDEDRAVRSAHQFYERLIGLWAPAVMEAAHELGVFAALAE
  - ligand:
      id: L
      smiles: 'CC(=O)OC1=CC=CC=C1C(=O)O'
```

**Protein-ligand complex (CCD code):**
```yaml
version: 1
sequences:
  - protein:
      id: A
      sequence: MVTPEGNVSLVDESLLVGVTDEDRAVRSAHQFYERLIGLWAPAVMEAAHELGVFAALAE
  - ligand:
      id: L
      ccd: ATP
```

**Protein-DNA complex:**
```yaml
version: 1
sequences:
  - protein:
      id: A
      sequence: MVTPEGNVSLVDESLLVGVTDEDRAVRSAHQFYERLIGLWAPAVMEAAHELGVFAALAE
  - dna:
      id: B
      sequence: ATCGATCGATCGATCG
  - dna:
      id: C
      sequence: CGATCGATCGATCGAT
```

**Modified residues (phosphorylation):**
```yaml
version: 1
sequences:
  - protein:
      id: A
      sequence: MVTPEGNVSLVDESLLVGVTDEDRAVRSAHQFYERLIGLWAPAVMEAAHELGVFAALAE
      modifications:
        - position: 5     # 1-indexed
          ccd: SEP        # Phosphoserine
        - position: 15
          ccd: TPO        # Phosphothreonine
```

**Cyclic peptide:**
```yaml
version: 1
sequences:
  - protein:
      id: A
      sequence: CYSILEVALCYS
      cyclic: true
```

#### FASTA Format (Deprecated)

Limited feature support, maintained for backward compatibility.

**Format:**
```
>CHAIN_ID|ENTITY_TYPE|MSA_PATH
SEQUENCE
```

**Examples:**

```fasta
>A|protein
MVTPEGNVSLVDESLLVGVTDEDRAVRSAHQFYERLIGLWAPAVMEAAHELGVFAALAE
>L|smiles
CC1=CC=CC=C1
```

With pre-computed MSA:
```fasta
>A|protein|./msas/protein_a.a3m
MVTPEGNVSLVDESLLVGVTDEDRAVRSAHQFYERLIGLWAPAVMEAAHELGVFAALAE
```

### 2.2 Output Path (Required)

Where to save prediction results.

| Interface | Parameter | Example |
|-----------|-----------|---------|
| CLI | `--out_dir` | `boltz predict input.yaml --out_dir ./output` |
| BV-BRC | `output_path` | Workspace folder path |

---

## 3. Optional Variable Inputs

These **may be provided** to guide or improve predictions.

### 3.1 Pre-computed MSA Files

Provide your own Multiple Sequence Alignments instead of using the MSA server.

| Format | Extension | Description |
|--------|-----------|-------------|
| A3M | `.a3m` | Standard MSA format |
| Stockholm | `.sto` | Alternative format |

**YAML usage:**
```yaml
sequences:
  - protein:
      id: A
      sequence: MVTPEGNVSLVDESLLVGVTDEDRAVRSAHQFYERLIGLWAPAVMEAAHELGVFAALAE
      msa: ./msas/protein_a.a3m
```

**FASTA usage:**
```fasta
>A|protein|./msas/protein_a.a3m
MVTPEGNVSLVDESLLVGVTDEDRAVRSAHQFYERLIGLWAPAVMEAAHELGVFAALAE
```

**Single-sequence mode (no MSA):**
```fasta
>A|protein|empty
MVTPEGNVSLVDESLLVGVTDEDRAVRSAHQFYERLIGLWAPAVMEAAHELGVFAALAE
```

### 3.2 Structural Templates

Pre-computed structural templates to guide prediction.

| Format | Extension | Description |
|--------|-----------|-------------|
| mmCIF | `.cif` | Recommended format |
| PDB | `.pdb` | Legacy format (chains become A1, A2, etc.) |

**Basic template:**
```yaml
templates:
  - cif: ./templates/reference.cif
```

**Template with chain mapping:**
```yaml
templates:
  - cif: ./templates/reference.cif
    chain_id: [A, B]        # Chains in your input
    template_id: [X, Y]     # Corresponding chains in template
```

**Forced template (with potential):**
```yaml
templates:
  - cif: ./templates/reference.cif
    force: true
    threshold: 2.0          # Max deviation in Angstroms
```

### 3.3 Constraints (YAML only)

Experimental restraints to guide structure prediction. Only available in YAML format.

#### Covalent Bond Constraints

Specify covalent connections between chains:

```yaml
constraints:
  - bond:
      atom1: [A, 123, SG]   # [chain_id, residue_index, atom_name]
      atom2: [L, 1, C1]     # Connect Cys sulfur to ligand carbon
```

#### Pocket Constraints

Define binding pocket residues for ligand docking:

```yaml
constraints:
  - pocket:
      binder: L             # Chain that binds to pocket
      contacts:             # Residues forming the pocket
        - [A, 45]           # [chain_id, residue_index]
        - [A, 67]
        - [A, 89]
      max_distance: 6.0     # Angstroms (4-20A, default 6A)
      force: false          # Use potential to enforce (default false)
```

#### Contact Constraints

Specify that two residues should be in contact:

```yaml
constraints:
  - contact:
      token1: [A, 45]       # [chain_id, residue_index]
      token2: [B, 67]
      max_distance: 8.0     # Angstroms
      force: false
```

### 3.4 Affinity Prediction (YAML only)

Enable binding affinity prediction for protein-ligand complexes:

```yaml
properties:
  - affinity:
      binder: L             # Ligand chain ID
```

**Requirements:**
- Only one ligand can be specified for affinity
- Ligand must be ≤128 atoms (recommended ≤56 atoms)
- Only protein targets supported (not DNA/RNA)

---

## 4. Runtime Parameters

User-configurable settings that affect prediction behavior.

### 4.1 MSA Server Toggle

| Parameter | CLI Flag | Default | Description |
|-----------|----------|---------|-------------|
| `use_msa_server` | `--use_msa_server` | `true` | Use ColabFold MSA server |

**Impact:** Significantly improves prediction accuracy. Adds 1-10 minutes runtime depending on sequence length.

### 4.2 Diffusion Samples

| Parameter | CLI Flag | Default | Range | Description |
|-----------|----------|---------|-------|-------------|
| `diffusion_samples` | `--diffusion_samples` | `1` | 1-50+ | Structure samples to generate |

**Impact:**
- More samples = more diversity, longer runtime
- AlphaFold3 uses 25 samples
- Each additional sample adds ~2-5 minutes on A100

### 4.3 Recycling Steps

| Parameter | CLI Flag | Default | Range | Description |
|-----------|----------|---------|-------|-------------|
| `recycling_steps` | `--recycling_steps` | `3` | 1-20 | Structure refinement iterations |

**Impact:**
- More steps = potentially better accuracy
- AlphaFold3 uses 10 steps
- Diminishing returns beyond 10 steps

### 4.4 Sampling Steps

| Parameter | CLI Flag | Default | Description |
|-----------|----------|---------|-------------|
| `sampling_steps` | `--sampling_steps` | `200` | Diffusion sampling steps |

**Impact:** Higher values may improve quality but increase runtime.

### 4.5 Output Format

| Parameter | CLI Flag | Default | Options | Description |
|-----------|----------|---------|---------|-------------|
| `output_format` | `--output_format` | `mmcif` | mmcif, pdb | Structure file format |

### 4.6 Inference Potentials

| Parameter | CLI Flag | Default | Description |
|-----------|----------|---------|-------------|
| `use_potentials` | `--use_potentials` | `false` | Apply inference-time potentials |

**Impact:** Can improve physical plausibility of predicted structures.

### 4.7 Resource Estimates by Configuration

| Configuration | Memory | Runtime | GPU |
|---------------|--------|---------|-----|
| 1 sample, MSA server | 64GB | ~1 hour | A100 |
| 5 samples, MSA server | 64GB | ~2 hours | A100 |
| 25 samples, MSA server | 80GB | ~4 hours | A100 |
| Affinity prediction | 80GB | ~3 hours | A100 80GB |

---

## 5. Output Files

Boltz produces these outputs:

| File | Format | Description |
|------|--------|-------------|
| `predictions/` | Directory | Contains all structure predictions |
| `*_model_*.cif` | mmCIF | Predicted structures |
| `*_model_*.pdb` | PDB | Optional PDB format |
| `confidence_*.json` | JSON | Confidence scores |
| `pae_*.npz` | NumPy | PAE matrices (if enabled) |

**Key confidence metrics:**

| Metric | Range | Interpretation |
|--------|-------|----------------|
| pLDDT | 0-100 | Per-residue confidence (>70 = reliable) |
| pTM | 0-1 | Global fold confidence (>0.5 = reliable) |
| ipTM | 0-1 | Interface confidence for complexes |
| pDE | 0-1 | Distance error estimate |

---

## 6. Quick Reference Tables

### Input Summary

| Input | Type | Required | User Provides | Changes Per Job |
|-------|------|----------|---------------|-----------------|
| Model weights | Infrastructure | Yes | No | Never |
| MSA server | Infrastructure | No | No | Never |
| CUDA/GPU | Infrastructure | Yes | No | Never |
| **Input file (YAML/FASTA)** | Variable | **Yes** | **Yes** | **Every job** |
| **Output path** | Variable | **Yes** | **Yes** | **Every job** |
| Pre-computed MSA | Variable | No | Yes | Per job |
| Templates | Variable | No | Yes | Per job |
| Constraints | Variable | No | Yes | Per job |
| `diffusion_samples` | Parameter | No | Yes | Per job |
| `recycling_steps` | Parameter | No | Yes | Per job |
| `use_msa_server` | Parameter | No | Yes | Per job |
| `output_format` | Parameter | No | Yes | Per job |

### BV-BRC App Spec Parameters

| Parameter ID | Type | Required | Default | Description |
|--------------|------|----------|---------|-------------|
| `input_file` | wsfile | Yes | - | Input YAML or FASTA file |
| `output_path` | folder | Yes | - | Output workspace folder |
| `input_format` | enum | No | auto | Format detection (auto/yaml/fasta) |
| `use_msa_server` | bool | No | true | Enable MSA server |
| `diffusion_samples` | int | No | 1 | Number of samples |
| `recycling_steps` | int | No | 3 | Recycling iterations |
| `sampling_steps` | int | No | 200 | Diffusion steps |
| `output_format` | enum | No | mmcif | Output format |
| `use_potentials` | bool | No | false | Inference potentials |
| `predict_affinity` | bool | No | false | Affinity prediction |
| `write_full_pae` | bool | No | false | Save PAE matrix |
| `accelerator` | enum | No | gpu | Compute device |

### YAML vs FASTA Feature Comparison

| Feature | YAML | FASTA |
|---------|------|-------|
| Proteins | Yes | Yes |
| DNA/RNA | Yes | Yes |
| SMILES ligands | Yes | Yes |
| CCD ligands | Yes | Yes |
| Custom MSA | Yes | Yes |
| Modified residues | Yes | No |
| Cyclic sequences | Yes | No |
| Covalent bonds | Yes | No |
| Pocket constraints | Yes | No |
| Contact constraints | Yes | No |
| Templates | Yes | No |
| Affinity prediction | Yes | No |
| Homodimer shorthand | Yes (`id: [A,B]`) | No |

---

## 7. Example Workflows

### Minimal Prediction (single protein)

```bash
# Create input
cat > input.yaml << 'EOF'
version: 1
sequences:
  - protein:
      id: A
      sequence: MVTPEGNVSLVDESLLVGVTDEDRAVRSAHQFYERLIGLWAPAVMEAAHELGVFAALAE
EOF

# Run prediction
boltz predict input.yaml --out_dir output/ --use_msa_server
```

### Protein-Ligand Docking with Pocket Constraints

```yaml
# input.yaml
version: 1
sequences:
  - protein:
      id: A
      sequence: MVTPEGNVSLVDESLLVGVTDEDRAVRSAHQFYERLIGLWAPAVMEAAHELGVFAALAE
  - ligand:
      id: L
      smiles: 'CC(=O)OC1=CC=CC=C1C(=O)O'

constraints:
  - pocket:
      binder: L
      contacts:
        - [A, 12]
        - [A, 15]
        - [A, 34]
      max_distance: 6.0
```

```bash
boltz predict input.yaml --out_dir output/ --use_msa_server --diffusion_samples 5
```

### Binding Affinity Prediction

```yaml
# input.yaml
version: 1
sequences:
  - protein:
      id: A
      sequence: MVTPEGNVSLVDESLLVGVTDEDRAVRSAHQFYERLIGLWAPAVMEAAHELGVFAALAE
  - ligand:
      id: L
      smiles: 'CC(=O)OC1=CC=CC=C1C(=O)O'

properties:
  - affinity:
      binder: L
```

```bash
boltz predict input.yaml --out_dir output/ --use_msa_server --predict_affinity
```

### BV-BRC Service Invocation

```json
{
  "input_file": "/user@bvbrc.org/home/my_complex.yaml",
  "output_path": "/user@bvbrc.org/home/predictions/",
  "use_msa_server": true,
  "diffusion_samples": 5,
  "recycling_steps": 3,
  "output_format": "mmcif"
}
```

---

## 8. Boltz vs Chai-Lab Comparison

| Aspect | Boltz | Chai-Lab |
|--------|-------|----------|
| **Primary format** | YAML | FASTA + JSON |
| **Constraints format** | Inline YAML | Separate JSON file |
| **Modified residues** | YAML `modifications:` block | Inline `[CCD]` notation |
| **Templates** | Inline YAML reference | Separate .m8 + CIF files |
| **MSA format** | A3M | Parquet (.aligned.pqt) |
| **Affinity prediction** | Yes | No |
| **Homodimer syntax** | `id: [A, B]` | Separate FASTA entries |
| **Cyclic support** | Yes (`cyclic: true`) | No |

### Equivalent Pocket Constraint

**Boltz YAML:**
```yaml
constraints:
  - pocket:
      binder: L
      contacts:
        - [A, 45]
        - [A, 67]
      max_distance: 6.0
```

**Chai-Lab JSON:**
```json
{
  "restraints": [{
    "type": "pocket",
    "binder_chain": "L",
    "pocket_residues": [
      {"chain": "A", "residue": 45},
      {"chain": "A", "residue": 67}
    ],
    "max_distance": 6.0
  }]
}
```

---

## References

- [Boltz GitHub](https://github.com/jwohlwend/boltz)
- [Boltz-2 Paper](https://doi.org/10.1101/2024.11.19.624167)
- [ColabFold MSA Server](https://github.com/sokrypton/ColabFold)
- [PDB Chemical Component Dictionary](https://www.wwpdb.org/data/ccd)
- [INPUT_FORMATS.md](./INPUT_FORMATS.md) - Detailed format specifications
- [MSA_SERVER.md](./MSA_SERVER.md) - MSA server documentation
