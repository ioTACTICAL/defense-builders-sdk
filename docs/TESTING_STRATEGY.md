# Gist-Based Architecture Testing Strategy

## Overview

This document outlines the testing strategy to validate the gist-based modular architecture before production deployment. The strategy ensures workflow repeatability, gist accessibility, schema compliance, and end-to-end integration.

## Testing Phases

### Phase 1: Local Schema Validation

**Objective**: Verify generated JSON matches expected schema structure

**Tests**:
1. **JSON Schema Validation**
   - Validate atak-civ generated JSON against defense-builders-sdk schema
   - Test edge cases: single version, multiple versions, missing fields
   - Verify template structure compliance

2. **Schema Evolution Testing**
   - Test backward compatibility with existing registry format
   - Validate new fields don't break existing consumers
   - Ensure required fields are present

**Commands**:
```bash
# Test atak-civ JSON generation
cd /home/ryan/code/github.com/iotactical/atak-civ
./test-schema-validation.sh

# Test defense-builders-sdk schema
cd /home/ryan/code/github.com/iotactical/defense-builders-sdk
npm install -g ajv-cli
ajv validate -s schema/sdk-versions-schema.json -d test-data/atak-civ-sample.json
```

### Phase 2: GitHub Authentication Testing

**Objective**: Verify GitHub App token permissions and gist operations

**Prerequisites**:
- Test GitHub App token with required scopes (repo, gist, workflow)
- Test organization access permissions

**Tests**:
1. **Gist Operations**
   - Create gist with test data
   - Update existing gist
   - Verify gist visibility (public)
   - Test error handling for invalid tokens

2. **Repository Dispatch**
   - Test triggering defense-builders-sdk workflow
   - Verify payload structure
   - Test error handling for failed dispatches

**Commands**:
```bash
# Test gist creation (requires GIST_TOKEN)
./test-gist-operations.sh

# Test repository dispatch
./test-repo-dispatch.sh
```

### Phase 3: SDK-Init Template Validation

**Objective**: Ensure sdk-init generates compliant workflows for different SDK types

**Tests**:
1. **Template Generation**
   - Generate workflows for each SDK type (mobile-android, desktop, server, web)
   - Verify Handlebars template compilation
   - Test variable substitution

2. **Workflow Structure**
   - Validate generated YAML syntax
   - Check job dependencies
   - Verify environment variable usage

**Commands**:
```bash
cd /home/ryan/code/github.com/iotactical/sdk-init
npm test -- --grep "template-generation"
./test-template-validation.sh
```

### Phase 4: Defense-Builders-SDK Aggregation Testing

**Objective**: Verify gist discovery and aggregation functionality

**Tests**:
1. **Gist Discovery**
   - Test GitHub API pagination for multiple gists
   - Verify naming pattern matching (sdk-versions-*.json)
   - Test error handling for malformed gists

2. **Aggregation Logic**
   - Test merging multiple SDK collections
   - Verify conflict resolution (duplicate SDK names)
   - Test validation of aggregated registry

**Commands**:
```bash
cd /home/ryan/code/github.com/iotactical/defense-builders-sdk
./test-gist-aggregation.sh
```

### Phase 5: End-to-End Integration Testing

**Objective**: Validate complete workflow from SDK collection to registry update

**Test Scenarios**:
1. **New SDK Collection**
   - Use sdk-init to create test repository
   - Trigger build-and-register workflow
   - Verify gist creation and defense-builders-sdk trigger

2. **Existing SDK Update**
   - Modify atak-civ structure (add/remove version)
   - Trigger workflow and verify gist update
   - Confirm aggregated registry reflects changes

3. **Multiple SDK Collections**
   - Test concurrent updates from multiple repositories
   - Verify no race conditions or conflicts
   - Confirm all collections appear in final registry

## Test Environment Setup

### Required Secrets
- `GIST_TOKEN`: GitHub App token with required permissions
- `TEST_GIST_PREFIX`: Prefix for test gists (e.g., "test-sdk-versions-")

### Test Data Structure
```
defense-builders-sdk/
├── test-data/
│   ├── sample-gists/
│   │   ├── sdk-versions-atak-civ.json
│   │   ├── sdk-versions-wintak.json
│   │   └── sdk-versions-custom.json
│   ├── expected-outputs/
│   │   └── aggregated-registry.json
│   └── test-schemas/
│       └── invalid-schema-examples.json
├── test-scripts/
│   ├── test-schema-validation.sh
│   ├── test-gist-operations.sh
│   ├── test-repo-dispatch.sh
│   └── test-gist-aggregation.sh
└── docs/
    └── TESTING_STRATEGY.md
```

## Validation Checklist

### Before Production Deployment

- [ ] All schema validation tests pass
- [ ] GitHub App token has correct permissions
- [ ] Gist operations work (create/update/read)
- [ ] Repository dispatch triggers successfully
- [ ] SDK-init templates generate valid workflows
- [ ] Defense-builders-sdk can discover and aggregate gists
- [ ] End-to-end workflow completes without errors
- [ ] Multiple SDK collections don't conflict
- [ ] Error handling works for common failure scenarios

### Production Readiness Criteria

1. **Functionality**
   - All tests pass in CI environment
   - Manual end-to-end test successful
   - Error scenarios handled gracefully

2. **Performance**
   - Gist operations complete within timeout limits
   - Aggregation scales to expected number of SDK collections
   - Workflow execution times acceptable

3. **Security**
   - GitHub App token has minimal required permissions
   - No sensitive data in gists or logs
   - Authentication errors handled securely

4. **Maintainability**
   - Documentation is complete and accurate
   - Test suite covers critical paths
   - Monitoring and alerting configured

## Risk Mitigation

### Rollback Plan
- Keep deprecated workflows (.deprecated extension) until new system proven
- Maintain manual registry update capability as backup
- Document quick revert process

### Monitoring
- Track gist update frequency and success rates
- Monitor defense-builders-sdk aggregation job success
- Alert on schema validation failures

### Gradual Deployment
1. Deploy to test environment first
2. Migrate atak-civ as pilot SDK collection
3. Monitor for 48 hours before expanding
4. Gradually onboard additional SDK collections

## Success Metrics

- Zero race conditions in registry updates
- 100% schema validation pass rate
- <5 minute end-to-end workflow completion
- Successful aggregation of multiple SDK collections
- Error recovery within defined SLAs