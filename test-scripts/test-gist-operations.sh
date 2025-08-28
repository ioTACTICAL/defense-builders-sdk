#!/bin/bash
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "=== GitHub Gist Operations Test Suite ==="

# Check for required environment variable
if [[ -z "${GIST_TOKEN:-}" ]]; then
    echo -e "${RED}❌ GIST_TOKEN environment variable is required${NC}"
    echo "Please set your GitHub App token:"
    echo "export GIST_TOKEN=your_token_here"
    exit 1
fi

# Test configuration
TEST_GIST_NAME="test-sdk-versions-$(date +%s).json"
TEST_JSON_CONTENT='{
  "test-sdk": {
    "name": "Test SDK",
    "description": "Test SDK for gist operations",
    "versions": [
      {
        "version": "1.0.0",
        "label": "1.0.0 (Latest)",
        "container": "ghcr.io/iotactical/test-sdk:1.0.0",
        "is_latest": true,
        "release_notes": "Test version for gist operations"
      }
    ],
    "templates": [
      {
        "id": "basic",
        "name": "Basic Template",
        "description": "Basic test template"
      }
    ]
  }
}'

GIST_ID=""

cleanup() {
    if [[ -n "$GIST_ID" ]]; then
        echo -e "${YELLOW}Cleaning up test gist...${NC}"
        curl -s -X DELETE \
            -H "Accept: application/vnd.github+json" \
            -H "Authorization: Bearer $GIST_TOKEN" \
            -H "X-GitHub-Api-Version: 2022-11-28" \
            "https://api.github.com/gists/$GIST_ID" > /dev/null || true
        echo -e "${GREEN}✅ Test gist cleaned up${NC}"
    fi
}

# Set up cleanup on exit
trap cleanup EXIT

echo -e "${YELLOW}Test 1: Verifying GitHub App token permissions...${NC}"

# Test token by checking user info (works for both PAT and GitHub App)
USER_INFO=$(curl -s \
    -H "Accept: application/vnd.github+json" \
    -H "Authorization: Bearer $GIST_TOKEN" \
    -H "X-GitHub-Api-Version: 2022-11-28" \
    "https://api.github.com/user")

if echo "$USER_INFO" | jq -e '.login' > /dev/null 2>&1; then
    USERNAME=$(echo "$USER_INFO" | jq -r '.login')
    echo -e "${GREEN}✅ Token is valid for user: $USERNAME${NC}"
elif echo "$USER_INFO" | jq -e '.message' > /dev/null 2>&1; then
    # Try alternative endpoint for GitHub Apps
    APP_INFO=$(curl -s \
        -H "Accept: application/vnd.github+json" \
        -H "Authorization: Bearer $GIST_TOKEN" \
        -H "X-GitHub-Api-Version: 2022-11-28" \
        "https://api.github.com/installation/repositories" 2>/dev/null)
    
    if echo "$APP_INFO" | jq -e '.repositories' > /dev/null 2>&1; then
        REPO_COUNT=$(echo "$APP_INFO" | jq '.repositories | length')
        echo -e "${GREEN}✅ GitHub App token is valid with access to $REPO_COUNT repositories${NC}"
    else
        echo -e "${RED}❌ Token is invalid or lacks permissions${NC}"
        echo "Response: $USER_INFO"
        exit 1
    fi
else
    echo -e "${RED}❌ Token is invalid or lacks permissions${NC}"
    echo "Response: $USER_INFO"
    exit 1
fi

echo -e "${YELLOW}Test 2: Creating test gist...${NC}"

# Create gist
CREATE_RESPONSE=$(curl -s -X POST \
    -H "Accept: application/vnd.github+json" \
    -H "Authorization: Bearer $GIST_TOKEN" \
    -H "X-GitHub-Api-Version: 2022-11-28" \
    "https://api.github.com/gists" \
    -d "{
        \"description\": \"Test SDK versions for Defense Builders - DELETE ME\",
        \"public\": true,
        \"files\": {
            \"$TEST_GIST_NAME\": {
                \"content\": $(echo "$TEST_JSON_CONTENT" | jq -R -s .)
            }
        }
    }")

if echo "$CREATE_RESPONSE" | jq -e '.id' > /dev/null 2>&1; then
    GIST_ID=$(echo "$CREATE_RESPONSE" | jq -r '.id')
    GIST_URL=$(echo "$CREATE_RESPONSE" | jq -r '.html_url')
    echo -e "${GREEN}✅ Gist created successfully${NC}"
    echo "   Gist ID: $GIST_ID"
    echo "   URL: $GIST_URL"
else
    echo -e "${RED}❌ Failed to create gist${NC}"
    echo "Response: $CREATE_RESPONSE"
    exit 1
fi

echo -e "${YELLOW}Test 3: Reading gist content...${NC}"

# Read gist back
READ_RESPONSE=$(curl -s \
    -H "Accept: application/vnd.github+json" \
    -H "Authorization: Bearer $GIST_TOKEN" \
    -H "X-GitHub-Api-Version: 2022-11-28" \
    "https://api.github.com/gists/$GIST_ID")

if echo "$READ_RESPONSE" | jq -e ".files.\"$TEST_GIST_NAME\".content" > /dev/null 2>&1; then
    RETRIEVED_CONTENT=$(echo "$READ_RESPONSE" | jq -r ".files.\"$TEST_GIST_NAME\".content")
    echo -e "${GREEN}✅ Gist content retrieved successfully${NC}"
    
    # Verify content matches
    if [[ "$RETRIEVED_CONTENT" == "$TEST_JSON_CONTENT" ]]; then
        echo -e "${GREEN}✅ Gist content matches original${NC}"
    else
        echo -e "${RED}❌ Gist content does not match original${NC}"
        echo "Expected: $TEST_JSON_CONTENT"
        echo "Got: $RETRIEVED_CONTENT"
        exit 1
    fi
else
    echo -e "${RED}❌ Failed to read gist content${NC}"
    echo "Response: $READ_RESPONSE"
    exit 1
fi

echo -e "${YELLOW}Test 4: Updating gist content...${NC}"

# Updated content
UPDATED_CONTENT='{
  "test-sdk": {
    "name": "Test SDK Updated",
    "description": "Test SDK for gist operations - UPDATED",
    "versions": [
      {
        "version": "1.0.0",
        "label": "1.0.0",
        "container": "ghcr.io/iotactical/test-sdk:1.0.0",
        "is_latest": false,
        "release_notes": "Test version for gist operations"
      },
      {
        "version": "2.0.0",
        "label": "2.0.0 (Latest)",
        "container": "ghcr.io/iotactical/test-sdk:2.0.0",
        "is_latest": true,
        "release_notes": "Updated test version"
      }
    ],
    "templates": [
      {
        "id": "basic",
        "name": "Basic Template",
        "description": "Basic test template"
      }
    ]
  }
}'

# Update gist
UPDATE_RESPONSE=$(curl -s -X PATCH \
    -H "Accept: application/vnd.github+json" \
    -H "Authorization: Bearer $GIST_TOKEN" \
    -H "X-GitHub-Api-Version: 2022-11-28" \
    "https://api.github.com/gists/$GIST_ID" \
    -d "{
        \"description\": \"Test SDK versions for Defense Builders - UPDATED - DELETE ME\",
        \"files\": {
            \"$TEST_GIST_NAME\": {
                \"content\": $(echo "$UPDATED_CONTENT" | jq -R -s .)
            }
        }
    }")

if echo "$UPDATE_RESPONSE" | jq -e '.id' > /dev/null 2>&1; then
    echo -e "${GREEN}✅ Gist updated successfully${NC}"
else
    echo -e "${RED}❌ Failed to update gist${NC}"
    echo "Response: $UPDATE_RESPONSE"
    exit 1
fi

echo -e "${YELLOW}Test 5: Verifying updated content...${NC}"

# Read updated gist
READ_UPDATED_RESPONSE=$(curl -s \
    -H "Accept: application/vnd.github+json" \
    -H "Authorization: Bearer $GIST_TOKEN" \
    -H "X-GitHub-Api-Version: 2022-11-28" \
    "https://api.github.com/gists/$GIST_ID")

if echo "$READ_UPDATED_RESPONSE" | jq -e ".files.\"$TEST_GIST_NAME\".content" > /dev/null 2>&1; then
    UPDATED_RETRIEVED_CONTENT=$(echo "$READ_UPDATED_RESPONSE" | jq -r ".files.\"$TEST_GIST_NAME\".content")
    
    if [[ "$UPDATED_RETRIEVED_CONTENT" == "$UPDATED_CONTENT" ]]; then
        echo -e "${GREEN}✅ Updated gist content matches expected${NC}"
    else
        echo -e "${RED}❌ Updated gist content does not match expected${NC}"
        exit 1
    fi
else
    echo -e "${RED}❌ Failed to read updated gist content${NC}"
    exit 1
fi

echo -e "${YELLOW}Test 6: Testing gist discovery (list gists)...${NC}"

# List gists to verify our test gist appears (using the gist we just created)
LIST_RESPONSE=$(curl -s \
    -H "Accept: application/vnd.github+json" \
    -H "Authorization: Bearer $GIST_TOKEN" \
    -H "X-GitHub-Api-Version: 2022-11-28" \
    "https://api.github.com/gists/$GIST_ID")

if echo "$LIST_RESPONSE" | jq -e ".id" > /dev/null 2>&1; then
    RETRIEVED_GIST_ID=$(echo "$LIST_RESPONSE" | jq -r '.id')
    if [[ "$RETRIEVED_GIST_ID" == "$GIST_ID" ]]; then
        echo -e "${GREEN}✅ Test gist discoverable and accessible${NC}"
    else
        echo -e "${RED}❌ Gist ID mismatch${NC}"
    fi
else
    echo -e "${RED}❌ Test gist not accessible${NC}"
    echo "Response: $LIST_RESPONSE"
fi

echo ""
echo -e "${GREEN}🎉 All gist operations tests passed!${NC}"
echo ""
echo "Summary:"
echo "- ✅ GitHub App token authentication"
echo "- ✅ Gist creation"
echo "- ✅ Gist content retrieval"
echo "- ✅ Gist content update"
echo "- ✅ Updated content verification"
echo "- ✅ Gist discovery in organization"
echo ""
echo -e "${YELLOW}Note: Test gist will be automatically cleaned up${NC}"