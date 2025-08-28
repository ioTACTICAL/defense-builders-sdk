#!/usr/bin/env python3
"""
Script to update SDK versions in sdk-versions.json
"""

import json
import argparse
import sys
from pathlib import Path


def load_sdk_versions(file_path: Path) -> dict:
    """Load existing SDK versions from JSON file"""
    if not file_path.exists():
        return {}
    
    with open(file_path, 'r') as f:
        return json.load(f)


def update_sdk_version(data: dict, sdk_name: str, version_info: dict) -> dict:
    """Update SDK with new version information"""
    if sdk_name not in data:
        print(f"SDK '{sdk_name}' not found in sdk-versions.json", file=sys.stderr)
        return data
    
    sdk = data[sdk_name]
    versions = sdk.get('versions', [])
    
    # Check if version already exists
    existing_version = next((v for v in versions if v['version'] == version_info['version']), None)
    if existing_version:
        print(f"Version {version_info['version']} already exists for {sdk_name}, updating...")
        versions.remove(existing_version)
    
    # If this is marked as latest, unmark all other versions
    if version_info.get('is_latest', False):
        for v in versions:
            v['is_latest'] = False
    
    # Add the new version
    versions.append(version_info)
    
    # Sort versions by semantic version (descending)
    def version_key(v):
        return tuple(map(int, v['version'].split('.')))
    
    versions.sort(key=version_key, reverse=True)
    
    sdk['versions'] = versions
    return data


def save_sdk_versions(data: dict, file_path: Path):
    """Save SDK versions to JSON file"""
    with open(file_path, 'w') as f:
        json.dump(data, f, indent=2)


def main():
    parser = argparse.ArgumentParser(description='Update SDK versions')
    parser.add_argument('--sdk-name', required=True, help='SDK name')
    parser.add_argument('--version', required=True, help='Version number')
    parser.add_argument('--container-image', required=True, help='Container image URI')
    parser.add_argument('--java-version', required=True, help='Java version')
    parser.add_argument('--gradle-version', required=True, help='Gradle version')
    parser.add_argument('--android-api', required=True, help='Android API level')
    parser.add_argument('--release-notes', default='', help='Release notes')
    parser.add_argument('--is-latest', type=lambda x: x.lower() == 'true', 
                       default=False, help='Mark as latest version')
    
    args = parser.parse_args()
    
    # Load existing data
    sdk_versions_file = Path('sdk-versions.json')
    data = load_sdk_versions(sdk_versions_file)
    
    # Prepare version info
    version_info = {
        'version': args.version,
        'label': f"{args.version} ({'Latest' if args.is_latest else ''})" if args.is_latest else args.version,
        'container': args.container_image,
        'java_version': args.java_version,
        'gradle_version': args.gradle_version,
        'android_api': args.android_api,
        'is_latest': args.is_latest,
        'release_notes': args.release_notes or f"Release version {args.version}"
    }
    
    # Update data
    updated_data = update_sdk_version(data, args.sdk_name, version_info)
    
    # Save updated data
    save_sdk_versions(updated_data, sdk_versions_file)
    
    print(f"Successfully updated {args.sdk_name} to version {args.version}")


if __name__ == '__main__':
    main()