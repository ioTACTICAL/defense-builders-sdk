#!/bin/bash
set -e

echo "🚀 Initializing ATAK Plugin Development Environment..."
echo "Project Name: ${PROJECT_NAME:-MyATAKPlugin}"
echo "ATAK SDK Version: ${ATAK_SDK_VERSION:-5.5.0.5}"

# Function to log with emoji
log() { echo "📋 $1"; }
success() { echo "✅ $1"; }
warn() { echo "⚠️  $1"; }
error() { echo "❌ $1"; }

# Set up project from ATAK template
if [ ! -f "build.gradle" ]; then
    log "Setting up ATAK plugin template..."
    
    # Find the correct SDK path based on version
    ATAK_SDK_PATH="/opt/atak-civ/${ATAK_SDK_VERSION}"
    if [ ! -d "$ATAK_SDK_PATH" ]; then
        warn "SDK path $ATAK_SDK_PATH not found, using default"
        ATAK_SDK_PATH="/opt/atak-civ/5.5.0.5"
    fi
    
    if [ -d "$ATAK_SDK_PATH/PluginTemplate" ]; then
        log "Copying plugin template from $ATAK_SDK_PATH/PluginTemplate"
        cp -r "$ATAK_SDK_PATH/PluginTemplate/"* . 2>/dev/null || true
        
        # Customize project name in files
        if [ -n "$PROJECT_NAME" ]; then
            log "Customizing project name to: $PROJECT_NAME"
            
            # Update settings.gradle
            if [ -f "settings.gradle" ]; then
                sed -i "s/PluginTemplate/${PROJECT_NAME}/g" settings.gradle
            fi
            
            # Update AndroidManifest.xml
            if [ -f "app/src/main/AndroidManifest.xml" ]; then
                sed -i "s/com\.atakmap\.android\.plugintemplate/com.atakmap.android.$(echo $PROJECT_NAME | tr '[:upper:]' '[:lower:]')/g" app/src/main/AndroidManifest.xml
            fi
            
            # Update package names in source files
            find app/src -name "*.java" -exec sed -i "s/plugintemplate/$(echo $PROJECT_NAME | tr '[:upper:]' '[:lower:]')/g" {} \; 2>/dev/null || true
        fi
        success "ATAK plugin template initialized"
    else
        warn "Plugin template not found, creating minimal project structure"
        mkdir -p app/src/main/java/com/atakmap/android/$(echo ${PROJECT_NAME:-myplugin} | tr '[:upper:]' '[:lower:]')
    fi
fi

# Configure local.properties for ATAK development
if [ ! -f "local.properties" ]; then
    log "Creating local.properties..."
    cat > local.properties << EOF
sdk.dir=/opt/android-sdk
takrepo.url=https://artifacts.tak.gov/artifactory/maven
takdev.plugin=.
EOF
    success "Created local.properties"
fi

# Make gradlew executable
if [ -f "gradlew" ]; then
    chmod +x gradlew
    success "Made gradlew executable"
fi

# Set up git configuration
if [ ! -f ".gitignore" ]; then
    log "Creating .gitignore for ATAK plugin..."
    cat > .gitignore << EOF
# Build outputs
build/
app/build/
*.apk
*.aab

# IDE files
.idea/
*.iml
.vscode/settings.json

# Local config
local.properties

# Android
*.keystore
proguard/

# Logs
*.log

# OS generated files
.DS_Store
Thumbs.db
EOF
    success "Created .gitignore"
fi

# Create README for the project
if [ ! -f "README.md" ]; then
    log "Creating project README..."
    cat > README.md << EOF
# ${PROJECT_NAME:-ATAK Plugin}

ATAK plugin developed with DBSDK v${ATAK_SDK_VERSION:-5.5.0.5}.

## Quick Start

### Building the Plugin
\`\`\`bash
# Build debug version
./gradlew civDebug

# Build release version  
./gradlew civRelease
\`\`\`

### Installing on Device
\`\`\`bash
# Install ATAK first (APK will be in app/build/outputs/atak-apks/sdk/)
adb install app/build/outputs/atak-apks/sdk/ATAK-civ-*.apk

# Then install your plugin
adb install app/build/outputs/apk/civ/debug/app-civ-debug.apk
\`\`\`

### Development Tips
- Use \`civDebug\` build variant for development
- Plugin templates are located in \`app/src/main/java/\`
- Resources go in \`app/src/main/res/\`
- Test with \`./gradlew connectedCivDebugAndroidTest\`

## Documentation
- [ATAK Plugin Development Guide](https://github.com/deptofdefense/AndroidTacticalAssaultKit-CIV)
- [DBSDK Documentation](https://github.com/iotactical/defense-builders-sdk)

Built with ❤️ using [Defense Builders SDK](https://github.com/iotactical/defense-builders-sdk)
EOF
    success "Created README.md"
fi

# Verify Gradle setup
if [ -f "gradlew" ]; then
    log "Verifying Gradle setup..."
    if ./gradlew --version >/dev/null 2>&1; then
        success "Gradle is working correctly"
        
        # Run initial build check
        log "Running initial build verification..."
        if ./gradlew tasks --console=plain | grep -q "civDebug"; then
            success "ATAK build tasks available"
            
            # Optional: Run a quick build to verify everything works
            # Commented out to speed up container startup
            # ./gradlew assembleDebug --console=plain
        else
            warn "ATAK build tasks not found - please check your plugin configuration"
        fi
    else
        error "Gradle setup failed"
    fi
else
    warn "Gradle wrapper not found"
fi

# Final setup
log "Setting up development environment..."

# Ensure proper permissions
chown -R vscode:vscode /workspaces 2>/dev/null || true

success "🎉 ATAK Plugin Development Environment Ready!"
echo ""
echo "📖 Next Steps:"
echo "   1. Review your plugin code in app/src/main/"
echo "   2. Run './gradlew civDebug' to build your plugin"
echo "   3. Connect your Android device via ADB"
echo "   4. Install ATAK APK, then install your plugin APK"
echo ""
echo "🔧 Useful Commands:"
echo "   ./gradlew tasks                    - List all available tasks"
echo "   ./gradlew civDebug                 - Build debug version"
echo "   ./gradlew civRelease               - Build release version"
echo "   ./gradlew connectedCivDebugAndroidTest - Run tests"
echo "   adb devices                        - List connected devices"
echo ""
echo "🆘 Need Help?"
echo "   - Check README.md for detailed instructions"
echo "   - Visit: https://github.com/iotactical/defense-builders-sdk"
echo ""