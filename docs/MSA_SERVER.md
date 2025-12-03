# MSA Server Documentation

## Overview

Multiple Sequence Alignment (MSA) is a critical input for protein structure prediction models like Boltz and Chai-Lab. MSAs provide evolutionary information by aligning homologous protein sequences, which helps the model understand which residues are conserved and how they co-evolve.

Both Boltz and Chai-Lab support automatic MSA generation via the ColabFold MMseqs2 server, eliminating the need to pre-compute MSAs locally.

## What is an MSA Server?

An MSA server provides a web API for generating Multiple Sequence Alignments on-demand. When you submit a protein sequence, the server:

1. Searches large sequence databases (UniRef, BFD, MGnify, etc.)
2. Identifies homologous sequences
3. Aligns them to produce an MSA in A3M format
4. Returns the MSA for use in structure prediction

### Benefits of Using an MSA Server

- **No local database required**: Avoids downloading 2-3TB of sequence databases
- **Always up-to-date**: Server databases are regularly updated
- **Faster setup**: Start predicting immediately without database preparation
- **Lower storage requirements**: Only store your inputs and outputs

### Limitations

- **Requires internet access**: Cannot be used in air-gapped environments
- **Rate limiting**: Public servers have usage limits
- **Latency**: MSA generation adds time to predictions (typically 1-10 minutes)
- **Dependency on external service**: Server availability affects your workflow

## ColabFold MMseqs2 Server

The default MSA server used by both Boltz and Chai-Lab is the ColabFold MMseqs2 server.

### Public Server

- **URL**: `https://api.colabfold.com`
- **Databases**: UniRef30, ColabFoldDB (based on BFD + MGnify)
- **Rate Limits**: Shared resource - please use responsibly
- **Authentication**: None required for basic usage

### API Endpoints

The ColabFold server provides several endpoints:

```
POST /batch          # Submit sequences for MSA generation
GET  /result/{id}    # Retrieve MSA results
GET  /queue/{id}     # Check job status
```

### Request Format

```json
{
  "q": ">sequence_id\nMKTAYIAKQRQISFVKS...",
  "database": "uniref30"
}
```

### Response Format

Returns MSA in A3M format:
```
>query
MKTAYIAKQRQISFVKSHFSRQLEERLGLIEVQAPILSRVGDGTQDNLSGAEKAV
>UniRef30_A0A0A0
MKTAYIAKQRQISFVKSHFSRQLEERLGLIEVQAPILSRVGDGTQDNLSGAEKAV
>UniRef30_B1B1B1
-KTAYIAKQRQISFVKSHFSRQLEERLGLIE-QAPILSRVGDGTQDNLSGAEK--
...
```

## Using MSA Server with Boltz

### Automatic MSA Generation

Enable automatic MSA generation with the `--use_msa_server` flag:

```bash
boltz predict input.yaml --use_msa_server
```

### Custom MSA Server

To use a self-hosted or alternative MSA server:

```bash
boltz predict input.yaml \
  --use_msa_server \
  --msa_server_url "https://your-server.com"
```

### Authentication Options

#### Basic Authentication

```bash
# Via environment variables (recommended)
export BOLTZ_MSA_USERNAME=myuser
export BOLTZ_MSA_PASSWORD=mypassword
boltz predict input.yaml --use_msa_server

# Or via CLI options
boltz predict input.yaml --use_msa_server \
  --msa_server_username myuser \
  --msa_server_password mypassword
```

#### API Key Authentication

```bash
# Via environment variable
export MSA_API_KEY_VALUE=your-api-key
boltz predict input.yaml --use_msa_server \
  --api_key_header X-API-Key

# Or via CLI
boltz predict input.yaml --use_msa_server \
  --api_key_header X-API-Key \
  --api_key_value your-api-key
```

### Pre-computed MSA Option

If you have pre-computed MSAs, specify them in your YAML input:

```yaml
sequences:
  - protein:
      id: A
      sequence: MVTPEGNVSLVDESLLVGVTDEDRAVRSAHQ...
      msa: /path/to/precomputed.a3m
```

For multiple protein chains with paired MSAs, use CSV format:
```yaml
sequences:
  - protein:
      id: A
      sequence: MVTPEGNVSLVDESLLVGVTDEDRAVRSAHQ...
      msa: /path/to/paired_msas.csv
```

### Single-Sequence Mode

To run without MSA (not recommended - reduces accuracy):
```yaml
sequences:
  - protein:
      id: A
      sequence: MVTPEGNVSLVDESLLVGVTDEDRAVRSAHQ...
      msa: empty
```

## Using MSA Server with Chai-Lab

### Automatic MSA Generation

Enable with the `--use-msa-server` flag:

```bash
chai-lab fold input.fasta output_folder --use-msa-server
```

### With Templates

Combine MSA and template servers for best results:

```bash
chai-lab fold input.fasta output_folder \
  --use-msa-server \
  --use-templates-server
```

### Custom Server URL

```bash
chai-lab fold input.fasta output_folder \
  --use-msa-server \
  --msa-server-url "https://your-server.com"
```

### Pre-computed MSA Option

Chai-Lab uses `.aligned.pqt` (Parquet) format for MSAs, which includes metadata like source database and pairing keys. Conversion utilities are provided:

```bash
# Convert A3M to aligned.pqt
chai a3m-to-pqt input.a3m output.aligned.pqt
```

## Comparison: Boltz vs Chai-Lab MSA Handling

| Feature | Boltz | Chai-Lab |
|---------|-------|----------|
| Default server | ColabFold | ColabFold |
| MSA file format | A3M | aligned.pqt (Parquet) |
| Single-sequence mode | `msa: empty` | Default (no flag) |
| Server flag | `--use_msa_server` | `--use-msa-server` |
| Custom server | `--msa_server_url` | `--msa-server-url` |
| Pairing strategy | `--msa_pairing_strategy` | Built-in |
| Template support | Via YAML `templates:` | `--use-templates-server` |

## Self-Hosting an MSA Server

For high-throughput or air-gapped environments, you can host your own ColabFold server:

### Requirements

- 2-3 TB storage for sequence databases
- 64+ GB RAM recommended
- MMseqs2 installed

### Setup

1. Download databases:
```bash
# UniRef30
wget https://wwwuser.gwdg.de/~compbiol/colabfold/uniref30_2302.tar.gz

# ColabFoldDB
wget https://wwwuser.gwdg.de/~compbiol/colabfold/colabfold_envdb_202108.tar.gz
```

2. Run ColabFold server:
```bash
colabfold_search --server --port 8080 --db /path/to/databases
```

3. Configure your predictions to use the local server:
```bash
boltz predict input.yaml --use_msa_server --msa_server_url http://localhost:8080
```

## Best Practices

1. **Use MSA server for convenience**: Great for small-to-medium workloads
2. **Pre-compute for large batches**: More efficient for hundreds of predictions
3. **Cache MSAs**: Save generated MSAs for re-use
4. **Respect rate limits**: Don't overwhelm public servers
5. **Consider self-hosting**: For production workloads or sensitive data

## Troubleshooting

### Connection Timeout
```
Error: MSA server connection timed out
```
- Check internet connectivity
- Try again later (server may be overloaded)
- Increase timeout: `--msa_server_timeout 600`

### Rate Limited
```
Error: 429 Too Many Requests
```
- Wait before retrying
- Reduce concurrent requests
- Consider self-hosting

### Invalid Response
```
Error: Invalid MSA format received
```
- Check sequence contains valid amino acids
- Ensure sequence is not too short (<10 aa) or too long (>2000 aa)
- Try with a different sequence

## References

- [ColabFold Paper](https://www.nature.com/articles/s41592-022-01488-1)
- [MMseqs2 Documentation](https://github.com/soedinglab/MMseqs2)
- [Boltz MSA Documentation](https://github.com/jwohlwend/boltz/blob/main/docs/prediction.md)
- [Chai-Lab MSA Documentation](https://github.com/chaidiscovery/chai-lab/tree/main/examples/msas)
