# Defense Builders SDK (DBSDK)

> **🚀 Production Ready:** Automated versioned SDK containers with complete ATAK-CIV integration

Open source, auditable development environments for the defense community. Built with transparency, security, and scalability in mind.

[![Build Status](https://github.com/iotactical/defense-builders-sdk/workflows/Build%20Versioned%20ATAK-CIV%20SDKs/badge.svg)](https://github.com/iotactical/defense-builders-sdk/actions) [![Container Registry](https://img.shields.io/badge/registry-ghcr.io-blue)](https://github.com/orgs/iotactical/packages)

## Mission

Provide **authoritative, verifiable development environments** that enable defense contractors, first responders, and developers to build secure applications with confidence.

## Features

- **🔄 Automated Versioning**: Automatic discovery and building of multiple SDK versions
- **📦 Container Registry**: Ready-to-use images available at `ghcr.io/iotactical/*`
- **🔒 Security First**: SBOM generation, vulnerability scanning, hardened base images
- **🧩 Modular Architecture**: Extensible SDK framework supporting multiple defense platforms
- **⚡ Instant Launch**: One-click environment creation via [ioTACTICAL.co](https://iotactical.co)

## Architecture

```
DBSDK Base Image
├── Security baseline (SBOM, hardened container)
├── Privacy-first telemetry (config/versions only)  
├── Common tooling (Git, networking, dev tools)
└── Update mechanisms

SDK-Specific Layers
└── ATAK-CIV: Android Tactical Assault Kit (Civil)
```

## Available SDKs

### ATAK-CIV (Android Tactical Assault Kit - Civil)

Production-ready development environments for ATAK plugin development with automated versioning.

| SDK Version | Container Image | Features | Status |
|-------------|-----------------|----------|--------|
| **5.5.0.5** (Latest) | `ghcr.io/iotactical/dbsdk-atak-civ:5.5.0.5` | Enhanced DSM manager, improved docs | ✅ Active |
| **5.4.0.21** | `ghcr.io/iotactical/dbsdk-atak-civ:5.4.0.21` | Action bar APIs, Typst support | ✅ Active |
| **5.3.0.12** | `ghcr.io/iotactical/dbsdk-atak-civ:5.3.0.12` | Foundation release | ✅ Active |

**All versions include:**
- Java 11 (Adoptium OpenJDK)
- Android SDK with API 21+ support
- Pre-configured development tools
- Gradle 7.6 with ProGuard
- ATAK plugin development templates

## Quick Start

### Using with GitHub Codespaces
1. Visit [ioTACTICAL Marketplace](https://iotactical.co)
2. Select "Launch ATAK Environment"
3. Choose your SDK version
4. Click "Create Environment" - launches automatically!

### Using Locally
```bash
# Pull the latest ATAK-CIV development environment
docker pull ghcr.io/iotactical/dbsdk-atak-civ:5.5.0.5

# Run the development environment
docker run -it --rm \
  -v $(pwd):/workspace \
  -p 8080:8080 \
  ghcr.io/iotactical/dbsdk-atak-civ:5.5.0.5

# Or use latest tag (points to 5.5.0.5)
docker pull ghcr.io/iotactical/dbsdk-atak-civ:latest
```

### Quick Plugin Development
```bash
# Create a new ATAK plugin
mkdir my-atak-plugin && cd my-atak-plugin

# Run development environment with current directory mounted
docker run -it --rm \
  -v $(pwd):/workspaces/my-plugin \
  -p 8080:8080 \
  ghcr.io/iotactical/dbsdk-atak-civ:5.5.0.5
  
# Inside the container:
# - Copy plugin template: cp -r /opt/atak-civ/5.5.0.5/PluginTemplate/* .
# - Build: ./gradlew civDebug
# - Deploy to device: adb install app/build/outputs/atak-apks/sdk/*.apk
```

## Security & Compliance

- **Open Source**: All container definitions are publicly auditable
- **SBOM Included**: Software Bill of Materials for supply chain security
- **Regular Scanning**: Automated security vulnerability scanning
- **Hardened Base**: Minimal attack surface, security-first design
- **Privacy First**: Telemetry collects only configuration data, never source code

## Telemetry & Privacy

We collect **anonymous usage data** to improve the platform:

**What we collect:**
- SDK version and configuration
- Container performance metrics
- Feature usage analytics
- Error diagnostics (anonymized)

**What we NEVER collect:**
- Source code content
- Personal information
- Proprietary data
- Project details

## Versioning

### Container Images
- `ghcr.io/iotactical/dbsdk-base:latest` - Latest hardened base image
- `ghcr.io/iotactical/dbsdk-atak-civ:latest` - Latest ATAK-CIV SDK (→ 5.5.0.5)
- `ghcr.io/iotactical/dbsdk-atak-civ:5.5.0.5` - ATAK-CIV SDK v5.5.0.5
- `ghcr.io/iotactical/dbsdk-atak-civ:5.4.0.21` - ATAK-CIV SDK v5.4.0.21
- `ghcr.io/iotactical/dbsdk-atak-civ:5.3.0.12` - ATAK-CIV SDK v5.3.0.12

**Latest Status**: [VERSION_MATRIX.md](VERSION_MATRIX.md) | [Container Registry](https://github.com/orgs/iotactical/packages)

## Development

### Repository Structure

```
defense-builders-sdk/
├── .github/workflows/          # Automated CI/CD pipelines
├── base/                       # DBSDK base container definition
├── sdk-configs/                # SDK configuration files
│   └── atak-civ.conf          # ATAK-CIV specific settings
├── scripts/                    # Build automation scripts
│   ├── workflow-discover-versions.sh  # Version discovery
│   └── build-versioned-containers.sh  # Container building
└── lib/                        # Shared libraries
    └── sdk-discovery.sh        # SDK discovery framework
```

### CI/CD Pipeline

The project uses GitHub Actions for fully automated versioned container builds:

1. **Version Discovery**: Automatically scans repositories to find SDK versions
2. **Matrix Builds**: Builds all discovered versions in parallel
3. **Security Scanning**: Runs Trivy vulnerability scans on all images
4. **Registry Push**: Publishes to GitHub Container Registry
5. **Documentation**: Auto-updates version matrices and README

**Triggers:**
- Push to main branch (sdk-configs, scripts changes)
- Manual workflow dispatch
- Scheduled builds for security updates

### Local Development

```bash
# Clone the repository
git clone https://github.com/iotactical/defense-builders-sdk.git
cd defense-builders-sdk

# Build base image
docker buildx build -t dbsdk-base:local ./base

# Build ATAK-CIV SDK containers
./scripts/build-versioned-containers.sh build

# Test specific version
docker run -it --rm ghcr.io/iotactical/dbsdk-atak-civ:5.5.0.5
```

### Adding New SDKs

1. Create SDK configuration file in `sdk-configs/`
2. Add discovery function for version detection
3. Define Dockerfile generation function
4. Update CI workflow triggers
5. Test and deploy

See [CONTRIBUTING.md](CONTRIBUTING.md) for detailed guidelines.

## Contributing

We welcome contributions from the defense development community!

See [CONTRIBUTING.md](CONTRIBUTING.md) for detailed guidelines.

## License

MIT License - See [LICENSE](LICENSE) for details.

Open source to enable community verification and trust.

## Links

- **Website**: [iotactical.co](https://iotactical.co)
- **Container Registry**: [ghcr.io/iotactical](https://github.com/orgs/iotactical/packages)
- **Documentation**: [docs.iotactical.co](https://docs.iotactical.co)
- **Support**: [support@iotactical.co](mailto:support@iotactical.co)

---

*Empowering the defense community with secure, open development environments.*