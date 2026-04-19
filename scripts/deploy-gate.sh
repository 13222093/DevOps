#!/bin/bash
# ============================================================
# Deployment Gate - Policy-Based Deployment Governance
# Validates environment, enforces role-based access,
# requires confirmation for staging/prod
# ============================================================

set -euo pipefail

VALID_ENVIRONMENTS=("dev" "staging" "production")
LOG_FILE="logs/deployment_audit.log"
DEPLOYER=$(whoami)
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

log_event() {
    local env="$1"
    local status="$2"
    local message="$3"
    mkdir -p "$(dirname "$LOG_FILE")"
    echo "[$TIMESTAMP] DEPLOYER=$DEPLOYER ENV=$env STATUS=$status MSG=\"$message\"" >> "$LOG_FILE"
}

usage() {
    echo -e "${CYAN}Usage: $0 <environment>${NC}"
    echo -e "Valid environments: ${GREEN}dev${NC}, ${YELLOW}staging${NC}, ${RED}production${NC}"
    exit 1
}

# --- Validation: argument check ---
if [ $# -lt 1 ]; then
    echo -e "${RED}[ERROR] No environment specified.${NC}"
    log_event "none" "REJECTED" "No environment specified"
    usage
fi

TARGET_ENV="$1"

# --- Validation: environment must be valid ---
VALID=false
for env in "${VALID_ENVIRONMENTS[@]}"; do
    if [ "$TARGET_ENV" == "$env" ]; then
        VALID=true
        break
    fi
done

if [ "$VALID" == "false" ]; then
    echo -e "${RED}[ERROR] Invalid environment: '$TARGET_ENV'${NC}"
    echo -e "Valid environments: ${VALID_ENVIRONMENTS[*]}"
    log_event "$TARGET_ENV" "REJECTED" "Invalid environment"
    exit 1
fi

echo -e "${CYAN}============================================${NC}"
echo -e "${CYAN} Deployment Gate - $TARGET_ENV${NC}"
echo -e "${CYAN}============================================${NC}"
echo -e "Deployer : ${GREEN}$DEPLOYER${NC}"
echo -e "Target   : ${YELLOW}$TARGET_ENV${NC}"
echo -e "Time     : $TIMESTAMP"
echo ""

# --- Policy: Dev = free pass ---
if [ "$TARGET_ENV" == "dev" ]; then
    echo -e "${GREEN}[PASS] Dev environment - no restrictions.${NC}"
    log_event "$TARGET_ENV" "APPROVED" "Auto-approved for dev"
    exit 0
fi

# --- Policy: Production requires explicit confirmation ---
if [ "$TARGET_ENV" == "production" ]; then
    echo -e "${RED}[WARNING] You are deploying to PRODUCTION!${NC}"
    echo -e "${YELLOW}This action affects the live environment.${NC}"
    echo ""
    read -p "Type 'DEPLOY PRODUCTION' to confirm: " CONFIRM
    if [ "$CONFIRM" != "DEPLOY PRODUCTION" ]; then
        echo -e "${RED}[REJECTED] Production deployment cancelled.${NC}"
        log_event "$TARGET_ENV" "REJECTED" "Confirmation failed by $DEPLOYER"
        exit 1
    fi
    echo -e "${GREEN}[APPROVED] Production deployment confirmed.${NC}"
    log_event "$TARGET_ENV" "APPROVED" "Manually confirmed by $DEPLOYER"
    exit 0
fi

# --- Policy: Staging requires yes/no confirmation ---
if [ "$TARGET_ENV" == "staging" ]; then
    echo -e "${YELLOW}[CONFIRM] Deploying to staging environment.${NC}"
    read -p "Continue? (yes/no): " CONFIRM
    if [ "$CONFIRM" != "yes" ]; then
        echo -e "${RED}[REJECTED] Staging deployment cancelled.${NC}"
        log_event "$TARGET_ENV" "REJECTED" "Declined by $DEPLOYER"
        exit 1
    fi
    echo -e "${GREEN}[APPROVED] Staging deployment confirmed.${NC}"
    log_event "$TARGET_ENV" "APPROVED" "Confirmed by $DEPLOYER"
    exit 0
fi
