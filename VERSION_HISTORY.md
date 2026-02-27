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