# Ansible Automation Platform (AAP) Deployment Guide

**IBM Power Systems Infrastructure Collection**  
**Version:** 1.1.0.0  
**Last Updated:** 2026-02-28

---

## Table of Contents

1. [Overview](#overview)
2. [Prerequisites](#prerequisites)
3. [Quick Start](#quick-start)
4. [Output Methods](#output-methods)
5. [Configuration](#configuration)
6. [Credentials Setup](#credentials-setup)
7. [Job Template Creation](#job-template-creation)
8. [Accessing Reports](#accessing-reports)
9. [Troubleshooting](#troubleshooting)
10. [Best Practices](#best-practices)

---

## Overview

This guide explains how to deploy and use the IBM Power Infrastructure Collection playbooks on Ansible Automation Platform (AAP) 2.x.

### Key Features

✅ **Automatic Environment Detection** - Playbooks detect AAP and adapt automatically  
✅ **Multiple Output Methods** - AAP artifacts, S3, Git, or local files  
✅ **Zero Configuration Required** - Works out-of-the-box with sensible defaults  
✅ **Backward Compatible** - CLI usage unchanged  
✅ **Secure** - Credentials managed by AAP credential system

### How It Works

```
┌─────────────────────────────────────────────────────────┐
│  AAP Job Execution                                       │
│  ┌─────────────────────────────────────────────────┐   │
│  │ 1. Detect AAP Environment (automatic)           │   │
│  │ 2. Collect Infrastructure Data from HMCs        │   │
│  │ 3. Generate Reports (JSON, CSV, YAML, HTML)     │   │
│  │ 4. Persist Reports:                             │   │
│  │    ✓ AAP Artifacts (default)                    │   │
│  │    ✓ S3 Upload (optional)                       │   │
│  │    ✓ Git Commit (optional)                      │   │
│  └─────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────┘
         │                    │                    │
         ▼                    ▼                    ▼
    AAP API              S3 Bucket           Git Repository
```

---

## Prerequisites

### AAP Requirements

- **AAP Version:** 2.0 or higher
- **Execution Environment:** Default or custom EE with required collections
- **Network Access:** Connectivity to HMCs (port 12443 for REST API or port 22 for SSH)

### Required Collections

```yaml
# Automatically installed from requirements.yml
- ansible.builtin (>=2.10.0)
- community.general (>=3.0.0)
- ibm.power_hmc (>=1.0.0)  # For CLI version
- amazon.aws (>=5.0.0)      # For S3 upload (optional)
```

### Optional Components

- **S3-Compatible Storage:** AWS S3, MinIO, or other S3-compatible service
- **Git Repository:** For version-controlled report storage
- **Custom Execution Environment:** If using S3 or Git features

---

## Quick Start

### 1. Import Project

**Via AAP UI:**
1. Navigate to **Projects** → **Add**
2. Configure:
   - **Name:** IBM Power Infrastructure Collection
   - **Organization:** Your organization
   - **Source Control Type:** Git
   - **Source Control URL:** `https://github.com/your-org/power-infrastructure-collection.git`
   - **Source Control Branch:** `main`
   - **Update on Launch:** ✓ (recommended)

**Via API:**
```bash
curl -X POST https://aap.example.com/api/v2/projects/ \
  -H "Content-Type: application/json" \
  -u admin:password \
  -d '{
    "name": "IBM Power Infrastructure Collection",
    "organization": 1,
    "scm_type": "git",
    "scm_url": "https://github.com/your-org/power-infrastructure-collection.git",
    "scm_branch": "main",
    "scm_update_on_launch": true
  }'
```

### 2. Create Inventory

**Via AAP UI:**
1. Navigate to **Inventories** → **Add** → **Add inventory**
2. Configure:
   - **Name:** Power Systems HMCs
   - **Organization:** Your organization
3. Add hosts:
   - Navigate to **Hosts** → **Add**
   - **Name:** `hmc01.example.com`
   - **Variables:**
     ```yaml
     ansible_host: 192.168.1.10
     hmc_description: "Production HMC"
     ```

### 3. Configure Credentials

**HMC Credentials:**
1. Navigate to **Credentials** → **Add**
2. Configure:
   - **Name:** HMC Credentials
   - **Credential Type:** Machine
   - **Username:** `hscroot`
   - **Password:** `<your_password>`

### 4. Create Job Template

**Via AAP UI:**
1. Navigate to **Templates** → **Add** → **Add job template**
2. Configure:
   - **Name:** Collect Power Infrastructure
   - **Job Type:** Run
   - **Inventory:** Power Systems HMCs
   - **Project:** IBM Power Infrastructure Collection
   - **Playbook:** `collect_infrastructure.yml`
   - **Credentials:** HMC Credentials
   - **Variables:**
     ```yaml
     enable_aap_artifacts: true
     enable_s3_upload: false
     enable_git_commit: false
     ```

### 5. Run Job

1. Navigate to **Templates**
2. Click **Launch** on "Collect Power Infrastructure"
3. Monitor execution in job output
4. Access artifacts after completion

---

## Output Methods

### Method 1: AAP Artifacts (Default)

**Enabled by default in AAP environment**

Reports are registered as job artifacts and accessible via AAP API.

**Configuration:**
```yaml
enable_aap_artifacts: auto  # auto|true|false
aap_artifact_formats:
  - json
  - csv
  - yml
  - html
```

**Access via API:**
```bash
# Get job artifacts
JOB_ID=123
curl -k -u admin:password \
  https://aap.example.com/api/v2/jobs/${JOB_ID}/artifacts/ \
  | jq .

# Download JSON report
curl -k -u admin:password \
  https://aap.example.com/api/v2/jobs/${JOB_ID}/artifacts/ \
  | jq -r '.infrastructure_report_json' \
  | base64 -d > report.json
```

**Access via UI:**
1. Navigate to **Jobs** → Select job
2. Click **Details** tab
3. Scroll to **Artifacts** section
4. Copy artifact content
5. Decode base64: `echo '<content>' | base64 -d > report.json`

**Limitations:**
- Size limit: ~1MB per artifact (base64 encoded)
- Retention: Tied to job retention policy
- Manual download/decode required

---

### Method 2: S3 Upload (Optional)

**Upload reports to S3-compatible storage**

**Configuration:**
```yaml
enable_s3_upload: true
s3_bucket: "power-infrastructure-reports"
s3_region: "us-east-1"
s3_path_prefix: "reports/{{ ansible_date_time.date }}"
s3_encryption: true
s3_storage_class: "STANDARD"
```

**Credentials Setup:**

**Option 1: AAP Credentials (Recommended)**
1. Navigate to **Credentials** → **Add**
2. Configure:
   - **Name:** S3 Credentials
   - **Credential Type:** Amazon Web Services
   - **Access Key:** `AKIAIOSFODNN7EXAMPLE`
   - **Secret Key:** `<your_secret_key>`
3. Add to job template credentials

**Option 2: IAM Role (AAP on AWS)**
- No credentials needed
- AAP uses EC2 instance profile
- Ensure IAM role has S3 permissions

**S3 Bucket Policy:**
```json
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Principal": {
      "AWS": "arn:aws:iam::123456789012:user/ansible-automation"
    },
    "Action": [
      "s3:PutObject",
      "s3:PutObjectAcl"
    ],
    "Resource": "arn:aws:s3:::power-infrastructure-reports/*"
  }]
}
```

**Access Reports:**
```bash
# List reports
aws s3 ls s3://power-infrastructure-reports/reports/2026-02-28/

# Download report
aws s3 cp s3://power-infrastructure-reports/reports/2026-02-28/hmc01.example.com/infrastructure_2026-02-28_19-30-00.json .
```

**MinIO Support:**
```yaml
s3_endpoint_url: "https://minio.example.com"
s3_validate_certs: false  # For self-signed certificates
```

---

### Method 3: Git Repository (Optional)

**Commit reports to version-controlled repository**

**Configuration:**
```yaml
enable_git_commit: true
git_repo_url: "git@github.com:org/power-reports.git"
git_branch: "main"
git_author_name: "Ansible Automation"
git_author_email: "ansible@example.com"
```

**Credentials Setup:**

**SSH Key Method (Recommended):**
1. Generate SSH key pair:
   ```bash
   ssh-keygen -t ed25519 -C "ansible@aap" -f ~/.ssh/aap_git_key
   ```
2. Add public key to Git repository (GitHub: Settings → Deploy keys)
3. In AAP:
   - Navigate to **Credentials** → **Add**
   - **Name:** Git Repository Credentials
   - **Credential Type:** Source Control
   - **SSH Private Key:** Paste private key content
4. Add to job template credentials

**HTTPS Token Method:**
```yaml
git_repo_url: "https://{{ git_token }}@github.com/org/power-reports.git"
```

**Repository Structure:**
```
power-reports/
├── reports/
│   ├── 2026-02-28/
│   │   ├── hmc01.example.com/
│   │   │   ├── infrastructure_2026-02-28_19-30-00.json
│   │   │   ├── infrastructure_2026-02-28_19-30-00.csv
│   │   │   ├── infrastructure_2026-02-28_19-30-00.yml
│   │   │   └── infrastructure_2026-02-28_19-30-00.html
│   │   └── hmc02.example.com/
│   └── 2026-02-29/
└── README.md
```

**Access Reports:**
```bash
# Clone repository
git clone git@github.com:org/power-reports.git
cd power-reports

# View history
git log --oneline reports/

# View specific report
cat reports/2026-02-28/hmc01.example.com/infrastructure_2026-02-28_19-30-00.json
```

---

## Configuration

### Complete Configuration Example

```yaml
# inventory/group_vars/hmcs.yml

# Environment Detection
force_aap_mode: false  # Set true to test AAP behavior in CLI

# Local Files (Always recommended)
enable_local_files: true
output_dir: "./output/reports"

# AAP Artifacts (Automatic in AAP)
enable_aap_artifacts: auto  # auto|true|false
aap_artifact_formats:
  - json
  - csv
  - yml
  - html

# S3 Upload (Optional)
enable_s3_upload: false
s3_bucket: "power-infrastructure-reports"
s3_region: "us-east-1"
s3_path_prefix: "reports/{{ ansible_date_time.date }}"
s3_endpoint_url: ""
s3_encryption: true
s3_storage_class: "STANDARD"

# Git Repository (Optional)
enable_git_commit: false
git_repo_url: "git@github.com:org/power-reports.git"
git_branch: "main"
git_local_path: "/tmp/power-reports-git"
git_author_name: "Ansible Automation"
git_author_email: "ansible@example.com"
```

### Survey Variables

Expose configuration via AAP survey:

```yaml
survey_spec:
  - question_name: "Enable S3 Upload"
    variable: "enable_s3_upload"
    type: "multiplechoice"
    choices: ["true", "false"]
    default: "false"
    
  - question_name: "Enable Git Commit"
    variable: "enable_git_commit"
    type: "multiplechoice"
    choices: ["true", "false"]
    default: "false"
    
  - question_name: "Report Formats"
    variable: "aap_artifact_formats"
    type: "multiselect"
    choices: ["json", "csv", "yml", "html"]
    default: "json,csv,html"
```

---

## Credentials Setup

### Credential Types Summary

| Credential Type | Purpose | Required For |
|----------------|---------|--------------|
| Machine | HMC authentication | All playbooks |
| Amazon Web Services | S3 upload | S3 output method |
| Source Control | Git operations | Git output method |

### HMC Credentials

**Create Credential:**
1. **Credentials** → **Add**
2. **Credential Type:** Machine
3. **Username:** `hscroot`
4. **Password:** HMC password
5. **Privilege Escalation:** Not required

**Use in Job Template:**
- Add to **Credentials** field
- Playbook automatically uses credentials

### S3 Credentials

**Create Credential:**
1. **Credentials** → **Add**
2. **Credential Type:** Amazon Web Services
3. **Access Key:** AWS access key ID
4. **Secret Key:** AWS secret access key

**IAM Policy (Minimum Permissions):**
```json
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Action": [
      "s3:PutObject",
      "s3:PutObjectAcl"
    ],
    "Resource": "arn:aws:s3:::power-infrastructure-reports/*"
  }]
}
```

### Git Credentials

**Create Credential:**
1. **Credentials** → **Add**
2. **Credential Type:** Source Control
3. **SSH Private Key:** Paste private key
4. **Passphrase:** If key is encrypted

**GitHub Deploy Key Setup:**
1. Generate key: `ssh-keygen -t ed25519 -f ~/.ssh/deploy_key`
2. GitHub: **Settings** → **Deploy keys** → **Add deploy key**
3. Paste public key content
4. ✓ **Allow write access**

---

## Job Template Creation

### Basic Job Template

```yaml
name: "Collect Power Infrastructure"
job_type: "run"
inventory: "Power Systems HMCs"
project: "IBM Power Infrastructure Collection"
playbook: "collect_infrastructure.yml"
credentials:
  - "HMC Credentials"
extra_vars:
  enable_aap_artifacts: true
  enable_s3_upload: false
  enable_git_commit: false
```

### Advanced Job Template (All Methods)

```yaml
name: "Collect Power Infrastructure (Full)"
job_type: "run"
inventory: "Power Systems HMCs"
project: "IBM Power Infrastructure Collection"
playbook: "collect_infrastructure.yml"
credentials:
  - "HMC Credentials"
  - "S3 Credentials"
  - "Git Repository Credentials"
extra_vars:
  enable_aap_artifacts: true
  enable_s3_upload: true
  enable_git_commit: true
  s3_bucket: "power-infrastructure-reports"
  s3_region: "us-east-1"
  git_repo_url: "git@github.com:org/power-reports.git"
  git_branch: "automated-reports"
```

### Scheduled Job Template

```yaml
name: "Daily Infrastructure Collection"
schedule:
  name: "Daily at 2 AM"
  rrule: "DTSTART:20260301T020000Z RRULE:FREQ=DAILY"
  enabled: true
notification_templates_started:
  - "Slack - Job Started"
notification_templates_success:
  - "Slack - Job Success"
  - "Email - Daily Report"
notification_templates_error:
  - "PagerDuty - Job Failed"
```

---

## Accessing Reports

### Via AAP API

**Get Job Artifacts:**
```bash
#!/bin/bash
# get_artifacts.sh

AAP_URL="https://aap.example.com"
AAP_USER="admin"
AAP_PASS="password"
JOB_ID=$1

# Get artifacts
curl -k -u ${AAP_USER}:${AAP_PASS} \
  ${AAP_URL}/api/v2/jobs/${JOB_ID}/artifacts/ \
  -o artifacts.json

# Extract reports
for format in json csv yml html; do
  jq -r ".infrastructure_report_${format}" artifacts.json \
    | base64 -d > report.${format}
  echo "✓ Extracted report.${format}"
done

# Extract metadata
jq '.infrastructure_report_metadata' artifacts.json > metadata.json
echo "✓ Extracted metadata.json"
```

**List Recent Jobs:**
```bash
curl -k -u admin:password \
  "https://aap.example.com/api/v2/jobs/?name__icontains=infrastructure&page_size=10" \
  | jq -r '.results[] | "\(.id)\t\(.status)\t\(.finished)"'
```

### Via S3

**AWS CLI:**
```bash
# List reports
aws s3 ls s3://power-infrastructure-reports/reports/ --recursive

# Download specific report
aws s3 cp s3://power-infrastructure-reports/reports/2026-02-28/hmc01.example.com/infrastructure_2026-02-28_19-30-00.json .

# Sync all reports
aws s3 sync s3://power-infrastructure-reports/reports/ ./local-reports/
```

**Python Script:**
```python
import boto3
import json

s3 = boto3.client('s3')
bucket = 'power-infrastructure-reports'
key = 'reports/2026-02-28/hmc01.example.com/infrastructure_2026-02-28_19-30-00.json'

# Download report
obj = s3.get_object(Bucket=bucket, Key=key)
report = json.loads(obj['Body'].read())

print(f"Systems: {len(report['managed_systems'])}")
print(f"LPARs: {len(report['lpars'])}")
```

### Via Git

**Clone and View:**
```bash
# Clone repository
git clone git@github.com:org/power-reports.git
cd power-reports

# View latest reports
ls -lh reports/$(date +%Y-%m-%d)/

# View report
cat reports/$(date +%Y-%m-%d)/hmc01.example.com/infrastructure_*.json | jq .

# View history
git log --oneline --graph reports/
```

---

## Troubleshooting

### Common Issues

#### 1. Artifacts Not Appearing

**Symptoms:**
- Job completes successfully
- No artifacts in AAP UI or API

**Solutions:**
```yaml
# Check configuration
enable_aap_artifacts: auto  # Should be 'auto' or 'true'

# Force AAP mode for testing
force_aap_mode: true

# Check artifact size
# Artifacts > 1MB may fail silently
# Solution: Enable compression or use S3/Git
```

#### 2. S3 Upload Fails

**Symptoms:**
- Error: "Unable to locate credentials"
- Error: "Access Denied"

**Solutions:**
```bash
# Verify credentials in AAP
# Credentials → S3 Credentials → Test

# Check IAM permissions
aws sts get-caller-identity
aws s3 ls s3://power-infrastructure-reports/

# Verify bucket exists
aws s3 mb s3://power-infrastructure-reports

# Check endpoint URL for MinIO
s3_endpoint_url: "https://minio.example.com"
```

#### 3. Git Commit Fails

**Symptoms:**
- Error: "Permission denied (publickey)"
- Error: "Could not resolve host"

**Solutions:**
```bash
# Test SSH key
ssh -T git@github.com

# Verify deploy key in GitHub
# Settings → Deploy keys → Check "Allow write access"

# Check Git URL format
git_repo_url: "git@github.com:org/power-reports.git"  # SSH
# OR
git_repo_url: "https://token@github.com/org/power-reports.git"  # HTTPS
```

#### 4. Environment Not Detected

**Symptoms:**
- Running in AAP but detected as CLI
- AAP artifacts not enabled

**Solutions:**
```yaml
# Force AAP mode
force_aap_mode: true

# Check detection markers
# Job output should show:
# "Environment: AAP (Ansible Automation Platform)"
```

### Debug Mode

**Enable verbose output:**
```yaml
# In job template extra vars
ansible_verbosity: 2

# Or via CLI
ansible-playbook collect_infrastructure.yml -vv
```

**Check environment detection:**
```yaml
# Add to playbook for debugging
- name: Debug environment
  ansible.builtin.debug:
    var: is_aap_environment
```

---

## Best Practices

### 1. Output Method Selection

**Use AAP Artifacts when:**
- Reports are small (<1MB)
- Immediate access needed
- Short retention acceptable

**Use S3 when:**
- Reports are large
- Long-term storage needed
- Integration with data lakes

**Use Git when:**
- Audit trail required
- Version history important
- GitOps workflows

**Use Multiple Methods:**
```yaml
# Recommended for production
enable_aap_artifacts: true  # Immediate access
enable_s3_upload: true      # Long-term storage
enable_git_commit: false    # Optional audit trail
```

### 2. Credential Management

- ✅ Use AAP credential system (never hardcode)
- ✅ Rotate credentials regularly
- ✅ Use least-privilege IAM policies
- ✅ Enable MFA for AWS accounts
- ✅ Use deploy keys (not personal keys) for Git

### 3. Scheduling

**Daily Collection:**
```yaml
schedule:
  rrule: "DTSTART:20260301T020000Z RRULE:FREQ=DAILY"
```

**Weekly Collection:**
```yaml
schedule:
  rrule: "DTSTART:20260301T020000Z RRULE:FREQ=WEEKLY;BYDAY=SU"
```

**Monthly Collection:**
```yaml
schedule:
  rrule: "DTSTART:20260301T020000Z RRULE:FREQ=MONTHLY;BYMONTHDAY=1"
```

### 4. Notifications

**Configure notifications for:**
- Job failures (PagerDuty, email)
- Job success (Slack, email)
- Long-running jobs (>30 minutes)

### 5. Retention Policies

**S3 Lifecycle Policy:**
```json
{
  "Rules": [{
    "Id": "Archive old reports",
    "Status": "Enabled",
    "Transitions": [{
      "Days": 90,
      "StorageClass": "GLACIER"
    }],
    "Expiration": {
      "Days": 365
    }
  }]
}
```

**Git Retention Script:**
```bash
#!/bin/bash
# cleanup_old_reports.sh
# Run monthly to remove reports older than 90 days

cd /path/to/power-reports
find reports/ -type f -mtime +90 -delete
find reports/ -type d -empty -delete
git add reports/
git commit -m "Cleanup: Removed reports older than 90 days"
git push origin main
```

### 6. Monitoring

**Key Metrics to Monitor:**
- Job success rate
- Job duration
- Artifact size
- S3 upload success rate
- Git commit success rate

**Example Prometheus Metrics:**
```yaml
# Expose via AAP metrics endpoint
- job_success_rate{template="collect_infrastructure"}
- job_duration_seconds{template="collect_infrastructure"}
- artifact_size_bytes{template="collect_infrastructure"}
```

---

## Additional Resources

- **Planning Document:** [docs/PLAN_AAP_COMPATIBILITY.md](PLAN_AAP_COMPATIBILITY.md)
- **Main README:** [README.md](../README.md)
- **Job Templates:** [docs/aap_job_templates/](aap_job_templates/)
- **AAP Documentation:** https://docs.ansible.com/automation-controller/

---

## Support

For issues or questions:
1. Check [Troubleshooting](#troubleshooting) section
2. Review job output logs in AAP
3. Enable debug mode (`ansible_verbosity: 2`)
4. Check planning document for implementation details

---

**Version:** 1.1.0.0  
**Last Updated:** 2026-02-28  
**License:** MIT