# Secret Handling Documentation

## Overview

This document describes how secrets and credentials are managed in our Ansible DevOps project.

## Architecture

```
inventory/
├── dev.ini                      # Host connection info (NO passwords)
├── staging.ini                  # Host connection info (NO passwords)
├── production.ini               # Host connection info (NO passwords)
└── group_vars/
    ├── all.yml                  # Shared non-sensitive vars
    ├── dev/
    │   ├── vars.yml             # Non-sensitive dev vars
    │   └── vault.yml            # Encrypted dev secrets
    ├── staging/
    │   ├── vars.yml             # Non-sensitive staging vars
    │   └── vault.yml            # Encrypted staging secrets
    └── production/
        ├── vars.yml             # Non-sensitive production vars
        └── vault.yml            # Encrypted production secrets
```

## How Secrets Are Managed

### Ansible Vault

All sensitive credentials are stored in vault.yml files and encrypted using Ansible Vault.

**Encrypt a vault file:**
```bash
ansible-vault encrypt inventory/group_vars/dev/vault.yml
ansible-vault encrypt inventory/group_vars/staging/vault.yml
ansible-vault encrypt inventory/group_vars/production/vault.yml
```

**Edit an encrypted vault file:**
```bash
ansible-vault edit inventory/group_vars/production/vault.yml
```

**Run playbook with vault:**
```bash
ansible-playbook -i inventory/dev.ini playbooks/site.yml --ask-vault-pass
# Or with vault password file:
ansible-playbook -i inventory/dev.ini playbooks/site.yml --vault-password-file .vault_pass
```

### Vault Password File

The vault password is stored locally in `.vault_pass` (excluded via `.gitignore`).

For CI/CD, the vault password is stored as a GitHub Secret (`ANSIBLE_VAULT_PASSWORD`) and injected at runtime.

### Docker Passwords

Docker container SSH passwords are passed via build args from environment variables:

```bash
# Create .env file (never commit this)
echo 'SSH_PASSWORD=your-secure-password' > .env

# Build with custom password
docker-compose --env-file .env up --build
```

## Rules

1. **NEVER** hardcode passwords, tokens, or API keys in any file that gets committed
2. **ALWAYS** use Ansible Vault for sensitive variables
3. **ALWAYS** use `.env` files or environment variables for Docker secrets
4. **NEVER** commit `.vault_pass`, `.env`, or any key files
5. **ROTATE** credentials immediately if they are accidentally exposed
6. **USE** different passwords for each environment (dev/staging/production)

## CI/CD Integration

GitHub Actions workflows use `secrets.ANSIBLE_VAULT_PASSWORD` to decrypt vault files during deployment. To set this up:

1. Go to repo Settings → Secrets and Variables → Actions
2. Add a new secret: `ANSIBLE_VAULT_PASSWORD`
3. Set its value to your vault password

## Credential Rotation

If credentials are leaked:

1. Immediately change all affected passwords
2. Re-encrypt vault files with new values
3. Rotate the vault password itself
4. Update the GitHub Secret
5. Audit git history for any remaining exposure
