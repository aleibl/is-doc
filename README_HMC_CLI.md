# IBM Power Systems Infrastructure Collection - HMC CLI Version

Alternative implementation using the `ibm.power_hmc` Ansible collection with HMC CLI commands.

## Overview

This version uses the `ibm.power_hmc.hmc_command` module to execute HMC CLI commands (lssyscfg, lshwres) instead of direct REST API calls. Both versions generate the same output reports.

## Comparison: REST API vs HMC CLI

| Feature | REST API Version | HMC CLI Version |
|---------|------------------|-----------------|
| **Playbook** | `collect_infrastructure.yml` | `collect_infrastructure_hmc_cli.yml` |
| **Method** | Direct REST API calls | HMC CLI commands via SSH |
| **Port** | 12443 (HTTPS) | 22 (SSH) |
| **Authentication** | REST session token | SSH with collection |
| **Data Format** | XML/JSON | CSV/Text |
| **Parsing** | XML regex | CSV split |
| **Dependencies** | ansible.builtin only | + ibm.power_hmc |
| **Complexity** | ~280 lines | ~220 lines |
| **Performance** | Faster (single API calls) | Slower (multiple SSH commands) |
| **Reliability** | More robust (structured data) | Less robust (text parsing) |

## When to Use Each Version

### Use REST API Version (`collect_infrastructure.yml`) When:
- ✅ REST API is available and accessible
- ✅ You want better performance
- ✅ You prefer structured data (XML/JSON)
- ✅ You want minimal dependencies
- ✅ You need more reliable parsing

### Use HMC CLI Version (`collect_infrastructure_hmc_cli.yml`) When:
- ✅ REST API is restricted or unavailable
- ✅ You only have SSH access to HMC
- ✅ You prefer using IBM's official collection
- ✅ You're familiar with HMC CLI commands
- ✅ You want to use standard Ansible patterns

## Installation

### Install the ibm.power_hmc Collection

```bash
# Install all collections including ibm.power_hmc
ansible-galaxy collection install -r requirements.yml

# Or install just the HMC collection
ansible-galaxy collection install ibm.power_hmc
```

## Usage

### Run the HMC CLI Version

```bash
# Collect from all HMCs using CLI commands
ansible-playbook collect_infrastructure_hmc_cli.yml

# Collect from specific HMC
ansible-playbook collect_infrastructure_hmc_cli.yml --limit hmc01.example.com

# Verbose output
ansible-playbook collect_infrastructure_hmc_cli.yml -v
```

## HMC CLI Commands Used

The playbook executes the following HMC commands:

### 1. Managed Systems
```bash
lssyscfg -r sys -F name,serial_num,type_model,state,system_firmware
```

**Output Format:**
```
system1,ABC123,9009-42A,operating,AL770_076
system2,DEF456,9009-42A,operating,AL770_076
```

### 2. LPARs
```bash
lssyscfg -r lpar -F name,lpar_id,serial_num,state,os_version,curr_mem,curr_proc_units
```

**Output Format:**
```
lpar1,1,12345AB,Running,AIX 7.2,8192,2.0
lpar2,2,67890CD,Running,Linux,4096,1.0
```

### 3. Physical Adapters
```bash
lshwres -r io --rsubtype slot -F drc_name,description,phys_loc
```

**Output Format:**
```
U78A9.001.1234567-P1-C1,Ethernet Adapter,U78A9.001.1234567-P1-C1
U78A9.001.1234567-P1-C2,Fibre Channel Adapter,U78A9.001.1234567-P1-C2
```

## Configuration

The HMC CLI version uses the same configuration files as the REST API version:

- `inventory/hosts.yml` - HMC inventory
- `inventory/group_vars/hmcs.yml` - Group variables
- `vars/vault.yml` - Encrypted credentials
- `templates/*.j2` - Report templates

## Output Reports

Reports are generated with a `_cli_` suffix to distinguish them from REST API reports:

```
power_infrastructure_cli_<hmc_name>_<timestamp>.<format>
```

Example:
```
power_infrastructure_cli_hmc01.example.com_2026-02-27_15-30-00.json
power_infrastructure_cli_hmc01.example.com_2026-02-27_15-30-00.csv
power_infrastructure_cli_hmc01.example.com_2026-02-27_15-30-00.yml
power_infrastructure_cli_hmc01.example.com_2026-02-27_15-30-00.html
```

## Prerequisites

### HMC Requirements
- SSH access enabled on HMC
- HMC user with appropriate permissions
- SSH key or password authentication

### Ansible Requirements
- Ansible 2.9 or higher
- Python 3.6 or higher
- `ibm.power_hmc` collection installed

## Troubleshooting

### Collection Not Found

```bash
# Install the collection
ansible-galaxy collection install ibm.power_hmc

# Verify installation
ansible-galaxy collection list | grep power_hmc
```

### SSH Connection Issues

- Verify SSH access: `ssh hscroot@hmc01.example.com`
- Check HMC SSH configuration
- Ensure credentials are correct in vault

### Command Execution Failures

- Verify HMC user has permission to run commands
- Check HMC command syntax
- Review Ansible verbose output: `-vvv`

### Empty or Incomplete Data

- Some HMC commands may require specific permissions
- Adapter collection may fail if no adapters are configured
- Check command output in verbose mode

## Advantages of HMC CLI Approach

1. **SSH-Based Access**: Works when REST API is restricted
2. **IBM Collection**: Uses officially supported collection
3. **Familiar Commands**: Standard HMC CLI commands
4. **Alternative Method**: Backup when REST API unavailable

## Disadvantages of HMC CLI Approach

1. **Text Parsing**: Less reliable than structured XML/JSON
2. **Multiple Commands**: Requires several SSH connections
3. **Performance**: Slower than single REST API calls
4. **Additional Dependency**: Requires ibm.power_hmc collection
5. **SSH Requirement**: Needs SSH access to HMC

## Recommendations

**Primary Method:** Use the REST API version (`collect_infrastructure.yml`) for:
- Production environments
- Automated reporting
- Better performance and reliability

**Alternative Method:** Use the HMC CLI version (`collect_infrastructure_hmc_cli.yml`) for:
- Environments where REST API is unavailable
- SSH-only access scenarios
- Testing and validation

## Support

For issues with:
- **ibm.power_hmc collection**: Check IBM's collection documentation
- **HMC CLI commands**: Refer to HMC documentation
- **This playbook**: Review logs and troubleshooting section

## Version History

- **1.0.0** - Initial CLI-based implementation
  - Uses ibm.power_hmc.hmc_command module
  - Executes lssyscfg and lshwres commands
  - Parses CSV output
  - Generates same reports as REST API version