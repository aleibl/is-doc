# AAP Credential Setup Guide
## IBM Power Systems Infrastructure Collection

**Version:** 1.2.0.0  
**Date:** 2026-03-13  
**Purpose:** Guide for configuring HMC credentials in Ansible Automation Platform

---

## Table of Contents

1. [Overview](#overview)
2. [Credential Types](#credential-types)
3. [Step-by-Step Setup](#step-by-step-setup)
4. [Troubleshooting](#troubleshooting)
5. [Best Practices](#best-practices)

---

## Overview

When running the IBM Power Systems Infrastructure Collection in Ansible Automation Platform (AAP), credentials must be configured through AAP's credential system, **not** through Ansible Vault files.

### Key Differences: CLI vs AAP

| Aspect | CLI Execution | AAP Execution |
|--------|---------------|---------------|
| **Credential Storage** | `vars/vault.yml` (Ansible Vault) | AAP Credentials |
| **Vault Password** | `.vault_pass` file or `--ask-vault-pass` | Not used |
| **Environment Variables** | Manual export | Injected by AAP |
| **ansible.cfg** | Can reference vault_password_file | Should not reference vault files |

---

## Credential Types

### Option 1: Machine Credential (Recommended)

Use AAP's built-in **Machine** credential type for HMC access.

**Advantages:**
- Native AAP credential type
- Well-documented
- Supports SSH and password authentication
- Automatic environment variable injection

**Configuration:**
- **Credential Type:** Machine
- **Username:** HMC username (e.g., `hscroot`)
- **Password:** HMC password
- **SSH Private Key:** (Optional, for SSH key authentication)

### Option 2: Custom Credential Type

Create a custom credential type specifically for HMC credentials.

**Advantages:**
- More explicit naming
- Can include additional HMC-specific fields
- Better organization for multiple HMCs

**Configuration:**
See [Creating Custom Credential Type](#creating-custom-credential-type) below.

---

## Step-by-Step Setup

### Step 1: Create Credential in AAP

#### Using Machine Credential Type

1. **Navigate to Credentials**
   - In AAP UI: Resources → Credentials → Add

2. **Configure Credential**
   - **Name:** `HMC Credentials` (or specific HMC name)
   - **Organization:** Select your organization
   - **Credential Type:** Machine
   - **Username:** Enter HMC username (e.g., `hscroot`)
   - **Password:** Enter HMC password
   - **Privilege Escalation Method:** None (not needed for HMC)

3. **Save Credential**

#### Using Custom Credential Type

See [Creating Custom Credential Type](#creating-custom-credential-type) section.

### Step 2: Configure Job Template

1. **Navigate to Job Templates**
   - In AAP UI: Resources → Templates → Add → Job Template

2. **Basic Configuration**
   - **Name:** `Collect Power Infrastructure`
   - **Job Type:** Run
   - **Inventory:** Select inventory with HMC hosts
   - **Project:** Select project containing this collection
   - **Playbook:** `collect_infrastructure.yml` or `collect_infrastructure_hmc_cli.yml`

3. **Credentials Section**
   - Click **Select** under Credentials
   - Choose the HMC credential created in Step 1
   - **Important:** The credential will inject `ANSIBLE_NET_USERNAME` and `ANSIBLE_NET_PASSWORD` environment variables

4. **Variables (Optional)**
   - Add extra variables if needed:
   ```yaml
   ---
   output_dir: "/tmp/reports"
   enable_aap_artifacts: true
   enable_s3_upload: false
   ```

5. **Save Template**

### Step 3: Update Inventory Variables

Ensure your inventory has the HMC hosts defined:

**inventory/hosts.yml:**
```yaml
---
all:
  children:
    hmcs:
      hosts:
        hmc01.example.com:
          ansible_host: 10.1.1.100
          hmc_port: 12443
          hmc_validate_certs: false
        
        hmc02.example.com:
          ansible_host: 10.1.1.101
          hmc_port: 12443
          hmc_validate_certs: false
```

**Note:** Do NOT include `ansible_user` or `ansible_password` in inventory when using AAP credentials.

### Step 4: Test Execution

1. **Launch Job Template**
   - Navigate to the job template
   - Click **Launch**
   - Monitor the job output

2. **Verify Credential Injection**
   - Check job output for: `Execution environment: AAP`
   - Credentials should be automatically available

3. **Check for Errors**
   - If you see vault-related errors, see [Troubleshooting](#troubleshooting)

---

## Creating Custom Credential Type

### Custom Credential Type Definition

1. **Navigate to Credential Types**
   - In AAP UI: Administration → Credential Types → Add

2. **Input Configuration**
   ```yaml
   fields:
     - id: hmc_username
       type: string
       label: HMC Username
       help_text: Username for HMC authentication
     - id: hmc_password
       type: string
       label: HMC Password
       secret: true
       help_text: Password for HMC authentication
   required:
     - hmc_username
     - hmc_password
   ```

3. **Injector Configuration**
   ```yaml
   env:
     HMC_USERNAME: '{{ hmc_username }}'
     HMC_PASSWORD: '{{ hmc_password }}'
   ```

4. **Save Credential Type**

### Using Custom Credential Type

1. **Create Credential**
   - Resources → Credentials → Add
   - **Credential Type:** Select your custom HMC type
   - Fill in username and password

2. **Attach to Job Template**
   - Same as Step 2 above
   - Select your custom HMC credential

---

## Troubleshooting

### Error: "The vault password file /runner/project/.vault_pass was not found"

**Cause:** The `ansible.cfg` file has `vault_password_file` configured, which doesn't exist in AAP.

**Solution:**
1. Comment out or remove the `vault_password_file` line in `ansible.cfg`:
   ```ini
   # vault_password_file = .vault_pass
   ```

2. Ensure playbooks don't have `vars_files` pointing to vault files

3. The updated playbooks (v1.2.0.0+) automatically handle this

### Error: "Failed to parse /runner/inventory/hosts"

**Full Error:**
```
[WARNING]: * Failed to parse /runner/inventory/hosts with yaml plugin
ERROR! No inventory was parsed, please check your configuration and options.
```

**Cause:** AAP is trying to use the project's `inventory/hosts.yml` file, which is for CLI use only.

**Solutions:**

1. **Create Inventory in AAP UI** (Correct approach)
   - Resources → Inventories → Add → Inventory
   - **Do NOT** use "Source from Project"
   - Manually add hosts in AAP UI
   - See [Step-by-Step Setup](#step-by-step-setup)

2. **Verify ansible.cfg**
   - Ensure `inventory = inventory/hosts.yml` is commented out
   - Version 1.2.0.0+ has this fixed
   - If using older version, comment out the line

3. **Check Job Template**
   - Ensure job template uses AAP-managed inventory
   - Not project inventory

4. **For CLI Usage**
   - Uncomment `inventory = inventory/hosts.yml` in ansible.cfg
   - Or use: `ansible-playbook -i inventory/hosts.yml collect_infrastructure.yml`

**Important:** AAP and CLI use different inventory management approaches:
- **AAP:** Inventory managed in AAP UI
- **CLI:** Inventory from `inventory/hosts.yml` file

### Error: "hmc_username is undefined"

**Cause:** Credentials not properly injected or playbook not detecting AAP environment.

**Solutions:**

1. **Verify Credential Attachment**
   - Check job template has credential attached
   - Verify credential type is correct

2. **Check Environment Detection**
   - Look for "Execution environment: AAP" in job output
   - If showing "CLI", environment detection failed

3. **Manual Override**
   - Add to job template extra variables:
   ```yaml
   hmc_username: "{{ lookup('env', 'ANSIBLE_NET_USERNAME') }}"
   hmc_password: "{{ lookup('env', 'ANSIBLE_NET_PASSWORD') }}"
   ```

### Error: "Authentication failed"

**Cause:** Incorrect credentials or HMC connectivity issues.

**Solutions:**

1. **Verify Credentials**
   - Test credentials manually: `ssh hscroot@hmc.example.com`
   - Verify password is correct

2. **Check Network Connectivity**
   - Ensure AAP execution environment can reach HMC
   - Verify firewall rules allow:
     - Port 12443 (HTTPS/REST API)
     - Port 22 (SSH for CLI version)

3. **Check HMC User Permissions**
   - User needs read permissions for system information
   - Test with: `lssyscfg -r sys` (CLI) or REST API call

### Error: "Failed to connect to HMC"

**Cause:** Network connectivity or certificate validation issues.

**Solutions:**

1. **Disable Certificate Validation** (for testing)
   - In inventory, set: `hmc_validate_certs: false`
   - Or in extra variables:
   ```yaml
   hmc_validate_certs: false
   ```

2. **Check HMC Hostname Resolution**
   - Verify DNS resolution from AAP execution environment
   - Use IP address instead of hostname if needed

3. **Verify HMC Service Status**
   - Ensure HMC web services are running
   - Check HMC is not in restricted mode

### Playbook Still Tries to Load vault.yml

**Cause:** Using older version of playbooks (pre-1.2.0.0).

**Solution:**
1. Update to version 1.2.0.0 or later
2. Or manually remove `vars_files` section from playbooks:
   ```yaml
   # Remove or comment out:
   # vars_files:
   #   - vars/vault.yml
   ```

---

## Best Practices

### 1. Use Separate Credentials per HMC

Create individual credentials for each HMC:
- `HMC01 Credentials`
- `HMC02 Credentials`
- etc.

**Benefits:**
- Easier credential rotation
- Better audit trail
- Granular access control

### 2. Use Credential Rotation

Regularly rotate HMC passwords:
1. Update password in HMC
2. Update credential in AAP
3. Test job execution
4. Document change

### 3. Limit Credential Access

Use AAP's RBAC to control who can:
- View credentials
- Use credentials
- Edit credentials

### 4. Use Read-Only HMC Accounts

Create dedicated read-only accounts for monitoring:
```bash
# On HMC (as hscroot)
mkhmcusr -u ansible_readonly -a hmcviewer --passwd <password>
```

**Benefits:**
- Principle of least privilege
- Reduced risk of accidental changes
- Better security posture

### 5. Test in Development First

Before production deployment:
1. Create test HMC credential
2. Create test job template
3. Run against test HMC
4. Verify all outputs work correctly
5. Then deploy to production

### 6. Monitor Credential Usage

Use AAP's audit logs to track:
- When credentials are used
- Which jobs use which credentials
- Failed authentication attempts

### 7. Document Credential Mapping

Maintain documentation of:
- Which credential is for which HMC
- Credential rotation schedule
- Emergency contact for credential issues

---

## Environment Variable Reference

### Standard AAP Machine Credential Variables

When using Machine credential type, AAP injects:

| Variable | Description | Example |
|----------|-------------|---------|
| `ANSIBLE_NET_USERNAME` | Network device username | `hscroot` |
| `ANSIBLE_NET_PASSWORD` | Network device password | `********` |
| `ANSIBLE_NET_SSH_KEYFILE` | SSH private key path | `/runner/artifacts/...` |

### Custom Credential Variables

When using custom credential type, you define the variable names in the injector configuration.

### Playbook Variable Mapping

The playbooks (v1.2.0.0+) automatically map:

**In AAP:**
```yaml
hmc_username: "{{ lookup('env', 'HMC_USERNAME') | default(lookup('env', 'ANSIBLE_NET_USERNAME')) }}"
hmc_password: "{{ lookup('env', 'HMC_PASSWORD') | default(lookup('env', 'ANSIBLE_NET_PASSWORD')) }}"
```

**In CLI:**
```yaml
hmc_username: "{{ hmc_credentials[inventory_hostname].username }}"
hmc_password: "{{ hmc_credentials[inventory_hostname].password }}"
```

---

## Example Job Template Configuration

### Complete Job Template YAML

```yaml
---
name: Collect Power Infrastructure
description: Collect infrastructure information from IBM Power HMCs
job_type: run
inventory: Power Systems Inventory
project: IBM Power Infrastructure Collection
playbook: collect_infrastructure.yml
credentials:
  - HMC Credentials
ask_credential_on_launch: false
ask_variables_on_launch: true
extra_vars: |
  ---
  output_dir: "/tmp/reports"
  enable_aap_artifacts: true
  enable_s3_upload: false
  hmc_validate_certs: false
verbosity: 0
job_tags: ""
skip_tags: ""
limit: ""
```

### Scheduled Job Template

For automated daily collection:

```yaml
---
name: Daily Power Infrastructure Collection
description: Automated daily collection of Power infrastructure data
job_type: run
inventory: Power Systems Inventory
project: IBM Power Infrastructure Collection
playbook: collect_infrastructure.yml
credentials:
  - HMC Credentials
extra_vars: |
  ---
  enable_aap_artifacts: true
  enable_s3_upload: true
  s3_bucket: "power-infrastructure-reports"
  s3_region: "us-east-1"
  s3_path_prefix: "daily/{{ ansible_date_time.date }}"
schedules:
  - name: Daily at 2 AM
    rrule: "DTSTART:20260101T020000Z RRULE:FREQ=DAILY;INTERVAL=1"
    enabled: true
```

---

## Security Considerations

### 1. Credential Storage

- AAP stores credentials encrypted in PostgreSQL
- Credentials are never written to disk in plain text
- Credentials are injected as environment variables at runtime

### 2. Credential Transmission

- Credentials transmitted over encrypted channels
- HTTPS for REST API (port 12443)
- SSH for CLI access (port 22)

### 3. Audit Trail

- All credential usage logged in AAP
- Job execution logs show when credentials used
- Failed authentication attempts recorded

### 4. Access Control

- Use AAP RBAC to limit credential access
- Separate credentials for different teams/purposes
- Regular access reviews

### 5. Credential Rotation

- Implement regular password rotation
- Update AAP credentials immediately after HMC password change
- Test after rotation

---

## Migration from CLI to AAP

### Step 1: Backup Current Configuration

```bash
# Backup vault file
cp vars/vault.yml vars/vault.yml.backup

# Backup ansible.cfg
cp ansible.cfg ansible.cfg.backup
```

### Step 2: Update Configuration Files

1. **Update ansible.cfg:**
   ```ini
   # Comment out vault_password_file
   # vault_password_file = .vault_pass
   ```

2. **Update playbooks to v1.2.0.0+**
   - Playbooks automatically detect environment
   - No manual changes needed if using latest version

### Step 3: Create AAP Credentials

Follow [Step-by-Step Setup](#step-by-step-setup) above.

### Step 4: Test in AAP

1. Create test job template
2. Run against single HMC
3. Verify output
4. Check AAP artifacts

### Step 5: Migrate Production

1. Create production job templates
2. Configure schedules
3. Set up notifications
4. Document for team

### Step 6: Cleanup (Optional)

After successful AAP migration:
```bash
# Remove vault file (keep backup)
rm vars/vault.yml

# Remove vault password file
rm .vault_pass

# Update .gitignore to prevent accidental commits
echo "vars/vault.yml" >> .gitignore
echo ".vault_pass" >> .gitignore
```

---

## Support and Resources

### Documentation
- Main README: `README.md`
- AAP Deployment Guide: `docs/README_AAP.md`
- Implementation Summary: `docs/IMPLEMENTATION_SUMMARY.md`

### Example Templates
- `docs/aap_job_templates/basic_job_template.yml`
- `docs/aap_job_templates/advanced_job_template.yml`
- `docs/aap_job_templates/scheduled_job_template.yml`

### Troubleshooting
- Check AAP job output for error messages
- Review execution environment logs
- Verify network connectivity to HMCs
- Test credentials manually

### Getting Help
1. Review this document
2. Check AAP job logs
3. Verify credential configuration
4. Test network connectivity
5. Contact your AAP administrator

---

## Changelog

### Version 1.2.0.0 (2026-03-13)
- Initial credential setup guide
- Added troubleshooting section
- Documented AAP credential types
- Added migration guide from CLI to AAP

---

**End of Document**