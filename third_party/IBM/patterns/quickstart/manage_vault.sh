#!/bin/bash

# Simple Vault Management Script (No Ansible Required)
# This version works with plain YAML files for testing

set -e

# Parameters
VAULT_PASSWORD="$1"

echo "[$(date)] Starting simple vault management (no encryption)..."
echo "[$(date)] Working directory: $(pwd)"
echo "[$(date)] Vault password provided: ${VAULT_PASSWORD:+YES}"

# Navigate to the Enterprise-Inference directory
if [ ! -d "/home/ubuntu/Enterprise-Inference" ]; then
    echo "[ERROR] Enterprise-Inference directory not found!"
    exit 1
fi

cd /home/ubuntu/Enterprise-Inference
echo "[$(date)] Changed to directory: $(pwd)"

# First, check if inference-config.cfg exists and source it
if [ -f "/home/ubuntu/inference-config.cfg" ]; then
    . /home/ubuntu/inference-config.cfg
    echo "[$(date)] Loaded configuration from inference-config.cfg"
    echo "[$(date)] Sample config check - vault_pass_code: ${vault_pass_code:+SET}"
    echo "[$(date)] Sample config check - litellm_master_key: ${litellm_master_key:+SET}"
else
    echo "[ERROR] inference-config.cfg not found!"
    exit 1
fi

# Create a basic vault file with the actual values from config
echo "[$(date)] Creating vault.yml with current configuration values..."
cat > /home/ubuntu/Enterprise-Inference/core/inventory/metadata/vault.yml << EOF
---
# Vault values loaded from inference-config.cfg
litellm_master_key: "${litellm_master_key:-}"
litellm_salt_key: "${litellm_salt_key:-}"
redis_password: "${redis_password:-}"
langfuse_secret_key: "${langfuse_secret_key:-}"
langfuse_public_key: "${langfuse_public_key:-}"
database_url: "${database_url:-}"
postgresql_username: "${postgresql_username:-}"
postgresql_password: "${postgresql_password:-}"
redis_auth_password: "${redis_auth_password:-}"
aws_access_key: "${aws_access_key:-}"
aws_secret_key: "${aws_secret_key:-}"
aws_region: "${aws_region:-}"
aws_bucket: "${aws_bucket:-}"
clickhouse_username: "${clickhouse_username:-}"
clickhouse_password: "${clickhouse_password:-}"
langfuse_login: "${langfuse_login:-}"
langfuse_user: "${langfuse_user:-}"
langfuse_password: "${langfuse_password:-}"
clickhouse_redis_url: "${clickhouse_redis_url:-}"
minio_secret: "${minio_secret:-}"
minio_user: "${minio_user:-}"
postgres_user: "${postgres_user:-}"
postgres_password: "${postgres_password:-}"
EOF

echo "[$(date)] Created vault.yml with configuration values"

# Verify the file was created properly
if [ -f "/home/ubuntu/Enterprise-Inference/core/inventory/metadata/vault.yml" ]; then
    echo "[$(date)] Vault file created successfully"
    echo "[$(date)] File size: $(wc -l < /home/ubuntu/Enterprise-Inference/core/inventory/metadata/vault.yml) lines"
    echo "[$(date)] Sample content (first 5 lines):"
    head -5 /home/ubuntu/Enterprise-Inference/core/inventory/metadata/vault.yml
else
    echo "[ERROR] Failed to create vault.yml file!"
    exit 1
fi

# Set proper permissions
chmod 640 /home/ubuntu/Enterprise-Inference/core/inventory/metadata/vault.yml
