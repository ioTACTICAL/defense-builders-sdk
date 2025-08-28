# Defense Builders SDK Workflow Documentation

## Overview

The Defense Builders SDK ecosystem employs multiple GitHub Actions workflows to automate SDK container building, version management, and registry maintenance. This document provides detailed technical specifications for each workflow, their triggers, dependencies, and outputs.

## Table of Contents

1. [Workflow Inventory](#workflow-inventory)
2. [Core Workflows](#core-workflows)
3. [Integration Workflows](#integration-workflows)
4. [Validation Workflows](#validation-workflows)
5. [Dependencies and Scripts](#dependencies-and-scripts)
6. [Environment Variables](#environment-variables)
7. [Security Considerations](#security-considerations)

## Workflow Inventory

### Active Workflows

| Workflow File | Primary Purpose | Trigger | Status |
|---------------|----------------|---------|---------|
| `build-versioned-sdks.yml` | Build and publish SDK containers | Push to main, PR, manual | Active |
| `update-sdk-versions.yml` | Update SDK registry from external repos | Repository dispatch, manual | Active |
| `validate-and-build.yml` | Validate registry integrity | Push to main, PR | Active |
| `build-base.yml` | Build base container image | Manual, dependency | Active |

### Legacy/Deprecated Files

| File | Status | Notes |
|------|--------|-------|
| `build-sdks.yml.old` | Deprecated | Backup of previous implementation |

## Core Workflows

### 1. Build Versioned SDKs (`build-versioned-sdks.yml`)

**Purpose**: Primary workflow for building and publishing versioned SDK containers.

**Triggers**:
- Push to main branch affecting:
  - `sdks/atak-civ/**`
  - `sdk-configs/atak-civ.conf`
  - `base/**`
  - `scripts/**`
  - `.github/workflows/**`
- Pull requests to main (same paths)
- Manual dispatch with optional parameters:
  - `version`: Specific SDK version to build
  - `sync_repos`: Whether to sync repositories after build

**Environment Variables**:
- `REGISTRY`: Container registry URL (`ghcr.io`)
- `REGISTRY_USER`: GitHub actor name
- `REGISTRY_PASSWORD`: GitHub token

**Jobs**:

1. **discover-versions**
   - Executes version discovery using `./scripts/workflow-discover-versions.sh`
   - Outputs discovered versions as JSON array
   - Uses fallback versions: `["5.3.0.12","5.4.0.21","5.5.0.5"]`
   - Runtime: ~30 seconds

2. **build-base**
   - Builds base container image from `./base/Dockerfile`
   - Pushes to registry with tags: `latest`, `{git-sha}`
   - Runs Trivy security scanning
   - Uploads SARIF results to GitHub Security tab
   - Runtime: ~5-10 minutes

3. **build-versioned-sdks**
   - Matrix build for each discovered SDK version
   - Creates placeholder SDK structure for CI
   - Generates version-specific Dockerfiles
   - Builds and pushes versioned containers
   - Tags latest version (5.5.0.5) as `latest`
   - Performs security scanning per version
   - Generates Software Bill of Materials (SBOM)
   - Runtime: ~15-20 minutes per version

4. **sync-repositories**
   - Simulates repository synchronization
   - Only runs on main branch pushes or manual trigger
   - Matrix execution per version
   - Currently simulated (would integrate with actual sync in production)
   - Runtime: ~1-2 minutes per version

5. **update-documentation**
   - Updates `VERSION_MATRIX.md` with build information
   - Generates `BUILD_STATUS.md` with current status
   - Updates `sdk-versions.json` with version metadata
   - Commits changes back to repository
   - Only runs on main branch pushes
   - Runtime: ~2-3 minutes

6. **report-results**
   - Aggregates build results from all jobs
   - Generates GitHub Actions summary
   - Provides artifact and security scan information
   - Always runs regardless of job success/failure
   - Runtime: ~30 seconds

**Permissions Required**:
- `contents: read` - Repository access
- `packages: write` - Container registry publishing
- `security-events: write` - Security scan uploads

**Outputs**:
- Container images: `ghcr.io/iotactical/dbsdk-atak-civ:{version}`
- SBOM artifacts (90-day retention)
- Security scan results
- Updated documentation files

### 2. Update SDK Versions (`update-sdk-versions.yml`)

**Purpose**: Automated SDK registry updates from external source repositories.

**Triggers**:
- Repository dispatch with type `sdk-update` from source repositories
- Manual dispatch with parameters:
  - `sdk_name`: SDK identifier
  - `version`: Version number
  - `container_image`: Container URI
  - `java_version`, `gradle_version`, `android_api`: Technical specifications
  - `release_notes`: Version description
  - `is_latest`: Latest version flag

**Jobs**:

1. **update-sdk-versions**
   - Extracts payload from dispatch event or manual inputs
   - Executes `scripts/update-sdk-versions.py` with parameters
   - Validates updated JSON against schema
   - Creates pull request with changes
   - Auto-deletes feature branch after merge

**Dependencies**:
- Node.js 18
- `ajv-cli` for JSON schema validation
- Python 3 for update script

**Integration Points**:
- Receives notifications from `atak-civ` repository CI
- Creates PRs for human review before registry updates
- Validates all changes against `schema/sdk-versions-schema.json`

**Permissions Required**:
- `contents: write` - Repository modifications
- `pull-requests: write` - PR creation

### 3. Validate and Build (`validate-and-build.yml`)

**Purpose**: Registry integrity validation and quality assurance.

**Triggers**:
- Push to main branch
- Pull requests to main branch
- Manual dispatch

**Jobs**:

1. **validate**
   - JSON schema validation using `ajv-cli`
   - Syntax validation using Python JSON parser
   - Required field verification
   - Update script functionality testing
   - Registry statistics generation

**Validation Checks**:
- Schema compliance against `sdk-versions-schema.json`
- JSON syntax correctness
- Presence of required fields: `name`, `description`, `versions`, `templates`
- Python script operational status

**Dependencies**:
- Node.js 18 with `ajv-cli`
- Python 3

**Runtime**: ~2-3 minutes

### 4. Build Base (`build-base.yml`)

**Purpose**: Base container image building for SDK environments.

**Triggers**:
- Manual dispatch only
- Dependency for versioned SDK builds

**Jobs**:

1. **build-base**
   - Builds from `./base/Dockerfile`
   - Multi-platform support (configurable)
   - Security scanning with Trivy
   - Registry publishing

**Usage**: 
- Provides foundation for SDK-specific containers
- Reduces build time through layer caching
- Ensures consistent base environment

## Integration Workflows

### External Repository Integration

**Source Repository Requirements**:
1. CI workflow that builds SDK containers
2. Repository dispatch capability
3. Secrets management for `DEFENSE_BUILDERS_PAT`

**Integration Flow**:
1. Source repo (e.g., atak-civ) builds successfully
2. Sends repository dispatch to defense-builders-sdk
3. `update-sdk-versions.yml` receives event
4. Updates registry and creates PR
5. Human review and merge
6. `validate-and-build.yml` validates changes
7. Updated registry available to community

### ATAK-CIV Integration

**Repository**: `iotactical/atak-civ`
**Workflow**: `.github/workflows/build-and-notify.yml`

**Trigger Payload**:
```json
{
  "sdk_name": "atak-civ",
  "version": "{version}",
  "container_image": "{container_uri}",
  "java_version": "11",
  "gradle_version": "7.6",
  "android_api": "30",
  "release_notes": "{release_description}",
  "is_latest": true
}
```

## Dependencies and Scripts

### Core Scripts

1. **`scripts/workflow-discover-versions.sh`**
   - Version discovery from GitHub repositories
   - GitHub Actions output generation
   - Fallback version handling
   - Multi-SDK support

2. **`scripts/update-sdk-versions.py`**
   - Programmatic JSON modification
   - Semantic version handling
   - Latest version management
   - Schema validation preparation

3. **`scripts/build-versioned-containers.sh`**
   - Dockerfile generation for specific versions
   - SDK packaging and preparation
   - Build context management

4. **`lib/sdk-discovery.sh`**
   - GitHub API integration
   - Repository pattern matching
   - Version extraction algorithms
   - Caching mechanisms

### Configuration Files

1. **`sdk-configs/atak-civ.conf`**
   - SDK-specific discovery functions
   - Custom version patterns
   - Repository configuration

2. **`schema/sdk-versions-schema.json`**
   - JSON Schema validation rules
   - Required field definitions
   - Type constraints

## Environment Variables

### GitHub Actions Variables

| Variable | Source | Purpose |
|----------|--------|---------|
| `GITHUB_TOKEN` | Automatic | Repository and registry access |
| `GITHUB_ACTOR` | Automatic | Registry authentication |
| `GITHUB_SHA` | Automatic | Build traceability |
| `GITHUB_RUN_ID` | Automatic | Build identification |
| `GITHUB_OUTPUT` | Automatic | Job output communication |
| `GITHUB_STEP_SUMMARY` | Automatic | Build summaries |

### Custom Variables

| Variable | Default | Purpose |
|----------|---------|---------|
| `REGISTRY` | `ghcr.io` | Container registry URL |
| `GITHUB_ORG` | `iotactical` | Organization for discovery |
| `DISCOVERY_CACHE_TTL` | `300` | Cache timeout seconds |
| `DBSDK_DEBUG` | `false` | Debug logging enable |

### Required Secrets

| Secret | Repository | Purpose |
|--------|------------|---------|
| `DEFENSE_BUILDERS_PAT` | Source repos | Cross-repository dispatch |
| `GITHUB_TOKEN` | Automatic | Standard operations |

## Security Considerations

### Container Security
- Trivy vulnerability scanning on all images
- SARIF results uploaded to GitHub Security tab
- Multi-architecture build support
- Base image security hardening

### Access Control
- Repository permissions strictly scoped
- Package registry access controlled
- Secrets rotation supported
- Branch protection enforcement

### Supply Chain Security
- SBOM generation for all containers
- Build provenance tracking
- Dependency scanning
- Automated security updates

### Compliance
- GPL-3.0 license compliance
- Security policy enforcement
- Audit trail maintenance
- Vulnerability disclosure process

## Monitoring and Observability

### Build Metrics
- Build success rates
- Build duration tracking
- Resource utilization
- Failure analysis

### Registry Metrics
- Container pull statistics
- Version adoption rates
- Geographic distribution
- Usage patterns

### Integration Health
- Repository dispatch success rates
- Schema validation pass rates
- PR merge timelines
- Community engagement metrics

## Troubleshooting

### Common Issues

1. **Version Discovery Failures**
   - Check GitHub API rate limits
   - Verify repository patterns
   - Validate authentication tokens

2. **Build Failures**
   - Review Docker build logs
   - Check base image availability
   - Verify SDK file accessibility

3. **Schema Validation Errors**
   - Validate JSON syntax
   - Check required field presence
   - Verify data type compliance

4. **Integration Problems**
   - Confirm webhook delivery
   - Verify secret configuration
   - Check repository permissions

### Debug Procedures

1. Enable debug logging: Set `DBSDK_DEBUG=true`
2. Review GitHub Actions logs
3. Check registry access permissions
4. Validate schema compliance locally
5. Test scripts in isolation

## Performance Optimization

### Build Time Reduction
- Docker layer caching
- Parallel matrix builds
- Incremental updates only
- Resource allocation tuning

### Resource Efficiency
- Workflow concurrency limits
- Build artifact cleanup
- Cache management
- Network optimization

### Scalability Considerations
- Multi-region registry support
- Load balancing strategies
- Horizontal scaling patterns
- Resource usage monitoring