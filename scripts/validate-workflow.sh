#!/bin/bash

# Validate workflow syntax using act or yamllint
set -e

echo "🔍 Validating GitHub workflow syntax..."

# Check if yamllint is available
if command -v yamllint &> /dev/null; then
    echo "Using yamllint for validation..."
    yamllint .github/workflows/build-versioned-sdks.yml
    echo "✅ Workflow YAML syntax is valid"
else
    echo "⚠️  yamllint not found. Checking basic YAML syntax with yq..."
    
    # Use yq for basic validation if available
    if command -v yq &> /dev/null; then
        yq eval . .github/workflows/build-versioned-sdks.yml > /dev/null
        echo "✅ Basic YAML syntax appears valid"
    else
        echo "⚠️  No YAML validation tools found. Please install yamllint or yq."
        echo "    sudo apt-get install yamllint"
        echo "    or"
        echo "    pip install yamllint"
    fi
fi

# Test the jq command used in the workflow
echo "🧪 Testing jq command for SDK versions..."
versions='["5.5.0.5","5.4.0.21","5.3.0.12"]'

jq -n \
  --argjson versions "$versions" \
  --arg registry "iotactical" \
  '{
    "atak-civ": {
      "name": "ATAK CIV SDK",
      "description": "Android Team Awareness Kit Civilian SDK",
      "versions": [
        ($versions[] | {
          "version": .,
          "label": (if . == "5.5.0.5" then "\(.) (Latest)" else . end),
          "container": "ghcr.io/\($registry)/dbsdk-atak-civ:\(.)",
          "java_version": "11",
          "gradle_version": "7.6",
          "android_api": "30",
          "is_latest": (. == "5.5.0.5"),
          "release_notes": (
            if . == "5.5.0.5" then 
              "Latest stable release with enhanced features and bug fixes"
            elif . == "5.4.0.21" then 
              "Stable release with improved performance and compatibility"
            elif . == "5.3.0.12" then 
              "Legacy stable release for compatibility testing"
            else 
              "ATAK SDK development environment"
            end
          )
        })
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
        },
        {
          "id": "custom", 
          "name": "Custom Template",
          "description": "Minimal setup for experienced developers who prefer to build from scratch"
        }
      ]
    }
  }' > /tmp/test-sdk-versions.json

echo "✅ jq command executed successfully"
echo "📋 Generated test JSON:"
cat /tmp/test-sdk-versions.json | jq .
rm /tmp/test-sdk-versions.json

echo ""
echo "🎉 Workflow validation complete!"
echo "💡 You can now safely commit and push the workflow changes."