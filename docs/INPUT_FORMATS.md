# Boltz Input Formats

## Overview

Boltz supports two input formats:
1. **YAML** (recommended) - Full feature support including constraints, templates, and affinity prediction
2. **FASTA** (deprecated) - Limited feature support, maintained for backward compatibility

## YAML Format (Recommended)

YAML is the primary input format for Boltz, providing access to all features.

### Basic Structure

```yaml
version: 1
sequences:
  - ENTITY_TYPE:
      id: CHAIN_ID
      sequence: SEQUENCE        # for protein, dna, rna
      smiles: 'SMILES'          # for ligand (exclusive with ccd)
      ccd: CCD_CODE             # for ligand (exclusive with smiles)
      msa: MSA_PATH             # optional, for protein
      modifications: []         # optional
      cyclic: false             # optional
constraints: []                 # optional
templates: []                   # optional
properties: []                  # optional
```

### Entity Types

| Entity Type | Required Fields | Optional Fields |
|-------------|-----------------|-----------------|
| `protein` | `id`, `sequence` | `msa`, `modifications`, `cyclic` |
| `dna` | `id`, `sequence` | `modifications`, `cyclic` |
| `rna` | `id`, `sequence` | `modifications`, `cyclic` |
| `ligand` | `id`, `smiles` OR `ccd` | - |

### Examples

#### Simple Protein

```yaml
version: 1
sequences:
  - protein:
      id: A
      sequence: MVTPEGNVSLVDESLLVGVTDEDRAVRSAHQFYERLIGLWAPAVMEAAHELGVFAALAE
```

#### Protein with Pre-computed MSA

```yaml
version: 1
sequences:
  - protein:
      id: A
      sequence: MVTPEGNVSLVDESLLVGVTDEDRAVRSAHQFYERLIGLWAPAVMEAAHELGVFAALAE
      msa: ./msas/protein_a.a3m
```

#### Protein Homodimer (Multiple Identical Chains)

```yaml
version: 1
sequences:
  - protein:
      id: [A, B]  # Two identical chains
      sequence: MVTPEGNVSLVDESLLVGVTDEDRAVRSAHQFYERLIGLWAPAVMEAAHELGVFAALAE
      msa: ./msas/protein.a3m
```

#### Protein-Ligand Complex (SMILES)

```yaml
version: 1
sequences:
  - protein:
      id: A
      sequence: MVTPEGNVSLVDESLLVGVTDEDRAVRSAHQFYERLIGLWAPAVMEAAHELGVFAALAE
  - ligand:
      id: L
      smiles: 'CC1=CC=CC=C1'  # Toluene
```

#### Protein-Ligand Complex (CCD Code)

```yaml
version: 1
sequences:
  - protein:
      id: A
      sequence: MVTPEGNVSLVDESLLVGVTDEDRAVRSAHQFYERLIGLWAPAVMEAAHELGVFAALAE
  - ligand:
      id: L
      ccd: ATP  # ATP from PDB Chemical Component Dictionary
```

#### Protein with Modified Residues

```yaml
version: 1
sequences:
  - protein:
      id: A
      sequence: MVTPEGNVSLVDESLLVGVTDEDRAVRSAHQFYERLIGLWAPAVMEAAHELGVFAALAE
      modifications:
        - position: 5    # 1-indexed
          ccd: SEP       # Phosphoserine
        - position: 15
          ccd: TPO       # Phosphothreonine
```

#### DNA-Protein Complex

```yaml
version: 1
sequences:
  - protein:
      id: A
      sequence: MVTPEGNVSLVDESLLVGVTDEDRAVRSAHQFYERLIGLWAPAVMEAAHELGVFAALAE
  - dna:
      id: B
      sequence: ATCGATCGATCG
  - dna:
      id: C
      sequence: CGATCGATCGAT
```

#### Cyclic Peptide

```yaml
version: 1
sequences:
  - protein:
      id: A
      sequence: CYSILEVALCYS
      cyclic: true
```

### Constraints

Constraints guide the structure prediction by specifying known interactions.

#### Covalent Bond Constraint

```yaml
constraints:
  - bond:
      atom1: [A, 1, SG]    # [chain_id, residue_index, atom_name]
      atom2: [L, 1, C1]    # Connect Cys sulfur to ligand carbon
```

#### Pocket Constraint

```yaml
constraints:
  - pocket:
      binder: L            # Chain that binds to pocket
      contacts:            # Residues forming the pocket
        - [A, 45]          # [chain_id, residue_index]
        - [A, 67]
        - [A, 89]
        - [A, 112]
      max_distance: 6.0    # Angstroms (4-20A, default 6A)
      force: false         # Use potential to enforce (default false)
```

#### Contact Constraint

```yaml
constraints:
  - contact:
      token1: [A, 45]      # [chain_id, residue_index]
      token2: [B, 67]
      max_distance: 8.0    # Angstroms
      force: false
```

### Templates

Provide structural templates to guide prediction.

#### Basic Template

```yaml
templates:
  - cif: ./templates/reference.cif
```

#### Template with Chain Mapping

```yaml
templates:
  - cif: ./templates/reference.cif
    chain_id: [A, B]              # Chains in your input to template
    template_id: [X, Y]           # Corresponding chains in template
```

#### Forced Template (with Potential)

```yaml
templates:
  - cif: ./templates/reference.cif
    force: true
    threshold: 2.0                # Max deviation in Angstroms
```

#### PDB Template

```yaml
templates:
  - pdb: ./templates/reference.pdb
    chain_id: [A]
    template_id: [A1]             # PDB chains become A1, A2, B1, etc.
```

### Affinity Prediction

Enable binding affinity prediction for small molecule ligands.

```yaml
properties:
  - affinity:
      binder: L                   # Ligand chain ID
```

**Notes**:
- Only one ligand can be specified for affinity
- Ligand must be ≤128 atoms (recommended ≤56 atoms)
- Only protein targets supported (not DNA/RNA)

### Complete Example

```yaml
version: 1
sequences:
  - protein:
      id: [A, B]
      sequence: MVTPEGNVSLVDESLLVGVTDEDRAVRSAHQFYERLIGLWAPAVMEAAHELGVFAALAEAPADSGELARRLDCDARAMRVLLDALYAYDVIDRIHDTNGFRYLLSAEARECLLPGTLFSLVGKFMHDINVAWPAWRNLAEVVRHGARDTSGAESPNGIAQEDYESLVGGINFWAPPIVTTLSRKLRASGRSGDATASVLDVGCGTGLYSQLLLREFPRWTATGLDVERIATLANAQALRLGVEERFATRAGDFWRGGWGTGYDLVLFANIFHLQTPASAVRLMRHAAACLAPDGLVAVVDQIVDADREPKTPQDRFALLFAASMTNTGGGDAYTFQEYEEWFTAAGLQRIETLDTPMHRILLARRATEPSAVPEGQASENLYFQ
      msa: ./examples/msa/seq1.a3m
  - ligand:
      id: [C, D]
      ccd: SAH
  - ligand:
      id: E
      smiles: 'N[C@@H](Cc1ccc(O)cc1)C(=O)O'

constraints:
  - pocket:
      binder: E
      contacts: [[A, 120], [A, 145], [A, 167]]
      max_distance: 6.0

templates:
  - cif: ./templates/homolog.cif
    chain_id: [A]

properties:
  - affinity:
      binder: E
```

---

## FASTA Format (Deprecated)

FASTA format is maintained for backward compatibility but has limited features.

### Supported Features

| Feature | FASTA | YAML |
|---------|-------|------|
| Polymers (protein/DNA/RNA) | Yes | Yes |
| SMILES ligands | Yes | Yes |
| CCD ligands | Yes | Yes |
| Custom MSA | Yes | Yes |
| Modified residues | No | Yes |
| Covalent bonds | No | Yes |
| Pocket constraints | No | Yes |
| Affinity prediction | No | Yes |

### Format

```
>CHAIN_ID|ENTITY_TYPE|MSA_PATH
SEQUENCE
```

### Entity Types

- `protein` - Amino acid sequence
- `dna` - DNA nucleotide sequence
- `rna` - RNA nucleotide sequence
- `smiles` - Small molecule as SMILES string
- `ccd` - Small molecule as CCD code

### Examples

#### Simple Protein

```
>A|protein
MVTPEGNVSLVDESLLVGVTDEDRAVRSAHQFYERLIGLWAPAVMEAAHELGVFAALAE
```

#### Protein with MSA

```
>A|protein|./msas/protein_a.a3m
MVTPEGNVSLVDESLLVGVTDEDRAVRSAHQFYERLIGLWAPAVMEAAHELGVFAALAE
```

#### Single-Sequence Mode

```
>A|protein|empty
MVTPEGNVSLVDESLLVGVTDEDRAVRSAHQFYERLIGLWAPAVMEAAHELGVFAALAE
```

#### Protein-Ligand Complex

```
>A|protein|./msas/protein_a.a3m
MVTPEGNVSLVDESLLVGVTDEDRAVRSAHQFYERLIGLWAPAVMEAAHELGVFAALAE
>L|smiles
CC1=CC=CC=C1
```

#### With CCD Ligand

```
>A|protein|./msas/protein_a.a3m
MVTPEGNVSLVDESLLVGVTDEDRAVRSAHQFYERLIGLWAPAVMEAAHELGVFAALAE
>L|ccd
ATP
```

#### Multi-Chain Complex

```
>A|protein|./msas/seq1.a3m
MVTPEGNVSLVDESLLVGVTDEDRAVRSAHQFYERLIGLWAPAVMEAAHELGVFAALAE
>B|protein|./msas/seq1.a3m
MVTPEGNVSLVDESLLVGVTDEDRAVRSAHQFYERLIGLWAPAVMEAAHELGVFAALAE
>C|ccd
SAH
>D|ccd
SAH
>E|smiles
N[C@@H](Cc1ccc(O)cc1)C(=O)O
>F|smiles
N[C@@H](Cc1ccc(O)cc1)C(=O)O
```

---

## Input Format Detection

Boltz automatically detects the input format based on file extension:
- `.yaml` or `.yml` → YAML format
- `.fasta` or `.fa` → FASTA format

When using the MSA server (`--use_msa_server`), MSA paths in input files are optional.

---

## Common Amino Acid Codes

| 1-Letter | 3-Letter | Name |
|----------|----------|------|
| A | ALA | Alanine |
| C | CYS | Cysteine |
| D | ASP | Aspartic acid |
| E | GLU | Glutamic acid |
| F | PHE | Phenylalanine |
| G | GLY | Glycine |
| H | HIS | Histidine |
| I | ILE | Isoleucine |
| K | LYS | Lysine |
| L | LEU | Leucine |
| M | MET | Methionine |
| N | ASN | Asparagine |
| P | PRO | Proline |
| Q | GLN | Glutamine |
| R | ARG | Arginine |
| S | SER | Serine |
| T | THR | Threonine |
| V | VAL | Valine |
| W | TRP | Tryptophan |
| Y | TYR | Tyrosine |

---

## Common CCD Codes

| Code | Description |
|------|-------------|
| ATP | Adenosine triphosphate |
| ADP | Adenosine diphosphate |
| GTP | Guanosine triphosphate |
| NAD | Nicotinamide adenine dinucleotide |
| FAD | Flavin adenine dinucleotide |
| HEM | Heme |
| SAH | S-adenosyl-L-homocysteine |
| SAM | S-adenosyl-L-methionine |
| ZN | Zinc ion |
| MG | Magnesium ion |
| CA | Calcium ion |

Full CCD dictionary: https://www.wwpdb.org/data/ccd
