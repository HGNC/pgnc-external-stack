#!/usr/bin/env bash
# Test suite for cert-renewal.sh
# This file tests the functionality of the dedicated certificate renewal script

set -euo pipefail

# Test framework variables
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CERT_SCRIPT="${SCRIPT_DIR}/cert-renewal.sh"
TEST_COUNT=0
PASS_COUNT=0
FAIL_COUNT=0
TEMP_DIR=""

# Colors for test output
readonly TEST_RED='\033[0;31m'
readonly TEST_GREEN='\033[0;32m'
readonly TEST_YELLOW='\033[1;33m'
readonly TEST_BLUE='\033[0;34m'
readonly TEST_NC='\033[0m'

# Test framework functions
setup_test_environment() {
    TEMP_DIR=$(mktemp -d)
    cd "$TEMP_DIR"
    
    # Copy the cert-renewal script
    cp "$CERT_SCRIPT" ./cert-renewal.sh
    
    # Create mock container tools
    mkdir -p bin
    cat > bin/docker << 'EOF'
#!/bin/bash
echo "Docker version 20.10.0"
EOF
    chmod +x bin/docker
    
    cat > bin/podman << 'EOF'
#!/bin/bash
echo "podman version 3.0.0"
EOF
    chmod +x bin/podman
    
    # Add mock binaries to PATH
    export PATH="$PWD/bin:$PATH"
    
    # Create a mock total-refresh.sh script
    cat > total-refresh.sh << 'EOF'
#!/bin/bash
case "$*" in
    "--container-tool docker --renew-certs")
        echo "[INFO] Running SSL certificate renewal"
        echo "[SUCCESS] SSL certificate renewal completed!"
        exit 0
        ;;
    "--container-tool podman --renew-certs")
        echo "[INFO] Running SSL certificate renewal"
        echo "[SUCCESS] SSL certificate renewal completed!"
        exit 0
        ;;
    *)
        echo "[ERROR] Unexpected arguments: $*"
        exit 1
        ;;
esac
EOF
    chmod +x total-refresh.sh
}

teardown_test_environment() {
    cd "$SCRIPT_DIR"
    rm -rf "$TEMP_DIR"
}

assert_equals() {
    local expected="$1"
    local actual="$2"
    local message="${3:-}"
    
    TEST_COUNT=$((TEST_COUNT + 1))
    
    if [[ "$expected" == "$actual" ]]; then
        PASS_COUNT=$((PASS_COUNT + 1))
        echo -e "${TEST_GREEN}✓ PASS${TEST_NC}: $message"
    else
        FAIL_COUNT=$((FAIL_COUNT + 1))
        echo -e "${TEST_RED}✗ FAIL${TEST_NC}: $message"
        echo -e "  Expected: '$expected'"
        echo -e "  Actual:   '$actual'"
    fi
}

assert_contains() {
    local haystack="$1"
    local needle="$2"
    local message="${3:-}"
    
    TEST_COUNT=$((TEST_COUNT + 1))
    
    if [[ "$haystack" == *"$needle"* ]]; then
        PASS_COUNT=$((PASS_COUNT + 1))
        echo -e "${TEST_GREEN}✓ PASS${TEST_NC}: $message"
    else
        FAIL_COUNT=$((FAIL_COUNT + 1))
        echo -e "${TEST_RED}✗ FAIL${TEST_NC}: $message"
        echo -e "  Haystack: '$haystack'"
        echo -e "  Needle:   '$needle'"
    fi
}

assert_exit_code() {
    local expected_code="$1"
    local command="$2"
    local message="${3:-}"
    
    TEST_COUNT=$((TEST_COUNT + 1))
    
    local actual_code=0
    eval "$command" || actual_code=$?
    
    if [[ "$expected_code" -eq "$actual_code" ]]; then
        PASS_COUNT=$((PASS_COUNT + 1))
        echo -e "${TEST_GREEN}✓ PASS${TEST_NC}: $message"
    else
        FAIL_COUNT=$((FAIL_COUNT + 1))
        echo -e "${TEST_RED}✗ FAIL${TEST_NC}: $message"
        echo -e "  Expected exit code: $expected_code"
        echo -e "  Actual exit code:   $actual_code"
    fi
}

# Test functions
test_cert_renewal_docker() {
    echo -e "${TEST_BLUE}Testing cert-renewal.sh with Docker...${TEST_NC}"
    
    local output
    output=$(./cert-renewal.sh docker 2>&1)
    assert_contains "$output" "Starting automated SSL certificate renewal" "Should start automated renewal"
    assert_contains "$output" "SSL certificate renewal completed successfully" "Should complete renewal successfully"
}

test_cert_renewal_podman() {
    echo -e "${TEST_BLUE}Testing cert-renewal.sh with Podman...${TEST_NC}"
    
    local output
    output=$(./cert-renewal.sh podman 2>&1)
    assert_contains "$output" "Starting automated SSL certificate renewal" "Should start automated renewal"
    assert_contains "$output" "SSL certificate renewal completed successfully" "Should complete renewal successfully"
}

test_cert_renewal_invalid_tool() {
    echo -e "${TEST_BLUE}Testing cert-renewal.sh with invalid container tool...${TEST_NC}"
    
    local exit_code=0
    ./cert-renewal.sh invalid >/dev/null 2>&1 || exit_code=$?
    assert_equals "1" "$exit_code" "Should fail with invalid container tool"
    
    local output
    output=$(./cert-renewal.sh invalid 2>&1 | grep "Container tool must be either")
    if [[ -n "$output" ]]; then
        TEST_COUNT=$((TEST_COUNT + 1))
        PASS_COUNT=$((PASS_COUNT + 1))
        echo -e "${TEST_GREEN}✓ PASS${TEST_NC}: Should show valid container tool error"
    else
        TEST_COUNT=$((TEST_COUNT + 1))
        FAIL_COUNT=$((FAIL_COUNT + 1))
        echo -e "${TEST_RED}✗ FAIL${TEST_NC}: Should show valid container tool error"
    fi
}

test_cert_renewal_no_arguments() {
    echo -e "${TEST_BLUE}Testing cert-renewal.sh with no arguments...${TEST_NC}"
    
    # Ensure we have the mock total-refresh.sh
    cat > total-refresh.sh << 'EOF'
#!/bin/bash
case "$*" in
    "--container-tool docker --renew-certs")
        echo "[INFO] Running SSL certificate renewal"
        echo "[SUCCESS] SSL certificate renewal completed!"
        exit 0
        ;;
    *)
        echo "[ERROR] Unexpected arguments: $*"
        exit 1
        ;;
esac
EOF
    chmod +x total-refresh.sh
    
    local output
    output=$(./cert-renewal.sh 2>&1)
    assert_contains "$output" "Starting automated SSL certificate renewal" "Should start with default (docker)"
    assert_contains "$output" "SSL certificate renewal completed successfully" "Should complete renewal successfully"
}

test_cert_renewal_logging() {
    echo -e "${TEST_BLUE}Testing cert-renewal.sh logging format...${TEST_NC}"
    
    # Ensure we have the mock total-refresh.sh
    cat > total-refresh.sh << 'EOF'
#!/bin/bash
case "$*" in
    "--container-tool docker --renew-certs")
        echo "[INFO] Running SSL certificate renewal"
        echo "[SUCCESS] SSL certificate renewal completed!"
        exit 0
        ;;
    *)
        echo "[ERROR] Unexpected arguments: $*"
        exit 1
        ;;
esac
EOF
    chmod +x total-refresh.sh
    
    local output
    output=$(./cert-renewal.sh docker 2>&1)
    
    # Check that timestamps are included in log output
    assert_contains "$output" "[INFO]" "Should include INFO log level"
    assert_contains "$output" "[SUCCESS]" "Should include SUCCESS log level"
    
    # Check that timestamp format is present (YYYY-MM-DD HH:MM:SS)
    if [[ "$output" =~ \[([0-9]{4}-[0-9]{2}-[0-9]{2}\ [0-9]{2}:[0-9]{2}:[0-9]{2})\] ]]; then
        PASS_COUNT=$((PASS_COUNT + 1))
        echo -e "${TEST_GREEN}✓ PASS${TEST_NC}: Should include timestamp in log format"
    else
        FAIL_COUNT=$((FAIL_COUNT + 1))
        echo -e "${TEST_RED}✗ FAIL${TEST_NC}: Should include timestamp in log format"
    fi
    TEST_COUNT=$((TEST_COUNT + 1))
}

test_cert_renewal_failure_handling() {
    echo -e "${TEST_BLUE}Testing cert-renewal.sh failure handling...${TEST_NC}"
    
    # Create a mock total-refresh.sh that fails
    cat > total-refresh.sh << 'EOF'
#!/bin/bash
echo "[ERROR] Certificate renewal failed"
exit 1
EOF
    chmod +x total-refresh.sh
    
    local exit_code=0
    ./cert-renewal.sh docker >/dev/null 2>&1 || exit_code=$?
    assert_equals "1" "$exit_code" "Should propagate failure exit code"
    
    local output
    output=$(./cert-renewal.sh docker 2>&1)
    assert_contains "$output" "SSL certificate renewal failed" "Should report renewal failure"
}

test_cert_renewal_missing_tool() {
    echo -e "${TEST_BLUE}Testing cert-renewal.sh with missing container tool...${TEST_NC}"
    
    # Remove mock container tools from PATH
    export PATH="${PATH#$PWD/bin:}"
    
    local exit_code=0
    ./cert-renewal.sh nonexistent >/dev/null 2>&1 || exit_code=$?
    assert_equals "1" "$exit_code" "Should fail when container tool is not found"
    
    local output
    output=$(./cert-renewal.sh nonexistent 2>&1)
    assert_contains "$output" "is not installed or not in PATH" "Should report missing container tool"
    
    # Restore PATH for subsequent tests
    export PATH="$PWD/bin:$PATH"
}

# Main test runner
run_all_tests() {
    echo -e "${TEST_BLUE}Starting test suite for cert-renewal.sh${TEST_NC}"
    echo "=============================================="
    
    setup_test_environment
    
    # Run all test functions
    test_cert_renewal_docker
    test_cert_renewal_podman
    test_cert_renewal_invalid_tool
    test_cert_renewal_no_arguments
    test_cert_renewal_logging
    test_cert_renewal_failure_handling
    test_cert_renewal_missing_tool
    
    teardown_test_environment
    
    # Print test summary
    echo
    echo "=============================================="
    echo -e "${TEST_BLUE}Test Summary:${TEST_NC}"
    echo -e "  Total tests: $TEST_COUNT"
    echo -e "  ${TEST_GREEN}Passed: $PASS_COUNT${TEST_NC}"
    echo -e "  ${TEST_RED}Failed: $FAIL_COUNT${TEST_NC}"
    
    if [[ $FAIL_COUNT -eq 0 ]]; then
        echo -e "${TEST_GREEN}All tests passed!${TEST_NC}"
        exit 0
    else
        echo -e "${TEST_RED}Some tests failed.${TEST_NC}"
        exit 1
    fi
}

# Only run tests if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    run_all_tests "$@"
fi
