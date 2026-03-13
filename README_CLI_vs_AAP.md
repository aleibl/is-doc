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
host_key_checking = False
timeout = 30
gathering = explicit

# Note: No inventory line - specify with -i flag for CLI
# Note: No vault_password_file - use --ask-vault-pass for CLI
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
# Standard CLI execution (recommended)
ansible-playbook -i inventory/hosts.yml collect_infrastructure.yml --ask-vault-pass

# With vault password file
ansible-playbook -i inventory/hosts.yml collect_infrastructure.yml --vault-password-file .vault_pass

# With specific HMC limit
ansible-playbook -i inventory/hosts.yml collect_infrastructure.yml --ask-vault-pass --limit hmc01.example.com

# With extra variables
ansible-playbook -i inventory/hosts.yml collect_infrastructure.yml --ask-vault-pass -e "output_dir=/tmp/reports"
```

**Note:** Always use the `-i` flag to specify inventory when running from CLI.

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
host_key_checking = False
timeout = 30
gathering = explicit

# No inventory line - AAP manages inventory in UI
# No vault_password_file - AAP manages credentials
```

**Note:** The same minimal ansible.cfg works for both CLI and AAP. The `inventory/hosts.yml` and `vars/vault.yml` files are NOT used in AAP mode.

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

**ansible.cfg (Universal - Works for Both):**
```ini
[defaults]
host_key_checking = False
timeout = 30
gathering = explicit
```

**Key Points:**
- No `inventory` line - specify with `-i` flag for CLI, managed in UI for AAP
- No `vault_password_file` - use `--ask-vault-pass` for CLI, credentials in UI for AAP
- No `[inventory]` section - causes conflicts with AAP
- Minimal configuration works universally

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

4. **No ansible.cfg changes needed**
   - The minimal ansible.cfg works for both!

5. **Create job template**
   - Configure in AAP UI
   - Test execution

### From AAP to CLI

1. **No ansible.cfg changes needed**
   - The minimal ansible.cfg works for both!

2. **Ensure inventory file exists**
   - Verify `inventory/hosts.yml` is present
   - Update with current HMC hosts

3. **Ensure vault file exists**
   - Verify `vars/vault.yml` exists
   - Decrypt if needed: `ansible-vault decrypt vars/vault.yml`
   - Update credentials
   - Re-encrypt: `ansible-vault encrypt vars/vault.yml`

4. **Run from CLI with -i flag**
   ```bash
   ansible-playbook -i inventory/hosts.yml collect_infrastructure.yml --ask-vault-pass
   ```

---

## Troubleshooting

### Issue: "No inventory was parsed"

**In AAP:**
- Ensure inventory is created in AAP UI
- Do NOT use project inventory file
- Ensure ansible.cfg has NO `inventory` line
- Ensure ansible.cfg has NO `[inventory]` section

**In CLI:**
- Ensure `inventory/hosts.yml` exists
- Always use `-i` flag: `ansible-playbook -i inventory/hosts.yml ...`
- Do NOT add `inventory` line to ansible.cfg (causes AAP conflicts)

### Issue: "Vault password file not found"

**In AAP:**
- This is expected - AAP doesn't use vault files
- Ensure ansible.cfg has NO `vault_password_file` line
- Use AAP credentials instead

**In CLI:**
- Always use `--ask-vault-pass` flag (recommended)
- Or use `--vault-password-file .vault_pass`
- Do NOT add `vault_password_file` to ansible.cfg (causes AAP conflicts)

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

3. **Always use -i flag**
   - Explicit inventory specification is best practice
   - Prevents conflicts with AAP
   - Makes commands self-documenting

4. **Automate with cron**
   ```bash
   # Daily collection at 2 AM
   0 2 * * * cd /path/to/project && ansible-playbook -i inventory/hosts.yml collect_infrastructure.yml --vault-password-file .vault_pass
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

### ansible.cfg (Universal - Works for Both CLI and AAP)

```ini
[defaults]
host_key_checking = False
timeout = 30
gathering = explicit
```

**That's it!** This minimal configuration:
- ✅ Works perfectly in CLI (use `-i` flag for inventory)
- ✅ Works perfectly in AAP (inventory from UI)
- ✅ No conflicts or compatibility issues
- ✅ No `[inventory]` section (causes AAP parse errors)
- ✅ No `inventory` line (use `-i` flag instead)
- ✅ No `vault_password_file` (use `--ask-vault-pass` instead)

**Why minimal is better:**
- Explicit inventory specification (`-i` flag) is best practice
- Prevents AAP inventory parsing conflicts
- Makes commands self-documenting
- Easier to maintain
- Works universally

---

## Summary

| Configuration | CLI Mode | AAP Mode |
|---------------|----------|----------|
| **ansible.cfg** | Same minimal config | Same minimal config |
| **Inventory specification** | `-i inventory/hosts.yml` flag | Managed in AAP UI |
| **Credentials** | `--ask-vault-pass` flag | AAP Credentials |
| **inventory/hosts.yml** | Required (for `-i` flag) | Not used |
| **vars/vault.yml** | Required | Not used |
| **AAP Inventory** | Not used | Required |
| **AAP Credentials** | Not used | Required |
| **Playbook changes** | None (auto-detect) | None (auto-detect) |
| **Command** | `ansible-playbook -i ... --ask-vault-pass` | Click "Launch" in AAP |

**Key Insight:** The same minimal ansible.cfg works for both modes! The difference is in how you specify inventory and credentials (command-line flags for CLI, UI configuration for AAP).

**The playbooks (v1.2.0.0+) automatically detect the execution environment and adapt accordingly. No manual playbook changes are needed when switching between CLI and AAP modes.**

---

## Additional Resources

- **Quick Start (AAP):** `docs/QUICKSTART_AAP.md`
- **Credential Setup (AAP):** `docs/AAP_CREDENTIAL_SETUP.md`
- **AAP Deployment Guide:** `docs/README_AAP.md`
- **Main README:** `README.md`

---

**End of Document**