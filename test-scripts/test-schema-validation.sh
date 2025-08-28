#!/bin/bash
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "=== Schema Validation Test Suite ==="

# Change to defense-builders-sdk directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"
cd "$REPO_DIR"

# Install validation tools if not present
if ! command -v ajv &> /dev/null; then
    echo -e "${YELLOW}Installing AJV CLI for schema validation...${NC}"
    npm install -g ajv-cli
fi

# Test 1: Validate existing schema syntax
echo -e "${YELLOW}Test 1: Validating schema syntax...${NC}"
if ajv compile -s schema/sdk-versions-schema.json > /dev/null 2>&1; then
    echo -e "${GREEN}✅ Schema syntax is valid${NC}"
else
    echo -e "${RED}❌ Schema syntax is invalid${NC}"
    exit 1
fi

# Test 2: Generate atak-civ JSON and validate
echo -e "${YELLOW}Test 2: Generating and validating atak-civ JSON...${NC}"

# Create atak-civ sample JSON (simulating workflow output)
ATAK_JSON=$(cat << 'EOF'
{
  "atak-civ": {
    "name": "ATAK CIV SDK",
    "description": "Android Team Awareness Kit Civilian SDK",
    "versions": [
      {
        "version": "5.3.0.12",
        "label": "5.3.0.12",
        "container": "ghcr.io/iotactical/dbsdk-atak-civ:5.3.0.12",
        "java_version": "11",
        "gradle_version": "7.6",
        "android_api": "30",
        "is_latest": false,
        "release_notes": "Legacy stable release for compatibility testing"
      },
      {
        "version": "5.5.0.5",
        "label": "5.5.0.5 (Latest)",
        "container": "ghcr.io/iotactical/dbsdk-atak-civ:5.5.0.5",
        "java_version": "11",
        "gradle_version": "7.6",
        "android_api": "30",
        "is_latest": true,
        "release_notes": "Latest stable release with enhanced features and bug fixes"
      }
    ],
    "templates": [
      {
        "id": "basic",
        "name": "Basic Plugin",
        "description": "Simple ATAK plugin with basic functionality and core SDK integration"
      },
      {
        "id": "advanced",
        "name": "Advanced Plugin",
        "description": "Complex plugin with UI components, data integration, and advanced ATAK features"
      }
    ]
  }
}
EOF
)

# Write to temporary file and validate
echo "$ATAK_JSON" > /tmp/test-atak-civ.json

if ajv validate -s schema/sdk-versions-schema.json -d /tmp/test-atak-civ.json; then
    echo -e "${GREEN}✅ ATAK-CIV JSON validates against schema${NC}"
else
    echo -e "${RED}❌ ATAK-CIV JSON validation failed${NC}"
    exit 1
fi

# Test 3: Test invalid JSON scenarios
echo -e "${YELLOW}Test 3: Testing invalid JSON rejection...${NC}"

# Invalid JSON - missing required fields
INVALID_JSON=$(cat << 'EOF'
{
  "test-sdk": {
    "name": "Test SDK",
    "versions": []
  }
}
EOF
)

echo "$INVALID_JSON" > /tmp/test-invalid.json

if ajv validate -s schema/sdk-versions-schema.json -d /tmp/test-invalid.json 2>/dev/null; then
    echo -e "${RED}❌ Invalid JSON was incorrectly accepted${NC}"
    exit 1
else
    echo -e "${GREEN}✅ Invalid JSON correctly rejected${NC}"
fi

# Test 4: Test multiple SDK collections in aggregated format
echo -e "${YELLOW}Test 4: Testing multiple SDK collections...${NC}"

MULTI_SDK_JSON=$(cat << 'EOF'
{
  "atak-civ": {
    "name": "ATAK CIV SDK",
    "description": "Android Team Awareness Kit Civilian SDK",
    "versions": [
      {
        "version": "5.5.0.5",
        "label": "5.5.0.5 (Latest)",
        "container": "ghcr.io/iotactical/dbsdk-atak-civ:5.5.0.5",
        "java_version": "11",
        "gradle_version": "7.6",
        "android_api": "30",
        "is_latest": true,
        "release_notes": "Latest stable release"
      }
    ],
    "templates": [
      {
        "id": "basic",
        "name": "Basic Plugin",
        "description": "Simple ATAK plugin"
      }
    ]
  },
  "wintak": {
    "name": "WinTAK SDK",
    "description": "Windows Team Awareness Kit SDK",
    "versions": [
      {
        "version": "4.8.0.1",
        "label": "4.8.0.1 (Latest)",
        "container": "ghcr.io/iotactical/dbsdk-wintak:4.8.0.1",
        "dotnet_version": "6.0",
        "windows_version": "2019",
        "is_latest": true,
        "release_notes": "Latest WinTAK release"
      }
    ],
    "templates": [
      {
        "id": "basic",
        "name": "Basic Plugin",
        "description": "Simple WinTAK plugin"
      }
    ]
  }
}
EOF
)

echo "$MULTI_SDK_JSON" > /tmp/test-multi-sdk.json

if ajv validate -s schema/sdk-versions-schema.json -d /tmp/test-multi-sdk.json; then
    echo -e "${GREEN}✅ Multiple SDK collections validate correctly${NC}"
else
    echo -e "${RED}❌ Multiple SDK collections validation failed${NC}"
    exit 1
fi

# Test 5: Test edge cases
echo -e "${YELLOW}Test 5: Testing edge cases...${NC}"

# Single version SDK
SINGLE_VERSION_JSON=$(cat << 'EOF'
{
  "test-single": {
    "name": "Single Version SDK",
    "description": "SDK with only one version",
    "versions": [
      {
        "version": "1.0.0",
        "label": "1.0.0 (Latest)",
        "container": "ghcr.io/iotactical/test-single:1.0.0",
        "is_latest": true,
        "release_notes": "Initial release"
      }
    ],
    "templates": [
      {
        "id": "minimal",
        "name": "Minimal Template",
        "description": "Minimal template"
      }
    ]
  }
}
EOF
)

echo "$SINGLE_VERSION_JSON" > /tmp/test-single.json

if ajv validate -s schema/sdk-versions-schema.json -d /tmp/test-single.json; then
    echo -e "${GREEN}✅ Single version SDK validates correctly${NC}"
else
    echo -e "${RED}❌ Single version SDK validation failed${NC}"
    exit 1
fi

# Cleanup
rm -f /tmp/test-*.json

echo ""
echo -e "${GREEN}🎉 All schema validation tests passed!${NC}"
echo ""
echo "Summary:"
echo "- ✅ Schema syntax validation"
echo "- ✅ ATAK-CIV JSON validation"
echo "- ✅ Invalid JSON rejection"
echo "- ✅ Multiple SDK collections support"
echo "- ✅ Edge cases handling"