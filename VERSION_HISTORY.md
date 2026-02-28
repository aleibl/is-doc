# IBM Power Systems Infrastructure Collection - Version History

## Versioning Convention

This project uses IBM's VRMF versioning convention.

Version numbers are **V.R.M.F**:

- **V (Version)**: Major product generation. Increment V for fundamental, often incompatible changes.
- **R (Release)**: Significant new function within a Version. First generally available release is R=1 (not 0), then 2, and so on.
- **M (Modification)**: Smaller enhancements or cumulative maintenance within a Release. Increment M when adding minor features or larger fix bundles.
- **F (Fix)**: Lowest level, individual fix packs or patches. Increment F for defect‑only updates, no new features.

### Hierarchy Rule

- When you increment V, reset R,M,F to 0.
- When you increment R, reset M,F to 0.
- When you increment M, reset F to 0.
- When you increment F, only F changes.

## Release History

### 1.2.0.0 (2026-03-01)

**Second Release - AAP Compatibility & Documentation**

Major Features:
- **Ansible Automation Platform (AAP) Compatibility**: Full support for AAP execution environments with automatic environment detection
- **Multiple Output Methods**: Four independent output strategies for report persistence
  - Local filesystem (backward compatible)
  - AAP artifacts via `set_stats` module
  - S3-compatible storage (AWS S3, MinIO, etc.)
  - Git repository integration
- **Graceful Degradation**: Each output method operates independently with comprehensive error handling
- **Zero Breaking Changes**: All new features are opt-in, maintaining full backward compatibility

New Components:
- `tasks/detect_environment.yml` - Automatic CLI vs AAP environment detection
- `tasks/persist_reports.yml` - Orchestrates all output methods
- `tasks/persist_local.yml` - Local filesystem output (always enabled)
- `tasks/persist_aap_artifacts.yml` - AAP artifact registration
- `tasks/persist_s3.yml` - S3-compatible storage upload
- `tasks/persist_git.yml` - Git repository integration

Enhanced Playbooks:
- Updated `collect_infrastructure.yml` with AAP compatibility
- Updated `collect_infrastructure_hmc_cli.yml` with AAP compatibility
- Updated `test_report_generation.yml` with output method testing

Configuration:
- Extended `inventory/group_vars/hmcs.yml` with 45 lines of output configuration
- Added `amazon.aws` collection to `requirements.yml` (>=5.0.0)
- All output methods configurable with sensible defaults

Documentation:
- `docs/README_AAP.md` (873 lines) - Comprehensive AAP deployment guide
- `docs/PLAN_AAP_COMPATIBILITY.md` (1,847 lines) - Technical design and architecture
- `docs/IMPLEMENTATION_SUMMARY.md` (673 lines) - Implementation status and metrics
- `docs/FUTURE_ENHANCEMENTS.md` (1,009 lines) - 35 potential enhancements with priorities
- `docs/ARCHITECTURE_INTEGRATION.md` (1,200+ lines) - Integration patterns and technology stack
- `docs/aap_job_templates/` - 4 example AAP job templates with README
- Updated main `README.md` with AAP compatibility section

Technical Improvements:
- Automatic environment detection (CLI vs AAP)
- Independent output method execution with rescue handlers
- Comprehensive error tracking and reporting
- S3 upload with retry logic (3 attempts)
- Git integration with SSH and HTTPS support
- Base64 encoding for AAP artifacts
- Metadata inclusion in all output methods

Security:
- Ansible Vault support for credentials
- AAP credential system integration
- Encrypted credential storage examples

Testing:
- Test playbook validates all output methods
- Synthetic data generation for testing without HMC access
- Comprehensive error scenario testing

Statistics:
- 6 new task files (678 lines of code)
- 8 new documentation files (6,600+ lines)
- 4 example job templates
- 6 files modified (playbooks and configuration)
- Total: 24 new/modified files
- Zero breaking changes
- 100% backward compatible

---

### 1.1.0.0 (2026-02-27)

**First General Availability Release**

Features:
- Dual collection methods (REST API and HMC CLI)
- Multi-format reporting (JSON, CSV, YAML, HTML)
- System resource summary with utilization calculations
- LPAR resource allocation tracking (min/current/max)
- Processor configuration details (dedicated/shared, capped/uncapped)
- Physical adapter inventory with ownership tracking
- Unassigned adapter identification
- Comprehensive documentation
- Test playbook with synthetic data
- Packaging script for distribution

Components:
- collect_infrastructure.yml (REST API version)
- collect_infrastructure_hmc_cli.yml (CLI version)
- test_report_generation.yml (testing)
- 4 report templates (JSON, CSV, YAML, HTML)
- Complete documentation (README.md, README_HMC_CLI.md)
- Sample inventory and configuration files
- Packaging script (package.sh)

Technical Details:
- Single source VERSION file
- Dynamic version reading in playbooks
- Ansible 2.9+ compatible
- Python 3.6+ compatible

---

### 0.x.x.x

Pre-release versions - not for production use.