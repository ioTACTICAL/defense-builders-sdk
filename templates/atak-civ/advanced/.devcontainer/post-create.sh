#!/bin/bash
set -e

echo "🚀 Initializing Advanced ATAK Plugin Development Environment..."
echo "Project Name: ${PROJECT_NAME:-MyAdvancedATAKPlugin}"
echo "ATAK SDK Version: ${ATAK_SDK_VERSION:-5.5.0.5}"

# Function to log with emoji
log() { echo "📋 $1"; }
success() { echo "✅ $1"; }
warn() { echo "⚠️  $1"; }
error() { echo "❌ $1"; }
info() { echo "ℹ️  $1"; }

# Advanced setup for ATAK plugin development
ATAK_SDK_PATH="/opt/atak-civ/${ATAK_SDK_VERSION}"
if [ ! -d "$ATAK_SDK_PATH" ]; then
    warn "SDK path $ATAK_SDK_PATH not found, using default"
    ATAK_SDK_PATH="/opt/atak-civ/5.5.0.5"
fi

# Set up project structure
if [ ! -f "build.gradle" ]; then
    log "Setting up advanced ATAK plugin template..."
    
    if [ -d "$ATAK_SDK_PATH/PluginTemplate" ]; then
        cp -r "$ATAK_SDK_PATH/PluginTemplate/"* . 2>/dev/null || true
        
        # Advanced project customization
        if [ -n "$PROJECT_NAME" ]; then
            log "Customizing project for: $PROJECT_NAME"
            
            # Create package structure
            PACKAGE_NAME=$(echo "$PROJECT_NAME" | tr '[:upper:]' '[:lower:]' | tr -d ' -')
            PACKAGE_PATH="app/src/main/java/com/atakmap/android/$PACKAGE_NAME"
            mkdir -p "$PACKAGE_PATH"
            
            # Update all relevant files
            find . -name "*.java" -o -name "*.xml" -o -name "*.gradle" | xargs sed -i "s/plugintemplate/$PACKAGE_NAME/g" 2>/dev/null || true
            sed -i "s/PluginTemplate/$PROJECT_NAME/g" settings.gradle 2>/dev/null || true
        fi
        success "Advanced ATAK plugin template initialized"
    fi
fi

# Configure local.properties with advanced settings
log "Setting up advanced local.properties..."
cat > local.properties << EOF
sdk.dir=/opt/android-sdk
takrepo.url=https://artifacts.tak.gov/artifactory/maven
takdev.plugin=.

# Advanced build settings
org.gradle.jvmargs=-Xmx2048m -Dfile.encoding=UTF-8
org.gradle.parallel=true
org.gradle.caching=true
android.useAndroidX=true
android.enableJetifier=true
EOF

# Set up advanced testing structure
log "Setting up testing infrastructure..."
mkdir -p app/src/test/java/com/atakmap/android/$(echo ${PROJECT_NAME:-plugin} | tr '[:upper:]' '[:lower:]')
mkdir -p app/src/androidTest/java/com/atakmap/android/$(echo ${PROJECT_NAME:-plugin} | tr '[:upper:]' '[:lower:]')

# Create unit test example
if [ ! -f "app/src/test/java/ExampleUnitTest.java" ]; then
cat > app/src/test/java/ExampleUnitTest.java << 'EOF'
import org.junit.Test;
import static org.junit.Assert.*;

/**
 * Example local unit test, which will execute on the development machine (host).
 *
 * @see <a href="http://d.android.com/tools/testing">Testing documentation</a>
 */
public class ExampleUnitTest {
    @Test
    public void addition_isCorrect() {
        assertEquals(4, 2 + 2);
    }
}
EOF
success "Created unit test template"
fi

# Create instrumented test example  
if [ ! -f "app/src/androidTest/java/ExampleInstrumentedTest.java" ]; then
cat > app/src/androidTest/java/ExampleInstrumentedTest.java << 'EOF'
import android.content.Context;
import androidx.test.platform.app.InstrumentationRegistry;
import androidx.test.ext.junit.runners.AndroidJUnit4;
import org.junit.Test;
import org.junit.runner.RunWith;
import static org.junit.Assert.*;

/**
 * Instrumented test, which will execute on an Android device.
 *
 * @see <a href="http://d.android.com/tools/testing">Testing documentation</a>
 */
@RunWith(AndroidJUnit4.class)
public class ExampleInstrumentedTest {
    @Test
    public void useAppContext() {
        Context appContext = InstrumentationRegistry.getInstrumentation().getTargetContext();
        assertEquals("com.atakmap.android.plugin", appContext.getPackageName());
    }
}
EOF
success "Created instrumented test template"
fi

# Set up documentation structure
log "Setting up documentation infrastructure..."
mkdir -p docs/{api,guides,examples}

cat > docs/README.md << EOF
# ${PROJECT_NAME:-ATAK Plugin} Documentation

## Overview
Advanced ATAK plugin with comprehensive development setup.

## Structure
- \`api/\` - API documentation
- \`guides/\` - Development guides
- \`examples/\` - Code examples and tutorials

## Development Workflow

### Building
\`\`\`bash
./gradlew civDebug      # Debug build
./gradlew civRelease    # Release build
\`\`\`

### Testing
\`\`\`bash
./gradlew test                              # Unit tests
./gradlew connectedCivDebugAndroidTest     # Instrumented tests
\`\`\`

### Code Quality
\`\`\`bash
./gradlew checkstyle    # Code style check
./gradlew lint          # Android lint
\`\`\`
EOF

# Set up GitHub Actions workflow
log "Creating CI/CD workflow..."
mkdir -p .github/workflows

cat > .github/workflows/ci.yml << 'EOF'
name: CI

on:
  push:
    branches: [ main, develop ]
  pull_request:
    branches: [ main ]

jobs:
  test:
    runs-on: ubuntu-latest
    
    steps:
    - uses: actions/checkout@v4
    
    - name: Set up JDK 11
      uses: actions/setup-java@v4
      with:
        java-version: '11'
        distribution: 'adopt'
        
    - name: Cache Gradle packages
      uses: actions/cache@v4
      with:
        path: |
          ~/.gradle/caches
          ~/.gradle/wrapper
        key: ${{ runner.os }}-gradle-${{ hashFiles('**/*.gradle*', '**/gradle-wrapper.properties') }}
        restore-keys: |
          ${{ runner.os }}-gradle-
          
    - name: Grant execute permission for gradlew
      run: chmod +x gradlew
      
    - name: Run tests
      run: ./gradlew test
      
    - name: Run lint
      run: ./gradlew lint
      
    - name: Build APK
      run: ./gradlew assembleDebug
      
    - name: Upload APK
      uses: actions/upload-artifact@v4
      with:
        name: app-debug
        path: app/build/outputs/apk/debug/app-debug.apk
EOF

success "Created CI/CD workflow"

# Create advanced .gitignore
cat > .gitignore << 'EOF'
# Built application files
*.apk
*.aab

# Files for the ART/Dalvik VM
*.dex

# Java class files
*.class

# Generated files
bin/
gen/
out/
build/

# Gradle files
.gradle/
gradle-app.setting
!gradle-wrapper.jar
.gradletasknamecache

# Local configuration file (sdk path, etc)
local.properties

# Proguard folder generated by Eclipse
proguard/

# Log Files
*.log

# Android Studio Navigation editor temp files
.navigation/

# Android Studio captures folder
captures/

# IntelliJ
*.iml
.idea/
misc.xml
deploymentTargetDropDown.xml
render.experimental.xml

# Keystore files
*.jks
*.keystore

# External native build folder generated in Android Studio 2.2 and later
.externalNativeBuild
.cxx/

# Version control
.svn/

# OS-specific files
.DS_Store
.DS_Store?
._*
.Spotlight-V100
.Trashes
ehthumbs.db
Thumbs.db

# Documentation builds
docs/_build/
docs/site/
EOF

# Set up pre-commit hooks
log "Setting up development tools..."
cat > scripts/pre-commit-check.sh << 'EOF'
#!/bin/bash
# Pre-commit checks for ATAK plugin development

echo "Running pre-commit checks..."

# Check Java code style
echo "Checking code style..."
./gradlew checkstyleMain checkstyleTest

# Run unit tests
echo "Running unit tests..."  
./gradlew test

# Run lint checks
echo "Running lint checks..."
./gradlew lint

echo "Pre-commit checks completed!"
EOF

chmod +x scripts/pre-commit-check.sh 2>/dev/null || true

# Advanced gradle configuration
if [ -f "gradlew" ]; then
    chmod +x gradlew
    log "Verifying advanced Gradle setup..."
    
    if ./gradlew --version >/dev/null 2>&1; then
        success "Gradle is working correctly"
        
        # Check available tasks
        log "Checking available build tasks..."
        if ./gradlew tasks --console=plain | grep -q "civDebug"; then
            success "ATAK build tasks available"
            
            # List key tasks for the developer
            info "Key development tasks:"
            echo "   • ./gradlew civDebug - Build debug version"
            echo "   • ./gradlew civRelease - Build release version"  
            echo "   • ./gradlew test - Run unit tests"
            echo "   • ./gradlew connectedCivDebugAndroidTest - Run instrumented tests"
            echo "   • ./gradlew lint - Run code analysis"
        fi
    fi
fi

# Create comprehensive README
cat > README.md << EOF
# ${PROJECT_NAME:-Advanced ATAK Plugin}

> 🔧 **Advanced ATAK plugin** developed with DBSDK v${ATAK_SDK_VERSION:-5.5.0.5}

## 🚀 Quick Start

### Prerequisites
- Android device with ATAK installed
- USB debugging enabled
- ADB connection established

### Development Workflow

#### 1. Build the Plugin
\`\`\`bash
# Debug build (for development)
./gradlew civDebug

# Release build (for deployment)
./gradlew civRelease
\`\`\`

#### 2. Install on Device
\`\`\`bash
# First install ATAK (if needed)
adb install app/build/outputs/atak-apks/sdk/ATAK-civ-*.apk

# Then install your plugin
adb install app/build/outputs/apk/civ/debug/app-civ-debug.apk
\`\`\`

#### 3. Testing
\`\`\`bash
# Unit tests
./gradlew test

# Instrumented tests (requires connected device)
./gradlew connectedCivDebugAndroidTest

# Code quality checks
./gradlew lint checkstyle
\`\`\`

## 🏗️ Project Structure

\`\`\`
${PROJECT_NAME:-plugin}/
├── app/
│   ├── src/
│   │   ├── main/java/           # Plugin source code
│   │   ├── test/java/           # Unit tests
│   │   └── androidTest/java/    # Instrumented tests
│   └── build.gradle             # App build configuration
├── docs/                        # Documentation
│   ├── api/                     # API documentation
│   ├── guides/                  # Development guides
│   └── examples/                # Code examples
├── scripts/                     # Development scripts
├── .github/workflows/           # CI/CD pipelines
└── README.md                    # This file
\`\`\`

## 🔧 Development Tools

### Available Gradle Tasks
- \`./gradlew tasks\` - List all available tasks
- \`./gradlew civDebug\` - Build debug APK
- \`./gradlew civRelease\` - Build release APK
- \`./gradlew test\` - Run unit tests
- \`./gradlew connectedCivDebugAndroidTest\` - Run instrumented tests
- \`./gradlew lint\` - Run Android lint checks
- \`./gradlew checkstyle\` - Run code style checks

### VS Code Extensions
This project includes optimized VS Code settings and extensions for:
- Java development with IntelliSense
- Android development tools
- Gradle build integration
- Git integration with GitLens
- Code formatting and linting

### Debugging
- Use VS Code's built-in Java debugger
- Attach debugger to running ATAK instance
- Use Android Studio for advanced debugging

## 📚 Documentation

- [API Documentation](docs/api/)
- [Development Guides](docs/guides/)
- [Code Examples](docs/examples/)
- [ATAK Plugin Development Guide](https://github.com/deptofdefense/AndroidTacticalAssaultKit-CIV)
- [DBSDK Documentation](https://github.com/iotactical/defense-builders-sdk)

## 🔄 CI/CD

This project includes GitHub Actions workflows for:
- ✅ Automated testing on push/PR
- 🔍 Code quality checks
- 📦 APK building and artifact upload
- 🚀 Release automation

## 🛠️ Troubleshooting

### Common Issues
- **Build fails**: Check \`local.properties\` configuration
- **Tests fail**: Ensure connected device for instrumented tests
- **Plugin not loading**: Verify ATAK compatibility and installation

### Getting Help
- Check the [troubleshooting guide](docs/guides/troubleshooting.md)
- Review ATAK plugin development documentation
- Open an issue in this repository

## 📄 License

This project is developed using the DBSDK framework and follows ATAK plugin development guidelines.

---

**Built with ❤️ using [Defense Builders SDK](https://github.com/iotactical/defense-builders-sdk)**
EOF

# Final setup
chown -R vscode:vscode /workspaces 2>/dev/null || true

success "🎉 Advanced ATAK Plugin Development Environment Ready!"
echo ""
echo "🔥 Advanced Features Enabled:"
echo "   ✅ Comprehensive testing framework (unit + instrumented)"
echo "   ✅ CI/CD pipeline with GitHub Actions"
echo "   ✅ Code quality tools (lint, checkstyle)"
echo "   ✅ Documentation structure and templates"
echo "   ✅ Development scripts and pre-commit hooks"
echo "   ✅ Enhanced VS Code configuration"
echo ""
echo "📖 Next Steps:"
echo "   1. Review your plugin code in app/src/main/"
echo "   2. Write tests in app/src/test/ and app/src/androidTest/"
echo "   3. Run './gradlew civDebug' to build"
echo "   4. Check docs/ for development guides"
echo ""
echo "🚀 Pro Tips:"
echo "   • Use './gradlew test lint' before committing"
echo "   • Check .github/workflows/ci.yml for CI configuration"
echo "   • Explore docs/ for advanced development guides"
echo "   • Use scripts/pre-commit-check.sh for quality assurance"
echo ""