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
ansible-playbook -i inventory/hosts.yml collect_infrastructure.yml --ask-vault-pass

# Collect from a specific HMC
ansible-playbook -i inventory/hosts.yml collect_infrastructure.yml --ask-vault-pass --limit hmc01.example.com

# With vault password file
ansible-playbook -i inventory/hosts.yml collect_infrastructure.yml --vault-password-file .vault_pass

# Run with verbose output
ansible-playbook -i inventory/hosts.yml collect_infrastructure.yml --ask-vault-pass -v
```

**HMC CLI Version (Alternative):**
```bash
# Collect using HMC CLI commands
ansible-playbook -i inventory/hosts.yml collect_infrastructure_hmc_cli.yml --ask-vault-pass

# Collect from a specific HMC
ansible-playbook -i inventory/hosts.yml collect_infrastructure_hmc_cli.yml --ask-vault-pass --limit hmc01.example.com
```

**Note:** Always use the `-i` flag to specify inventory. This ensures compatibility with both CLI and AAP environments.

### Understanding Host Patterns and the --limit Flag

The playbooks use `hosts: hmcs` which targets the `hmcs` group in your inventory. This design provides:

**Benefits:**
- **Organization**: Group-based configuration via `inventory/group_vars/hmcs.yml`
- **Scalability**: Easy to add/remove HMCs from the group
- **Maintainability**: Centralized HMC-specific settings
- **Flexibility**: Can override with `--limit` flag

**Running Against Hosts Not in the hmcs Group:**

If you have hosts in your inventory that are NOT in the `hmcs` group, you can still run the playbook against them using the `--limit` flag:

```bash
# Run against a specific host (even if not in hmcs group)
ansible-playbook -i inventory/hosts.yml collect_infrastructure.yml --ask-vault-pass --limit other-hmc.example.com

# Run against multiple specific hosts
ansible-playbook -i inventory/hosts.yml collect_infrastructure.yml --ask-vault-pass --limit "hmc01.example.com,other-hmc.example.com"

# Run against a different group
ansible-playbook -i inventory/hosts.yml collect_infrastructure.yml --ask-vault-pass --limit dev_hmcs
```

**How it Works:**
1. The playbook declares `hosts: hmcs` as the default target
2. The `--limit` flag overrides this and restricts execution to specified hosts/groups
3. The host(s) specified in `--limit` must exist in your inventory
4. Group variables from `group_vars/hmcs.yml` are still applied if the host is in that group

**Example Inventory with Multiple Groups:**
```yaml
all:
  children:
    hmcs:
      hosts:
        hmc01.example.com:
        hmc02.example.com:
    dev_hmcs:
      hosts:
        hmc-dev.example.com:
    test_hmcs:
      hosts:
        hmc-test.example.com:
```

With this inventory:
- `ansible-playbook ... collect_infrastructure.yml` → Runs against hmc01 and hmc02 (hmcs group)
- `ansible-playbook ... collect_infrastructure.yml --limit dev_hmcs` → Runs against hmc-dev only
- `ansible-playbook ... collect_infrastructure.yml --limit hmc-test.example.com` → Runs against hmc-test only

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

### Group Variables: Two Locations, Same Effect

Variables for the `hmcs` group can be defined in **two locations** with identical effect:

1. **Inline in inventory** (`inventory/hosts.yml` under `vars:`)
2. **Separate file** (`inventory/group_vars/hmcs.yml`)

Both have the **same precedence level** and you can move variables between them without changing behavior.

#### Current Organization (Recommended)

**inventory/hosts.yml** - Connection and infrastructure settings:
```yaml
hmcs:
  hosts:
    hmc01.example.com:
      ansible_host: 192.168.1.10
      hmc_description: "Production HMC"
  vars:
    ansible_connection: local
    ansible_python_interpreter: /usr/bin/python3
    hmc_port: 12443
    hmc_api_base: "/rest/api"
    hmc_validate_certs: true
    hmc_timeout: 60
    output_dir: "{{ playbook_dir }}/../output/reports"
```

**inventory/group_vars/hmcs.yml** - Application and playbook settings:
```yaml
# HMC API Configuration
hmc_api_version: "web"
hmc_content_type: "application/vnd.ibm.powervm.web+xml"

# Collection settings
collect_managed_systems: true
collect_lpars: true
collect_adapters: true

# Report generation
generate_json: true
generate_csv: true
generate_yaml: true
generate_html: true

# Output persistence (AAP compatibility)
enable_local_files: true
enable_aap_artifacts: auto
enable_s3_upload: false
enable_git_commit: false
```

#### Best Practices

**Use inline vars (hosts.yml) for:**
- Connection settings (`ansible_connection`, `ansible_host`)
- Infrastructure basics (`hmc_port`, `hmc_timeout`)
- Settings that rarely change

**Use group_vars file for:**
- Application-specific settings
- Feature toggles (`collect_*`, `generate_*`)
- Complex configurations (AAP output, S3, Git)
- Settings that change frequently

**Consolidation Option:**
You can move all vars to `group_vars/hmcs.yml` and remove the `vars:` section from `hosts.yml` entirely. This is cleaner for large configurations.

#### Configuring in AAP

In Ansible Automation Platform, you configure these differently:

**1. Inventory Variables (replaces hosts.yml vars):**
- Navigate to: **Inventories** → Select inventory → **Groups** → `hmcs` → **Variables**
- Add in YAML format:
```yaml
ansible_connection: local
ansible_python_interpreter: /usr/bin/python3
hmc_port: 12443
hmc_validate_certs: true
hmc_timeout: 60
```

**2. Project Files (group_vars/hmcs.yml):**
- Synced automatically from your Git repository
- AAP reads `inventory/group_vars/hmcs.yml` from the project
- No manual configuration needed

**3. Variable Precedence in AAP:**
Both locations work identically in AAP:
- Group variables from project files (group_vars/)
- Group variables from AAP inventory UI
- Both have the same precedence level
- AAP merges them automatically

**4. AAP Best Practice:**
- **Connection settings** → AAP Inventory UI (easier to manage per environment)
- **Application settings** → Project files (version controlled, consistent across environments)

**Example AAP Setup:**

1. **Create Inventory in AAP:**
   - Name: `Power Systems HMCs`
   - Add hosts: `hmc01.example.com`, `hmc02.example.com`
   - Create group: `hmcs`
   - Add hosts to group

2. **Set Group Variables in AAP UI:**
   ```yaml
   ansible_connection: local
   hmc_port: 12443
   hmc_timeout: 60
   ```

3. **Sync Project** (pulls group_vars/hmcs.yml automatically)

4. **Result:** Variables from both locations are merged and applied to all hosts in the `hmcs` group

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
