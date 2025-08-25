# IBM Cloud Infrastructure Configuration
ibmcloud_api_key = ""
ibmcloud_region  = ""

# VPC and Instance Configuration
instance_name         = ""
instance_zone         = ""
image                 = ""
resource_group        = ""

# SSH Configuration
ssh_key               = ""
ssh_private_key       = ""

# Cluster Configuration
cluster_url           = ""
cert_path             = "~/certs/cert.pem"
key_path              = "~/certs/key.pem"
user_cert             = ""
user_key              = ""
# AI/ML Configuration
hugging_face_token    = ""
cpu_or_gpu            = ""
models                = ""

# =============================================================================
# OPTION 1: Using IBM Secrets Manager (Recommended for Production)
# =============================================================================
# Enable IBM Secrets Manager integration
use_secrets_manager = true

# IBM Secrets Manager Configuration
secrets_manager_instance_id  = ""
secrets_manager_region      = ""  # Leave empty to use ibmcloud_region
secrets_manager_secret_name = ""
secrets_manager_secret_group_name = ""


# When using Secrets Manager, you still need vault_pass_code for local vault operations
vault_pass_code = ""

# =============================================================================
# OPTION 2: Using Individual Variables (For Development/Testing)
# =============================================================================
# Disable IBM Secrets Manager to use individual variables
# use_secrets_manager = false

# Vault Configuration
# vault_pass_code = ""

# Individual Vault Secrets (uncomment when use_secrets_manager = false)
# litellm_master_key      = ""
# litellm_salt_key        = ""
# redis_password          = ""
# langfuse_secret_key     = ""
# langfuse_public_key     = ""
# database_url            = ""
# postgresql_username     = ""
# postgresql_password     = ""
# redis_auth_password     = ""
# aws_access_key          = ""
# aws_secret_key          = ""
# aws_region              = ""
# aws_bucket              = ""
# clickhouse_username     = ""
# clickhouse_password     = ""
# langfuse_login          = ""
# langfuse_user           = ""
# langfuse_password       = ""
# clickhouse_redis_url    = ""
# minio_secret            = ""
# minio_user              = ""
# postgres_user           = ""
# postgres_password       = ""
