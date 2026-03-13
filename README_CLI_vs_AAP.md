# CLI vs AAP Usage Guide
## IBM Power Systems Infrastructure Collection

**Version:** 1.2.0.0  
**Last Updated:** 2026-03-13

---

## Overview

This collection supports two execution modes:
1. **CLI Mode** - Run directly from command line using `ansible-playbook`
2. **AAP Mode** - Run in Ansible Automation Platform

Each mode has different configuration requirements.

---

## Quick Comparison

| Aspect | CLI Mode | AAP Mode |
|--------|----------|----------|
| **Execution** | `ansible-playbook` command | AAP Job Template |
| **Inventory** | `inventory/hosts.yml` file | AAP UI inventory |
| **Credentials** | `vars/vault.yml` (Ansible Vault) | AAP Credentials |
| **ansible.cfg** | Uses `inventory` setting | Ignores `inventory` setting |
| **Output** | Local files | AAP artifacts + optional S3/Git |
| **Scheduling** | Cron or manual | AAP Schedules |

---

## CLI Mode Setup

### 1. Configuration Files

**ansible.cfg:**
```ini
[defaults]
# Uncomment for CLI usage
inventory = inventory/hosts.yml
# vault_password_file = .vault_pass  # Optional
```

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
```

**vars/vault.yml:**
```yaml
---
hmc_credentials:
  hmc01.example.com:
    username: "hscroot"
    password: "your_password"
```

### 2. Encrypt Credentials

```bash
# Create vault password file
echo "your_vault_password" > .vault_pass
chmod 600 .vault_pass

# Encrypt credentials
ansible-vault encrypt vars/vault.yml
```

### 3. Run Playbook

```bash
# With vault password file
ansible-playbook collect_infrastructure.yml

# Or prompt for vault password
ansible-playbook collect_infrastructure.yml --ask-vault-pass

# Or specify inventory explicitly
ansible-playbook -i inventory/hosts.yml collect_infrastructure.yml
```

### 4. View Results

```bash
ls -l output/reports/
# infrastructure_2026-03-13_12-00-00.json
# infrastructure_2026-03-13_12-00-00.csv
# infrastructure_2026-03-13_12-00-00.yml
# infrastructure_2026-03-13_12-00-00.html
```

---

## AAP Mode Setup

### 1. Configuration Files

**ansible.cfg:**
```ini
[defaults]
# Comment out for AAP usage
# inventory = inventory/hosts.yml
# vault_password_file = .vault_pass
```

**Note:** The `inventory/hosts.yml` and `vars/vault.yml` files are NOT used in AAP mode.

### 2. AAP Configuration

#### Create Inventory in AAP UI
1. Resources → Inventories → Add → Inventory
2. Name: `Power Systems Infrastructure`
3. Add hosts manually in AAP UI

#### Create Credential in AAP UI
1. Resources → Credentials → Add
2. Type: Machine
3. Username: `hscroot`
4. Password: Your HMC password

#### Create Job Template
1. Resources → Templates → Add → Job Template
2. Inventory: Select AAP inventory
3. Credentials: Select HMC credential
4. Playbook: `collect_infrastructure.yml`

### 3. Run Job

1. Navigate to job template
2. Click **Launch**
3. Monitor execution

### 4. View Results

- **AAP UI:** Job Details → Artifacts tab
- **AAP API:** `GET /api/v2/jobs/{job_id}/artifacts/`
- **S3/Git:** If configured in extra variables

---

## Key Differences Explained

### Inventory Management

**CLI Mode:**
- Inventory defined in `inventory/hosts.yml`
- File committed to Git
- Managed by editing YAML file
- ansible.cfg points to inventory file

**AAP Mode:**
- Inventory defined in AAP UI
- Stored in AAP database
- Managed through AAP interface
- ansible.cfg inventory setting ignored

### Credential Management

**CLI Mode:**
- Credentials in `vars/vault.yml`
- Encrypted with Ansible Vault
- Requires vault password
- File-based storage

**AAP Mode:**
- Credentials in AAP UI
- Encrypted in AAP database
- No vault password needed
- AAP credential system

### Configuration File Handling

**ansible.cfg:**
```ini
# For CLI: Uncomment these lines
inventory = inventory/hosts.yml
vault_password_file = .vault_pass

# For AAP: Comment out these lines
# inventory = inventory/hosts.yml
# vault_password_file = .vault_pass
```

**Playbooks (v1.2.0.0+):**
- Automatically detect execution environment
- Load vault file only in CLI mode
- Use environment variables in AAP mode
- No manual changes needed

---

## Switching Between Modes

### From CLI to AAP

1. **Sync project to AAP**
   - Create project in AAP
   - Point to Git repository
   - Sync project

2. **Create AAP inventory**
   - Manually recreate hosts from `inventory/hosts.yml`
   - Add to AAP UI

3. **Create AAP credentials**
   - Extract credentials from `vars/vault.yml`
   - Create in AAP UI

4. **Update ansible.cfg** (if needed)
   - Comment out `inventory` line
   - Comment out `vault_password_file` line

5. **Create job template**
   - Configure in AAP UI
   - Test execution

### From AAP to CLI

1. **Update ansible.cfg**
   - Uncomment `inventory = inventory/hosts.yml`
   - Optionally uncomment `vault_password_file`

2. **Ensure inventory file exists**
   - Verify `inventory/hosts.yml` is present
   - Update with current HMC hosts

3. **Ensure vault file exists**
   - Verify `vars/vault.yml` exists
   - Decrypt if needed: `ansible-vault decrypt vars/vault.yml`
   - Update credentials
   - Re-encrypt: `ansible-vault encrypt vars/vault.yml`

4. **Run from CLI**
   ```bash
   ansible-playbook collect_infrastructure.yml
   ```

---

## Troubleshooting

### Issue: "No inventory was parsed"

**In AAP:**
- Ensure inventory is created in AAP UI
- Do NOT use project inventory file
- Comment out `inventory` line in ansible.cfg

**In CLI:**
- Ensure `inventory/hosts.yml` exists
- Uncomment `inventory` line in ansible.cfg
- Or use `-i` flag: `ansible-playbook -i inventory/hosts.yml ...`

### Issue: "Vault password file not found"

**In AAP:**
- This is expected - AAP doesn't use vault files
- Ensure ansible.cfg has `vault_password_file` commented out
- Use AAP credentials instead

**In CLI:**
- Create `.vault_pass` file with vault password
- Or use `--ask-vault-pass` flag
- Or set `ANSIBLE_VAULT_PASSWORD_FILE` environment variable

### Issue: "hmc_username is undefined"

**In AAP:**
- Ensure credential is attached to job template
- Verify credential type is correct (Machine)
- Check playbook version is 1.2.0.0+

**In CLI:**
- Ensure `vars/vault.yml` exists and is decrypted
- Verify credentials are defined for each HMC
- Check vault password is correct

---

## Best Practices

### For CLI Usage

1. **Keep credentials secure**
   - Never commit unencrypted `vars/vault.yml`
   - Add `.vault_pass` to `.gitignore`
   - Use strong vault passwords

2. **Use version control**
   - Commit `inventory/hosts.yml` to Git
   - Document inventory changes
   - Use branches for different environments

3. **Automate with cron**
   ```bash
   # Daily collection at 2 AM
   0 2 * * * cd /path/to/project && ansible-playbook collect_infrastructure.yml
   ```

### For AAP Usage

1. **Use AAP features**
   - Leverage AAP RBAC for access control
   - Use AAP schedules instead of cron
   - Enable notifications for job failures

2. **Separate environments**
   - Create separate inventories for dev/test/prod
   - Use different credentials per environment
   - Test in dev before deploying to prod

3. **Monitor and audit**
   - Review AAP job logs regularly
   - Monitor credential usage
   - Set up alerts for failures

---

## Configuration File Templates

### ansible.cfg for CLI

```ini
[defaults]
inventory = inventory/hosts.yml
host_key_checking = False
vault_password_file = .vault_pass
stdout_callback = default
timeout = 30
gathering = explicit
log_path = ./ansible.log

[inventory]
enable_plugins = yaml, ini
```

### ansible.cfg for AAP

```ini
[defaults]
# inventory = inventory/hosts.yml  # Commented for AAP
host_key_checking = False
# vault_password_file = .vault_pass  # Commented for AAP
stdout_callback = default
timeout = 30
gathering = explicit
# log_path = ./ansible.log  # Not used in AAP

[inventory]
enable_plugins = yaml, ini
```

### ansible.cfg for Both (Recommended)

```ini
[defaults]
# Inventory configuration
# Note: For AAP, inventory is managed in AAP UI
# For CLI, uncomment the line below or use -i flag
# inventory = inventory/hosts.yml

host_key_checking = False

# Vault configuration
# Note: For AAP, use AAP's credential system
# For CLI with vault, use --ask-vault-pass or set ANSIBLE_VAULT_PASSWORD_FILE
# vault_password_file = .vault_pass

stdout_callback = default
timeout = 30
gathering = explicit
log_path = ./ansible.log

[inventory]
enable_plugins = yaml, ini
```

---

## Summary

| Configuration | CLI Mode | AAP Mode |
|---------------|----------|----------|
| **ansible.cfg inventory** | Uncommented | Commented |
| **ansible.cfg vault_password_file** | Optional | Commented |
| **inventory/hosts.yml** | Required | Not used |
| **vars/vault.yml** | Required | Not used |
| **AAP Inventory** | Not used | Required |
| **AAP Credentials** | Not used | Required |
| **Playbook changes** | None (auto-detect) | None (auto-detect) |

**The playbooks (v1.2.0.0+) automatically detect the execution environment and adapt accordingly. No manual playbook changes are needed when switching between CLI and AAP modes.**

---

## Additional Resources

- **Quick Start (AAP):** `docs/QUICKSTART_AAP.md`
- **Credential Setup (AAP):** `docs/AAP_CREDENTIAL_SETUP.md`
- **AAP Deployment Guide:** `docs/README_AAP.md`
- **Main README:** `README.md`

---

**End of Document**