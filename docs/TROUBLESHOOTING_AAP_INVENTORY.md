# AAP Inventory Troubleshooting Guide
## IBM Power Systems Infrastructure Collection

**Version:** 1.2.0.0  
**Last Updated:** 2026-03-13  
**Issue:** Inventory parse errors in AAP

---

## The Problem

**Error Message:**
```
[WARNING]: * Failed to parse /runner/inventory/hosts with yaml plugin
ERROR! No inventory was parsed, please check your configuration and options.
```

**What This Means:**
AAP is trying to parse the project's `inventory/hosts.yml` file instead of using the AAP-managed inventory.

---

## Step-by-Step Resolution

### Step 1: Verify AAP Inventory Configuration ✅

1. **Check Inventory in AAP UI**
   - Navigate to: Resources → Inventories
   - Find your inventory (e.g., "Power Systems Infrastructure")
   - Click on it

2. **Verify Inventory Type**
   - Should show: **Inventory** (not "Smart Inventory" or other types)
   - Should NOT have any "Sources" configured

3. **Check Hosts**
   - Click **Hosts** tab
   - Should see your HMC hosts listed
   - Example: `hmc0001` with variables

4. **Verify Host Variables**
   - Click on a host
   - Should have variables like:
   ```yaml
   ansible_host: 1.2.3.16
   hmc_port: 12443
   hmc_validate_certs: false
   ```

### Step 2: Check Job Template Configuration ✅

1. **Open Job Template**
   - Navigate to: Resources → Templates
   - Find your job template
   - Click **Edit**

2. **Verify Inventory Field**
   - **Inventory:** Should show your AAP inventory name
   - Should NOT be empty
   - Should NOT show a project-based inventory

3. **Check Playbook Field**
   - **Playbook:** Should be `collect_infrastructure.yml` or `collect_infrastructure_hmc_cli.yml`
   - Should be a dropdown selection (not manual entry)

4. **Verify Project**
   - **Project:** Should show your project name
   - Project should be synced (green checkmark)

### Step 3: Sync Project in AAP ✅

**CRITICAL:** After any ansible.cfg changes, you MUST sync the project!

1. **Navigate to Project**
   - Resources → Projects
   - Find your project

2. **Sync Project**
   - Click the sync icon (circular arrows)
   - Wait for completion (should turn green)
   - Check "Last Job Status" shows "Successful"

3. **Verify Sync Time**
   - "Last Updated" should be recent (after your ansible.cfg changes)
   - If old, sync again

### Step 4: Check for Inventory Sources ✅

1. **Open Your Inventory**
   - Resources → Inventories → Your Inventory

2. **Check Sources Tab**
   - Click **Sources** tab
   - Should be EMPTY (no sources)
   - If you see any sources, DELETE them

3. **Why This Matters**
   - Inventory sources can pull from project files
   - This causes the parse error
   - AAP inventory should be manually managed

### Step 5: Verify ansible.cfg ✅

1. **Check Project Files**
   - In AAP, go to your project
   - View files (if possible) or check in Git

2. **Verify ansible.cfg Content**
   ```ini
   [defaults]
   # inventory = inventory/hosts.yml  ← Should be commented
   # vault_password_file = .vault_pass  ← Should be commented
   ```

3. **If Not Commented**
   - Update in Git repository
   - Sync project in AAP
   - Try again

### Step 6: Clear AAP Cache (If Needed) ✅

Sometimes AAP caches old configurations:

1. **Re-sync Project**
   - Force a fresh sync
   - Resources → Projects → Your Project → Sync

2. **Edit and Save Job Template**
   - Open job template
   - Make a minor change (e.g., add a space in description)
   - Save
   - Change it back
   - Save again

3. **Restart Job**
   - Launch the job template again

---

## Verification Checklist

Before running the job, verify:

- [ ] AAP inventory created in UI (not from project)
- [ ] Hosts added manually to AAP inventory
- [ ] No inventory sources configured
- [ ] Job template uses AAP inventory (not project inventory)
- [ ] Project synced after ansible.cfg changes
- [ ] ansible.cfg has inventory line commented out
- [ ] ansible.cfg has vault_password_file commented out

---

## Common Mistakes

### ❌ Mistake 1: Using "Source from Project"

**Wrong:**
- Creating inventory with "Source from Project"
- Pointing to `inventory/hosts.yml`

**Right:**
- Create empty inventory in AAP UI
- Manually add hosts

### ❌ Mistake 2: Not Syncing Project

**Wrong:**
- Changing ansible.cfg in Git
- Running job immediately

**Right:**
- Change ansible.cfg in Git
- Sync project in AAP
- Then run job

### ❌ Mistake 3: Inventory Sources

**Wrong:**
- Adding inventory source pointing to project

**Right:**
- No inventory sources
- Manually managed hosts only

### ❌ Mistake 4: Old Project Version

**Wrong:**
- Using cached/old project version

**Right:**
- Always sync project before running
- Verify "Last Updated" timestamp

---

## Alternative: Create New Inventory from Scratch

If issues persist, create a completely new inventory:

### Step 1: Create New Inventory

1. **Navigate to Inventories**
   - Resources → Inventories → Add → Inventory

2. **Configure**
   - **Name:** `Power Systems Infrastructure v2`
   - **Organization:** Your organization
   - Click **Save**

### Step 2: Add Hosts Manually

For each HMC:

1. **Add Host**
   - Click **Hosts** tab → Add
   - **Name:** `hmc0001` (your HMC hostname)
   - **Variables:**
   ```yaml
   ---
   ansible_host: 1.2.3.16
   hmc_port: 12443
   hmc_validate_certs: false
   ```
   - Click **Save**

2. **Repeat for Each HMC**

### Step 3: Create Group (Optional)

1. **Add Group**
   - Click **Groups** tab → Add
   - **Name:** `hmcs`
   - Click **Save**

2. **Add Hosts to Group**
   - Click on group → **Hosts** tab
   - Add existing hosts

### Step 4: Update Job Template

1. **Edit Job Template**
   - Change **Inventory** to new inventory
   - Save

2. **Test**
   - Launch job
   - Should work now

---

## Debug Mode

If still having issues, enable debug output:

### In Job Template Extra Variables:

```yaml
---
# Enable debug output
ansible_verbosity: 2

# Force environment detection
force_aap_mode: true

# Verify inventory
debug_inventory: true
```

### Check Job Output For:

```
TASK [Display collection start information]
ok: [hmc0001] => {
    "msg": [
        "Starting infrastructure collection from HMC: hmc0001",
        "Execution environment: AAP",  ← Should show AAP
        ...
    ]
}
```

---

## Still Not Working?

### Check These Additional Items:

1. **AAP Version**
   - Ensure AAP 2.4 or higher
   - Check: Administration → About

2. **Execution Environment**
   - Verify execution environment has required collections
   - Check: Administration → Execution Environments

3. **Project SCM**
   - Verify Git repository is accessible
   - Check project sync logs for errors

4. **Permissions**
   - Verify you have permission to use the inventory
   - Check: Access tab on inventory

5. **Network**
   - Verify AAP can reach HMCs
   - Test from AAP execution environment

---

## Manual Inventory Test

Test if AAP can use your inventory:

### Create Simple Test Playbook

In your project, create `test_inventory.yml`:

```yaml
---
- name: Test Inventory
  hosts: all
  gather_facts: false
  
  tasks:
    - name: Display inventory information
      debug:
        msg:
          - "Hostname: {{ inventory_hostname }}"
          - "ansible_host: {{ ansible_host | default('not set') }}"
          - "Groups: {{ group_names }}"
```

### Create Test Job Template

1. **Create Template**
   - Name: `Test Inventory`
   - Inventory: Your AAP inventory
   - Playbook: `test_inventory.yml`

2. **Run**
   - Should show your hosts
   - Should NOT show inventory parse errors

3. **If This Works**
   - Inventory is configured correctly
   - Issue is with main playbook
   - Check playbook-specific settings

---

## Contact Information

If you've followed all steps and still have issues:

1. **Check AAP Logs**
   - SSH to AAP server
   - Check: `/var/log/tower/`

2. **Review Job Output**
   - Full job output in AAP UI
   - Look for specific error messages

3. **Verify Configuration**
   - Export job template as JSON
   - Review all settings

4. **Test in CLI First**
   - Try running playbook from CLI
   - If CLI works but AAP doesn't, it's an AAP configuration issue

---

## Success Indicators

You'll know it's working when you see:

✅ **No inventory parse warnings**  
✅ **Job starts successfully**  
✅ **Shows "Execution environment: AAP"**  
✅ **Connects to HMC**  
✅ **Collects data**  
✅ **Generates artifacts**

---

## Quick Reference Commands

### Sync Project (AAP CLI)
```bash
awx projects update <project_id>
```

### Check Inventory (AAP CLI)
```bash
awx inventory list
awx inventory get <inventory_id>
awx hosts list --inventory <inventory_id>
```

### Launch Job (AAP CLI)
```bash
awx job_templates launch <template_id>
```

---

**End of Troubleshooting Guide**