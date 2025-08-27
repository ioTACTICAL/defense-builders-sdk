#!/bin/bash
# DBSDK Versioned Container Builder
# Builds version-specific ATAK-CIV containers with automated Dockerfile generation
# https://github.com/iotactical/defense-builders-sdk

set -e

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
BUILD_CONTEXT="$REPO_ROOT"
REGISTRY="ghcr.io/iotactical"
SDK_DOWNLOADS="$HOME/Downloads"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() { echo -e "${BLUE}ℹ${NC} $1"; }
log_success() { echo -e "${GREEN}✓${NC} $1"; }
log_warn() { echo -e "${YELLOW}⚠${NC} $1"; }
log_error() { echo -e "${RED}✗${NC} $1"; }

# Framework logging functions for compatibility with SDK config functions
framework_log_debug() { log_info "DEBUG: $1"; }
framework_log_info() { log_info "$1"; }  
framework_log_warn() { log_warn "$1"; }
framework_log_error() { log_error "$1"; }
framework_log_success() { log_success "$1"; }

# Discover available SDK versions
discover_versions() {
    local versions=()
    for sdk_file in "$SDK_DOWNLOADS"/ATAK-CIV-*.zip; do
        if [[ -f "$sdk_file" ]]; then
            local filename=$(basename "$sdk_file")
            local version=$(echo "$filename" | sed -E 's/ATAK-CIV-([0-9]+\.[0-9]+\.[0-9]+\.[0-9]+)-SDK\.zip/\1/')
            if [[ "$version" != "$filename" ]]; then
                versions+=("$version")
            fi
        fi
    done
    printf '%s\n' "${versions[@]}" | sort -V
}

# Generate version-specific Dockerfile
generate_dockerfile() {
    local version="$1"
    local dockerfile_path="$2"
    
    # Load ATAK-CIV configuration to use proper settings
    local config_file="$REPO_ROOT/sdk-configs/atak-civ.conf"
    if [[ -f "$config_file" ]]; then
        source "$config_file"
        
        # Use the custom Dockerfile generation function if available
        if declare -F "generate_atak_civ_dockerfile" >/dev/null 2>&1; then
            log_info "Using custom Dockerfile generator with Java ${SDK_JAVA_VERSION}"
            generate_atak_civ_dockerfile "$version" "$dockerfile_path"
            return 0
        fi
    fi
    
    log_warn "Using fallback hardcoded Dockerfile generator"
    
    cat > "$dockerfile_path" << EOF
# Defense Builders SDK - ATAK-CIV v${version}
# Android Tactical Assault Kit (Civil) Development Environment
# https://github.com/iotactical/defense-builders-sdk

FROM ghcr.io/iotactical/dbsdk-base:latest

LABEL org.opencontainers.image.source="https://github.com/iotactical/defense-builders-sdk"
LABEL org.opencontainers.image.description="DBSDK ATAK-CIV v${version} Development Environment"
LABEL org.opencontainers.image.licenses="MIT"
LABEL org.opencontainers.image.version="${version}"

# ATAK-CIV specific environment
ENV DBSDK_SDK_TYPE=atak-civ
ENV DBSDK_SDK_VERSION=${version}
ENV ANDROID_HOME=/opt/android-sdk
ENV PATH=\$PATH:\$ANDROID_HOME/cmdline-tools/latest/bin:\$ANDROID_HOME/platform-tools
ENV JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64

USER root

# Install Java 17 and Android development tools
RUN apt-get update && apt-get install -y \\
    # Java 17 (LTS)
    openjdk-17-jdk \\
    # Android development dependencies  
    lib32stdc++6 \\
    lib32z1 \\
    libc6-i386 \\
    # Build tools
    maven \\
    # Additional utilities
    unzip \\
    wget \\
    zip \\
    && apt-get clean \\
    && rm -rf /var/lib/apt/lists/*

# Install Gradle manually (more reliable than apt package)
RUN wget -q https://services.gradle.org/distributions/gradle-8.5-bin.zip -O gradle.zip \\
    && unzip -q gradle.zip -d /opt \\
    && rm gradle.zip \\
    && ln -s /opt/gradle-8.5/bin/gradle /usr/local/bin/gradle

# Download and install Android SDK
RUN mkdir -p \$ANDROID_HOME/cmdline-tools && \\
    cd \$ANDROID_HOME/cmdline-tools && \\
    curl -o android-tools.zip https://dl.google.com/android/repository/commandlinetools-linux-8512546_latest.zip && \\
    unzip android-tools.zip && \\
    mv cmdline-tools latest && \\
    rm android-tools.zip

# Accept Android licenses and install required components
RUN yes | \$ANDROID_HOME/cmdline-tools/latest/bin/sdkmanager --licenses && \\
    \$ANDROID_HOME/cmdline-tools/latest/bin/sdkmanager \\
        "platform-tools" \\
        "platforms;android-30" \\
        "platforms;android-33" \\
        "build-tools;30.0.3" \\
        "build-tools;33.0.1"

# Create ATAK-CIV version-specific directories
RUN mkdir -p /opt/atak-civ/${version}

# Copy ATAK-CIV SDK v${version} (will be injected during build)
COPY sdks/atak-civ/v${version}/ATAK-CIV-${version}-SDK.zip /tmp/atak-sdk.zip

# Extract and install ATAK-CIV SDK
RUN cd /tmp && \\
    unzip -q atak-sdk.zip && \\
    mv ATAK-CIV-${version}-SDK/* /opt/atak-civ/${version}/ && \\
    rm -rf /tmp/atak-sdk.zip /tmp/ATAK-CIV-${version}-SDK && \\
    chown -R vscode:vscode /opt/atak-civ

# Copy ATAK-CIV specific scripts
COPY sdks/atak-civ/scripts/ /opt/dbsdk/atak-civ/scripts/
RUN chmod +x /opt/dbsdk/atak-civ/scripts/*

# Set up ATAK development environment with version-specific paths
RUN ATAK_SDK_PATH=/opt/atak-civ/${version} /opt/dbsdk/atak-civ/scripts/setup-atak.sh

# Create version-aware wrapper scripts
RUN echo '#!/bin/bash' > /usr/local/bin/atak-sdk-path && \\
    echo 'echo "/opt/atak-civ/${version}"' >> /usr/local/bin/atak-sdk-path && \\
    chmod +x /usr/local/bin/atak-sdk-path

# Switch back to vscode user
USER vscode

# Set working directory to workspaces
WORKDIR /workspaces

# ATAK-CIV version-specific health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=10s --retries=3 \\
    CMD /opt/dbsdk/atak-civ/scripts/healthcheck-atak.sh

# Version-specific welcome message
RUN echo 'echo "ATAK-CIV v${version} Development Environment Ready!"' >> ~/.bashrc && \\
    echo 'echo "ATAK-CIV SDK: /opt/atak-civ/${version}"' >> ~/.bashrc && \\
    echo 'echo "SDK Version: ${version}"' >> ~/.bashrc && \\
    echo 'echo "Start developing: Create your plugin in /workspaces"' >> ~/.bashrc && \\
    echo 'echo "Documentation: https://github.com/deptofdefense/AndroidTacticalAssaultKit-CIV"' >> ~/.bashrc

CMD ["/bin/bash"]
EOF

    log_success "Generated Dockerfile for ATAK-CIV v${version}"
}

# Prepare SDK file for build context
prepare_sdk_build_context() {
    local version="$1"
    local sdk_source="$SDK_DOWNLOADS/ATAK-CIV-${version}-SDK.zip"
    local version_dir="$REPO_ROOT/sdks/atak-civ/v${version}"
    
    if [[ ! -f "$sdk_source" ]]; then
        log_error "SDK zip file not found: $sdk_source"
        return 1
    fi
    
    log_info "Preparing build context for ATAK-CIV v${version}"
    
    # Create version-specific directory in build context
    mkdir -p "$version_dir"
    
    # Copy SDK zip to build context
    cp "$sdk_source" "$version_dir/"
    
    log_success "SDK v${version} prepared in build context"
}

# Build version-specific container
build_version_container() {
    local version="$1"
    local dockerfile_path="$REPO_ROOT/sdks/atak-civ/Dockerfile.v${version}"
    local image_tag="$REGISTRY/dbsdk-atak-civ:${version}"
    local latest_tag="$REGISTRY/dbsdk-atak-civ:latest"
    
    log_info "Building ATAK-CIV v${version} container"
    
    # Generate version-specific Dockerfile
    generate_dockerfile "$version" "$dockerfile_path"
    
    # Prepare SDK in build context
    prepare_sdk_build_context "$version"
    
    # Build the container
    log_info "Building image: $image_tag"
    
    # Build multi-architecture image
    docker buildx build \\
        --platform linux/amd64,linux/arm64 \\
        --file "$dockerfile_path" \\
        --tag "$image_tag" \\
        --tag "$latest_tag" \\
        --build-arg BUILD_DATE="$(date -u +%Y-%m-%dT%H:%M:%SZ)" \\
        --build-arg GIT_SHA="$(git rev-parse HEAD)" \\
        --build-arg SDK_VERSION="$version" \\
        --push \\
        "$BUILD_CONTEXT"
    
    if [[ $? -eq 0 ]]; then
        log_success "Successfully built and pushed: $image_tag"
    else
        log_error "Failed to build: $image_tag"
        return 1
    fi
    
    # Clean up version-specific Dockerfile
    rm -f "$dockerfile_path"
}

# Build all available versions
build_all_versions() {
    local versions=($(discover_versions))
    
    if [[ ${#versions[@]} -eq 0 ]]; then
        log_error "No ATAK-CIV SDK versions found in $SDK_DOWNLOADS"
        return 1
    fi
    
    log_info "Building ${#versions[@]} ATAK-CIV versions: ${versions[*]}"
    
    for version in "${versions[@]}"; do
        log_info "Processing version: $version"
        build_version_container "$version" || log_warn "Failed to build version $version"
    done
    
    log_success "Completed building all versions"
}

# Update GitHub Actions matrix
update_github_matrix() {
    local versions=($(discover_versions))
    local workflow_file="$REPO_ROOT/.github/workflows/build-versioned-sdks.yml"
    
    log_info "Generating GitHub Actions workflow for ${#versions[@]} versions"
    
    cat > "$workflow_file" << 'EOF'
name: Build Versioned ATAK-CIV SDKs

on:
  push:
    branches: [ main ]
    paths: 
      - 'sdks/atak-civ/**'
      - 'base/**'
      - 'scripts/build-versioned-containers.sh'
  pull_request:
    branches: [ main ]
    paths: 
      - 'sdks/atak-civ/**'
      - 'base/**'
  workflow_dispatch:
    inputs:
      version:
        description: 'Specific SDK version to build (leave empty for all)'
        required: false
        type: string

env:
  REGISTRY: ghcr.io
  REGISTRY_USER: ${{ github.actor }}
  REGISTRY_PASSWORD: ${{ github.token }}

jobs:
  discover-versions:
    runs-on: ubuntu-latest
    outputs:
      versions: ${{ steps.versions.outputs.versions }}
    steps:
    - uses: actions/checkout@v4
    
    - name: Discover SDK versions
      id: versions
      run: |
        # This would normally scan for SDK files, but for CI we'll use a static list
        # In production, this would be populated by the SDK discovery process
EOF

    # Add the versions matrix
    echo "        VERSIONS='[" >> "$workflow_file"
    local first=true
    for version in "${versions[@]}"; do
        if [[ "$first" == "true" ]]; then
            first=false
        else
            echo -n "," >> "$workflow_file"
        fi
        echo -n "\"$version\"" >> "$workflow_file"
    done
    echo "]'" >> "$workflow_file"
    
    cat >> "$workflow_file" << 'EOF'
        echo "versions=$VERSIONS" >> $GITHUB_OUTPUT
        echo "Discovered versions: $VERSIONS"

  build-base:
    runs-on: ubuntu-latest
    permissions:
      contents: read
      packages: write
      security-events: write
    steps:
    - uses: actions/checkout@v4
    
    - name: Set up Docker Buildx
      uses: docker/setup-buildx-action@v3
    
    - name: Log in to Container Registry
      uses: docker/login-action@v3
      with:
        registry: ${{ env.REGISTRY }}
        username: ${{ env.REGISTRY_USER }}
        password: ${{ env.REGISTRY_PASSWORD }}
    
    - name: Build and push base image
      uses: docker/build-push-action@v5
      with:
        context: .
        file: ./base/Dockerfile
        platforms: linux/amd64,linux/arm64
        push: true
        tags: |
          ${{ env.REGISTRY }}/${{ github.repository_owner }}/dbsdk-base:latest
          ${{ env.REGISTRY }}/${{ github.repository_owner }}/dbsdk-base:${{ github.sha }}
        build-args: |
          BUILD_DATE=${{ github.run_id }}
          GIT_SHA=${{ github.sha }}

  build-versioned-sdks:
    needs: [discover-versions, build-base]
    runs-on: ubuntu-latest
    if: github.event.inputs.version == '' || contains(fromJSON(needs.discover-versions.outputs.versions), github.event.inputs.version)
    permissions:
      contents: read
      packages: write
      security-events: write
    strategy:
      fail-fast: false
      matrix:
        version: ${{ fromJSON(needs.discover-versions.outputs.versions) }}
    steps:
    - uses: actions/checkout@v4
    
    - name: Set up Docker Buildx
      uses: docker/setup-buildx-action@v3
    
    - name: Log in to Container Registry
      uses: docker/login-action@v3
      with:
        registry: ${{ env.REGISTRY }}
        username: ${{ env.REGISTRY_USER }}
        password: ${{ env.REGISTRY_PASSWORD }}
    
    - name: Download ATAK-CIV SDK
      env:
        VERSION: ${{ matrix.version }}
      run: |
        echo "In production, this would download SDK v${VERSION} from secure storage"
        echo "For now, using placeholder SDK structure"
        mkdir -p sdks/atak-civ/v${VERSION}
        echo "PLACEHOLDER SDK v${VERSION}" > sdks/atak-civ/v${VERSION}/ATAK-CIV-${VERSION}-SDK.zip
    
    - name: Generate version-specific Dockerfile
      env:
        VERSION: ${{ matrix.version }}
      run: |
        ./scripts/build-versioned-containers.sh generate-dockerfile ${VERSION}
    
    - name: Build and push SDK image
      uses: docker/build-push-action@v5
      env:
        VERSION: ${{ matrix.version }}
      with:
        context: .
        file: ./sdks/atak-civ/Dockerfile.v${{ matrix.version }}
        platforms: linux/amd64,linux/arm64
        push: true
        tags: |
          ${{ env.REGISTRY }}/${{ github.repository_owner }}/dbsdk-atak-civ:${{ matrix.version }}
          ${{ env.REGISTRY }}/${{ github.repository_owner }}/dbsdk-atak-civ:latest
        build-args: |
          BUILD_DATE=${{ github.run_id }}
          GIT_SHA=${{ github.sha }}
          SDK_VERSION=${{ matrix.version }}
    
    - name: Run Trivy vulnerability scanner
      uses: aquasecurity/trivy-action@master
      with:
        image-ref: ${{ env.REGISTRY }}/${{ github.repository_owner }}/dbsdk-atak-civ:${{ matrix.version }}
        format: 'sarif'
        output: 'trivy-results-atak-civ-${{ matrix.version }}-${{ github.sha }}.sarif'
    
    - name: Upload Trivy scan results to GitHub Security tab
      uses: github/codeql-action/upload-sarif@v2
      if: always()
      with:
        sarif_file: 'trivy-results-atak-civ-${{ matrix.version }}-${{ github.sha }}.sarif'
        category: 'trivy-atak-civ-${{ matrix.version }}'
    
    - name: Generate SBOM
      uses: anchore/sbom-action@v0
      with:
        image: ${{ env.REGISTRY }}/${{ github.repository_owner }}/dbsdk-atak-civ:${{ matrix.version }}
        format: spdx-json
        output-file: sbom-atak-civ-${{ matrix.version }}.spdx.json
    
    - name: Upload SBOM artifact
      uses: actions/upload-artifact@v4
      with:
        name: sbom-atak-civ-${{ matrix.version }}
        path: sbom-atak-civ-${{ matrix.version }}.spdx.json
        retention-days: 30
EOF
    
    log_success "Generated GitHub Actions workflow: $workflow_file"
}

# Show help
show_help() {
    cat << EOF
DBSDK Versioned Container Builder

USAGE:
    build-versioned-containers.sh COMMAND [OPTIONS]

COMMANDS:
    discover                Discover available SDK versions
    build VERSION           Build specific version container
    build-all              Build all available versions
    generate-dockerfile VERSION    Generate Dockerfile for version
    update-matrix          Update GitHub Actions matrix
    
EXAMPLES:
    ./scripts/build-versioned-containers.sh discover
    ./scripts/build-versioned-containers.sh build 5.5.0.5
    ./scripts/build-versioned-containers.sh build-all
    ./scripts/build-versioned-containers.sh update-matrix

OPTIONS:
    -h, --help            Show this help message
    --registry REGISTRY   Override container registry (default: ghcr.io/iotactical)

ENVIRONMENT:
    SDK_DOWNLOADS         Directory containing SDK zip files (default: ~/Downloads)
EOF
}

# Main function
main() {
    local command="$1"
    shift || true
    
    case "$command" in
        "discover")
            discover_versions
            ;;
        "build")
            local version="$1"
            if [[ -z "$version" ]]; then
                log_error "Version required for build command"
                exit 1
            fi
            build_version_container "$version"
            ;;
        "build-all")
            build_all_versions
            ;;
        "generate-dockerfile")
            local version="$1"
            if [[ -z "$version" ]]; then
                log_error "Version required for generate-dockerfile command"
                exit 1
            fi
            local dockerfile="$REPO_ROOT/sdks/atak-civ/Dockerfile.v${version}"
            generate_dockerfile "$version" "$dockerfile"
            log_info "Generated: $dockerfile"
            ;;
        "update-matrix")
            update_github_matrix
            ;;
        "-h"|"--help"|"help")
            show_help
            ;;
        "")
            log_error "Command required"
            show_help
            exit 1
            ;;
        *)
            log_error "Unknown command: $command"
            show_help
            exit 1
            ;;
    esac
}

main "$@"