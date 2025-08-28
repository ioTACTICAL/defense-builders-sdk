#!/bin/bash
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "=== Repository Dispatch Test Suite ==="

# Check for required environment variable
if [[ -z "${GIST_TOKEN:-}" ]]; then
    echo -e "${RED}❌ GIST_TOKEN environment variable is required${NC}"
    echo "Please set your GitHub App token:"
    echo "export GIST_TOKEN=your_token_here"
    exit 1
fi

# Test configuration
TARGET_REPO="iotactical/defense-builders-sdk"
EVENT_TYPE="sdk-registry-update"
TEST_PAYLOAD='{
  "sdk_name": "test-sdk",
  "gist_name": "sdk-versions-test-sdk.json",
  "organization": "iotactical",
  "repository": "iotactical/test-sdk-collection",
  "commit_sha": "abc123def456",
  "versions": ["1.0.0", "2.0.0"]
}'

echo -e "${YELLOW}Test 1: Verifying repository access...${NC}"

# Check if we can access the target repository
REPO_INFO=$(curl -s \
    -H "Accept: application/vnd.github+json" \
    -H "Authorization: Bearer $GIST_TOKEN" \
    -H "X-GitHub-Api-Version: 2022-11-28" \
    "https://api.github.com/repos/$TARGET_REPO")

if echo "$REPO_INFO" | jq -e '.name' > /dev/null 2>&1; then
    REPO_NAME=$(echo "$REPO_INFO" | jq -r '.name')
    echo -e "${GREEN}✅ Repository access confirmed: $REPO_NAME${NC}"
else
    echo -e "${RED}❌ Cannot access repository $TARGET_REPO${NC}"
    echo "Response: $REPO_INFO"
    exit 1
fi

echo -e "${YELLOW}Test 2: Testing repository dispatch...${NC}"

# Send repository dispatch
DISPATCH_RESPONSE=$(curl -s -w "%{http_code}" -o /tmp/dispatch_response.json \
    -X POST \
    -H "Accept: application/vnd.github+json" \
    -H "Authorization: Bearer $GIST_TOKEN" \
    -H "X-GitHub-Api-Version: 2022-11-28" \
    "https://api.github.com/repos/$TARGET_REPO/dispatches" \
    -d "{
        \"event_type\": \"$EVENT_TYPE\",
        \"client_payload\": $TEST_PAYLOAD
    }")

HTTP_CODE="${DISPATCH_RESPONSE: -3}"
RESPONSE_BODY=$(cat /tmp/dispatch_response.json)

if [[ "$HTTP_CODE" == "204" ]]; then
    echo -e "${GREEN}✅ Repository dispatch sent successfully (HTTP $HTTP_CODE)${NC}"
else
    echo -e "${RED}❌ Repository dispatch failed (HTTP $HTTP_CODE)${NC}"
    echo "Response: $RESPONSE_BODY"
    
    # Check for common error scenarios
    if echo "$RESPONSE_BODY" | jq -e '.message' > /dev/null 2>&1; then
        ERROR_MSG=$(echo "$RESPONSE_BODY" | jq -r '.message')
        case "$ERROR_MSG" in
            *"Bad credentials"*)
                echo -e "${RED}Error: GitHub App token is invalid or expired${NC}"
                ;;
            *"Not Found"*)
                echo -e "${RED}Error: Repository not found or token lacks access${NC}"
                ;;
            *"Validation Failed"*)
                echo -e "${RED}Error: Invalid payload format${NC}"
                ;;
            *)
                echo -e "${RED}Error: $ERROR_MSG${NC}"
                ;;
        esac
    fi
    exit 1
fi

echo -e "${YELLOW}Test 3: Verifying workflow exists to handle dispatch...${NC}"

# Check if the target repository has a workflow that listens for our event type
WORKFLOWS_RESPONSE=$(curl -s \
    -H "Accept: application/vnd.github+json" \
    -H "Authorization: Bearer $GIST_TOKEN" \
    -H "X-GitHub-Api-Version: 2022-11-28" \
    "https://api.github.com/repos/$TARGET_REPO/actions/workflows")

if echo "$WORKFLOWS_RESPONSE" | jq -e '.workflows' > /dev/null 2>&1; then
    # Look for workflows that might handle our dispatch event
    MATCHING_WORKFLOWS=$(echo "$WORKFLOWS_RESPONSE" | jq -r --arg event_type "$EVENT_TYPE" '
        .workflows[] | 
        select(.name | test("aggregate|registry|sdk"; "i")) | 
        .name
    ')
    
    if [[ -n "$MATCHING_WORKFLOWS" ]]; then
        echo -e "${GREEN}✅ Found workflows that may handle dispatch events:${NC}"
        echo "$MATCHING_WORKFLOWS" | while read workflow; do
            echo "   - $workflow"
        done
    else
        echo -e "${YELLOW}⚠️ No obvious workflows found to handle dispatch event${NC}"
        echo "This may be expected if workflows are in development"
    fi
else
    echo -e "${RED}❌ Cannot list workflows for repository${NC}"
    echo "Response: $WORKFLOWS_RESPONSE"
fi

echo -e "${YELLOW}Test 4: Testing payload format variations...${NC}"

# Test with minimal payload
MINIMAL_PAYLOAD='{
  "sdk_name": "minimal-test",
  "gist_name": "sdk-versions-minimal-test.json"
}'

MINIMAL_DISPATCH_RESPONSE=$(curl -s -w "%{http_code}" -o /tmp/minimal_dispatch_response.json \
    -X POST \
    -H "Accept: application/vnd.github+json" \
    -H "Authorization: Bearer $GIST_TOKEN" \
    -H "X-GitHub-Api-Version: 2022-11-28" \
    "https://api.github.com/repos/$TARGET_REPO/dispatches" \
    -d "{
        \"event_type\": \"$EVENT_TYPE\",
        \"client_payload\": $MINIMAL_PAYLOAD
    }")

HTTP_CODE_MINIMAL="${MINIMAL_DISPATCH_RESPONSE: -3}"

if [[ "$HTTP_CODE_MINIMAL" == "204" ]]; then
    echo -e "${GREEN}✅ Minimal payload dispatch successful${NC}"
else
    echo -e "${RED}❌ Minimal payload dispatch failed (HTTP $HTTP_CODE_MINIMAL)${NC}"
    MINIMAL_RESPONSE_BODY=$(cat /tmp/minimal_dispatch_response.json)
    echo "Response: $MINIMAL_RESPONSE_BODY"
fi

echo -e "${YELLOW}Test 5: Testing error handling with invalid payload...${NC}"

# Test with invalid JSON payload (should fail gracefully)
INVALID_RESPONSE=$(curl -s -w "%{http_code}" -o /tmp/invalid_dispatch_response.json \
    -X POST \
    -H "Accept: application/vnd.github+json" \
    -H "Authorization: Bearer $GIST_TOKEN" \
    -H "X-GitHub-Api-Version: 2022-11-28" \
    "https://api.github.com/repos/$TARGET_REPO/dispatches" \
    -d '{
        "event_type": "invalid-event-type-with-very-long-name-that-exceeds-limits",
        "client_payload": {"invalid": "json""}
    }' 2>/dev/null || echo "400")

HTTP_CODE_INVALID="${INVALID_RESPONSE: -3}"

if [[ "$HTTP_CODE_INVALID" != "204" ]]; then
    echo -e "${GREEN}✅ Invalid payload correctly rejected (HTTP $HTTP_CODE_INVALID)${NC}"
else
    echo -e "${RED}❌ Invalid payload was unexpectedly accepted${NC}"
fi

# Cleanup
rm -f /tmp/*dispatch_response.json

echo ""
echo -e "${GREEN}🎉 Repository dispatch tests completed!${NC}"
echo ""
echo "Summary:"
echo "- ✅ Repository access verification"
echo "- ✅ Repository dispatch functionality"
echo "- ✅ Workflow existence check"
echo "- ✅ Payload format validation"
echo "- ✅ Error handling verification"
echo ""
echo -e "${YELLOW}Note: Dispatched events may take a few moments to trigger workflows${NC}"
echo -e "${YELLOW}Check the Actions tab in $TARGET_REPO to see if workflows were triggered${NC}"