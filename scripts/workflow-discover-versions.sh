#!/bin/bash
# DBSDK Workflow Version Discovery
# GitHub Actions compatible version discovery for CI/CD pipelines
# https://github.com/iotactical/defense-builders-sdk

set -e

# Script directory and libraries
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
DISCOVERY_LIB="$REPO_ROOT/lib/sdk-discovery.sh"

# Source discovery library
if [[ ! -f "$DISCOVERY_LIB" ]]; then
    echo "::error::Discovery library not found: $DISCOVERY_LIB"
    exit 1
fi

source "$DISCOVERY_LIB"

# Framework logging functions for compatibility (output to stderr to avoid capture)
framework_log_debug() { echo "DEBUG: $1" >&2; }
framework_log_info() { echo "INFO: $1" >&2; }  
framework_log_warn() { echo "WARN: $1" >&2; }
framework_log_error() { echo "ERROR: $1" >&2; }
framework_log_success() { echo "SUCCESS: $1" >&2; }

# GitHub Actions output helpers
gh_output() {
    local name="$1"
    local value="$2"
    echo "${name}=${value}" >> $GITHUB_OUTPUT
}

gh_summary() {
    local content="$1"
    echo "$content" >> $GITHUB_STEP_SUMMARY
}

gh_notice() {
    echo "::notice::$1"
}

gh_warning() {
    echo "::warning::$1"
}

gh_error() {
    echo "::error::$1"
}

# Main discovery function for workflows
workflow_discover_versions() {
    local sdk_type="${1:-atak-civ}"
    local filter_version="${2:-}"
    local fallback_versions="${3:-}"
    
    echo "🔍 Discovering $sdk_type SDK versions from GitHub repositories..."
    
    # Validate SDK type
    if ! validate_sdk_type "$sdk_type"; then
        gh_error "Invalid SDK type: $sdk_type"
        exit 1
    fi
    
    # Add to step summary
    gh_summary "## 🔍 SDK Version Discovery"
    gh_summary ""
    gh_summary "**SDK Type**: $sdk_type"
    gh_summary "**Organization**: $GITHUB_ORG"
    gh_summary ""
    
    # Load SDK configuration to use custom discovery function if available
    local config_file="$REPO_ROOT/sdk-configs/${sdk_type}.conf"
    if [[ -f "$config_file" ]]; then
        echo "Loading SDK configuration: $config_file"
        source "$config_file"
        
        # Use custom discovery function if defined
        local discovery_func="${SDK_VERSION_DISCOVERY:-discover_${sdk_type//-/_}_versions}"
        if declare -F "$discovery_func" >/dev/null 2>&1; then
            echo "Using custom discovery function: $discovery_func"
            discovered_versions=$($discovery_func | jq -R . | jq -s . 2>/dev/null || echo '[]')
        else
            echo "Custom discovery function $discovery_func not found, using generic discovery"
            discovered_versions=$(discover_sdk_versions "$sdk_type" 2>/dev/null | jq -R . | jq -s . 2>/dev/null || echo '[]')
        fi
    else
        echo "No configuration file found, using generic discovery"
        # Discover versions using generic function
        discovered_versions=$(discover_sdk_versions "$sdk_type" 2>/dev/null | jq -R . | jq -s . 2>/dev/null || echo '[]')
    fi
    
    # Check if discovery was successful
    if [[ "$discovered_versions" == "[]" || "$discovered_versions" == "null" ]]; then
        gh_warning "No versions discovered via GitHub API for $sdk_type"
        
        if [[ -n "$fallback_versions" ]]; then
            gh_notice "Using fallback versions: $fallback_versions"
            discovered_versions="$fallback_versions"
            
            gh_summary "**Status**: ⚠️ Fallback versions used"
            gh_summary "**Reason**: No repositories found matching pattern"
        else
            gh_error "No versions found and no fallback provided for $sdk_type"
            gh_summary "**Status**: ❌ Failed"
            gh_summary "**Reason**: No versions discovered and no fallback"
            exit 1
        fi
    else
        gh_notice "Successfully discovered $(echo "$discovered_versions" | jq '. | length') versions for $sdk_type"
        gh_summary "**Status**: ✅ Success"
        gh_summary "**Method**: GitHub API repository discovery"
    fi
    
    echo "Discovered versions: $discovered_versions"
    
    # Add discovered versions to summary
    gh_summary "**Discovered Versions**:"
    echo "$discovered_versions" | jq -r '.[]' | while read -r version; do
        gh_summary "- $version"
    done
    gh_summary ""
    
    # Filter by specific version if requested
    local final_versions="$discovered_versions"
    if [[ -n "$filter_version" ]]; then
        echo "Filtering to specific version: $filter_version"
        
        if echo "$discovered_versions" | jq -e --arg v "$filter_version" 'index($v) != null' >/dev/null; then
            final_versions="[\"$filter_version\"]"
            gh_notice "Filtered to requested version: $filter_version"
            
            gh_summary "**Filtered**: Yes (to $filter_version)"
        else
            gh_error "Requested version $filter_version not found in discovered versions: $discovered_versions"
            gh_summary "**Error**: Requested version $filter_version not available"
            exit 1
        fi
    fi
    
    # Output for GitHub Actions
    gh_output "versions" "$final_versions"
    gh_output "sdk_type" "$sdk_type"
    gh_output "discovery_method" "$(test "$discovered_versions" != "$fallback_versions" && echo "github-api" || echo "fallback")"
    
    echo "Final versions for build: $final_versions"
    gh_summary "**Final Build Versions**:"
    echo "$final_versions" | jq -r '.[]' | while read -r version; do
        gh_summary "- $version"
    done
    
    return 0
}

# Multi-SDK discovery for workflows that need to build multiple SDK types
workflow_discover_multi_sdk() {
    local sdk_types=("$@")
    
    if [[ ${#sdk_types[@]} -eq 0 ]]; then
        sdk_types=("atak-civ" "wintak" "tak-server")
    fi
    
    echo "🔍 Discovering versions for multiple SDK types: ${sdk_types[*]}"
    
    gh_summary "## 🔍 Multi-SDK Version Discovery"
    gh_summary ""
    
    local all_results=()
    local discovery_summary=()
    
    for sdk_type in "${sdk_types[@]}"; do
        echo "--- Processing $sdk_type ---"
        
        if ! validate_sdk_type "$sdk_type"; then
            gh_warning "Skipping invalid SDK type: $sdk_type"
            continue
        fi
        
        local versions
        versions=$(discover_sdk_versions "$sdk_type" 2>/dev/null | jq -R . | jq -s . 2>/dev/null || echo '[]')
        
        if [[ "$versions" != "[]" && "$versions" != "null" ]]; then
            local sdk_result
            sdk_result=$(jq -n \
                --arg sdk_type "$sdk_type" \
                --argjson versions "$versions" \
                '{sdk_type: $sdk_type, versions: $versions}')
            
            all_results+=("$sdk_result")
            
            local version_count
            version_count=$(echo "$versions" | jq '. | length')
            discovery_summary+=("- **$sdk_type**: $version_count versions")
            
            gh_notice "Found $version_count versions for $sdk_type"
        else
            discovery_summary+=("- **$sdk_type**: ❌ No versions found")
            gh_warning "No versions found for $sdk_type"
        fi
    done
    
    # Create final JSON output
    local multi_result
    multi_result=$(printf '%s\n' "${all_results[@]}" | jq -s .)
    
    # Output results
    gh_output "multi_sdk_versions" "$multi_result"
    gh_output "sdk_types" "$(printf '%s\n' "${sdk_types[@]}" | jq -R . | jq -s .)"
    
    # Add to summary
    gh_summary "**Discovery Results**:"
    printf '%s\n' "${discovery_summary[@]}" | while read -r line; do
        gh_summary "$line"
    done
    
    echo "Multi-SDK discovery complete: $multi_result"
    return 0
}

# Validate that discovered versions have corresponding repositories
validate_discovered_versions() {
    local sdk_type="$1"
    local versions_json="$2"
    
    echo "🔍 Validating discovered versions have repositories and branches..."
    
    local validation_results=()
    local valid_versions=()
    
    echo "$versions_json" | jq -r '.[]' | while read -r version; do
        echo "Validating $sdk_type v$version..."
        
        if check_version_branch "$sdk_type" "${SDK_PATTERNS[$sdk_type]/\*/$version}" "$version" 2>/dev/null; then
            valid_versions+=("$version")
            validation_results+=("✅ $version")
            gh_notice "$sdk_type v$version: Repository and branch exist"
        else
            validation_results+=("❌ $version")
            gh_warning "$sdk_type v$version: Repository or branch missing"
        fi
    done
    
    # Output validation results
    local valid_json
    valid_json=$(printf '%s\n' "${valid_versions[@]}" | jq -R . | jq -s .)
    
    gh_output "validated_versions" "$valid_json"
    
    # Add validation summary
    gh_summary ""
    gh_summary "**Repository Validation**:"
    printf '%s\n' "${validation_results[@]}" | while read -r line; do
        gh_summary "$line"
    done
    
    echo "Validation complete. Valid versions: $valid_json"
}

# Main function for command-line usage
main() {
    local command="${1:-discover}"
    shift || true
    
    case "$command" in
        "discover")
            local sdk_type="${1:-atak-civ}"
            local filter_version="$2"
            local fallback_versions="$3"
            
            workflow_discover_versions "$sdk_type" "$filter_version" "$fallback_versions"
            ;;
        "multi")
            workflow_discover_multi_sdk "$@"
            ;;
        "validate")
            local sdk_type="$1"
            local versions_json="$2"
            
            if [[ -z "$sdk_type" || -z "$versions_json" ]]; then
                gh_error "SDK type and versions JSON required for validation"
                exit 1
            fi
            
            validate_discovered_versions "$sdk_type" "$versions_json"
            ;;
        *)
            echo "Usage: $0 {discover|multi|validate} [args...]"
            echo ""
            echo "Commands:"
            echo "  discover [SDK_TYPE] [FILTER_VERSION] [FALLBACK_VERSIONS]"
            echo "  multi [SDK_TYPES...]"
            echo "  validate SDK_TYPE VERSIONS_JSON"
            exit 1
            ;;
    esac
}

# Execute if run directly (not sourced)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi