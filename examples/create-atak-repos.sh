#!/bin/bash
# Example: Create ATAK-CIV SDK repositories for version discovery
# This script demonstrates how to set up the repository structure
# that the SDK discovery system expects to find

set -e

GITHUB_ORG="iotactical"
GITHUB_TOKEN="${GITHUB_TOKEN:-}"

if [[ -z "$GITHUB_TOKEN" ]]; then
    echo "Error: GITHUB_TOKEN environment variable required"
    echo "Get a token from: https://github.com/settings/tokens"
    exit 1
fi

# ATAK-CIV versions to create repositories for
ATAK_VERSIONS=(
    "5.3.0.12"
    "5.4.0.21" 
    "5.5.0.5"
)

echo "🚀 Creating ATAK-CIV SDK repositories for version discovery..."
echo "Organization: $GITHUB_ORG"
echo "Versions: ${ATAK_VERSIONS[*]}"
echo

create_atak_repo() {
    local version="$1"
    local repo_name="ATAK-CIV-${version}-SDK"
    local branch_name="atak-civ-${version}"
    
    echo "📦 Creating repository: $repo_name"
    
    # Create repository via GitHub API
    local repo_payload
    repo_payload=$(jq -n \
        --arg name "$repo_name" \
        --arg description "ATAK-CIV SDK v${version} - Android Tactical Assault Kit (Civil) Development Environment" \
        '{
            name: $name,
            description: $description,
            private: false,
            has_issues: true,
            has_projects: false,
            has_wiki: false,
            auto_init: true,
            license_template: "mit"
        }')
    
    local create_response
    create_response=$(curl -s -X POST \
        -H "Authorization: token $GITHUB_TOKEN" \
        -H "Accept: application/vnd.github.v3+json" \
        -H "Content-Type: application/json" \
        "https://api.github.com/orgs/$GITHUB_ORG/repos" \
        -d "$repo_payload")
    
    local repo_created
    repo_created=$(echo "$create_response" | jq -r '.name // empty')
    
    if [[ "$repo_created" == "$repo_name" ]]; then
        echo "  ✅ Repository created: https://github.com/$GITHUB_ORG/$repo_name"
    else
        local error_msg
        error_msg=$(echo "$create_response" | jq -r '.message // "Unknown error"')
        echo "  ❌ Failed to create repository: $error_msg"
        return 1
    fi
    
    # Wait a moment for repository to be ready
    sleep 2
    
    # Create the version-specific branch
    echo "  🌿 Creating branch: $branch_name"
    
    # Get the default branch SHA
    local default_branch_response
    default_branch_response=$(curl -s \
        -H "Authorization: token $GITHUB_TOKEN" \
        -H "Accept: application/vnd.github.v3+json" \
        "https://api.github.com/repos/$GITHUB_ORG/$repo_name/git/refs/heads/main")
    
    local main_sha
    main_sha=$(echo "$default_branch_response" | jq -r '.object.sha // empty')
    
    if [[ -z "$main_sha" ]]; then
        echo "  ❌ Could not get main branch SHA"
        return 1
    fi
    
    # Create new branch from main
    local branch_payload
    branch_payload=$(jq -n \
        --arg ref "refs/heads/$branch_name" \
        --arg sha "$main_sha" \
        '{
            ref: $ref,
            sha: $sha
        }')
    
    local branch_response
    branch_response=$(curl -s -X POST \
        -H "Authorization: token $GITHUB_TOKEN" \
        -H "Accept: application/vnd.github.v3+json" \
        -H "Content-Type: application/json" \
        "https://api.github.com/repos/$GITHUB_ORG/$repo_name/git/refs" \
        -d "$branch_payload")
    
    local branch_created
    branch_created=$(echo "$branch_response" | jq -r '.ref // empty')
    
    if [[ "$branch_created" == "refs/heads/$branch_name" ]]; then
        echo "  ✅ Branch created: $branch_name"
    else
        local error_msg
        error_msg=$(echo "$branch_response" | jq -r '.message // "Unknown error"')
        echo "  ❌ Failed to create branch: $error_msg"
        return 1
    fi
    
    # Create version-specific README content
    local readme_content
    readme_content=$(cat << EOF
# ATAK-CIV SDK v${version}

**Android Tactical Assault Kit (Civil) Development Environment**

[![Open in GitHub Codespaces](https://github.com/codespaces/badge.svg)](https://codespaces.new/${GITHUB_ORG}/${repo_name}?quickstart=1&ref=${branch_name})

## Quick Start

This is the official ATAK-CIV SDK v${version} development environment.

### What's Included

- **ATAK-CIV SDK v${version}**: Complete development kit
- **Android Development Tools**: Pre-configured Android SDK and build tools
- **Java 17**: LTS Java runtime and development kit  
- **Gradle**: Build automation and dependency management
- **DBSDK Utilities**: Compliance checking, telemetry control, SBOM management

### Development Environment

Start developing immediately with GitHub Codespaces or VS Code Dev Containers.

Container Image: \`ghcr.io/iotactical/dbsdk-atak-civ:${version}\`

### Documentation

- [ATAK-CIV Official Documentation](https://github.com/deptofdefense/AndroidTacticalAssaultKit-CIV)
- [Defense Builders SDK](https://github.com/iotactical/defense-builders-sdk)
- [Plugin Development Guide](https://iotactical.co/docs/atak-civ)

---

**SDK Version**: ${version}  
**Branch**: ${branch_name}  
**Container**: \`ghcr.io/iotactical/dbsdk-atak-civ:${version}\`

Built with ❤️ by [ioTACTICAL](https://iotactical.co) for the defense development community.
EOF
    )
    
    # Update README on the version branch
    echo "  📝 Creating version-specific README"
    
    # Get current README file SHA
    local readme_response
    readme_response=$(curl -s \
        -H "Authorization: token $GITHUB_TOKEN" \
        -H "Accept: application/vnd.github.v3+json" \
        "https://api.github.com/repos/$GITHUB_ORG/$repo_name/contents/README.md?ref=$branch_name")
    
    local readme_sha
    readme_sha=$(echo "$readme_response" | jq -r '.sha // empty')
    
    # Create update payload
    local readme_payload
    readme_payload=$(jq -n \
        --arg message "Add ATAK-CIV v${version} README and documentation" \
        --arg content "$(echo "$readme_content" | base64 -w 0)" \
        --arg branch "$branch_name" \
        --arg sha "$readme_sha" \
        '{
            message: $message,
            content: $content,
            branch: $branch
        } + (if $sha != "" then {sha: $sha} else {} end)')
    
    local readme_update_response
    readme_update_response=$(curl -s -X PUT \
        -H "Authorization: token $GITHUB_TOKEN" \
        -H "Accept: application/vnd.github.v3+json" \
        -H "Content-Type: application/json" \
        "https://api.github.com/repos/$GITHUB_ORG/$repo_name/contents/README.md" \
        -d "$readme_payload")
    
    local readme_updated
    readme_updated=$(echo "$readme_update_response" | jq -r '.commit.sha // empty')
    
    if [[ -n "$readme_updated" ]]; then
        echo "  ✅ README updated"
    else
        echo "  ❌ Failed to update README"
    fi
    
    echo "  🎉 Repository setup complete!"
    echo "     Repository: https://github.com/$GITHUB_ORG/$repo_name"
    echo "     Branch: $branch_name"
    echo "     Codespaces: https://codespaces.new/$GITHUB_ORG/$repo_name?quickstart=1&ref=$branch_name"
    echo
}

# Create repositories for all versions
for version in "${ATAK_VERSIONS[@]}"; do
    create_atak_repo "$version"
    
    # Rate limit protection
    echo "⏳ Waiting 5 seconds to avoid rate limits..."
    sleep 5
done

echo "🎉 All ATAK-CIV SDK repositories created!"
echo
echo "🔍 Test the discovery system:"
echo "   ./scripts/sdk-discovery discover atak-civ"
echo "   ./scripts/sdk-discovery metadata atak-civ --format table"
echo
echo "📋 Repository Summary:"
for version in "${ATAK_VERSIONS[@]}"; do
    echo "  • ATAK-CIV-${version}-SDK → atak-civ-${version} branch"
done
echo
echo "🚀 These repositories are now discoverable by the DBSDK version system!"
echo "   The CI/CD pipeline will automatically detect and build containers for all versions."