# AAP Quick Start Guide
## IBM Power Systems Infrastructure Collection

**Version:** 1.2.0.0  
**Last Updated:** 2026-03-13

---

## 🚀 Quick Start (5 Minutes)

### Prerequisites
- ✅ AAP 2.4+ installed and accessible
- ✅ HMC credentials (username/password)
- ✅ Network connectivity from AAP to HMC (port 12443 or 22)

### Step 1: Import Project (1 min)

1. **Create Project in AAP**
   - Navigate to: Resources → Projects → Add
   - **Name:** `IBM Power Infrastructure Collection`
   - **SCM Type:** Git
   - **SCM URL:** `<your-git-repo-url>`
   - **SCM Branch:** `main`
   - Click **Save**

2. **Sync Project**
   - Click the sync icon
   - Wait for completion

### Step 2: Create Credential (1 min)

1. **Navigate to Credentials**
   - Resources → Credentials → Add

2. **Configure Credential**
   - **Name:** `HMC Credentials`
   - **Organization:** Your organization
   - **Credential Type:** Machine
   - **Username:** `hscroot` (or your HMC username)
   - **Password:** Your HMC password
   - Click **Save**

### Step 3: Create Inventory (1 min)

1. **Create Inventory**
   - Resources → Inventories → Add → Inventory
   - **Name:** `Power Systems Infrastructure`
   - Click **Save**

2. **Add HMC Host**
   - Click **Hosts** tab → Add
   - **Name:** `hmc01.example.com`
   - **Variables:**
   ```yaml
   ---
   ansible_host: 10.1.1.100
   hmc_port: 12443
   hmc_validate_certs: false
   ```
   - Click **Save**

### Step 4: Create Job Template (2 min)

1. **Create Template**
   - Resources → Templates → Add → Job Template
   - **Name:** `Collect Power Infrastructure`
   - **Job Type:** Run
   - **Inventory:** Power Systems Infrastructure
   - **Project:** IBM Power Infrastructure Collection
   - **Playbook:** `collect_infrastructure.yml`
   - **Credentials:** Select "HMC Credentials"
   - **Variables:**
   ```yaml
   ---
   enable_aap_artifacts: true
   hmc_validate_certs: false
   ```
   - Click **Save**

### Step 5: Run Job (30 seconds)

1. **Launch Job**
   - Click **Launch** button
   - Monitor execution

2. **View Results**
   - Check job output for success
   - Download artifacts from job details page

---

## 📊 Expected Output

### Job Output
```
TASK [Display collection start information]
ok: [hmc01.example.com] => {
    "msg": [
        "Starting infrastructure collection from HMC: hmc01.example.com",
        "Execution environment: AAP",
        "Timestamp: 2026-03-13T11:00:00.000Z",
        "Output directory: ./output/reports"
    ]
}

TASK [Collect managed systems]
ok: [hmc01.example.com]

TASK [Collect LPARs]
ok: [hmc01.example.com]

PLAY RECAP
hmc01.example.com : ok=25 changed=0 unreachable=0 failed=0
```

### AAP Artifacts

After job completion, artifacts are available:
- `infrastructure_report_json` - JSON format
- `infrastructure_report_csv` - CSV format
- `infrastructure_report_yml` - YAML format
- `infrastructure_report_html` - HTML format

**Download via:**
- AAP UI: Job Details → Artifacts tab
- AAP API: `GET /api/v2/jobs/{job_id}/artifacts/`

---

## 🔧 Common Issues & Quick Fixes

### Issue 1: Vault Password Error

**Error:**
```
ERROR! The vault password file /runner/project/.vault_pass was not found
```

**Fix:**
This is already fixed in v1.2.0.0. If you see this error:
1. Ensure you're using version 1.2.0.0 or later
2. Check that `ansible.cfg` has vault_password_file commented out
3. Sync your project in AAP

### Issue 2: Authentication Failed

**Error:**
```
FAILED! => {"msg": "Authentication failed"}
```

**Fix:**
1. Verify HMC credentials in AAP credential
2. Test manually: `ssh hscroot@hmc.example.com`
3. Check HMC is accessible from AAP execution environment

### Issue 3: Connection Timeout

**Error:**
```
FAILED! => {"msg": "Connection timeout"}
```

**Fix:**
1. Verify network connectivity: `ping hmc.example.com`
2. Check firewall allows port 12443 (REST API) or 22 (SSH)
3. Verify HMC hostname/IP is correct in inventory

### Issue 4: No Artifacts Generated

**Symptom:** Job succeeds but no artifacts available

**Fix:**
1. Check `enable_aap_artifacts: true` in job template variables
2. Verify playbook version is 1.2.0.0+
3. Check job output for "Registering AAP artifacts" task

---

## 📚 Next Steps

### For Basic Usage
- ✅ You're done! Schedule the job to run daily
- See: [Scheduling Jobs](#scheduling-jobs)

### For Advanced Features
- 📤 **S3 Upload:** Store reports in S3 bucket
- 📝 **Git Integration:** Commit reports to Git repository
- 🔔 **Notifications:** Set up Slack/email alerts
- See: `docs/README_AAP.md` for details

### For Multiple HMCs
1. Add more hosts to inventory
2. Each host needs same variables
3. Job will collect from all HMCs in parallel

---

## ⏰ Scheduling Jobs

### Daily Collection at 2 AM

1. **Open Job Template**
   - Navigate to your job template
   - Click **Schedules** tab

2. **Add Schedule**
   - Click **Add**
   - **Name:** `Daily Collection`
   - **Start Date/Time:** Today at 02:00
   - **Repeat Frequency:** Daily
   - **Run Every:** 1 day
   - Click **Save**

### Weekly Collection

- **Repeat Frequency:** Weekly
- **Run On:** Select days (e.g., Monday)
- **Run Every:** 1 week

---

## 🔐 Security Best Practices

### 1. Use Read-Only HMC Account
```bash
# On HMC (as hscroot)
mkhmcusr -u ansible_readonly -a hmcviewer --passwd <password>
```

### 2. Rotate Credentials Regularly
- Update HMC password monthly
- Update AAP credential immediately after
- Test job execution after rotation

### 3. Limit Access
- Use AAP RBAC to control who can:
  - View credentials
  - Run jobs
  - View artifacts

### 4. Enable Audit Logging
- Monitor credential usage in AAP
- Review failed authentication attempts
- Track job execution history

---

## 📖 Additional Documentation

| Document | Purpose |
|----------|---------|
| `README.md` | Main project documentation |
| `docs/README_AAP.md` | Comprehensive AAP deployment guide |
| `docs/AAP_CREDENTIAL_SETUP.md` | Detailed credential configuration |
| `docs/IMPLEMENTATION_SUMMARY.md` | Technical implementation details |
| `docs/aap_job_templates/` | Example job template configurations |

---

## 🆘 Getting Help

### Troubleshooting Steps
1. ✅ Check this quick start guide
2. ✅ Review `docs/AAP_CREDENTIAL_SETUP.md`
3. ✅ Check AAP job output logs
4. ✅ Verify network connectivity
5. ✅ Test HMC credentials manually

### Common Commands for Testing

**Test HMC SSH Access:**
```bash
ssh hscroot@hmc.example.com
```

**Test HMC REST API:**
```bash
curl -k -u hscroot:password https://hmc.example.com:12443/rest/api/web/Logon -X PUT
```

**Check AAP Execution Environment:**
```bash
# In AAP job output, look for:
"Execution environment: AAP"
```

---

## ✅ Success Checklist

Before considering setup complete:

- [ ] Project synced successfully in AAP
- [ ] Credential created and tested
- [ ] Inventory contains HMC hosts
- [ ] Job template created
- [ ] Test job executed successfully
- [ ] Artifacts downloaded and verified
- [ ] Schedule configured (if needed)
- [ ] Team members have appropriate access
- [ ] Documentation reviewed

---

## 🎯 What You've Accomplished

After completing this quick start:

✅ **Automated Data Collection** - AAP collects infrastructure data automatically  
✅ **Centralized Credentials** - Secure credential management in AAP  
✅ **Multiple Output Formats** - JSON, CSV, YAML, HTML reports  
✅ **AAP Artifacts** - Reports accessible via AAP UI and API  
✅ **Scheduled Execution** - Optional automated daily/weekly collection  
✅ **Audit Trail** - All executions logged in AAP  

---

## 📞 Support

For issues or questions:
1. Review documentation in `docs/` directory
2. Check AAP job logs for error details
3. Verify configuration against this guide
4. Contact your AAP administrator

---

**Happy Automating! 🚀**