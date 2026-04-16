#!/bin/bash
# Fetch secrets from HashiCorp Vault for a given environment
set -euo pipefail

TARGET_ENV="${1:-}"
VAULT_ADDR="${VAULT_ADDR:-http://127.0.0.1:8200}"
VAULT_TOKEN="${VAULT_TOKEN:-}"

RED='\033[0;31m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
NC='\033[0m'

if [ -z "$TARGET_ENV" ]; then
    echo -e "${RED}Usage: $0 <environment>${NC}"
    exit 1
fi

if [ -z "$VAULT_TOKEN" ]; then
    echo -e "${RED}[ERROR] VAULT_TOKEN not set. Export it first.${NC}"
    exit 1
fi

echo -e "${CYAN}[VAULT] Fetching secrets for $TARGET_ENV from $VAULT_ADDR${NC}"

# Fetch ansible_password from Vault
PASSWORD=$(curl -s \
    -H "X-Vault-Token: $VAULT_TOKEN" \
    "$VAULT_ADDR/v1/devops/data/ansible/$TARGET_ENV" \
    | python3 -c "import sys,json; print(json.load(sys.stdin)['data']['data']['ansible_password'])" 2>/dev/null)

if [ -z "$PASSWORD" ]; then
    echo -e "${RED}[ERROR] Failed to fetch secret from Vault for env: $TARGET_ENV${NC}"
    exit 1
fi

echo -e "${GREEN}[VAULT] Secret fetched successfully${NC}"
echo "$PASSWORD"
