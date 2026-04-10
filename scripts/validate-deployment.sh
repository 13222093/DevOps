#!/bin/bash
set -euo pipefail
LOG_FILE="logs/deployment_audit.log"
VALIDATION_LOG="logs/validation_results.log"
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
RED='[0;31m'
GREEN='[0;32m'
YELLOW='[1;33m'
CYAN='[0;36m'
NC='[0m'
TARGET_ENV="${1:-}"
PASS_COUNT=0
FAIL_COUNT=0
WARN_COUNT=0
log_validation() {
    mkdir -p "$(dirname "$VALIDATION_LOG")"
    echo "[$TIMESTAMP] ENV=$TARGET_ENV CHECK=$1 STATUS=$2 DETAIL="$3"" >> "$VALIDATION_LOG"
}
print_result() {
    if [ "$2" == "PASS" ]; then
        echo -e "  ${GREEN}[PASS]${NC} $1 - $3"
        PASS_COUNT=$((PASS_COUNT + 1))
    elif [ "$2" == "FAIL" ]; then
        echo -e "  ${RED}[FAIL]${NC} $1 - $3"
        FAIL_COUNT=$((FAIL_COUNT + 1))
    else
        echo -e "  ${YELLOW}[WARN]${NC} $1 - $3"
        WARN_COUNT=$((WARN_COUNT + 1))
    fi
    log_validation "$1" "$2" "$3"
}
[ -z "$TARGET_ENV" ] && echo "Usage: $0 <env>" && exit 1
case "$TARGET_ENV" in
    dev) PORT=2221 ;; staging) PORT=2222 ;; production) PORT=2223 ;;
    *) echo "Invalid env"; exit 1 ;;
esac
HOST="127.0.0.1"
CONTAINER_NAME="ansible-${TARGET_ENV}"
echo -e "${CYAN}============================================${NC}"
echo -e "${CYAN} Deployment Validation - $TARGET_ENV${NC}"
echo -e "${CYAN}============================================${NC}"
echo ""
echo -e "${CYAN}[1/4] Connectivity${NC}"
if timeout 5 bash -c "echo > /dev/tcp/$HOST/$PORT" 2>/dev/null; then
    print_result "SSH Port" "PASS" "Port $PORT open"
else
    print_result "SSH Port" "FAIL" "Port $PORT not reachable"
fi
echo ""
echo -e "${CYAN}[2/4] Container Health${NC}"
if docker ps --format '{{.Names}}' 2>/dev/null | grep -q "^${CONTAINER_NAME}$"; then
    print_result "Container" "PASS" "$CONTAINER_NAME running"
    RC=$(docker inspect --format='{{.RestartCount}}' "$CONTAINER_NAME" 2>/dev/null)
    [ "$RC" -gt 0 ] && print_result "Restarts" "WARN" "$RC restart(s)" || print_result "Restarts" "PASS" "No restarts"
else
    print_result "Container" "FAIL" "$CONTAINER_NAME not running"
    print_result "Restarts" "FAIL" "Cannot check"
fi
echo ""
echo -e "${CYAN}[3/4] Service Health${NC}"
if docker ps --format '{{.Names}}' 2>/dev/null | grep -q "^${CONTAINER_NAME}$"; then
    docker exec "$CONTAINER_NAME" pgrep nginx >/dev/null 2>&1 && print_result "Nginx" "PASS" "Running" || print_result "Nginx" "FAIL" "Not running"
    docker exec "$CONTAINER_NAME" nginx -t 2>/dev/null && print_result "Nginx Config" "PASS" "Valid" || print_result "Nginx Config" "FAIL" "Errors"
else
    print_result "Nginx" "FAIL" "Container not running"
    print_result "Nginx Config" "FAIL" "Container not running"
fi
echo ""
echo -e "${CYAN}[4/4] HTTP Health${NC}"
if docker ps --format '{{.Names}}' 2>/dev/null | grep -q "^${CONTAINER_NAME}$"; then
    HR=$(docker exec "$CONTAINER_NAME" curl -s -o /dev/null -w "%{http_code}" http://localhost/ 2>/dev/null || echo "000")
    [ "$HR" == "200" ] && print_result "HTTP" "PASS" "200 OK" || { [ "$HR" == "000" ] && print_result "HTTP" "WARN" "curl unavailable" || print_result "HTTP" "FAIL" "HTTP $HR"; }
    CT=$(docker exec "$CONTAINER_NAME" cat /var/www/html/index.html 2>/dev/null || echo "")
    echo "$CT" | grep -qi "server\|production\|automated\|dev\|staging" && print_result "Content" "PASS" "Expected content" || print_result "Content" "WARN" "Content unclear"
else
    print_result "HTTP" "FAIL" "Container not running"
    print_result "Content" "FAIL" "Container not running"
fi
echo ""
echo -e "${CYAN}============================================${NC}"
echo -e "${CYAN} Validation Summary - $TARGET_ENV${NC}"
echo -e "${CYAN}============================================${NC}"
TOTAL=$((PASS_COUNT + FAIL_COUNT + WARN_COUNT))
echo "  Total: $TOTAL | Pass: $PASS_COUNT | Fail: $FAIL_COUNT | Warn: $WARN_COUNT"
echo ""
if [ "$FAIL_COUNT" -gt 0 ]; then
    echo -e "  ${RED}OVERALL: UNHEALTHY${NC}"
    log_validation "OVERALL" "UNHEALTHY" "$FAIL_COUNT failures"
    exit 1
else
    echo -e "  ${GREEN}OVERALL: HEALTHY${NC}"
    log_validation "OVERALL" "HEALTHY" "All passed"
    exit 0
fi
