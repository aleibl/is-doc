# IBM Power Systems Infrastructure Collection

Ansible playbooks for collecting infrastructure information from IBM Power Systems environments. Two implementations available:

1. **REST API Version** (`collect_infrastructure.yml`) - Direct HMC REST API calls
2. **HMC CLI Version** (`collect_infrastructure_hmc_cli.yml`) - HMC CLI commands via ibm.power_hmc collection

Both generate comprehensive reports in multiple formats (JSON, CSV, YAML, HTML) containing details about managed systems, LPARs, and physical adapters.

## Features

- **Two Implementations**: Choose REST API or HMC CLI approach
- **Single Playbook Design**: All logic in one file - no complex role structure
- **Secure Credentials**: Ansible Vault encryption for HMC passwords
- **Multiple Output Formats**: JSON, CSV, YAML, and HTML reports
- **AAP Compatible**: Works seamlessly on Ansible Automation Platform with multiple output methods
- **Comprehensive Data**: Collects systems, LPARs, and physical adapter information

## Which Version to Use?

### REST API Version (Recommended)
**File:** `collect_infrastructure.yml`

✅ **Use when:**
- REST API is available (port 12443)
- You want better performance
- You prefer structured data (XML/JSON)
- You want minimal dependencies

### HMC CLI Version (Alternative)
**File:** `collect_infrastructure_hmc_cli.yml`

✅ **Use when:**
- REST API is restricted or unavailable
- You only have SSH access (port 22)
- You prefer using IBM's official collection
- You want to use standard HMC CLI commands

📖 **See [README_HMC_CLI.md](README_HMC_CLI.md) for detailed CLI version documentation**

## Prerequisites

- Ansible 2.9 or higher
- Python 3.6 or higher
- Network access to HMC REST API (default port 12443)
- HMC user account with read permissions

## Project Structure

```
.
├── ansible.cfg                    # Ansible configuration
├── collect_infrastructure.yml     # Main playbook (all logic here)
├── inventory/
│   ├── hosts.yml                  # HMC inventory
│   └── group_vars/
│       └── hmcs.yml              # HMC group variables
├── templates/                     # Report templates
│   ├── infrastructure.json.j2
│   ├── infrastructure.csv.j2
│   ├── infrastructure.yml.j2
│   └── infrastructure.html.j2
├── vars/
│   └── vault.yml.example         # Vault template
├── output/
│   └── reports/                  # Generated reports
└── requirements.yml              # Ansible dependencies
```

## Quick Start

### 1. Install Dependencies

```bash
# Install Ansible collections
ansible-galaxy collection install -r requirements.yml
```

### 2. Configure Inventory

Edit `inventory/hosts.yml` to add your HMC hosts:

```yaml
hmcs:
  hosts:
    hmc01.example.com:
      ansible_host: 192.168.1.10
      hmc_description: "Production HMC"
```

### 3. Set Up Credentials

```bash
# Copy the vault template
cp vars/vault.yml.example vars/vault.yml

# Edit the vault file with your HMC credentials
vi vars/vault.yml

# Create a vault password file
echo "your_vault_password" > .vault_pass
chmod 600 .vault_pass

# Encrypt the vault file
ansible-vault encrypt vars/vault.yml
```

### 4. Run the Playbook

**REST API Version (Recommended):**
```bash
# Collect infrastructure from all HMCs
ansible-playbook collect_infrastructure.yml

# Collect from a specific HMC
ansible-playbook collect_infrastructure.yml --limit hmc01.example.com

# Run with verbose output
ansible-playbook collect_infrastructure.yml -v
```

**HMC CLI Version (Alternative):**
```bash
# Collect using HMC CLI commands
ansible-playbook collect_infrastructure_hmc_cli.yml

# Collect from a specific HMC
ansible-playbook collect_infrastructure_hmc_cli.yml --limit hmc01.example.com
```

## Configuration

### HMC Credentials (vars/vault.yml)

```yaml
hmc_credentials:
  hmc01.example.com:
    username: "hscroot"
    password: "your_password"
  hmc02.example.com:
    username: "hscroot"
    password: "your_password"
```

### Group Variables (inventory/group_vars/hmcs.yml)

```yaml
# Collection settings
collect_managed_systems: true
collect_lpars: true
collect_adapters: true

# Report generation
generate_json: true
generate_csv: true
generate_yaml: true
generate_html: true

# API settings
hmc_validate_certs: true
hmc_timeout: 60
api_retries: 3
```

## Output Reports

Reports are generated in `output/reports/` with the following naming convention:

```
power_infrastructure_<hmc_name>_<timestamp>.<format>
```

### Report Formats

1. **JSON** - Structured data for automation and integration
2. **CSV** - Spreadsheet-compatible format for analysis
3. **YAML** - Human-readable, Ansible-friendly format
4. **HTML** - Styled web report with tables and summaries

### Collected Data

#### Managed Systems
- System name
- Serial number
- Machine Type/Model/Serial (MTMS)
- State
- Firmware level
- Description

#### LPARs
- LPAR name
- Partition ID
- Serial number
- Description
- State
- Operating system version
- Memory allocation (MB)
- Processor count

#### Physical Adapters
- Adapter ID
- Adapter type
- Physical location
- DRC (Dynamic Reconfiguration Connector) name
- Description

## Troubleshooting

### Authentication Failures

- Verify HMC credentials in vault file
- Check network connectivity to HMC
- Ensure HMC user has appropriate permissions
- Verify HMC REST API is enabled

### Connection Timeouts

- Increase timeout in `inventory/group_vars/hmcs.yml`:
  ```yaml
  hmc_timeout: 120
  ```
- Check firewall rules for port 12443

### Empty Reports

- Verify HMC has managed systems configured
- Check Ansible verbose output: `-vvv`
- Review `ansible.log` for errors

### Certificate Validation Errors

For self-signed certificates (non-production):
```yaml
hmc_validate_certs: false
```

For production, import HMC certificate to system trust store.

## Security Best Practices

1. **Never commit** `vars/vault.yml` or `.vault_pass` to version control
2. **Use strong passwords** for vault encryption
3. **Restrict file permissions**: `chmod 600 .vault_pass`
4. **Enable certificate validation** in production
5. **Rotate HMC credentials** regularly
6. **Limit HMC user permissions** to read-only

## Maintenance

### Update Vault Credentials

```bash
# Edit encrypted vault
ansible-vault edit vars/vault.yml

# Change vault password
ansible-vault rekey vars/vault.yml
```

### View Encrypted Vault

```bash
ansible-vault view vars/vault.yml
```

## API Reference

This playbook uses the following HMC REST API endpoints:

- `POST /rest/api/web/Logon` - Authentication
- `GET /rest/api/uom/ManagedSystem` - Managed systems
- `GET /rest/api/uom/LogicalPartition` - LPARs
- `GET /rest/api/uom/IOAdapter` - Physical adapters
## Ansible Automation Platform (AAP) Compatibility

This project is fully compatible with Ansible Automation Platform 2.x with automatic environment detection and multiple output methods.

### Key Features

✅ **Automatic Detection** - Playbooks detect AAP environment and adapt automatically  
✅ **Multiple Output Methods** - AAP artifacts, S3, Git, or local files  
✅ **Zero Configuration** - Works out-of-the-box with sensible defaults  
✅ **Backward Compatible** - CLI usage unchanged  

### Output Methods

| Method | CLI | AAP | Best For |
|--------|-----|-----|----------|
| **Local Files** | ✅ Default | ✅ Optional | Development, debugging |
| **AAP Artifacts** | ❌ N/A | ✅ Auto | Immediate access via API |
| **S3 Upload** | ✅ Optional | ✅ Optional | Long-term storage |
| **Git Commit** | ✅ Optional | ✅ Optional | Version control, audit trail |

### Quick Start (AAP)

1. **Import Project** into AAP from Git repository
2. **Create Inventory** with HMC hosts
3. **Configure Credentials** (HMC, S3, Git as needed)
4. **Create Job Template** using provided examples
5. **Run Job** and access reports via AAP artifacts or configured storage

### Configuration

Enable output methods in `inventory/group_vars/hmcs.yml`:

```yaml
# AAP Artifacts (automatic in AAP environment)
enable_aap_artifacts: auto  # auto|true|false

# S3 Upload (optional)
enable_s3_upload: false
s3_bucket: "power-infrastructure-reports"
s3_region: "us-east-1"

# Git Repository (optional)
enable_git_commit: false
git_repo_url: "git@github.com:org/power-reports.git"
git_branch: "main"
```

### Documentation

- **📖 AAP Deployment Guide:** [docs/README_AAP.md](docs/README_AAP.md)
- **📋 Job Template Examples:** [docs/aap_job_templates/](docs/aap_job_templates/)
- **🔧 Planning Document:** [docs/PLAN_AAP_COMPATIBILITY.md](docs/PLAN_AAP_COMPATIBILITY.md)

### Accessing Reports

**Via AAP API:**
```bash
# Get job artifacts
curl -k -u admin:password \
  https://aap.example.com/api/v2/jobs/123/artifacts/ \
  | jq -r '.infrastructure_report_json' \
  | base64 -d > report.json
```

**Via S3:**
```bash
aws s3 cp s3://power-infrastructure-reports/reports/2026-02-28/hmc01/report.json .
```

**Via Git:**
```bash
git clone git@github.com:org/power-reports.git
cat power-reports/reports/2026-02-28/hmc01/report.json
```


## License

MIT License - See LICENSE file for details.

## Version History

See [VERSION_HISTORY.md](VERSION_HISTORY.md) for complete version history and release notes.
