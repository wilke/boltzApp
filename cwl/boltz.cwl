#!/usr/bin/env cwl-runner

cwlVersion: v1.2
class: CommandLineTool

label: Boltz Biomolecular Structure Prediction
doc: |
  Boltz-2 biomolecular structure prediction tool for proteins, DNA, RNA, and ligands.

  Boltz is a state-of-the-art deep learning model for predicting the 3D structure
  of biomolecular complexes. It supports:
  - Protein structure prediction
  - Protein-protein complexes
  - Protein-nucleic acid complexes
  - Protein-ligand binding
  - Binding affinity prediction

  For more information: https://github.com/jwohlwend/boltz

requirements:
  DockerRequirement:
    dockerPull: dxkb/boltz-bvbrc:latest-gpu
  ResourceRequirement:
    coresMin: 8
    ramMin: 65536  # 64GB
    tmpdirMin: 51200  # 50GB
  NetworkAccess:
    networkAccess: true  # For MSA server access
  InlineJavascriptRequirement: {}

hints:
  cwltool:CUDARequirement:
    cudaVersionMin: "11.8"
    cudaDeviceCountMin: 1
    cudaDeviceCountMax: 1

baseCommand: [boltz, predict]

inputs:
  input_file:
    type: File
    inputBinding:
      position: 1
    doc: |
      Input file in YAML or FASTA format describing the molecular system.
      YAML format allows specifying complex multi-chain systems with ligands.
      FASTA format is simpler for single proteins.

  use_msa_server:
    type: boolean?
    default: true
    inputBinding:
      prefix: --use_msa_server
    doc: |
      Use the ColabFold MSA server for generating multiple sequence alignments.
      Recommended for best results. Requires network access.

  diffusion_samples:
    type: int?
    default: 1
    inputBinding:
      prefix: --diffusion_samples
    doc: |
      Number of diffusion samples to generate. More samples increase diversity
      but take longer. Default: 1, recommended: 1-5 for production.

  recycling_steps:
    type: int?
    default: 3
    inputBinding:
      prefix: --recycling_steps
    doc: |
      Number of recycling steps in the model. More steps can improve accuracy
      but increase runtime. Default: 3.

  sampling_steps:
    type: int?
    default: 200
    inputBinding:
      prefix: --sampling_steps
    doc: |
      Number of diffusion sampling steps. Higher values may improve quality
      but increase runtime. Default: 200.

  output_format:
    type:
      - "null"
      - type: enum
        symbols: [pdb, mmcif]
    default: mmcif
    inputBinding:
      prefix: --output_format
    doc: |
      Output structure format. mmCIF is recommended for complex structures,
      PDB for compatibility with older tools.

  use_potentials:
    type: boolean?
    default: false
    inputBinding:
      prefix: --use_potentials
    doc: |
      Apply structure potentials during sampling. Can help with certain
      molecular interactions.

  write_full_pae:
    type: boolean?
    default: false
    inputBinding:
      prefix: --write_full_pae
    doc: |
      Write the full predicted aligned error (PAE) matrix as NPZ file.
      Useful for analyzing prediction confidence across residue pairs.

  accelerator:
    type:
      - "null"
      - type: enum
        symbols: [gpu, cpu]
    default: gpu
    inputBinding:
      prefix: --accelerator
    doc: |
      Compute accelerator to use. GPU strongly recommended for reasonable
      performance.

  output_dir:
    type: string?
    default: output
    inputBinding:
      prefix: --out_dir
    doc: Output directory for prediction results.

outputs:
  predictions:
    type: Directory
    outputBinding:
      glob: $(inputs.output_dir)
    doc: |
      Directory containing prediction outputs including:
      - Structure files (CIF/PDB)
      - Confidence scores (JSON)
      - PAE matrices (if requested)

  structure_files:
    type: File[]
    outputBinding:
      glob: "$(inputs.output_dir)/**/*.cif"
    doc: Predicted structure files in mmCIF format.

  confidence_scores:
    type: File[]
    outputBinding:
      glob: "$(inputs.output_dir)/**/*confidence*.json"
    doc: Confidence score files for predictions.

stdout: boltz_stdout.txt
stderr: boltz_stderr.txt

s:author:
  - class: s:Person
    s:name: BV-BRC Team
    s:email: help@bv-brc.org

s:license: https://spdx.org/licenses/MIT

$namespaces:
  s: https://schema.org/
  cwltool: http://commonwl.org/cwltool#

$schemas:
  - https://schema.org/version/latest/schemaorg-current-https.rdf
