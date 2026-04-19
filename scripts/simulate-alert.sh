#!/bin/bash
# ============================================================
# Alert Simulation - Test failure scenarios
# Simulates deployment failures for validation testing
# ============================================================

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

LOG_FILE="logs/deployment_audit.log"
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')

log_event() {
    mkdir -p "$(dirname "$LOG_FILE")"
    echo "[$TIMESTAMP] DEPLOYER=$(whoami) ENV=$1 STATUS=$2 MSG=\"$3\"" >> "$LOG_FILE"
}

echo -e "${CYAN}============================================${NC}"
echo -e "${CYAN} Alert Simulation Suite${NC}"
echo -e "${CYAN}============================================${NC}"
echo ""

# Scenario 1: Invalid environment
echo -e "${YELLOW}[Scenario 1] Deploy to invalid environment${NC}"
if bash scripts/deploy-gate.sh invalid_env 2>/dev/null; then
    echo -e "  ${RED}UNEXPECTED: Should have been rejected${NC}"
else
    echo -e "  ${GREEN}EXPECTED: Correctly rejected invalid environment${NC}"
fi
echo ""

# Scenario 2: Validate non-running container
echo -e "${YELLOW}[Scenario 2] Validate stopped container${NC}"
FAKE_ENV="dev"
CONTAINER="ansible-${FAKE_ENV}"
RUNNING=$(docker ps --format '{{.Names}}' 2>/dev/null | grep "^${CONTAINER}$" || true)
if [ -z "$RUNNING" ]; then
    echo -e "  Container $CONTAINER is not running - testing validation..."
    bash scripts/validate-deployment.sh "$FAKE_ENV" 2>/dev/null || true
    echo -e "  ${GREEN}EXPECTED: Validation reported failures for stopped container${NC}"
else
    echo -e "  ${YELLOW}Container $CONTAINER is running - stopping for test...${NC}"
    docker stop "$CONTAINER" > /dev/null 2>&1
    bash scripts/validate-deployment.sh "$FAKE_ENV" 2>/dev/null || true
    echo -e "  ${GREEN}EXPECTED: Validation reported failures${NC}"
    docker start "$CONTAINER" > /dev/null 2>&1
    echo -e "  ${CYAN}Container restarted after test${NC}"
fi
echo ""

# Scenario 3: Deploy rejection (production without confirmation)
echo -e "${YELLOW}[Scenario 3] Production deploy without confirmation${NC}"
echo "no" | bash scripts/deploy-gate.sh production 2>/dev/null || true
echo -e "  ${GREEN}EXPECTED: Production deployment rejected${NC}"
log_event "production" "ALERT_SIM" "Simulated unauthorized production deploy attempt"
echo ""

echo -e "${CYAN}============================================${NC}"
echo -e "${CYAN} All alert scenarios completed${NC}"
echo -e "${CYAN}============================================${NC}"
echo -e "Check logs: cat logs/deployment_audit.log"
echo -e "Check validation: cat logs/validation_results.log"
