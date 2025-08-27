# Contributing to Defense Builders SDK

Thank you for your interest in contributing to the Defense Builders SDK! This project serves the defense development community with secure, auditable development environments.

## Mission & Values

- **Security First**: All contributions undergo security review
- **Community Driven**: Open discussion and transparent processes
- **Defense Focus**: Solutions tailored for defense and first responder communities
- **Verification**: Everything must be auditable and verifiable

## Security Guidelines

### Before Contributing
- **No Secrets**: Never commit API keys, passwords, or sensitive information
- **Supply Chain**: Only use trusted, verified dependencies
- **Minimal Scope**: Keep changes focused and minimal
- **Documentation**: Document all security-relevant changes

### Security Review Process
1. All PRs undergo automated security scanning
2. Maintainers perform manual security review
3. Community review period for significant changes
4. Final approval from security team

## Development Setup

### Prerequisites
- Docker and Docker Buildx
- Git
- Basic understanding of containers and devcontainers

### Local Development
```bash
# Clone the repository
git clone https://github.com/iotactical/defense-builders-sdk.git
cd defense-builders-sdk

# Build base image locally
docker buildx build -t dbsdk-base:local ./base

# Build SDK image locally
docker buildx build -t dbsdk-atak-civ:local ./sdks/atak-civ

# Test the image
docker run -it --rm dbsdk-atak-civ:local
```

## Contribution Types

### Bug Fixes
- Fix security vulnerabilities
- Resolve container build issues
- Correct documentation errors

### New Features
- Add new SDK support
- Improve telemetry (privacy-first)
- Enhance security hardening
- Better developer experience

### Documentation
- Improve setup instructions
- Add troubleshooting guides
- Enhance security documentation

### Security Enhancements
- Container hardening improvements
- SBOM enhancements
- Vulnerability fixes
- Supply chain security

## Adding a New SDK

### 1. Plan Your SDK
- **Identify need**: What defense/first responder use case?
- **Security review**: What are the security implications?
- **Community input**: Discuss in GitHub Discussions first

### 2. Create SDK Configuration

**New Approach**: Create a configuration file in `sdk-configs/your-sdk.conf`:

```bash
# Required configuration functions
cat > sdk-configs/your-sdk.conf << 'EOF'
#!/bin/bash
# SDK Configuration for Your SDK

# Basic Information
SDK_NAME="your-sdk"
SDK_JAVA_VERSION="11"
SDK_GRADLE_VERSION="7.6"

# Version Discovery Function - REQUIRED
discover_your_sdk_versions() {
    # Implement version discovery logic
    echo "1.0.0"
    echo "1.1.0" 
}

# Dockerfile Generation Function - REQUIRED  
generate_your_sdk_dockerfile() {
    local version="$1"
    local dockerfile_path="$2"
    
    cat > "$dockerfile_path" << DOCKERFILE
FROM ghcr.io/iotactical/dbsdk-base:latest
ENV SDK_VERSION=${version}
# Your SDK setup here...
DOCKERFILE
}

# Build Context Preparation Function - REQUIRED
prepare_your_sdk_build_context() {
    local version="$1"
    local build_context="$2"
    
    # Prepare build context (download files, etc.)
    framework_log_info "Preparing Your SDK v$version"
    return 0
}
EOF
```

### 3. Update CI Workflow

Add your SDK to `.github/workflows/build-versioned-sdks.yml`:
```yaml
paths: 
  - 'sdk-configs/your-sdk.conf'
  # ... other SDK configs
```

### 4. SDK Requirements
- **Configuration File**: Must include all three required functions
- **Version Discovery**: Automatic detection of available SDK versions
- **Security**: Follow container hardening practices  
- **Documentation**: Clear setup and usage instructions
- **Testing**: Local build verification before PR submission

## Pull Request Process

### 1. Preparation
- Fork the repository
- Create feature branch: `git checkout -b feature/your-feature`
- Make your changes
- Test locally

### 2. Testing Requirements
- **Build Test**: Ensure images build successfully
- **Health Check**: Verify health checks pass
- **Security Scan**: No new vulnerabilities introduced
- **Documentation**: Update relevant docs

### 3. Pull Request Checklist
- [ ] **Security**: No secrets or sensitive information
- [ ] **Testing**: All tests pass locally
- [ ] **Documentation**: README and docs updated
- [ ] **Backwards Compatibility**: No breaking changes
- [ ] **SBOM**: Software Bill of Materials updated if needed

## Code Review Process

### Automated Checks
1. **Build Verification**: All images build successfully
2. **Security Scanning**: Trivy vulnerability scanning
3. **SBOM Generation**: Software Bill of Materials created
4. **Health Checks**: Container health verification

### Manual Review
1. **Security Review**: Maintainer security assessment
2. **Architecture Review**: Fits with DBSDK architecture
3. **Community Review**: Open for community feedback
4. **Final Approval**: Maintainer approval

## Telemetry Guidelines

### What We Collect (Anonymous)
- SDK version and configuration
- Container performance metrics  
- Feature usage analytics
- Error diagnostics (anonymized)

### What We Never Collect
- Source code content
- Personal information
- Proprietary data
- Project details

### Implementation
- Always privacy-first
- Opt-out capability required
- Transparent about data collection
- No tracking without consent

## Getting Help

### Community Support
- **GitHub Discussions**: General questions and ideas
- **GitHub Issues**: Bug reports and feature requests
- **Documentation**: [docs.iotactical.co](https://docs.iotactical.co)

### Direct Support
- **Security Issues**: [security@iotactical.co](mailto:security@iotactical.co)
- **General Support**: [support@iotactical.co](mailto:support@iotactical.co)
- **Enterprise**: [enterprise@iotactical.co](mailto:enterprise@iotactical.co)

## License

By contributing to this project, you agree that your contributions will be licensed under the MIT License.

---

*Thank you for helping build secure development environments for the defense community!*