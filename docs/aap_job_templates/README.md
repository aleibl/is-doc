# AAP Job Template Examples

This directory contains example job templates for deploying the IBM Power Infrastructure Collection on Ansible Automation Platform.

## Available Templates

### 1. Basic Job Template
**File:** `basic_job_template.yml`

Simple configuration with AAP artifacts only. Best for:
- Getting started
- Testing
- Small deployments
- Immediate access to reports

**Features:**
- AAP artifacts enabled
- All report formats (JSON, CSV, YAML, HTML)
- No external dependencies

### 2. Advanced Job Template
**File:** `advanced_job_template.yml`

Full-featured configuration with all output methods. Best for:
- Production deployments
- Long-term storage requirements
- Audit trail needs
- Integration with external systems

**Features:**
- AAP artifacts (immediate access)
- S3 upload (long-term storage)
- Git commit (version control)
- Survey for runtime configuration

**Prerequisites:**
- S3 bucket created
- Git repository created
- S3 credentials in AAP
- Git credentials in AAP

### 3. Scheduled Job Template
**File:** `scheduled_job_template.yml`

Optimized for scheduled execution. Best for:
- Daily/weekly/monthly collection
- Automated reporting
- Monitoring and alerting
- Unattended operation

**Features:**
- Scheduled execution (daily at 2 AM)
- Notifications (Slack, Email, PagerDuty)
- S3 upload for persistence
- Optimized report formats
- Higher concurrency

## How to Use

### Method 1: Import via AAP UI

1. Navigate to **Templates** → **Add** → **Add job template**
2. Copy configuration from YAML file
3. Paste into AAP UI fields
4. Adjust as needed for your environment
5. Save template

### Method 2: Import via AAP API

```bash
# Set variables
AAP_URL="https://aap.example.com"
AAP_USER="admin"
AAP_PASS="password"
TEMPLATE_FILE="basic_job_template.yml"

# Import template
curl -X POST ${AAP_URL}/api/v2/job_templates/ \
  -H "Content-Type: application/json" \
  -u ${AAP_USER}:${AAP_PASS} \
  -d @${TEMPLATE_FILE}
```

### Method 3: Use as Reference

Copy and modify the YAML files to create custom templates that fit your specific requirements.

## Configuration Guide

### Required Fields

All templates require:
- **name**: Unique template name
- **inventory**: Target inventory
- **project**: AAP project containing playbooks
- **playbook**: Playbook filename
- **credentials**: At least HMC credentials

### Optional Fields

Customize based on needs:
- **extra_vars**: Runtime variables
- **survey_spec**: Interactive prompts
- **notification_templates**: Alerts
- **schedule**: Automated execution
- **timeout**: Job timeout (seconds)
- **forks**: Parallel execution
- **verbosity**: Debug level (0-4)

## Customization Examples

### Enable Only S3 Upload

```yaml
extra_vars:
  enable_aap_artifacts: false
  enable_s3_upload: true
  enable_git_commit: false
  s3_bucket: "my-bucket"
  s3_region: "us-west-2"
```

### Use MinIO Instead of AWS S3

```yaml
extra_vars:
  enable_s3_upload: true
  s3_bucket: "power-reports"
  s3_region: "us-east-1"
  s3_endpoint_url: "https://minio.example.com"
  s3_validate_certs: false
```

### Generate Only JSON Reports

```yaml
extra_vars:
  generate_json: true
  generate_csv: false
  generate_yaml: false
  generate_html: false
```

### Add Survey for Runtime Configuration

```yaml
survey_enabled: true
survey_spec:
  name: "Collection Options"
  description: "Configure collection behavior"
  spec:
    - question_name: "Target HMC"
      variable: "limit"
      type: "text"
      default: "all"
      required: false
    
    - question_name: "Enable S3 Upload"
      variable: "enable_s3_upload"
      type: "multiplechoice"
      choices: ["true", "false"]
      default: "false"
      required: true
```

## Notification Configuration

### Slack Notification

Create notification template in AAP:

```yaml
name: "Slack - Job Success"
notification_type: "slack"
notification_configuration:
  token: "xoxb-your-slack-token"
  channels:
    - "#power-infrastructure"
  username: "Ansible AAP"
  icon_url: "https://example.com/ansible-icon.png"
```

### Email Notification

```yaml
name: "Email - Job Failure"
notification_type: "email"
notification_configuration:
  host: "smtp.example.com"
  port: 587
  use_tls: true
  username: "ansible@example.com"
  password: "{{ vault_smtp_password }}"
  sender: "ansible@example.com"
  recipients:
    - "ops-team@example.com"
  subject: "Power Infrastructure Collection Failed"
```

### PagerDuty Notification

```yaml
name: "PagerDuty - Job Failed"
notification_type: "pagerduty"
notification_configuration:
  token: "your-pagerduty-token"
  service_key: "your-service-key"
  client_name: "Ansible AAP"
```

## Schedule Configuration

### Daily at 2 AM UTC

```
DTSTART:20260301T020000Z RRULE:FREQ=DAILY
```

### Weekly on Sunday at 2 AM UTC

```
DTSTART:20260301T020000Z RRULE:FREQ=WEEKLY;BYDAY=SU
```

### Monthly on 1st Day at 2 AM UTC

```
DTSTART:20260301T020000Z RRULE:FREQ=MONTHLY;BYMONTHDAY=1
```

### Every 6 Hours

```
DTSTART:20260301T000000Z RRULE:FREQ=HOURLY;INTERVAL=6
```

### Business Hours Only (Mon-Fri, 9 AM - 5 PM)

```
DTSTART:20260301T090000Z RRULE:FREQ=HOURLY;BYDAY=MO,TU,WE,TH,FR;BYHOUR=9,10,11,12,13,14,15,16
```

## Best Practices

### 1. Template Naming

Use descriptive names:
- ✅ `Collect Power Infrastructure - Production`
- ✅ `Collect Power Infrastructure - Daily Scheduled`
- ❌ `Power Collection`
- ❌ `Template 1`

### 2. Credential Management

- Use AAP credential system (never hardcode)
- Create separate credentials for dev/prod
- Rotate credentials regularly
- Use least-privilege access

### 3. Output Method Selection

**For scheduled jobs:**
- Enable S3 upload (long-term storage)
- Disable Git commit (avoid repo bloat)
- Use INTELLIGENT_TIERING storage class

**For on-demand jobs:**
- Enable AAP artifacts (immediate access)
- Enable S3 if needed
- Enable Git for audit trail

### 4. Performance Tuning

**For large environments (>10 HMCs):**
```yaml
forks: 20
timeout: 7200  # 2 hours
job_slice_count: 5
```

**For small environments (<5 HMCs):**
```yaml
forks: 5
timeout: 1800  # 30 minutes
job_slice_count: 1
```

### 5. Error Handling

Always configure notifications:
- **Started**: Slack/Email (optional)
- **Success**: Slack/Email (recommended)
- **Error**: PagerDuty/Email (required)

### 6. Testing

Before production:
1. Test with `ask_limit_on_launch: true`
2. Run against single HMC first
3. Verify all output methods work
4. Check artifact sizes
5. Validate S3 uploads
6. Confirm Git commits

## Troubleshooting

### Template Import Fails

**Error:** "Invalid JSON"
- Ensure YAML is valid
- Check indentation
- Verify all required fields present

### Job Fails Immediately

**Error:** "Credential not found"
- Verify credentials exist in AAP
- Check credential names match template
- Ensure credentials have correct type

### Artifacts Not Created

**Error:** "No artifacts found"
- Check `enable_aap_artifacts: true`
- Verify artifact size < 1MB
- Check job output for errors

### S3 Upload Fails

**Error:** "Access Denied"
- Verify S3 credentials in AAP
- Check IAM permissions
- Confirm bucket exists
- Validate bucket policy

## Additional Resources

- **AAP Documentation:** [docs/README_AAP.md](../README_AAP.md)
- **Planning Document:** [docs/PLAN_AAP_COMPATIBILITY.md](../PLAN_AAP_COMPATIBILITY.md)
- **Main README:** [README.md](../../README.md)

## Support

For issues or questions:
1. Check job output logs
2. Enable verbosity: `verbosity: 2`
3. Review troubleshooting section
4. Check AAP system logs

---

**Last Updated:** 2026-02-28  
**Version:** 1.1.0.0