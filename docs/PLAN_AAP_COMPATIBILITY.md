# AAP Compatibility Implementation Plan

**Version:** 1.1.0.0  
**Date:** 2026-02-28  
**Status:** Planning Phase  
**Target:** Make IBM Power Infrastructure Collection playbooks compatible with Ansible Automation Platform

---

## Table of Contents

1. [Executive Summary](#executive-summary)
2. [Problem Statement](#problem-statement)
3. [Solution Architecture](#solution-architecture)
4. [Environment Detection](#environment-detection)
5. [Output Methods](#output-methods)
6. [Configuration Structure](#configuration-structure)
7. [Implementation Details](#implementation-details)
8. [Credential Management](#credential-management)
9. [Error Handling](#error-handling)
10. [Testing Strategy](#testing-strategy)
11. [Migration Path](#migration-path)
12. [Performance Considerations](#performance-considerations)
13. [Implementation Checklist](#implementation-checklist)

---

## Executive Summary

### Objective
Enable the IBM Power Infrastructure Collection playbooks to run seamlessly on both:
- **Ansible CLI** (traditional ansible-playbook command)
- **Ansible Automation Platform** (AAP 2.x execution environments)

### Key Requirements
1. **Backward Compatibility**: Existing CLI usage must work unchanged
2. **Flexible Output**: Support multiple persistence methods
3. **Zero Configuration**: Automatic environment detection
4. **Enterprise Ready**: Support S3, Git, and AAP artifacts
5. **Secure**: Proper credential management for all methods

### Success Criteria
- ✅ Playbooks run unchanged on CLI
- ✅ Playbooks detect and adapt to AAP environment
- ✅ Reports persist beyond job execution in AAP
- ✅ Multiple output methods work independently or together
- ✅ No breaking changes to existing functionality

---

## Problem Statement

### Current State
The playbooks write reports to local filesystem using `ansible.builtin.template`:
```yaml
- name: Generate JSON report
  ansible.builtin.template:
    src: templates/infrastructure.json.j2
    dest: "{{ output_dir }}/infrastructure_{{ report_timestamp }}.json"
```

**Works on CLI**: Files persist on control node  
**Fails on AAP**: Files written to ephemeral container, lost after job completion

### AAP Execution Environment Characteristics
1. **Isolated Containers**: Each job runs in a fresh container
2. **Ephemeral Filesystem**: All files discarded after execution
3. **No Direct Access**: Cannot browse or download files from container
4. **Artifact System**: Special mechanism to persist data via `set_stats`
5. **API Access**: Artifacts retrievable via AAP REST API

### Business Impact
Without AAP compatibility:
- Reports are lost after job execution
- No audit trail or historical data
- Cannot integrate with downstream systems
- Manual workarounds required (external scripts, custom modules)

---

## Solution Architecture

### High-Level Design

```
┌─────────────────────────────────────────────────────────────┐
│                    Playbook Execution                        │
└─────────────────────┬───────────────────────────────────────┘
                      │
                      ▼
         ┌────────────────────────┐
         │  Environment Detection  │
         │  (CLI vs AAP)          │
         └────────┬───────────────┘
                  │
        ┌─────────┴─────────┐
        │                   │
        ▼                   ▼
   ┌────────┐         ┌──────────┐
   │  CLI   │         │   AAP    │
   └───┬────┘         └────┬─────┘
       │                   │
       ▼                   ▼
┌──────────────┐    ┌─────────────────┐
│ Local Files  │    │ Multiple Options │
│ (unchanged)  │    │  - AAP Artifacts │
└──────────────┘    │  - S3 Upload     │
                    │  - Git Commit    │
                    └─────────────────┘
```

### Output Method Matrix

| Method | CLI | AAP | Size Limit | Persistence | Access Method |
|--------|-----|-----|------------|-------------|---------------|
| Local Files | ✅ Default | ✅ Optional | Disk space | Until deleted | Direct filesystem |
| AAP Artifacts | ❌ N/A | ✅ Default | ~1MB/artifact | Job retention | AAP API/UI |
| S3 Upload | ✅ Optional | ✅ Optional | 5TB/object | Indefinite | S3 API/CLI |
| Git Commit | ✅ Optional | ✅ Optional | Repo limits | Indefinite | Git operations |

### Design Principles

1. **Fail-Safe Defaults**: Always write local files, add other methods as enhancements
2. **Independent Methods**: Each output method works independently
3. **Graceful Degradation**: If one method fails, others continue
4. **Configuration Over Convention**: Explicit configuration, sensible defaults
5. **Idempotent Operations**: Safe to re-run without side effects

---

## Environment Detection

### Detection Logic

```yaml
# tasks/detect_environment.yml
---
- name: Check for AAP execution environment
  ansible.builtin.stat:
    path: /runner
  register: runner_dir
  
- name: Set AAP environment fact
  ansible.builtin.set_fact:
    is_aap_environment: "{{ runner_dir.stat.exists | default(false) }}"
    
- name: Display environment information
  ansible.builtin.debug:
    msg: "Running in {{ 'AAP' if is_aap_environment else 'CLI' }} environment"
```

### Detection Markers

| Indicator | CLI | AAP |
|-----------|-----|-----|
| `/runner` directory | ❌ Absent | ✅ Present |
| `ANSIBLE_RUNNER_DIR` env var | ❌ Unset | ✅ Set |
| `AWX_*` environment variables | ❌ Unset | ✅ Set |
| Execution environment | Local system | Container |

### Manual Override

Allow users to force environment type:
```yaml
# inventory/group_vars/hmcs.yml
force_aap_mode: false  # Override detection
```

---

## Output Methods

### Method 1: Local Files (Default)

**Purpose**: Write reports to local filesystem  
**Use Case**: CLI execution, debugging, local development  
**Always Enabled**: Yes (backward compatibility)

**Implementation**:
```yaml
- name: Generate JSON report
  ansible.builtin.template:
    src: templates/infrastructure.json.j2
    dest: "{{ output_dir }}/infrastructure_{{ report_timestamp }}.json"
  when: enable_local_files | default(true)
```

**Configuration**:
```yaml
enable_local_files: true
output_dir: "./output/reports"
```

**Pros**:
- Simple, no dependencies
- Fast, no network operations
- Easy to debug

**Cons**:
- Lost in AAP containers
- No centralized storage
- Manual cleanup required

---

### Method 2: AAP Artifacts

**Purpose**: Register reports as AAP job artifacts  
**Use Case**: AAP execution, immediate access via API  
**Auto-Enabled**: When AAP detected

**Implementation**:
```yaml
- name: Register JSON report as artifact
  ansible.builtin.set_stats:
    data:
      infrastructure_report_json: "{{ lookup('file', json_report_path) | b64encode }}"
      infrastructure_report_metadata:
        timestamp: "{{ collection_timestamp }}"
        hmc_count: "{{ groups['hmcs'] | length }}"
        system_count: "{{ all_systems | length }}"
        lpar_count: "{{ all_lpars | length }}"
        version: "{{ project_version }}"
    per_host: false
  when: enable_aap_artifacts | default(is_aap_environment)
```

**Configuration**:
```yaml
enable_aap_artifacts: auto  # auto|true|false
aap_artifact_formats:
  - json
  - csv
  - yaml
  - html
```

**Artifact Structure**:
```json
{
  "data": {
    "infrastructure_report_json": "<base64_encoded_content>",
    "infrastructure_report_csv": "<base64_encoded_content>",
    "infrastructure_report_yaml": "<base64_encoded_content>",
    "infrastructure_report_html": "<base64_encoded_content>",
    "infrastructure_report_metadata": {
      "timestamp": "2026-02-28T19:30:00Z",
      "hmc_count": 2,
      "system_count": 5,
      "lpar_count": 20,
      "version": "1.1.0.0",
      "collection_duration_seconds": 45
    }
  }
}
```

**Retrieval via API**:
```bash
# Get job artifacts
curl -k -u admin:password \
  https://aap.example.com/api/v2/jobs/123/artifacts/

# Download specific artifact
curl -k -u admin:password \
  https://aap.example.com/api/v2/jobs/123/artifacts/ \
  | jq -r '.infrastructure_report_json' \
  | base64 -d > report.json
```

**Pros**:
- Native AAP integration
- Accessible via API/UI
- No external dependencies

**Cons**:
- Size limit (~1MB per artifact)
- Retention tied to job retention
- Base64 encoding overhead

**Size Optimization**:
- Compress before encoding: `gzip | b64encode`
- Store only essential formats
- Use external storage for large reports

---

### Method 3: S3 Upload

**Purpose**: Upload reports to S3-compatible storage  
**Use Case**: Long-term storage, data lakes, large reports  
**Auto-Enabled**: No (requires configuration)

**Implementation**:
```yaml
- name: Upload JSON report to S3
  amazon.aws.s3_object:
    bucket: "{{ s3_bucket }}"
    object: "{{ s3_path_prefix }}/{{ inventory_hostname }}/infrastructure_{{ report_timestamp }}.json"
    src: "{{ output_dir }}/infrastructure_{{ report_timestamp }}.json"
    mode: put
    encrypt: "{{ s3_encryption | default(true) }}"
    metadata:
      collection_timestamp: "{{ collection_timestamp }}"
      hmc_name: "{{ inventory_hostname }}"
      version: "{{ project_version }}"
  when: enable_s3_upload | default(false)
  environment:
    AWS_ACCESS_KEY_ID: "{{ s3_access_key }}"
    AWS_SECRET_ACCESS_KEY: "{{ s3_secret_key }}"
    AWS_DEFAULT_REGION: "{{ s3_region }}"
```

**Configuration**:
```yaml
enable_s3_upload: false
s3_bucket: "power-infrastructure-reports"
s3_region: "us-east-1"
s3_path_prefix: "reports/{{ ansible_date_time.date }}"
s3_endpoint_url: ""  # For MinIO: "https://minio.example.com"
s3_encryption: true
s3_storage_class: "STANDARD"  # STANDARD|INTELLIGENT_TIERING|GLACIER
```

**Path Structure**:
```
s3://power-infrastructure-reports/
├── reports/
│   ├── 2026-02-28/
│   │   ├── hmc01.example.com/
│   │   │   ├── infrastructure_2026-02-28_19-30-00.json
│   │   │   ├── infrastructure_2026-02-28_19-30-00.csv
│   │   │   ├── infrastructure_2026-02-28_19-30-00.yml
│   │   │   └── infrastructure_2026-02-28_19-30-00.html
│   │   └── hmc02.example.com/
│   │       └── ...
│   └── 2026-02-29/
│       └── ...
```

**Credential Management**:
```yaml
# Option 1: AAP Credentials (Recommended)
# Configure in AAP: Credentials → Add → Amazon Web Services

# Option 2: Vault Variables
# vars/vault.yml
s3_credentials:
  access_key: "AKIAIOSFODNN7EXAMPLE"
  secret_key: "wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY"

# Option 3: IAM Role (AAP on AWS)
# No credentials needed, use instance profile
```

**Pros**:
- Unlimited storage
- Highly durable (99.999999999%)
- Lifecycle policies
- Integration with analytics tools

**Cons**:
- Requires AWS/S3 setup
- Network dependency
- Cost considerations

**MinIO Support**:
```yaml
# For on-premises S3-compatible storage
s3_endpoint_url: "https://minio.example.com"
s3_validate_certs: false  # For self-signed certs
```

---

### Method 4: Git Repository

**Purpose**: Commit reports to version-controlled repository  
**Use Case**: Audit trail, GitOps workflows, change tracking  
**Auto-Enabled**: No (requires configuration)

**Implementation**:
```yaml
- name: Clone/update Git repository
  ansible.builtin.git:
    repo: "{{ git_repo_url }}"
    dest: "{{ git_local_path }}"
    version: "{{ git_branch }}"
    force: true
  when: enable_git_commit | default(false)

- name: Copy reports to Git repository
  ansible.builtin.copy:
    src: "{{ output_dir }}/infrastructure_{{ report_timestamp }}.{{ item }}"
    dest: "{{ git_local_path }}/reports/{{ ansible_date_time.date }}/{{ inventory_hostname }}/"
  loop:
    - json
    - csv
    - yml
    - html
  when: enable_git_commit | default(false)

- name: Commit and push reports
  ansible.builtin.shell: |
    cd {{ git_local_path }}
    git config user.name "{{ git_author_name }}"
    git config user.email "{{ git_author_email }}"
    git add reports/
    git commit -m "{{ git_commit_message }}" || true
    git push origin {{ git_branch }}
  when: enable_git_commit | default(false)
  environment:
    GIT_SSH_COMMAND: "ssh -i {{ git_ssh_key_path }} -o StrictHostKeyChecking=no"
```

**Configuration**:
```yaml
enable_git_commit: false
git_repo_url: "git@github.com:org/power-reports.git"
git_branch: "main"
git_local_path: "/tmp/power-reports-git"
git_author_name: "Ansible Automation"
git_author_email: "ansible@example.com"
git_commit_message: "Infrastructure report {{ report_timestamp }} from {{ inventory_hostname }}"
git_ssh_key_path: "{{ lookup('env', 'HOME') }}/.ssh/id_rsa"
```

**Repository Structure**:
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
│   │       └── ...
│   └── 2026-02-29/
│       └── ...
├── .gitignore
└── README.md
```

**Credential Management**:
```yaml
# Option 1: SSH Key (Recommended)
# AAP: Credentials → Add → Source Control
# Specify private key, AAP manages it

# Option 2: HTTPS with Token
git_repo_url: "https://{{ git_token }}@github.com/org/power-reports.git"

# Option 3: Deploy Key
# GitHub: Settings → Deploy keys → Add deploy key
```

**Pros**:
- Full version history
- Audit trail with commits
- GitOps integration
- Diff capabilities

**Cons**:
- Repository size growth
- Git operations overhead
- Merge conflict potential

**Best Practices**:
- Use separate branch for automated commits
- Implement retention policy (delete old reports)
- Use Git LFS for large files
- Squash commits periodically

---

## Configuration Structure

### Variable Hierarchy

```
1. Playbook defaults (lowest priority)
   ↓
2. inventory/group_vars/all.yml
   ↓
3. inventory/group_vars/hmcs.yml
   ↓
4. inventory/host_vars/hmc01.example.com.yml
   ↓
5. Extra vars (-e flag or AAP survey)
   ↓
6. Runtime detection (highest priority)
```

### Complete Configuration Example

```yaml
# inventory/group_vars/hmcs.yml
---
# ============================================================================
# Output Configuration
# ============================================================================

# Environment Detection
force_aap_mode: false  # Set to true to force AAP behavior in CLI

# Local Files (Always recommended)
enable_local_files: true
output_dir: "./output/reports"

# AAP Artifacts
enable_aap_artifacts: auto  # auto|true|false (auto = detect environment)
aap_artifact_formats:
  - json    # Always include for programmatic access
  - csv     # Include for spreadsheet import
  - yaml    # Include for Ansible consumption
  - html    # Include for human viewing
aap_artifact_compression: true  # Compress before base64 encoding

# S3 Upload
enable_s3_upload: false
s3_bucket: "power-infrastructure-reports"
s3_region: "us-east-1"
s3_path_prefix: "reports/{{ ansible_date_time.date }}"
s3_endpoint_url: ""  # Leave empty for AWS S3
s3_encryption: true
s3_storage_class: "STANDARD"
s3_acl: "private"

# Git Repository
enable_git_commit: false
git_repo_url: "git@github.com:org/power-reports.git"
git_branch: "automated-reports"
git_local_path: "/tmp/power-reports-git"
git_author_name: "Ansible Automation"
git_author_email: "ansible@example.com"
git_commit_message: "Report {{ report_timestamp }} from {{ inventory_hostname }}"

# Report Generation
generate_json: true
generate_csv: true
generate_yaml: true
generate_html: true

# Collection Settings
collect_managed_systems: true
collect_lpars: true
collect_adapters: true
```

### AAP Survey Variables

For AAP job templates, expose key variables as survey questions:

```yaml
# AAP Job Template Survey
survey_spec:
  - question_name: "Enable S3 Upload"
    variable: "enable_s3_upload"
    type: "multiplechoice"
    choices:
      - "true"
      - "false"
    default: "false"
    
  - question_name: "Enable Git Commit"
    variable: "enable_git_commit"
    type: "multiplechoice"
    choices:
      - "true"
      - "false"
    default: "false"
    
  - question_name: "Report Formats"
    variable: "report_formats"
    type: "multiselect"
    choices:
      - "json"
      - "csv"
      - "yaml"
      - "html"
    default: "json,csv,html"
```

---

## Implementation Details

### File Structure Changes

```
.
├── tasks/                          # NEW DIRECTORY
│   ├── detect_environment.yml      # Environment detection
│   ├── persist_reports.yml         # Output handling orchestration
│   ├── persist_local.yml           # Local file operations
│   ├── persist_aap_artifacts.yml   # AAP artifact registration
│   ├── persist_s3.yml              # S3 upload operations
│   └── persist_git.yml             # Git commit/push operations
│
├── inventory/
│   └── group_vars/
│       └── hmcs.yml                # UPDATED: Add output config
│
├── docs/                           # NEW DIRECTORY
│   ├── PLAN_AAP_COMPATIBILITY.md   # This document
│   ├── README_AAP.md               # AAP user guide
│   └── aap_job_templates/          # Example configurations
│       ├── job_template.yml
│       ├── workflow_template.yml
│       └── survey_spec.yml
│
├── collect_infrastructure.yml      # UPDATED: Include new tasks
├── collect_infrastructure_hmc_cli.yml  # UPDATED: Include new tasks
├── test_report_generation.yml      # UPDATED: Include new tasks
└── requirements.yml                # UPDATED: Add amazon.aws
```

### Task File: detect_environment.yml

```yaml
---
# tasks/detect_environment.yml
# Detect execution environment (CLI vs AAP)

- name: Check for AAP execution environment markers
  ansible.builtin.stat:
    path: "{{ item }}"
  register: aap_markers
  loop:
    - /runner
    - /runner/project
    - /runner/inventory
  
- name: Check for AAP environment variables
  ansible.builtin.set_fact:
    has_aap_env_vars: "{{ lookup('env', 'ANSIBLE_RUNNER_DIR') != '' }}"

- name: Determine execution environment
  ansible.builtin.set_fact:
    is_aap_environment: >-
      {{
        force_aap_mode | default(false) or
        (aap_markers.results | selectattr('stat.exists') | list | length > 0) or
        has_aap_env_vars
      }}

- name: Display environment information
  ansible.builtin.debug:
    msg:
      - "Execution Environment: {{ 'AAP' if is_aap_environment else 'CLI' }}"
      - "Force AAP Mode: {{ force_aap_mode | default(false) }}"
      - "AAP Markers Found: {{ aap_markers.results | selectattr('stat.exists') | list | length }}"
      - "AAP Env Vars: {{ has_aap_env_vars }}"
```

### Task File: persist_reports.yml

```yaml
---
# tasks/persist_reports.yml
# Orchestrate report persistence across all enabled methods

- name: Display persistence configuration
  ansible.builtin.debug:
    msg:
      - "Local Files: {{ enable_local_files | default(true) }}"
      - "AAP Artifacts: {{ enable_aap_artifacts | default(is_aap_environment) }}"
      - "S3 Upload: {{ enable_s3_upload | default(false) }}"
      - "Git Commit: {{ enable_git_commit | default(false) }}"

# Method 1: Local Files
- name: Persist reports to local filesystem
  ansible.builtin.include_tasks: persist_local.yml
  when: enable_local_files | default(true)

# Method 2: AAP Artifacts
- name: Register reports as AAP artifacts
  ansible.builtin.include_tasks: persist_aap_artifacts.yml
  when: enable_aap_artifacts | default(is_aap_environment)

# Method 3: S3 Upload
- name: Upload reports to S3
  ansible.builtin.include_tasks: persist_s3.yml
  when: enable_s3_upload | default(false)

# Method 4: Git Commit
- name: Commit reports to Git repository
  ansible.builtin.include_tasks: persist_git.yml
  when: enable_git_commit | default(false)

- name: Display persistence summary
  ansible.builtin.debug:
    msg:
      - "Reports persisted successfully"
      - "Methods used: {{ persistence_methods | join(', ') }}"
  vars:
    persistence_methods: >-
      {{
        (['Local Files'] if (enable_local_files | default(true)) else []) +
        (['AAP Artifacts'] if (enable_aap_artifacts | default(is_aap_environment)) else []) +
        (['S3'] if (enable_s3_upload | default(false)) else []) +
        (['Git'] if (enable_git_commit | default(false)) else [])
      }}
```

### Task File: persist_aap_artifacts.yml

```yaml
---
# tasks/persist_aap_artifacts.yml
# Register reports as AAP job artifacts

- name: Read generated report files
  ansible.builtin.slurp:
    src: "{{ output_dir }}/infrastructure_{{ report_timestamp }}.{{ item }}"
  register: report_contents
  loop: "{{ aap_artifact_formats | default(['json', 'csv', 'yaml', 'html']) }}"
  when: item in ['json', 'csv', 'yaml', 'html']

- name: Prepare artifact data
  ansible.builtin.set_fact:
    artifact_data: >-
      {{
        artifact_data | default({}) | combine({
          'infrastructure_report_' + item.item: item.content
        })
      }}
  loop: "{{ report_contents.results }}"
  when: not item.skipped | default(false)

- name: Add metadata to artifacts
  ansible.builtin.set_fact:
    artifact_data: >-
      {{
        artifact_data | combine({
          'infrastructure_report_metadata': {
            'timestamp': collection_timestamp,
            'hmc_count': groups['hmcs'] | length,
            'system_count': all_systems | default([]) | length,
            'lpar_count': all_lpars | default([]) | length,
            'adapter_count': all_adapters | default([]) | length,
            'version': project_version,
            'formats': aap_artifact_formats | default(['json', 'csv', 'yaml', 'html'])
          }
        })
      }}

- name: Register artifacts with AAP
  ansible.builtin.set_stats:
    data: "{{ artifact_data }}"
    per_host: false
    aggregate: false

- name: Display artifact registration summary
  ansible.builtin.debug:
    msg:
      - "AAP artifacts registered successfully"
      - "Formats: {{ aap_artifact_formats | default(['json', 'csv', 'yaml', 'html']) | join(', ') }}"
      - "Total size: {{ artifact_data | to_json | length }} bytes"
```

### Task File: persist_s3.yml

```yaml
---
# tasks/persist_s3.yml
# Upload reports to S3-compatible storage

- name: Validate S3 configuration
  ansible.builtin.assert:
    that:
      - s3_bucket is defined
      - s3_bucket | length > 0
      - s3_region is defined
    fail_msg: "S3 configuration incomplete. Required: s3_bucket, s3_region"

- name: Set S3 credentials from vault
  ansible.builtin.set_fact:
    s3_access_key: "{{ s3_credentials.access_key }}"
    s3_secret_key: "{{ s3_credentials.secret_key }}"
  when: s3_credentials is defined
  no_log: true

- name: Upload reports to S3
  amazon.aws.s3_object:
    bucket: "{{ s3_bucket }}"
    object: "{{ s3_path_prefix }}/{{ inventory_hostname }}/infrastructure_{{ report_timestamp }}.{{ item }}"
    src: "{{ output_dir }}/infrastructure_{{ report_timestamp }}.{{ item }}"
    mode: put
    encrypt: "{{ s3_encryption | default(true) }}"
    storage_class: "{{ s3_storage_class | default('STANDARD') }}"
    acl: "{{ s3_acl | default('private') }}"
    metadata:
      collection_timestamp: "{{ collection_timestamp }}"
      hmc_name: "{{ inventory_hostname }}"
      version: "{{ project_version }}"
      format: "{{ item }}"
  loop:
    - json
    - csv
    - yml
    - html
  when: item in ['json', 'csv', 'yml', 'html']
  environment:
    AWS_ACCESS_KEY_ID: "{{ s3_access_key | default(omit) }}"
    AWS_SECRET_ACCESS_KEY: "{{ s3_secret_key | default(omit) }}"
    AWS_DEFAULT_REGION: "{{ s3_region }}"
    AWS_ENDPOINT_URL: "{{ s3_endpoint_url | default(omit) }}"
  register: s3_upload_results

- name: Display S3 upload summary
  ansible.builtin.debug:
    msg:
      - "Reports uploaded to S3 successfully"
      - "Bucket: {{ s3_bucket }}"
      - "Path: {{ s3_path_prefix }}/{{ inventory_hostname }}/"
      - "Files: {{ s3_upload_results.results | selectattr('changed') | list | length }}"
```

### Task File: persist_git.yml

```yaml
---
# tasks/persist_git.yml
# Commit reports to Git repository

- name: Validate Git configuration
  ansible.builtin.assert:
    that:
      - git_repo_url is defined
      - git_repo_url | length > 0
      - git_branch is defined
    fail_msg: "Git configuration incomplete. Required: git_repo_url, git_branch"

- name: Ensure Git local path exists
  ansible.builtin.file:
    path: "{{ git_local_path }}"
    state: directory
    mode: '0755'

- name: Clone or update Git repository
  ansible.builtin.git:
    repo: "{{ git_repo_url }}"
    dest: "{{ git_local_path }}"
    version: "{{ git_branch }}"
    force: true
    accept_hostkey: true
  environment:
    GIT_SSH_COMMAND: "ssh -i {{ git_ssh_key_path }} -o StrictHostKeyChecking=no"
  when: git_ssh_key_path is defined

- name: Ensure report directory exists in Git repo
  ansible.builtin.file:
    path: "{{ git_local_path }}/reports/{{ ansible_date_time.date }}/{{ inventory_hostname }}"
    state: directory
    mode: '0755'

- name: Copy reports to Git repository
  ansible.builtin.copy:
    src: "{{ output_dir }}/infrastructure_{{ report_timestamp }}.{{ item }}"
    dest: "{{ git_local_path }}/reports/{{ ansible_date_time.date }}/{{ inventory_hostname }}/"
    mode: '0644'
  loop:
    - json
    - csv
    - yml
    - html
  when: item in ['json', 'csv', 'yml', 'html']

- name: Configure Git user
  ansible.builtin.shell: |
    cd {{ git_local_path }}
    git config user.name "{{ git_author_name }}"
    git config user.email "{{ git_author_email }}"
  changed_when: false

- name: Commit reports
  ansible.builtin.shell: |
    cd {{ git_local_path }}
    git add reports/
    git diff --cached --quiet || git commit -m "{{ git_commit_message }}"
  register: git_commit_result
  changed_when: "'nothing to commit' not in git_commit_result.stdout"

- name: Push to remote repository
  ansible.builtin.shell: |
    cd {{ git_local_path }}
    git push origin {{ git_branch }}
  environment:
    GIT_SSH_COMMAND: "ssh -i {{ git_ssh_key_path }} -o StrictHostKeyChecking=no"
  when: 
    - git_commit_result.changed
    - git_ssh_key_path is defined

- name: Display Git commit summary
  ansible.builtin.debug:
    msg:
      - "Reports committed to Git successfully"
      - "Repository: {{ git_repo_url }}"
      - "Branch: {{ git_branch }}"
      - "Commit: {{ git_commit_result.changed }}"
```

### Playbook Integration

Update main playbooks to include new tasks:

```yaml
# collect_infrastructure.yml (add after report generation)

    # ============================================
    # Detect execution environment
    # ============================================
    - name: Detect execution environment
      ansible.builtin.include_tasks: tasks/detect_environment.yml
      run_once: true

    # ============================================
    # Persist reports using configured methods
    # ============================================
    - name: Persist reports
      ansible.builtin.include_tasks: tasks/persist_reports.yml
      run_once: true
```

---

## Credential Management

### AAP Credential Types

#### 1. HMC Credentials
```yaml
# Credential Type: Machine
# Used for: HMC authentication
name: "HMC Credentials"
inputs:
  username: "hscroot"
  password: "{{ vault_hmc_password }}"
```

#### 2. AWS/S3 Credentials
```yaml
# Credential Type: Amazon Web Services
# Used for: S3 uploads
name: "S3 Credentials"
inputs:
  access_key: "AKIAIOSFODNN7EXAMPLE"
  secret_key: "{{ vault_s3_secret_key }}"
```

#### 3. Source Control Credentials
```yaml
# Credential Type: Source Control
# Used for: Git operations
name: "Git Repository Credentials"
inputs:
  ssh_key_data: |
    -----BEGIN OPENSSH PRIVATE KEY-----
    {{ vault_git_ssh_key }}
    -----END OPENSSH PRIVATE KEY-----
```

### Vault Structure

```yaml
# vars/vault.yml (encrypted with ansible-vault)
---
# HMC Credentials
hmc_credentials:
  hmc01.example.com:
    username: "hscroot"
    password: "SecurePassword123!"
  hmc02.example.com:
    username: "hscroot"
    password: "AnotherSecurePass456!"

# S3 Credentials
s3_credentials:
  access_key: "AKIAIOSFODNN7EXAMPLE"
  secret_key: "wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY"

# Git Credentials
git_ssh_key: |
  -----BEGIN OPENSSH PRIVATE KEY-----
  b3BlbnNzaC1rZXktdjEAAAAABG5vbmUAAAAEbm9uZQAAAAAAAAABAAABlwAAAAdzc2gtcn
  ...
  -----END OPENSSH PRIVATE KEY-----
```

### AAP Credential Injection

AAP automatically injects credentials as environment variables:

```yaml
# S3 credentials injected as:
AWS_ACCESS_KEY_ID: "{{ lookup('env', 'AWS_ACCESS_KEY_ID') }}"
AWS_SECRET_ACCESS_KEY: "{{ lookup('env', 'AWS_SECRET_ACCESS_KEY') }}"

# Git credentials injected as:
# SSH key written to temporary file, path in GIT_SSH_KEY_PATH
```

---

## Error Handling

### Graceful Degradation Strategy

```yaml
# Each output method wrapped in block/rescue
- name: Attempt S3 upload
  block:
    - name: Upload to S3
      amazon.aws.s3_object:
        # ... S3 upload tasks
  rescue:
    - name: Log S3 upload failure
      ansible.builtin.debug:
        msg: "WARNING: S3 upload failed, continuing with other methods"
    
    - name: Record failure in stats
      ansible.builtin.set_stats:
        data:
          s3_upload_failed: true
          s3_upload_error: "{{ ansible_failed_result.msg }}"
        per_host: false
```

### Validation Checks

```yaml
# Pre-flight validation
- name: Validate S3 configuration
  ansible.builtin.assert:
    that:
      - s3_bucket is defined
      - s3_region is defined
      - s3_credentials is defined or lookup('env', 'AWS_ACCESS_KEY_ID') != ''
    fail_msg: "S3 upload enabled but configuration incomplete"
  when: enable_s3_upload | default(false)
```

### Retry Logic

```yaml
# Retry network operations
- name: Upload to S3 with retry
  amazon.aws.s3_object:
    # ... parameters
  retries: 3
  delay: 5
  register: s3_result
  until: s3_result is succeeded
```

### Error Reporting

```yaml
# Collect all errors and report at end
- name: Report persistence errors
  ansible.builtin.debug:
    msg:
      - "Persistence Summary:"
      - "  Local Files: {{ 'SUCCESS' if local_files_success else 'FAILED' }}"
      - "  AAP Artifacts: {{ 'SUCCESS' if aap_artifacts_success else 'FAILED' }}"
      - "  S3 Upload: {{ 'SUCCESS' if s3_upload_success else 'FAILED' }}"
      - "  Git Commit: {{ 'SUCCESS' if git_commit_success else 'FAILED' }}"
```

---

## Testing Strategy

### Test Matrix

| Test Case | Environment | Output Methods | Expected Result |
|-----------|-------------|----------------|-----------------|
| TC-01 | CLI | Local only | Files in output/reports/ |
| TC-02 | CLI | Local + S3 | Files local + S3 |
| TC-03 | CLI | Local + Git | Files local + Git commit |
| TC-04 | CLI | All methods | All outputs succeed |
| TC-05 | AAP | Local + Artifacts | Files + AAP artifacts |
| TC-06 | AAP | Artifacts + S3 | AAP artifacts + S3 |
| TC-07 | AAP | Artifacts + Git | AAP artifacts + Git |
| TC-08 | AAP | All methods | All outputs succeed |
| TC-09 | AAP | S3 failure | Graceful degradation |
| TC-10 | AAP | Git failure | Graceful degradation |

### Unit Tests

```yaml
# tests/test_environment_detection.yml
---
- name: Test environment detection
  hosts: localhost
  gather_facts: true
  
  tasks:
    - name: Test CLI detection
      ansible.builtin.include_tasks: tasks/detect_environment.yml
      
    - name: Verify CLI environment
      ansible.builtin.assert:
        that:
          - not is_aap_environment
        fail_msg: "CLI environment not detected correctly"
    
    - name: Test forced AAP mode
      ansible.builtin.include_tasks: tasks/detect_environment.yml
      vars:
        force_aap_mode: true
        
    - name: Verify forced AAP mode
      ansible.builtin.assert:
        that:
          - is_aap_environment
        fail_msg: "Forced AAP mode not working"
```

### Integration Tests

```yaml
# tests/test_s3_upload.yml
---
- name: Test S3 upload functionality
  hosts: localhost
  gather_facts: true
  
  vars:
    enable_s3_upload: true
    s3_bucket: "test-bucket"
    s3_region: "us-east-1"
    
  tasks:
    - name: Create test report
      ansible.builtin.copy:
        content: "{{ test_data | to_json }}"
        dest: "/tmp/test_report.json"
      vars:
        test_data:
          test: true
          timestamp: "{{ ansible_date_time.iso8601 }}"
    
    - name: Test S3 upload
      ansible.builtin.include_tasks: tasks/persist_s3.yml
      
    - name: Verify upload
      amazon.aws.s3_object:
        bucket: "{{ s3_bucket }}"
        object: "test_report.json"
        mode: geturl
      register: s3_verify
      
    - name: Assert upload succeeded
      ansible.builtin.assert:
        that:
          - s3_verify.url is defined
        fail_msg: "S3 upload verification failed"
```

### AAP Testing

```bash
# Test AAP artifact retrieval
#!/bin/bash

JOB_ID=123
AAP_URL="https://aap.example.com"
AAP_USER="admin"
AAP_PASS="password"

# Get artifacts
curl -k -u ${AAP_USER}:${AAP_PASS} \
  ${AAP_URL}/api/v2/jobs/${JOB_ID}/artifacts/ \
  | jq -r '.infrastructure_report_json' \
  | base64 -d \
  | jq . > report.json

# Verify report
if [ -s report.json ]; then
  echo "✓ Artifact retrieved successfully"
  jq '.metadata.version' report.json
else
  echo "✗ Artifact retrieval failed"
  exit 1
fi
```

---

## Migration Path

### Phase 1: Preparation (Week 1)

**Objective**: Set up infrastructure and test in non-production

1. **Create S3 Bucket** (if using S3)
   ```bash
   aws s3 mb s3://power-infrastructure-reports
   aws s3api put-bucket-versioning \
     --bucket power-infrastructure-reports \
     --versioning-configuration Status=Enabled
   ```

2. **Create Git Repository** (if using Git)
   ```bash
   git init power-reports
   cd power-reports
   mkdir -p reports
   echo "# Power Infrastructure Reports" > README.md
   git add .
   git commit -m "Initial commit"
   git remote add origin git@github.com:org/power-reports.git
   git push -u origin main
   ```

3. **Configure AAP Credentials**
   - Add HMC credentials
   - Add S3 credentials (if applicable)
   - Add Git credentials (if applicable)

4. **Test in Development**
   ```bash
   # Test CLI with all methods
   ansible-playbook collect_infrastructure.yml \
     -e enable_s3_upload=true \
     -e enable_git_commit=true \
     --limit dev-hmc
   ```

### Phase 2: AAP Integration (Week 2)

**Objective**: Deploy to AAP and validate

1. **Create AAP Project**
   - Source: Git repository with playbooks
   - Branch: main
   - Update on launch: Yes

2. **Create Job Template**
   ```yaml
   name: "Collect Power Infrastructure"
   job_type: "run"
   inventory: "Power Systems"
   project: "Power Infrastructure Collection"
   playbook: "collect_infrastructure.yml"
   credentials:
     - "HMC Credentials"
     - "S3 Credentials"
     - "Git Credentials"
   extra_vars:
     enable_aap_artifacts: true
     enable_s3_upload: true
     enable_git_commit: false
   ```

3. **Test AAP Execution**
   - Run job manually
   - Verify artifacts in AAP UI
   - Check S3 bucket for uploads
   - Review job output logs

4. **Validate Artifact Retrieval**
   ```bash
   # Via AAP API
   curl -k -u admin:password \
     https://aap.example.com/api/v2/jobs/123/artifacts/
   ```

### Phase 3: Production Rollout (Week 3)

**Objective**: Deploy to production with monitoring

1. **Create Production Job Template**
   - Same as development
   - Add notification templates
   - Configure schedules

2. **Set Up Monitoring**
   - AAP job success/failure notifications
   - S3 upload monitoring (CloudWatch)
   - Git commit monitoring (webhooks)

3. **Create Scheduled Jobs**
   ```yaml
   # Daily collection at 2 AM
   schedule:
     name: "Daily Infrastructure Collection"
     rrule: "DTSTART:20260301T020000Z RRULE:FREQ=DAILY"
     enabled: true
   ```

4. **Document Procedures**
   - Update runbooks
   - Train operators
   - Create troubleshooting guide

### Phase 4: Optimization (Week 4)

**Objective**: Fine-tune and optimize

1. **Review Performance**
   - Job execution time
   - Artifact sizes
   - S3 costs
   - Git repository size

2. **Implement Optimizations**
   - Compress artifacts if needed
   - Adjust S3 storage class
   - Implement Git retention policy
   - Optimize playbook tasks

3. **Set Up Retention Policies**
   ```yaml
   # S3 lifecycle policy
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

### Rollback Plan

If issues arise:

1. **Immediate**: Disable new output methods
   ```yaml
   enable_aap_artifacts: false
   enable_s3_upload: false
   enable_git_commit: false
   ```

2. **Revert**: Use previous playbook version
   ```bash
   git revert HEAD
   git push origin main
   ```

3. **Fallback**: Manual report collection
   ```bash
   ansible-playbook collect_infrastructure.yml \
     --limit production-hmcs \
     -e enable_local_files=true
   ```

---

## Performance Considerations

### Execution Time Impact

| Operation | Time (seconds) | Notes |
|-----------|----------------|-------|
| Local file write | 0.1 - 0.5 | Baseline |
| AAP artifact registration | 0.5 - 2.0 | Base64 encoding overhead |
| S3 upload (1MB) | 1.0 - 5.0 | Network dependent |
| Git commit/push | 2.0 - 10.0 | Repository size dependent |

**Total overhead**: 3-17 seconds per execution

### Optimization Strategies

#### 1. Parallel Execution
```yaml
# Upload to S3 in parallel
- name: Upload reports to S3
  amazon.aws.s3_object:
    # ... parameters
  loop: "{{ report_formats }}"
  async: 300
  poll: 0
  register: s3_async

- name: Wait for S3 uploads
  ansible.builtin.async_status:
    jid: "{{ item.ansible_job_id }}"
  loop: "{{ s3_async.results }}"
  register: s3_results
  until: s3_results.finished
  retries: 30
  delay: 10
```

#### 2. Compression
```yaml
# Compress before upload
- name: Compress reports
  ansible.builtin.archive:
    path: "{{ output_dir }}/infrastructure_{{ report_timestamp }}.*"
    dest: "{{ output_dir }}/infrastructure_{{ report_timestamp }}.tar.gz"
    format: gz

- name: Upload compressed archive
  amazon.aws.s3_object:
    bucket: "{{ s3_bucket }}"
    object: "{{ s3_path_prefix }}/infrastructure_{{ report_timestamp }}.tar.gz"
    src: "{{ output_dir }}/infrastructure_{{ report_timestamp }}.tar.gz"
```

#### 3. Selective Formats
```yaml
# Only upload essential formats to S3
s3_upload_formats:
  - json  # For programmatic access
  - csv   # For spreadsheet import
# Skip yaml and html to reduce upload time
```

#### 4. Conditional Execution
```yaml
# Only commit to Git if changes detected
- name: Check for changes
  ansible.builtin.shell: |
    cd {{ git_local_path }}
    git diff --quiet reports/ || echo "changed"
  register: git_changes
  changed_when: false

- name: Commit only if changed
  ansible.builtin.shell: |
    cd {{ git_local_path }}
    git commit -m "{{ git_commit_message }}"
  when: git_changes.stdout == "changed"
```

### Resource Usage

| Resource | CLI | AAP |
|----------|-----|-----|
| Memory | 100-200 MB | 200-400 MB |
| CPU | 1-5% | 5-15% |
| Disk I/O | Low | Medium |
| Network | Low | Medium-High |

### Scaling Considerations

**For large deployments (>10 HMCs):**

1. **Use workflow templates** to parallelize HMC collection
2. **Implement batching** for S3 uploads
3. **Use separate Git branches** per HMC to avoid conflicts
4. **Consider database storage** instead of files for very large scale

---

## Implementation Checklist

### Development Phase

- [ ] Create `tasks/` directory structure
- [ ] Implement `detect_environment.yml`
- [ ] Implement `persist_reports.yml`
- [ ] Implement `persist_local.yml`
- [ ] Implement `persist_aap_artifacts.yml`
- [ ] Implement `persist_s3.yml`
- [ ] Implement `persist_git.yml`
- [ ] Update `collect_infrastructure.yml`
- [ ] Update `collect_infrastructure_hmc_cli.yml`
- [ ] Update `test_report_generation.yml`
- [ ] Update `inventory/group_vars/hmcs.yml`
- [ ] Update `requirements.yml` (add amazon.aws)
- [ ] Create `docs/README_AAP.md`
- [ ] Create `docs/aap_job_templates/` examples
- [ ] Update main `README.md`

### Testing Phase

- [ ] Test CLI execution (local files only)
- [ ] Test CLI with S3 upload
- [ ] Test CLI with Git commit
- [ ] Test CLI with all methods
- [ ] Test AAP execution (artifacts only)
- [ ] Test AAP with S3 upload
- [ ] Test AAP with Git commit
- [ ] Test AAP with all methods
- [ ] Test error handling (S3 failure)
- [ ] Test error handling (Git failure)
- [ ] Test environment detection
- [ ] Test artifact retrieval via API
- [ ] Performance testing
- [ ] Load testing (multiple HMCs)

### Documentation Phase

- [ ] Complete `PLAN_AAP_COMPATIBILITY.md`
- [ ] Write `README_AAP.md`
- [ ] Create job template examples
- [ ] Create workflow template examples
- [ ] Document credential setup
- [ ] Document S3 configuration
- [ ] Document Git configuration
- [ ] Create troubleshooting guide
- [ ] Create operator runbook
- [ ] Update version history

### Deployment Phase

- [ ] Create development S3 bucket
- [ ] Create development Git repository
- [ ] Configure AAP development credentials
- [ ] Deploy to AAP development
- [ ] Validate development deployment
- [ ] Create production S3 bucket
- [ ] Create production Git repository
- [ ] Configure AAP production credentials
- [ ] Deploy to AAP production
- [ ] Configure schedules
- [ ] Set up monitoring
- [ ] Train operators

### Post-Deployment

- [ ] Monitor first week of production runs
- [ ] Review performance metrics
- [ ] Optimize based on findings
- [ ] Implement retention policies
- [ ] Document lessons learned
- [ ] Plan future enhancements

---

## Appendix A: AAP API Examples

### Retrieve Job Artifacts

```bash
#!/bin/bash
# get_artifacts.sh - Retrieve AAP job artifacts

AAP_URL="https://aap.example.com"
AAP_USER="admin"
AAP_PASS="password"
JOB_ID=$1

if [ -z "$JOB_ID" ]; then
  echo "Usage: $0 <job_id>"
  exit 1
fi

# Get artifacts
curl -k -u ${AAP_USER}:${AAP_PASS} \
  ${AAP_URL}/api/v2/jobs/${JOB_ID}/artifacts/ \
  -o artifacts.json

# Extract and decode reports
for format in json csv yaml html; do
  jq -r ".infrastructure_report_${format}" artifacts.json \
    | base64 -d > report.${format}
  echo "✓ Extracted report.${format}"
done

# Extract metadata
jq '.infrastructure_report_metadata' artifacts.json > metadata.json
echo "✓ Extracted metadata.json"
```

### List Recent Jobs

```bash
#!/bin/bash
# list_jobs.sh - List recent infrastructure collection jobs

AAP_URL="https://aap.example.com"
AAP_USER="admin"
AAP_PASS="password"

curl -k -u ${AAP_USER}:${AAP_PASS} \
  "${AAP_URL}/api/v2/jobs/?name__icontains=infrastructure&page_size=10" \
  | jq -r '.results[] | "\(.id)\t\(.status)\t\(.finished)"'
```

---

## Appendix B: S3 Configuration Examples

### AWS S3 Bucket Policy

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "AllowAnsibleUpload",
      "Effect": "Allow",
      "Principal": {
        "AWS": "arn:aws:iam::123456789012:user/ansible-automation"
      },
      "Action": [
        "s3:PutObject",
        "s3:PutObjectAcl"
      ],
      "Resource": "arn:aws:s3:::power-infrastructure-reports/*"
    }
  ]
}
```

### MinIO Configuration

```yaml
# docker-compose.yml for MinIO
version: '3'
services:
  minio:
    image: minio/minio:latest
    ports:
      - "9000:9000"
      - "9001:9001"
    environment:
      MINIO_ROOT_USER: admin
      MINIO_ROOT_PASSWORD: password123
    command: server /data --console-address ":9001"
    volumes:
      - minio_data:/data

volumes:
  minio_data:
```

---

## Appendix C: Git Repository Setup

### Repository Structure

```
power-reports/
├── .gitignore
├── README.md
├── reports/
│   ├── 2026-02-28/
│   │   ├── hmc01.example.com/
│   │   └── hmc02.example.com/
│   └── 2026-02-29/
└── scripts/
    ├── cleanup_old_reports.sh
    └── generate_summary.py
```

### .gitignore

```
# Ignore temporary files
*.tmp
*.swp
.DS_Store

# Ignore large files (use Git LFS)
*.tar.gz
*.zip

# Ignore local configuration
.env
config.local.yml
```

### Retention Script

```bash
#!/bin/bash
# cleanup_old_reports.sh - Remove reports older than 90 days

REPORTS_DIR="reports"
RETENTION_DAYS=90

find ${REPORTS_DIR} -type f -mtime +${RETENTION_DAYS} -delete
find ${REPORTS_DIR} -type d -empty -delete

git add ${REPORTS_DIR}
git commit -m "Cleanup: Removed reports older than ${RETENTION_DAYS} days"
git push origin main
```

---

## Conclusion

This implementation plan provides a comprehensive roadmap for adding AAP compatibility to the IBM Power Infrastructure Collection playbooks. The design maintains backward compatibility while adding enterprise-grade features for report persistence.

**Key Takeaways:**

1. **Flexible Architecture**: Multiple output methods work independently
2. **Zero Breaking Changes**: Existing CLI usage unchanged
3. **Enterprise Ready**: S3, Git, and AAP artifact support
4. **Well Tested**: Comprehensive testing strategy
5. **Documented**: Complete documentation for operators

**Next Steps:**

1. Review and approve this plan
2. Switch to Code mode for implementation
3. Follow implementation checklist
4. Execute testing phase
5. Deploy to production

---

**Document Version:** 1.0  
**Last Updated:** 2026-02-28  
**Status:** Ready for Review