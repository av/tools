#!/bin/bash
set -e

echo "=========================================="
echo "SYSTEMATIC BASE IMAGE ANALYSIS"
echo "=========================================="
echo ""

# Create a temporary directory for test builds
mkdir -p /tmp/base-image-tests

# 1. IDENTIFY THE CURRENT BASE IMAGE
echo "1. ANALYZING CURRENT BASE IMAGE"
echo "-------------------------------------------"
docker pull ghcr.io/astral-sh/uv:debian 2>&1 | grep -E "Digest|Status" || true
echo ""
echo "Inspecting image metadata..."
docker image inspect ghcr.io/astral-sh/uv:debian --format '{{.Os}}/{{.Architecture}}' | head -1
docker image inspect ghcr.io/astral-sh/uv:debian --format 'Created: {{.Created}}' | head -1
docker image inspect ghcr.io/astral-sh/uv:debian --format 'Size: {{.Size}} bytes ({{div .Size 1048576}} MB)' | head -1

# Check Debian version
echo ""
echo "Debian version in uv:debian image:"
docker run --rm ghcr.io/astral-sh/uv:debian cat /etc/os-release | grep -E "PRETTY_NAME|VERSION_ID" || true

echo ""
echo ""

# 2. SCAN ALTERNATIVE BASE IMAGES
echo "2. PULLING ALTERNATIVE BASE IMAGES"
echo "-------------------------------------------"
docker pull debian:bookworm-slim
docker pull debian:12-slim  
docker pull ubuntu:24.04
docker pull ubuntu:22.04
echo "✓ All base images pulled"
echo ""
echo ""

# 3. RUN VULNERABILITY SCANS
echo "3. RUNNING VULNERABILITY SCANS (OS packages only)"
echo "-------------------------------------------"
echo "This will take a few minutes..."
echo ""

scan_base_image() {
    local image=$1
    local name=$2
    echo "Scanning: $name ($image)"
    
    # Scan only OS packages, ignore unfixed, get JSON output
    trivy image --format json \
        --scanners vuln \
        --ignore-unfixed \
        --severity CRITICAL,HIGH,MEDIUM \
        "$image" > "/tmp/base-image-tests/${name}.json" 2>/dev/null || true
    
    # Parse the JSON and extract counts
    local critical=$(jq '[.Results[]?.Vulnerabilities[]? | select(.Severity=="CRITICAL")] | length' "/tmp/base-image-tests/${name}.json" 2>/dev/null || echo "0")
    local high=$(jq '[.Results[]?.Vulnerabilities[]? | select(.Severity=="HIGH")] | length' "/tmp/base-image-tests/${name}.json" 2>/dev/null || echo "0")
    local medium=$(jq '[.Results[]?.Vulnerabilities[]? | select(.Severity=="MEDIUM")] | length' "/tmp/base-image-tests/${name}.json" 2>/dev/null || echo "0")
    local total=$((critical + high + medium))
    
    echo "  → CRITICAL: $critical | HIGH: $high | MEDIUM: $medium | TOTAL: $total"
    echo ""
}

scan_base_image "ghcr.io/astral-sh/uv:debian" "uv-debian"
scan_base_image "debian:bookworm-slim" "debian-12-slim"
scan_base_image "ubuntu:24.04" "ubuntu-24.04"
scan_base_image "ubuntu:22.04" "ubuntu-22.04"

echo ""
echo ""

# 4. ANALYZE RESULTS
echo "4. COMPARATIVE ANALYSIS"
echo "-------------------------------------------"
echo ""
printf "%-25s | %8s | %6s | %6s | %5s\n" "IMAGE" "CRITICAL" "HIGH" "MEDIUM" "TOTAL"
printf "%-25s-+-%8s-+-%6s-+-%6s-+-%5s\n" "-------------------------" "--------" "------" "------" "-----"

for scan_file in /tmp/base-image-tests/*.json; do
    name=$(basename "$scan_file" .json)
    critical=$(jq '[.Results[]?.Vulnerabilities[]? | select(.Severity=="CRITICAL")] | length' "$scan_file" 2>/dev/null || echo "0")
    high=$(jq '[.Results[]?.Vulnerabilities[]? | select(.Severity=="HIGH")] | length' "$scan_file" 2>/dev/null || echo "0")
    medium=$(jq '[.Results[]?.Vulnerabilities[]? | select(.Severity=="MEDIUM")] | length' "$scan_file" 2>/dev/null || echo "0")
    total=$((critical + high + medium))
    
    printf "%-25s | %8s | %6s | %6s | %5s\n" "$name" "$critical" "$high" "$medium" "$total"
done

echo ""
echo ""

# 5. SIZE COMPARISON
echo "5. IMAGE SIZE COMPARISON"
echo "-------------------------------------------"
docker images --format "table {{.Repository}}:{{.Tag}}\t{{.Size}}" | grep -E "uv:debian|debian:.*-slim|ubuntu:2[24]" | head -5

echo ""
echo ""

# 6. CHECK UV BINARY COMPATIBILITY
echo "6. UV BINARY COMPATIBILITY TEST"
echo "-------------------------------------------"
echo "Testing if we can copy uv binary to each base..."

test_uv_copy() {
    local base=$1
    local name=$2
    
    cat > /tmp/test-uv-$name.Dockerfile <<EOF
FROM $base
COPY --from=ghcr.io/astral-sh/uv:latest /uv /usr/local/bin/uv
RUN uv --version
EOF
    
    if docker build -q -f /tmp/test-uv-$name.Dockerfile -t test-uv-$name . > /dev/null 2>&1; then
        local version=$(docker run --rm test-uv-$name uv --version 2>/dev/null || echo "FAILED")
        echo "  $name: ✓ $version"
        docker rmi test-uv-$name > /dev/null 2>&1 || true
    else
        echo "  $name: ✗ FAILED"
    fi
    rm -f /tmp/test-uv-$name.Dockerfile
}

test_uv_copy "debian:bookworm-slim" "debian-12"
test_uv_copy "ubuntu:24.04" "ubuntu-24"
test_uv_copy "ubuntu:22.04" "ubuntu-22"

echo ""
echo ""

# 7. FINAL RECOMMENDATION
echo "7. RECOMMENDATION MATRIX"
echo "-------------------------------------------"
echo ""
echo "CRITERIA EVALUATION:"
echo ""
echo "Security (CVE Count):"
echo "  - Lower is better"
echo "  - Focus on CRITICAL and HIGH"
echo "  - 'unfixed' CVEs are excluded from count"
echo ""
echo "Compatibility:"
echo "  - Must support uv binary"
echo "  - Must have recent glibc"
echo ""
echo "Maintenance:"
echo "  - Ubuntu 24.04: Latest LTS (support until 2029)"
echo "  - Ubuntu 22.04: Previous LTS (support until 2027)"
echo "  - Debian 12: Current stable (support until ~2026)"
echo ""
echo "=========================================="
echo "ANALYSIS COMPLETE"
echo "=========================================="
echo ""
echo "Results saved to: /tmp/base-image-tests/"
echo ""
echo "To view detailed CVE lists:"
echo "  jq '.Results[].Vulnerabilities[] | {Package: .PkgName, CVE: .VulnerabilityID, Severity}' /tmp/base-image-tests/<name>.json"
