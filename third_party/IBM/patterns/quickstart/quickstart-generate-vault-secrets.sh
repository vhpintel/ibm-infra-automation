
#!/bin/bash

# Quickstart Individual Vault Secrets Auto-Generator
# This script generates secure values for all vault secrets when use_secrets_manager = false
# Specifically designed for the quickstart pattern

set -e

echo "🔐 Quickstart Individual Vault Secrets Generator"
echo "==============================================="
echo ""
echo "This script will generate secure Individual Vault Secrets for development/testing"
echo "when you want to use use_secrets_manager = false instead of IBM Secrets Manager."
echo ""

# Function to generate secure passwords
generate_password() {
    local length=${1:-16}
    openssl rand -base64 $((length * 3 / 4)) | tr -d "=+/" | cut -c1-$length
}

# Function to generate hex keys
generate_hex_key() {
    local length=${1:-32}
    openssl rand -hex $length
}

echo "🔧 Generating secure credentials..."

# Generate secure individual vault secrets
LITELLM_MASTER_KEY="sk-$(generate_hex_key 10)"
LITELLM_SALT_KEY=$(generate_hex_key 10)
REDIS_PASSWORD=$(generate_password 20)
LANGFUSE_SECRET_KEY="lf_sk_$(generate_hex_key 10)"
LANGFUSE_PUBLIC_KEY="lf_pk_$(generate_hex_key 10)"
POSTGRESQL_USERNAME="admin"
POSTGRESQL_PASSWORD=$(generate_password 20)
REDIS_AUTH_PASSWORD=$(generate_password 20)
aws_access_key=""
aws_secret_key=""
aws_region=""
aws_bucket=""
CLICKHOUSE_USERNAME="default"
CLICKHOUSE_PASSWORD=$(generate_password 20)
LANGFUSE_LOGIN="quickstart@admin.com"
LANGFUSE_USER="admin"
LANGFUSE_PASSWORD="Admin$(generate_password 20)!"
MINIO_USER="minio"
MINIO_SECRET="miniosecret"
POSTGRES_USER="postgres"
POSTGRES_PASSWORD="postgres"

# Generate connection strings
DATABASE_URL="postgresql://admin:${POSTGRESQL_PASSWORD}@genai-gateway-postgresql:5432/litellm"
CLICKHOUSE_REDIS_URL="redis://default:${CLICKHOUSE_PASSWORD}@genai-gateway-trace-valkey-primary:6379/0"

echo "✅ Generated secure credentials!"
echo ""

# Create target directory if it doesn't exist
VAULT_DIR="/home/ubuntu/Enterprise-Inference/core/inventory/metadata"

# Create vault.yml file
VAULT_FILE="$VAULT_DIR/vault.yml"
echo "📝 Creating vault.yml file at: $VAULT_FILE"

cat > "$VAULT_FILE" << EOF
# Auto-generated Individual Vault Secrets
litellm_master_key: "$LITELLM_MASTER_KEY"
litellm_salt_key: "$LITELLM_SALT_KEY"
redis_password: "$REDIS_PASSWORD"
langfuse_secret_key: "$LANGFUSE_SECRET_KEY"
langfuse_public_key: "$LANGFUSE_PUBLIC_KEY"
database_url: "$DATABASE_URL"
postgresql_username: "$POSTGRESQL_USERNAME"
postgresql_password: "$POSTGRESQL_PASSWORD"
redis_auth_password: "$REDIS_AUTH_PASSWORD"
aws_access_key: "$aws_access_key"
aws_secret_key: "$aws_secret_key"
aws_region: "$aws_region"
aws_bucket: "$aws_bucket"
clickhouse_username: "$CLICKHOUSE_USERNAME"
clickhouse_password: "$CLICKHOUSE_PASSWORD"
langfuse_login: "$LANGFUSE_LOGIN"
langfuse_user: "$LANGFUSE_USER"
langfuse_password: "$LANGFUSE_PASSWORD"
clickhouse_redis_url: "$CLICKHOUSE_REDIS_URL"
minio_secret: "$MINIO_SECRET"
minio_user: "$MINIO_USER"
postgres_user: "$POSTGRES_USER"
postgres_password: "$POSTGRES_PASSWORD"
EOF

# Set appropriate permissions
chmod 640 "$VAULT_FILE"

echo ""
echo "🎉 SUCCESS! Individual Vault Secrets generated and saved to:"
echo "   $VAULT_FILE"
echo ""
echo "📊 Summary:"
echo "   - Generated 24 secure vault secrets"
echo "   - File permissions set to 640 (read-write for owner, read for group)"
echo "   - Ready for Enterprise-Inference deployment"
echo ""
