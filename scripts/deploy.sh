#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
LOG_FILE="$PROJECT_DIR/logs/deployment_audit.log"
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
DEPLOYER=$(whoami)

RED='\033[0;31m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
NC='\033[0m'

log_event() {
    local env="$1"
    local status="$2"
    local message="$3"
    mkdir -p "$(dirname "$LOG_FILE")"
    echo "[$TIMESTAMP] DEPLOYER=$DEPLOYER ENV=$env STATUS=$status MSG=\"$message\"" >> "$LOG_FILE"
}

if [ $# -lt 1 ]; then
    echo -e "${RED}Usage: $0 <environment>${NC}"
    echo "Example: $0 dev"
    exit 1
fi

TARGET_ENV="$1"
INVENTORY_FILE="$PROJECT_DIR/inventory/${TARGET_ENV}.ini"

if [ ! -f "$INVENTORY_FILE" ]; then
    echo -e "${RED}[ERROR] Inventory file not found: $INVENTORY_FILE${NC}"
    log_event "$TARGET_ENV" "FAILED" "Inventory file not found"
    exit 1
fi

# Step 1: Run deployment gate
echo -e "${CYAN}[1/5] Running deployment gate...${NC}"
if ! bash "$SCRIPT_DIR/deploy-gate.sh" "$TARGET_ENV"; then
    echo -e "${RED}[ABORT] Deployment blocked by governance policy.${NC}"
    exit 1
fi

# Step 2: Fetch secrets from HashiCorp Vault
echo ""
echo -e "${CYAN}[2/5] Fetching secrets from Vault...${NC}"
if [ -z "${VAULT_TOKEN:-}" ]; then
    echo -e "${RED}[ERROR] VAULT_TOKEN not set. Export it first:${NC}"
    echo "  export VAULT_TOKEN='hvs.xxxxx'"
    log_event "$TARGET_ENV" "FAILED" "VAULT_TOKEN not set"
    exit 1
fi

VAULT_ADDR="${VAULT_ADDR:-http://127.0.0.1:8200}"
ANSIBLE_PASSWORD=$(curl -s \
    -H "X-Vault-Token: $VAULT_TOKEN" \
    "$VAULT_ADDR/v1/devops/data/ansible/$TARGET_ENV" \
    | python3 -c "import sys,json; print(json.load(sys.stdin)['data']['data']['ansible_password'])" 2>/dev/null)

if [ -z "$ANSIBLE_PASSWORD" ]; then
    echo -e "${RED}[ERROR] Failed to fetch secret from Vault${NC}"
    log_event "$TARGET_ENV" "FAILED" "Vault secret fetch failed"
    exit 1
fi
echo -e "${GREEN}[VAULT] Secret fetched successfully from $VAULT_ADDR${NC}"

# Step 3: Run Ansible playbook with Vault-fetched password
echo ""
echo -e "${CYAN}[3/5] Running Ansible playbook...${NC}"
if ansible-playbook -i "$INVENTORY_FILE" "$PROJECT_DIR/playbooks/site.yml" \
    -e "ansible_password=$ANSIBLE_PASSWORD"; then
    echo -e "${GREEN}[SUCCESS] Ansible playbook completed.${NC}"
    log_event "$TARGET_ENV" "DEPLOYED" "Playbook executed by $DEPLOYER"
else
    echo -e "${RED}[FAILED] Ansible playbook failed.${NC}"
    log_event "$TARGET_ENV" "FAILED" "Playbook failed for $DEPLOYER"
    exit 1
fi

# Step 4: Run post-deployment validation
echo ""
echo -e "${CYAN}[4/5] Running post-deployment validation...${NC}"
if bash "$SCRIPT_DIR/validate-deployment.sh" "$TARGET_ENV"; then
    echo -e "${GREEN}[HEALTHY] All validation checks passed.${NC}"
    log_event "$TARGET_ENV" "VALIDATED" "Post-deployment checks passed"
else
    echo -e "${RED}[UNHEALTHY] Validation found issues.${NC}"
    log_event "$TARGET_ENV" "VALIDATION_FAILED" "Post-deployment checks found failures"
fi

# Step 5: Summary
echo ""
echo -e "${CYAN}[5/5] Deployment summary${NC}"
echo -e "Environment : $TARGET_ENV"
echo -e "Deployer    : $DEPLOYER"
echo -e "Time        : $TIMESTAMP"
echo -e "Vault       : $VAULT_ADDR"
echo -e "Status      : ${GREEN}COMPLETE${NC}"
echo -e "Audit log   : $LOG_FILE"
echo -e "Validation  : logs/validation_results.log"
