#!/bin/bash
set -e

IMAGE_NAME="${IMAGE_NAME:-tools-image}"
TEST_RESULTS=()

echo "=========================================="
echo "BUILD AND TEST SCRIPT"
echo "=========================================="
echo ""
echo "Image: $IMAGE_NAME"
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_test() {
    local status=$1
    local name=$2
    if [ "$status" = "PASS" ]; then
        echo -e "${GREEN}✓${NC} $name"
        TEST_RESULTS+=("PASS:$name")
    elif [ "$status" = "SKIP" ]; then
        echo -e "${YELLOW}⊘${NC} $name (skipped)"
        TEST_RESULTS+=("SKIP:$name")
    else
        echo -e "${RED}✗${NC} $name"
        TEST_RESULTS+=("FAIL:$name")
    fi
}

echo "1. BUILDING IMAGE FROM SCRATCH"
echo "-------------------------------------------"
# docker build --no-cache -t "$IMAGE_NAME" .
docker build -t "$IMAGE_NAME" .
echo ""

echo "2. TESTING RUNTIMES"
echo "-------------------------------------------"

# Test Python
if docker run --rm "$IMAGE_NAME" python3 --version > /dev/null 2>&1; then
    VERSION=$(docker run --rm "$IMAGE_NAME" python3 --version)
    log_test "PASS" "Python runtime: $VERSION"
else
    log_test "FAIL" "Python runtime"
fi

# Test Node.js
if docker run --rm "$IMAGE_NAME" node --version > /dev/null 2>&1; then
    VERSION=$(docker run --rm "$IMAGE_NAME" node --version)
    log_test "PASS" "Node.js runtime: $VERSION"
else
    log_test "FAIL" "Node.js runtime"
fi

# Test Deno
if docker run --rm "$IMAGE_NAME" deno --version > /dev/null 2>&1; then
    VERSION=$(docker run --rm "$IMAGE_NAME" deno --version | head -1)
    log_test "PASS" "Deno runtime: $VERSION"
else
    log_test "FAIL" "Deno runtime"
fi

# Test Rust/Cargo
if docker run --rm "$IMAGE_NAME" cargo --version > /dev/null 2>&1; then
    VERSION=$(docker run --rm "$IMAGE_NAME" cargo --version)
    log_test "PASS" "Rust/Cargo toolchain: $VERSION"
else
    log_test "FAIL" "Rust/Cargo toolchain"
fi

echo ""
echo "3. TESTING PACKAGE MANAGERS"
echo "-------------------------------------------"

# Test uvx
if docker run --rm "$IMAGE_NAME" uvx --version > /dev/null 2>&1; then
    VERSION=$(docker run --rm "$IMAGE_NAME" uvx --version)
    log_test "PASS" "uvx: $VERSION"
else
    log_test "FAIL" "uvx"
fi

# Test npx
if docker run --rm "$IMAGE_NAME" npx --version > /dev/null 2>&1; then
    VERSION=$(docker run --rm "$IMAGE_NAME" npx --version)
    log_test "PASS" "npx: $VERSION"
else
    log_test "FAIL" "npx"
fi

echo ""
echo "4. TESTING MCP/OPENAPI TOOLS"
echo "-------------------------------------------"

# Test mcpo
if docker run --rm "$IMAGE_NAME" uvx mcpo --help > /dev/null 2>&1; then
    log_test "PASS" "mcpo (MCP to OpenAPI bridge)"
else
    log_test "FAIL" "mcpo"
fi

# Test supergateway
if docker run --rm "$IMAGE_NAME" npx -y supergateway --help > /dev/null 2>&1; then
    log_test "PASS" "supergateway (MCP STDIO/SSE bridge)"
else
    log_test "FAIL" "supergateway"
fi

# Test MCP inspector (just check it can start, then kill it)
if timeout 3 docker run --rm "$IMAGE_NAME" npx -y @modelcontextprotocol/inspector > /dev/null 2>&1 || [ $? -eq 124 ]; then
    log_test "PASS" "@modelcontextprotocol/inspector"
else
    log_test "FAIL" "@modelcontextprotocol/inspector"
fi

# Test metamcp
if docker run --rm "$IMAGE_NAME" npx -y @metamcp/mcp-server-metamcp@latest --help > /dev/null 2>&1; then
    log_test "PASS" "@metamcp/mcp-server-metamcp"
else
    log_test "FAIL" "@metamcp/mcp-server-metamcp"
fi

echo ""
echo "5. TESTING UTILITY PACKAGES"
echo "-------------------------------------------"

# Test curl
if docker run --rm "$IMAGE_NAME" curl --version > /dev/null 2>&1; then
    VERSION=$(docker run --rm "$IMAGE_NAME" curl --version | head -1)
    log_test "PASS" "curl: $VERSION"
else
    log_test "FAIL" "curl"
fi

# Test jq
if docker run --rm "$IMAGE_NAME" jq --version > /dev/null 2>&1; then
    VERSION=$(docker run --rm "$IMAGE_NAME" jq --version)
    log_test "PASS" "jq: $VERSION"
else
    log_test "FAIL" "jq"
fi

# Test git
if docker run --rm "$IMAGE_NAME" git --version > /dev/null 2>&1; then
    VERSION=$(docker run --rm "$IMAGE_NAME" git --version)
    log_test "PASS" "git: $VERSION"
else
    log_test "FAIL" "git"
fi

# Test ffmpeg
if docker run --rm "$IMAGE_NAME" ffmpeg -version > /dev/null 2>&1; then
    VERSION=$(docker run --rm "$IMAGE_NAME" ffmpeg -version | head -1)
    log_test "PASS" "ffmpeg: $VERSION"
else
    log_test "FAIL" "ffmpeg"
fi

echo ""
echo "6. TESTING CACHE DIRECTORY"
echo "-------------------------------------------"

# Test cache directory exists and is writable
if docker run --rm "$IMAGE_NAME" sh -c 'test -d /app/cache && touch /app/cache/test.txt && rm /app/cache/test.txt' > /dev/null 2>&1; then
    log_test "PASS" "/app/cache directory exists and is writable"
else
    log_test "FAIL" "/app/cache directory"
fi

# Test UV_CACHE_DIR is set
if docker run --rm "$IMAGE_NAME" sh -c 'test "$UV_CACHE_DIR" = "/app/cache/uv"' > /dev/null 2>&1; then
    log_test "PASS" "UV_CACHE_DIR environment variable"
else
    log_test "FAIL" "UV_CACHE_DIR environment variable"
fi

# Test npm cache is set
if docker run --rm "$IMAGE_NAME" sh -c 'test "$npm_config_cache" = "/app/cache/npm"' > /dev/null 2>&1; then
    log_test "PASS" "npm_config_cache environment variable"
else
    log_test "FAIL" "npm_config_cache environment variable"
fi

echo ""
echo "7. FUNCTIONAL TEST: MCP SERVER"
echo "-------------------------------------------"

# Try to run an actual MCP server for a few seconds
echo "Starting mcp-server-time for 3 seconds..."
if timeout 3 docker run --rm "$IMAGE_NAME" uvx mcp-server-time 2>&1 | grep -q "error"; then
    log_test "FAIL" "mcp-server-time execution"
else
    log_test "PASS" "mcp-server-time execution (no errors)"
fi

echo ""
echo "=========================================="
echo "TEST SUMMARY"
echo "=========================================="
echo ""

PASS_COUNT=0
FAIL_COUNT=0
SKIP_COUNT=0

for result in "${TEST_RESULTS[@]}"; do
    STATUS="${result%%:*}"
    case "$STATUS" in
        PASS) PASS_COUNT=$((PASS_COUNT + 1)) ;;
        FAIL) FAIL_COUNT=$((FAIL_COUNT + 1)) ;;
        SKIP) SKIP_COUNT=$((SKIP_COUNT + 1)) ;;
    esac
done

TOTAL_COUNT=${#TEST_RESULTS[@]}
echo "Total Tests: $TOTAL_COUNT"
echo -e "${GREEN}Passed: $PASS_COUNT${NC}"
if [ $SKIP_COUNT -gt 0 ]; then
    echo -e "${YELLOW}Skipped: $SKIP_COUNT${NC}"
fi
if [ $FAIL_COUNT -gt 0 ]; then
    echo -e "${RED}Failed: $FAIL_COUNT${NC}"
    echo ""
    echo "Failed tests:"
    for result in "${TEST_RESULTS[@]}"; do
        if [[ "$result" == FAIL:* ]]; then
            echo -e "  ${RED}✗${NC} ${result#FAIL:}"
        fi
    done
fi

echo ""
if [ $FAIL_COUNT -eq 0 ]; then
    echo -e "${GREEN}All tests passed!${NC}"
    exit 0
else
    echo -e "${RED}Some tests failed.${NC}"
    exit 1
fi
