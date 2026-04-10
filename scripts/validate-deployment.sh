#!/bin/bash
# ============================================================
# Deployment Validation & Monitoring
# Health checks, service status, and deployment result logging
# ============================================================

set -euo pipefail

LOG_FILE="logs/deployment_audit.log"
VALIDATION_LOG="logs/validation_results.log"
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
DEPLOYER=$(whoami)

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

TARGET_ENV="${1:-}"
PASS_COUNT=0
FAIL_COUNT=0
WARN_COUNT=0

log_validation() {
    local check="$1"
    local status="$2"
    local detail="$3"
    mkdir -p "$(dirname "$VALIDATION_LOG")"
    echo "[$TIMESTAMP] ENV=$TARGET_ENV CHECK=$check STATUS=$status DETAIL=\"$detail\"" >> "$VALIDATION_LOG"
}

print_result() {
    local check="$1"
    local status="$2"
    local detail="$3"
    if [ "$status" == "PASS" ]; then
        echo -e "  ${GREEN}[PASS]${NC} $check - $detail"
        PASS_COUNT=$((PASS_COUNT + 1))
    elif [ "$status" == "FAIL" ]; then
        echo -e "  ${RED}[FAIL]${NC} $check - $detail"
        FAIL_COUNT=$((FAIL_COUNT + 1))
    else
        echo -e "  ${YELLOW}[WARN]${NC} $check - $detail"
        WARN_COUNT=$((WARN_COUNT + 1))
    fi
    log_validation "$check" "$status" "$detail"
}

usage() {
    echo -e "${CYAN}Usage: $0 <environment>${NC}"
    echo "Runs health checks and service validation after deployment"
    echo "Valid environments: dev, staging, production"
    exit 1
}

if [ -z "$TARGET_ENV" ]; then
    usage
fi

# Map environment to port
case "$TARGET_ENV" in
    dev) PORT=2221 ;;
    staging) PORT=2222 ;;
    production) PORT=2223 ;;
    *)
        echo -e "${RED}[ERROR] Invalid environment: $TARGET_ENV${NC}"
        exit 1
        ;;
esac

HOST="127.0.0.1"

echo -e "${CYAN}============================================${NC}"
echo -e "${CYAN} Deployment Validation - $TARGET_ENV${NC}"
echo -e "${CYAN}============================================${NC}"
echo -e "Target  : $TARGET_ENV ($HOST:$PORT)"
echo -e "Time    : $TIMESTAMP"
echo ""

# --- Check 1: SSH Connectivity ---
echo -e "${CYAN}[1/4] Connectivity Checks${NC}"
if timeout 5 bash -c "echo > /dev/tcp/$HOST/$PORT" 2>/dev/null; then
    print_result "SSH Port" "PASS" "Port $PORT is open and accepting connections"
else
    print_result "SSH Port" "FAIL" "Port $PORT is not reachable"
fi

# --- Check 2: Docker Container Status ---
echo ""
echo -e "${CYAN}[2/4] Container Health${NC}"
CONTAINER_NAME="ansible-${TARGET_ENV}"
if docker ps --format '{{.Names}}' 2>/dev/null | grep -q "^${CONTAINER_NAME}$"; then
    CONTAINER_STATUS=$(docker inspect --format='{{.State.Status}}' "$CONTAINER_NAME" 2>/dev/null)
    CONTAINER_UPTIME=$(docker inspect --format='{{.State.StartedAt}}' "$CONTAINER_NA
