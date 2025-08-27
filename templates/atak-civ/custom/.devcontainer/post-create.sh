#!/bin/bash
set -e

echo "🛠️  Initializing Custom ATAK Plugin Development Environment..."
echo "Project Name: ${PROJECT_NAME:-CustomATAKPlugin}"
echo "ATAK SDK Version: ${ATAK_SDK_VERSION:-5.5.0.5}"

# Function to log with emoji
log() { echo "📋 $1"; }
success() { echo "✅ $1"; }
info() { echo "ℹ️  $1"; }

# Minimal setup for custom ATAK plugin development
log "Setting up minimal ATAK development environment..."

# Create basic local.properties
if [ ! -f "local.properties" ]; then
    log "Creating basic local.properties..."
    cat > local.properties << EOF
sdk.dir=/opt/android-sdk
takrepo.url=https://artifacts.tak.gov/artifactory/maven
takdev.plugin=.
EOF
    success "Created local.properties"
fi

# Create basic .gitignore
if [ ! -f ".gitignore" ]; then
    log "Creating basic .gitignore..."
    cat > .gitignore << EOF
# Build outputs
build/
*.apk
*.aab

# IDE files
.idea/
*.iml

# Local config
local.properties

# Logs
*.log

# OS generated files
.DS_Store
Thumbs.db
EOF
    success "Created .gitignore"
fi

# Create README with customization guidance
if [ ! -f "README.md" ]; then
    log "Creating customization guide..."
    cat > README.md << EOF
# ${PROJECT_NAME:-Custom ATAK Plugin}

> 🛠️  **Custom ATAK plugin** environment - ready for your customization!

## Environment Information
- **ATAK SDK Version**: ${ATAK_SDK_VERSION:-5.5.0.5}
- **Java**: OpenJDK 11
- **Android SDK**: API 21, 30, 33
- **Build Tools**: Gradle 7.6

## Getting Started

### Option 1: Copy ATAK Plugin Template
\`\`\`bash
# Copy the official plugin template
cp -r /opt/atak-civ/${ATAK_SDK_VERSION:-5.5.0.5}/PluginTemplate/* .

# Make gradlew executable
chmod +x gradlew

# Build the template
./gradlew civDebug
\`\`\`

### Option 2: Start from Scratch
\`\`\`bash
# Create your own project structure
mkdir -p app/src/main/java/com/yourcompany/yourplugin
mkdir -p app/src/main/res

# Create your build.gradle, AndroidManifest.xml, etc.
\`\`\`

### Option 3: Import Existing Project
\`\`\`bash
# Copy your existing plugin files here
# Update local.properties if needed
# Run your build commands
\`\`\`

## Available Resources

### ATAK SDK Location
- **SDK Path**: \`/opt/atak-civ/${ATAK_SDK_VERSION:-5.5.0.5}/\`
- **Plugin Template**: \`/opt/atak-civ/${ATAK_SDK_VERSION:-5.5.0.5}/PluginTemplate/\`
- **Documentation**: \`/opt/atak-civ/${ATAK_SDK_VERSION:-5.5.0.5}/ATAK_Plugin_Development_Guide.pdf\`

### Development Tools
- **Java**: \`/usr/lib/jvm/msopenjdk-current/bin/java\`
- **Android SDK**: \`/opt/android-sdk/\`
- **Gradle**: Available via \`./gradlew\` or \`gradle\`
- **ADB**: Available in PATH

## Common Commands

\`\`\`bash
# Check Java version
java -version

# Check Android SDK
/opt/android-sdk/cmdline-tools/latest/bin/sdkmanager --list

# List connected devices
adb devices

# Build debug (if using template)
./gradlew civDebug

# Install APK (if using template)
adb install app/build/outputs/apk/civ/debug/app-civ-debug.apk
\`\`\`

## Customization Ideas

### VS Code Extensions
Add extensions to your \`.devcontainer/devcontainer.json\`:
\`\`\`json
"customizations": {
  "vscode": {
    "extensions": [
      "ms-python.python",
      "ms-vscode.cmake-tools",
      "ms-vscode.cpptools"
    ]
  }
}
\`\`\`

### Additional Tools
Install additional tools in a custom \`post-create.sh\`:
\`\`\`bash
# Install Node.js
curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
sudo apt-get install -y nodejs

# Install Python packages
pip install requests beautifulsoup4

# Install custom tools
# ...
\`\`\`

### Environment Variables
Set custom environment variables in \`.devcontainer/devcontainer.json\`:
\`\`\`json
"remoteEnv": {
  "CUSTOM_VAR": "custom_value",
  "DEBUG_MODE": "true"
}
\`\`\`

## Documentation & Resources

- [ATAK Plugin Development Guide](https://github.com/deptofdefense/AndroidTacticalAssaultKit-CIV)
- [Android Development Docs](https://developer.android.com/docs)
- [DBSDK Documentation](https://github.com/iotactical/defense-builders-sdk)

## Need Help?

This is a **minimal setup** designed for customization. For pre-configured environments, consider:
- **Basic Template**: Ready-to-go plugin development
- **Advanced Template**: Full testing, CI/CD, and tooling setup

---

**Happy customizing! 🚀**
EOF
    success "Created customization guide"
fi

# Set proper permissions
chown -R vscode:vscode /workspaces 2>/dev/null || true

success "🎉 Custom ATAK Development Environment Ready!"
echo ""
echo "🛠️  Environment Summary:"
echo "   • ATAK SDK v${ATAK_SDK_VERSION:-5.5.0.5} available at /opt/atak-civ/${ATAK_SDK_VERSION:-5.5.0.5}/"
echo "   • Java 11, Android SDK, Gradle configured"
echo "   • Minimal VS Code setup with Java extensions"
echo "   • Ready for your custom configuration"
echo ""
echo "📖 Next Steps:"
echo "   1. Check README.md for customization options"
echo "   2. Copy plugin template: cp -r /opt/atak-civ/${ATAK_SDK_VERSION:-5.5.0.5}/PluginTemplate/* ."
echo "   3. Or start building your custom setup!"
echo ""
echo "💡 Pro Tips:"
echo "   • Explore /opt/atak-civ/${ATAK_SDK_VERSION:-5.5.0.5}/ for SDK resources"
echo "   • Modify .devcontainer/devcontainer.json to add tools and extensions"
echo "   • Use README.md as your customization guide"
echo ""