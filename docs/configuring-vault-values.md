# Configuring Vault Values

This document explains how to configure and manage vault values for deployment using **Automated Vault Management** within the IBM deployable architecture.

## Overview

The vault file contains sensitive configuration values like passwords, API keys, and secrets. This deployment supports **automated vault management** that eliminates the manual decrypt-edit-encrypt workflow entirely.

## 🚀 Automated Approach (Recommended)

### How It Works

1. **Set Variables**: Simply set your passwords in `terraform.tfvars`
2. **Deploy**: Run `terraform apply`  
3. **Automatic Processing**: The system automatically:
   - Copies the example vault file (if available) or creates a new one
   - Updates it with your actual passwords from Terraform variables
   - Encrypts it (if ansible-vault is available) or leaves it as plain text
   - Continues with deployment

### Configuration

Update your `terraform.tfvars` with your actual passwords:

```hcl
# Vault password for encryption/decryption
vault_pass_code="ibm-prod-123"

# Your actual secrets - set these and deployment handles the rest!
litellm_master_key="your-actual-master-key"
litellm_salt_key="your-actual-salt-key"
redis_password="your-redis-password"
postgresql_password="your-db-password"

# Set any other fields you need:
langfuse_secret_key="your-langfuse-secret"
aws_access_key="your-aws-key"
# ... etc
```

### That's It!

Just run:
```bash
terraform apply
```

The deployment will handle all vault operations automatically.

### 2. Decrypt the Vault File

To edit the vault file, you first need to decrypt it:

```bash
ansible-vault decrypt inventory/metadata/vault.yml
```

**Default Password:** `place-holder-123`

### 3. Update Your Values

Once decrypted, edit the `vault.yml` file with your actual values:

```yaml
# Example values (replace with your actual secrets)
litellm_master_key: "your-actual-master-key"
litellm_salt_key: "your-actual-salt-key"
redis_password: "your-redis-password"
postgresql_password: "your-db-password"
# ... add other secrets as needed
```

### 4. Encrypt the Vault File

After making your changes, encrypt the file again:

```bash
ansible-vault encrypt inventory/metadata/vault.yml
```

**Important:** Always encrypt the vault file before committing to version control.

## Changing the Vault Password

You can customize the vault password by updating the configuration in:

```
core/inference-config.cfg
```

Look for the key:
```
vault-pass-code=your-new-password
```

After changing the password, you'll need to rekey your existing vault file:

```bash
ansible-vault rekey inventory/metadata/vault.yml
```

## Best Practices

1. **Use strong, unique passwords** for your vault
2. **Backup your vault password** securely
3. **Use different vault files** for different environments (dev, staging, prod)

## Security Notes
- The vault file should have restricted permissions (600 or 640)

## Example Workflow

```bash
# 1. Decrypt the vault
ansible-vault decrypt inventory/metadata/vault.yml

# 2. Edit the file
nano inventory/metadata/vault.yml

# 3. Encrypt the file
ansible-vault encrypt inventory/metadata/vault.yml
