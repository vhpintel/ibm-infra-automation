# IBM Secrets Manager Integration Guide

This guide explains how to integrate IBM Secrets Manager with your Terraform deployable architecture as an alternative to manual vault management.

## Overview

The IBM Secrets Manager integration provides a secure, enterprise-grade solution for managing secrets in your IBM Cloud deployable architecture. Instead of manually managing encrypted vault files, you can store all secrets centrally in IBM Secrets Manager and retrieve them dynamically during Terraform execution.

## Two Approaches Available

### 1. IBM Secrets Manager Integration (Recommended for Production)
- Centralized secret management in IBM Cloud
- Automatic secret retrieval during deployment
- Enterprise security and compliance features
- Role-based access control

### 2. Individual Variables (For Development/Testing)
- Direct variable assignment in terraform.tfvars
- Simpler setup for development environments
- Compatible with existing vault management scripts

## Setting Up IBM Secrets Manager

### Step 1: Create Secrets Manager Instance

1. Log in to IBM Cloud Console
2. Navigate to **Security and Compliance** > **Secrets Manager**
3. Click **Create instance**
4. Configure the instance:
   - **Name**: `terraform-secrets-manager`
   - **Resource group**: Select appropriate resource group
   - **Location**: Choose region (should match your deployment region)
   - **Plan**: Standard or Trial

### Step 2: Create Secret for Vault Data

1. Open your Secrets Manager instance
2. Go to **Secrets** > **Add secret**
3. Select **Arbitrary secret**
4. Configure the secret:
   - **Name**: `vault-secrets`
   - **Secret value**: JSON payload with all vault secrets (see example below)

#### Example Secret JSON Payload:

```json
{
  "litellm_master_key": "sk-1234567890abcdef1234567890abcdef12345678",
  "litellm_salt_key": "salt_1234567890abcdef1234567890abcdef",
  "redis_password": "Redis2024!@#$",
  "langfuse_secret_key": "sk-lf-1234567890abcdef1234567890abcdef",
  "langfuse_public_key": "pk-lf-1234567890abcdef1234567890abcdef",
  "database_url": "postgresql://user:pass@localhost:5432/langfuse",
  "postgresql_username": "postgres",
  "postgresql_password": "PostgresDB2024!@#",
  "redis_auth_password": "RedisAuth2024!@#",
  "aws_access_key": "AKIAIOSFODNN7EXAMPLE",
  "aws_secret_key": "wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY",
  "aws_region": "us-east-1",
  "aws_bucket": "my-inference-bucket",
  "clickhouse_username": "clickhouse_user",
  "clickhouse_password": "ClickHouse2024!@#",
  "langfuse_login": "admin@example.com",
  "langfuse_user": "langfuse_admin",
  "langfuse_password": "LangFuse2024!@#",
  "clickhouse_redis_url": "redis://localhost:6379/1",
  "minio_secret": "minio123456789",
  "minio_user": "minio_admin",
  "postgres_user": "postgres",
  "postgres_password": "PostgresDB2024!@#"
}
```

### Step 3: Configure Terraform Variables

Update your `terraform.tfvars` file:

```hcl
# Enable IBM Secrets Manager integration
use_secrets_manager = true

# IBM Secrets Manager Configuration
secrets_manager_instance_id  = "12345678-1234-1234-1234-123456789012"  # Your instance ID
secrets_manager_region      = "us-south"  # Your instance region
secrets_manager_secret_name = "vault-secrets"  # The secret name you created

# Keep vault_pass_code for local vault operations
vault_pass_code = "your-vault-password"

# Leave individual vault secrets empty when using Secrets Manager
litellm_master_key      = ""
litellm_salt_key        = ""
redis_password          = ""
# ... (all other vault secrets should be empty)
```

### Step 4: Get Secrets Manager Instance ID

You can find your instance ID in several ways:

#### Option 1: IBM Cloud Console
1. Navigate to your Secrets Manager instance
2. Go to **Settings** > **Instance information**
3. Copy the **Instance ID**

#### Option 2: IBM Cloud CLI
```bash
ibmcloud resource service-instances --service-name secrets-manager
```

#### Option 3: Terraform Data Source
```hcl
data "ibm_resource_instance" "secrets_manager" {
  name              = "terraform-secrets-manager"
  resource_group_id = data.ibm_resource_group.group.id
  service           = "secrets-manager"
}
```

## How It Works

### Architecture Flow

1. **Terraform Initialization**: When `use_secrets_manager = true`, Terraform creates a data source for IBM Secrets Manager
2. **Secret Retrieval**: The `ibm_sm_arbitrary_secret` data source fetches the JSON payload from Secrets Manager
3. **Secret Parsing**: The `locals` block parses the JSON and creates individual secret values
4. **Template Generation**: The configuration template uses secrets from the locals block
5. **Deployment**: Secrets are injected into the deployment configuration

### Terraform Configuration Details

The integration uses these key components:

#### Data Source for Secret Retrieval
```hcl
data "ibm_sm_arbitrary_secret" "vault_secrets" {
  count       = var.use_secrets_manager ? 1 : 0
  instance_id = var.secrets_manager_instance_id
  region      = var.secrets_manager_region
  secret_type = "arbitrary"
  name        = var.secrets_manager_secret_name
}
```

#### Local Values for Secret Processing
```hcl
locals {
  secrets_from_manager = var.use_secrets_manager ? jsondecode(data.ibm_sm_arbitrary_secret.vault_secrets[0].payload) : {}
  
  vault_secrets = {
    litellm_master_key = var.use_secrets_manager ? lookup(local.secrets_from_manager, "litellm_master_key", "") : var.litellm_master_key
    # ... other secrets
  }
}
```

## Security Considerations

### Access Control
- Configure IAM policies to restrict Secrets Manager access
- Use service-to-service authorization for Terraform execution
- Implement least-privilege access principles

### Secret Rotation
- Regularly rotate secrets in Secrets Manager
- Update secret versions without changing Terraform configuration
- Monitor secret access patterns

### Audit and Compliance
- Enable Activity Tracker for secret access logging
- Set up alerts for unauthorized access attempts
- Review access logs regularly

## Deployment Options

### Option 1: Using Secrets Manager (Production)
```bash
# Set up terraform.tfvars with Secrets Manager configuration
terraform init
terraform plan
terraform apply
```

### Option 2: Using Individual Variables (Development)
```bash
# Set use_secrets_manager = false in terraform.tfvars
# Populate individual vault secret variables
terraform init
terraform plan
terraform apply
```

## Migration from Vault Files

If you're migrating from the existing vault file approach:

1. **Extract Current Secrets**: Use the `manage_vault.sh` script to decrypt your vault file and extract values
2. **Create Secrets Manager Secret**: Copy the decrypted values into the JSON payload format
3. **Update Configuration**: Set `use_secrets_manager = true` and configure Secrets Manager variables
4. **Test Deployment**: Verify the deployment works with Secrets Manager integration
5. **Clean Up**: Remove or archive the old vault files

## Troubleshooting

### Common Issues

#### Secret Not Found
```
Error: No arbitrary secret found with name 'vault-secrets'
```
**Solution**: Verify the secret name and ensure it exists in the specified Secrets Manager instance.

#### Access Denied
```
Error: Unable to retrieve secret from Secrets Manager
```
**Solution**: Check IAM permissions and ensure the API key has access to the Secrets Manager instance.

#### Invalid JSON Format
```
Error: Invalid JSON in secret payload
```
**Solution**: Validate the JSON format of your secret value. Use a JSON validator to check syntax.

### Debugging Steps

1. **Verify Instance ID**: Ensure the Secrets Manager instance ID is correct
2. **Check Region**: Confirm the region matches your Secrets Manager instance
3. **Validate JSON**: Test your secret JSON payload in a JSON validator
4. **Test Access**: Use IBM Cloud CLI to manually retrieve the secret
5. **Review Logs**: Check Terraform debug logs for detailed error information

## Best Practices

1. **Use Descriptive Secret Names**: Choose clear, consistent naming for your secrets
2. **Implement Secret Versioning**: Take advantage of Secrets Manager's versioning capabilities
3. **Monitor Secret Access**: Set up logging and monitoring for secret retrieval
4. **Regular Rotation**: Implement a regular secret rotation schedule
5. **Environment Separation**: Use different Secrets Manager instances for different environments
6. **Backup Strategy**: Ensure you have a backup strategy for critical secrets

## Cost Considerations

- IBM Secrets Manager pricing is based on the number of secrets and API calls
- Monitor usage to optimize costs
- Consider secret consolidation to reduce the number of individual secrets
- Use appropriate instance sizing for your needs

## Support and Resources

- [IBM Secrets Manager Documentation](https://cloud.ibm.com/docs/secrets-manager)
- [Terraform IBM Provider Documentation](https://registry.terraform.io/providers/IBM-Cloud/ibm/latest/docs)
- [IBM Cloud Support](https://cloud.ibm.com/unifiedsupport/supportcenter)
