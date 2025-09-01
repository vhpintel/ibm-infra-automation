# Individual Vault Secrets - Easy Setup Guide

This guide provides simple solutions to configure Individual Vault Secrets when you want to use `use_secrets_manager = false` instead of IBM Secrets Manager.

## 🚀 Quick Start (Recommended)

### Option 1: Auto-Generate All Secrets (30 seconds)

```bash
# Run the auto-generator script
./quickstart-generate-vault-secrets.sh

# Copy the output to your terraform.tfvars file
# Set use_secrets_manager = false
# Done!
```

### Option 2: One-Command Setup

```bash
# Run the complete setup
./setup-vault-secrets.sh

# Follow the instructions to merge with terraform.tfvars
```

## 📋 What Gets Generated

The scripts automatically generate secure values for all 22 Individual Vault Secrets:

### 🔐 Authentication & Keys
- `vault_pass_code` - Master vault password
- `litellm_master_key` - LiteLLM API master key
- `litellm_salt_key` - LiteLLM encryption salt
- `langfuse_secret_key` - Langfuse secret key
- `langfuse_public_key` - Langfuse public key

### 🗄️ Database Configuration
- `postgresql_username` & `postgresql_password` - PostgreSQL credentials
- `postgres_user` & `postgres_password` - Postgres user credentials
- `database_url` - Complete PostgreSQL connection string
- `clickhouse_username` & `clickhouse_password` - ClickHouse credentials

### 🔒 Service Authentication
- `redis_password` & `redis_auth_password` - Redis authentication
- `langfuse_login`, `langfuse_user` & `langfuse_password` - Langfuse user credentials
- `minio_user` & `minio_secret` - MinIO storage credentials
- `clickhouse_redis_url` - ClickHouse Redis connection string

### ☁️ AWS Configuration (Optional)
- `aws_access_key`, `aws_secret_key`, `aws_region`, `aws_bucket` - AWS S3 integration

## 🛠️ Manual Setup (Alternative)

If you prefer to configure manually:

1. **Set the mode**: In `terraform.tfvars`, change to:
   ```hcl
   use_secrets_manager = false
   ```

2. **Uncomment the Individual Vault Secrets section** and replace values

3. **Generate secure passwords** using these commands:
   ```bash
   # For hex keys (32 chars)
   openssl rand -hex 32
   
   # For base64 passwords (16 chars)
   openssl rand -base64 16 | tr -d "=+/" | cut -c1-16
   
   # For longer passwords (24 chars)
   openssl rand -base64 24 | tr -d "=+/"
   ```

## 🔄 Switching Between Modes

### From Secrets Manager → Individual Variables
1. Change: `use_secrets_manager = false`
2. Run: `./quickstart-generate-vault-secrets.sh`
3. Copy generated values to terraform.tfvars

### From Individual Variables → Secrets Manager
1. Change: `use_secrets_manager = true`
2. Comment out the Individual Vault Secrets section
3. Ensure IBM Secrets Manager is properly configured

## 🔒 Security Best Practices

### For Development
- ✅ Use the auto-generated values as-is
- ✅ Keep simple passwords for easy debugging
- ✅ No AWS credentials needed for local testing

### For Production
- ⚠️ **Replace ALL generated values with your own secure credentials**
- ⚠️ **Use strong, unique passwords for each service**
- ⚠️ **Store backup of credentials in secure password manager**
- ⚠️ **Rotate passwords regularly**
- ⚠️ **Use IBM Secrets Manager instead (`use_secrets_manager = true`)**

## 🆘 Troubleshooting

### Script not found
```bash
# Make sure you're in the correct directory
ls -la quickstart-generate-vault-secrets.sh

# If missing, download/copy the script file
```

### Permission denied
```bash
# Make scripts executable
chmod +x quickstart-generate-vault-secrets.sh
chmod +x setup-vault-secrets.sh
```

### Terraform validation errors
```bash
# Check your terraform.tfvars syntax
terraform validate

# Ensure use_secrets_manager is set correctly
grep "use_secrets_manager" terraform.tfvars
```

## 📊 Benefits Summary

| Approach | Setup Time | Security | Maintenance |
|----------|------------|----------|-------------|
| **Auto-Generator** | 30 seconds | High | Low |
| IBM Secrets Manager | 5 minutes | Highest | Lowest |
| Manual Configuration | 15-30 minutes | Medium-High | High |

## 🎯 Recommendations

- **Development/Testing**: Use the auto-generator script
- **Staging**: Use auto-generator + review/customize values  
- **Production**: Use IBM Secrets Manager (`use_secrets_manager = true`)

---

💡 **Need help?** Check the generated examples in your terraform.tfvars file or run the interactive configurator!
