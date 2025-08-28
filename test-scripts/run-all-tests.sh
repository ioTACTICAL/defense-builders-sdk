#!/bin/bash
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=========================================${NC}"
echo -e "${BLUE}  Gist-Based Architecture Test Suite    ${NC}"
echo -e "${BLUE}=========================================${NC}"
echo ""

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Test configuration
TESTS_PASSED=0
TESTS_FAILED=0
FAILED_TESTS=()

# Make scripts executable
chmod +x *.sh

run_test() {
    local test_name="$1"
    local test_script="$2"
    local skip_reason="$3"
    
    echo -e "${BLUE}===========================================${NC}"
    echo -e "${BLUE}Running: $test_name${NC}"
    echo -e "${BLUE}===========================================${NC}"
    
    if [[ -n "$skip_reason" ]]; then
        echo -e "${YELLOW}⏭️  SKIPPED: $skip_reason${NC}"
        echo ""
        return 0
    fi
    
    if [[ ! -f "$test_script" ]]; then
        echo -e "${RED}❌ Test script not found: $test_script${NC}"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        FAILED_TESTS+=("$test_name - Script not found")
        return 1
    fi
    
    if "./$test_script"; then
        echo -e "${GREEN}✅ $test_name PASSED${NC}"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo -e "${RED}❌ $test_name FAILED${NC}"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        FAILED_TESTS+=("$test_name")
    fi
    
    echo ""
}

# Check prerequisites
echo -e "${YELLOW}Checking prerequisites...${NC}"

# Check if we're in the right directory
if [[ ! -f "../schema/sdk-versions-schema.json" ]]; then
    echo -e "${RED}❌ Must run from defense-builders-sdk/test-scripts directory${NC}"
    exit 1
fi

# Check for required tools
MISSING_TOOLS=()

if ! command -v curl &> /dev/null; then
    MISSING_TOOLS+=("curl")
fi

if ! command -v jq &> /dev/null; then
    MISSING_TOOLS+=("jq")
fi

if ! command -v node &> /dev/null; then
    MISSING_TOOLS+=("node")
fi

if [[ ${#MISSING_TOOLS[@]} -gt 0 ]]; then
    echo -e "${RED}❌ Missing required tools: ${MISSING_TOOLS[*]}${NC}"
    echo "Please install the missing tools and try again"
    exit 1
fi

echo -e "${GREEN}✅ Prerequisites check passed${NC}"
echo ""

# Determine which tests to run based on environment
SKIP_GITHUB_TESTS=""
if [[ -z "${GIST_TOKEN:-}" ]]; then
    SKIP_GITHUB_TESTS="GIST_TOKEN not set - run with token for full tests"
fi

# Run tests in order of complexity
echo -e "${BLUE}Starting test execution...${NC}"
echo ""

# Phase 1: Local tests (no API calls)
run_test "Schema Validation" "test-schema-validation.sh"

# Phase 2: GitHub API tests (require token)
run_test "Gist Operations" "test-gist-operations.sh" "$SKIP_GITHUB_TESTS"
run_test "Repository Dispatch" "test-repo-dispatch.sh" "$SKIP_GITHUB_TESTS"
run_test "Gist Aggregation" "test-gist-aggregation.sh" "$SKIP_GITHUB_TESTS"

# Summary
echo -e "${BLUE}=========================================${NC}"
echo -e "${BLUE}           TEST RESULTS SUMMARY          ${NC}"
echo -e "${BLUE}=========================================${NC}"
echo ""

TOTAL_TESTS=$((TESTS_PASSED + TESTS_FAILED))

echo -e "Total Tests Run: $TOTAL_TESTS"
echo -e "${GREEN}Tests Passed: $TESTS_PASSED${NC}"
if [[ $TESTS_FAILED -gt 0 ]]; then
    echo -e "${RED}Tests Failed: $TESTS_FAILED${NC}"
    echo ""
    echo -e "${RED}Failed Tests:${NC}"
    for failed_test in "${FAILED_TESTS[@]}"; do
        echo -e "${RED}  - $failed_test${NC}"
    done
else
    echo -e "${GREEN}Tests Failed: 0${NC}"
fi

echo ""

# Overall result
if [[ $TESTS_FAILED -eq 0 ]]; then
    echo -e "${GREEN}🎉 ALL TESTS PASSED! 🎉${NC}"
    echo ""
    echo -e "${GREEN}The gist-based architecture is ready for production deployment.${NC}"
    echo ""
    echo -e "${YELLOW}Next steps:${NC}"
    echo "1. Set up GitHub App token in repository secrets"
    echo "2. Test with actual atak-civ repository push"
    echo "3. Verify defense-builders-sdk aggregation workflow triggers"
    echo "4. Monitor for any edge cases in production"
    exit 0
else
    echo -e "${RED}❌ SOME TESTS FAILED${NC}"
    echo ""
    echo -e "${RED}Please fix the failing tests before production deployment.${NC}"
    echo ""
    
    if [[ -n "$SKIP_GITHUB_TESTS" ]]; then
        echo -e "${YELLOW}Note: GitHub API tests were skipped due to missing GIST_TOKEN${NC}"
        echo "To run full test suite:"
        echo "  export GIST_TOKEN=your_token_here"
        echo "  ./run-all-tests.sh"
    fi
    
    exit 1
fi