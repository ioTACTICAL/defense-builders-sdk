# Gist-Based Modular Architecture

## Overview

The Defense Builders SDK ecosystem has been redesigned to use a modular, gist-based architecture that eliminates race conditions and enables scalable SDK collection management. This document describes the new architecture, workflow patterns, and integration mechanisms.

## Architecture Principles

### 1. Single Source of Truth
Each SDK collection generates its own `sdk-versions.json` from its actual directory structure, ensuring version consistency with the source code.

### 2. Modular Registration
SDK collections register themselves via GitHub gists, enabling dynamic discovery and automatic integration without manual registry updates.

### 3. Race Condition Elimination
No conflicting writes to central registry files. The defense-builders-sdk aggregates from individual gists, preventing concurrent modification conflicts.

### 4. Scalable Growth
New SDK collections are automatically discovered and integrated without requiring changes to the defense-builders-sdk repository.

## System Components

### SDK Collection Repositories (e.g., atak-civ, wintak)

**Responsibilities**:
- Generate `sdk-versions.json` from directory structure
- Validate against defense-builders-sdk schema
- Build and publish SDK containers
- Update dedicated GitHub gist
- Trigger defense-builders-sdk aggregation

**Workflow**: `build-and-register.yml`

**Gist Naming**: `sdk-versions-{repo-name}.json`

### Defense Builders SDK Repository

**Responsibilities**:
- Discover all SDK collection gists
- Aggregate individual registries into master registry
- Validate consolidated registry
- Provide unified SDK catalog for subscribers

**Workflow**: `aggregate-sdk-registry.yml`

**Triggered by**:
- Repository dispatch from SDK collections
- Scheduled runs (every 6 hours)
- Manual dispatch

### SDK Init Utility

**Responsibilities**:
- Generate SDK collection repositories
- Create workflow templates with gist integration
- Collect and configure GitHub App tokens
- Enable community SDK creation

**Template**: `build-and-register.yml.hbs`

## Data Flow

### 1. SDK Collection Update Flow

```
SDK Collection Repository (e.g., atak-civ):
├── 1. Discover versions from directory structure
├── 2. Generate sdk-versions.json with metadata
├── 3. Validate against schema
├── 4. Build container images
├── 5. Update gist: sdk-versions-atak-civ.json
└── 6. Dispatch to defense-builders-sdk

Defense Builders SDK:
├── 7. Receive repository dispatch
├── 8. Discover all SDK collection gists
├── 9. Aggregate into master registry
├── 10. Validate consolidated registry
├── 11. Update repository registry file
└── 12. Deploy to iotactical.co subscribers
```

### 2. New SDK Collection Creation

```
Developer runs sdk-init:
├── 1. Collect GitHub App token
├── 2. Generate repository structure
├── 3. Configure gist-based workflow
├── 4. Create GitHub repository
├── 5. Setup secrets and permissions
└── 6. Ready for first build

First Build:
├── 1. Execute build-and-register workflow
├── 2. Create sdk-versions-{name}.json gist
├── 3. Trigger defense-builders-sdk
└── 4. Automatically appear in registry
```

## Technical Implementation

### GitHub Gist Integration

**Gist Naming Convention**: `sdk-versions-{repo-name}.json`

**Gist Structure**:
```json
{
  "{sdk-name}": {
    "name": "SDK Display Name",
    "description": "SDK description",
    "versions": [...],
    "templates": [...]
  }
}
```

**API Operations**:
- **Discovery**: `GET /users/iotactical/gists`
- **Create**: `POST /gists`
- **Update**: `PATCH /gists/{gist_id}`

### Workflow Templates

**SDK Collection Template**: `build-and-register.yml.hbs`

**Key Features**:
- Version discovery from directory structure
- JSON generation with Handlebars templating
- Schema validation
- Container building and publishing
- Gist management
- Repository dispatch triggering

**Template Variables**:
- `{{name}}`: Repository name
- `{{displayName}}`: Human-readable name
- `{{description}}`: SDK description
- `{{organization}}`: GitHub organization
- `{{javaVersion}}`, `{{gradleVersion}}`, etc.: Technical specifications

### Authentication

**GitHub App Token Requirements**:
- `repo`: Repository access
- `gist`: Gist creation/modification
- `workflow`: Workflow updates

**Token Collection**:
- CLI option: `--github-app-token`
- Environment variable: `GIST_TOKEN`
- Interactive prompt with validation

**Secret Configuration**:
- `GIST_TOKEN`: Stored in each SDK collection repository
- Used for gist updates and repository dispatch

## Workflow Specifications

### SDK Collection Workflow (build-and-register.yml)

**Jobs**:

1. **discover-versions**
   - Scans directory structure for SDK versions
   - Generates consolidated JSON registry
   - Outputs structured data for subsequent jobs

2. **validate-registry**
   - Downloads schema from defense-builders-sdk
   - Validates generated JSON
   - Ensures compliance before deployment

3. **build-containers**
   - Matrix build for all discovered versions
   - Publishes to GitHub Container Registry
   - Sets public visibility for community access

4. **register-with-defense-builders**
   - Updates or creates GitHub gist
   - Triggers defense-builders-sdk aggregation
   - Only runs on main branch pushes

### Defense Builders SDK Workflow (aggregate-sdk-registry.yml)

**Jobs**:

1. **discover-gists**
   - Scans organization for SDK version gists
   - Fetches and validates content
   - Aggregates into master registry

2. **validate-registry**
   - Schema validation of aggregated registry
   - Consistency checks across SDKs
   - Required field verification

3. **update-registry**
   - Updates repository registry file
   - Generates documentation
   - Commits changes to main branch

4. **report-status**
   - Generates workflow summary
   - Reports aggregation results
   - Provides debugging information

## Migration Strategy

### Phase 1: Infrastructure (Completed)
- Created gist-based workflows
- Updated sdk-init templates
- Modified defense-builders-sdk aggregation

### Phase 2: SDK Collection Migration
- Convert atak-civ to new pattern
- Test end-to-end functionality
- Validate gist creation and updates

### Phase 3: Legacy Cleanup
- Remove deprecated workflows
- Update documentation
- Archive old patterns

### Phase 4: Community Rollout
- Publish sdk-init updates
- Create migration documentation
- Support community adoption

## Security Considerations

### Token Management
- GitHub App tokens stored as repository secrets
- Scope-limited permissions (repo, gist, workflow)
- Regular rotation supported

### Access Control
- Gists are public for transparency
- Write access controlled by token ownership
- Repository dispatch requires authenticated tokens

### Validation
- Schema validation prevents malformed data
- JSON syntax checking ensures integrity
- Required field verification maintains consistency

## Monitoring and Observability

### Gist Discovery Metrics
- Number of discovered SDK collections
- Gist update frequency
- Aggregation success rates

### Registry Health
- Schema validation pass rates
- Version consistency checks
- Container availability verification

### Integration Monitoring
- Repository dispatch success rates
- Workflow completion times
- Error rates and failure analysis

## Error Handling

### Gist Management Errors
- Graceful fallback for missing gists
- Retry mechanisms for API failures
- Detailed logging for debugging

### Validation Failures
- Clear error messages for schema violations
- Rollback mechanisms for invalid data
- Notification systems for maintainers

### Integration Failures
- Repository dispatch retry logic
- Timeout handling for long operations
- Circuit breakers for repeated failures

## Benefits of New Architecture

### For SDK Maintainers
- **Autonomous Operations**: No dependency on central registry updates
- **Source of Truth**: Versions automatically reflect actual SDK structure
- **Simplified Maintenance**: Single workflow handles entire lifecycle

### for Defense Builders Ecosystem
- **Scalable Growth**: Unlimited SDK collections without infrastructure changes
- **Conflict Prevention**: No race conditions or concurrent modification issues
- **Automatic Discovery**: New SDKs appear automatically in registry

### For Community Contributors
- **Lower Barrier**: Easy SDK collection creation via sdk-init
- **Self-Service**: Complete autonomy from repository creation to deployment
- **Professional Quality**: Automated best practices and standards compliance

### For iotactical.co Subscribers
- **Always Current**: Registry automatically reflects latest SDK versions
- **Comprehensive**: All active SDK collections included automatically
- **Reliable**: Robust error handling and validation ensures quality

## Future Enhancements

### Advanced Features
- Version deprecation policies
- Automated dependency tracking
- Cross-SDK compatibility matrices

### Integration Improvements
- Webhook alternatives to repository dispatch
- Enhanced caching mechanisms
- Multi-region gist replication

### Community Features
- SDK collection ratings and reviews
- Usage analytics and metrics
- Collaborative development tools

## Conclusion

The gist-based modular architecture provides a robust, scalable foundation for the Defense Builders SDK ecosystem. By eliminating central bottlenecks and race conditions while maintaining quality standards, this architecture enables sustainable community-driven growth while preserving operational excellence.