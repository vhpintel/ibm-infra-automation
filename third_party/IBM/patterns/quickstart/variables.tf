variable "ssh_key" {
  description = "SSH key name"
  type        = string
  default     = ""
}

variable "instance_name" {
  description = "IBM Cloud instance name"
  type        = string
  default     = ""
}

variable "instance_zone" {
  description = "IBM Cloud instance zone"
  type        = string
  default     = ""
}

variable "instance_profile" {
  description = "IBM Cloud instance profile"
  type        = string
  default     = ""
}

variable "vpc" {
  description = "IBM Cloud VPC"
  type        = string
  default     = ""
}

variable "security_group" {
  description = "IBM Cloud security_group"
  type        = string
  default     = ""
}

variable "public_gateway" {
  description = "IBM Cloud public_gateway"
  type        = string
  default     = ""
}

variable "subnet" {
  description = "IBM Cloud subnet"
  type        = string
  default     = ""
}

variable "resource_group" {
  description = "IBM Cloud resource_group"
  type        = string
  default     = ""
}

variable "image" {
  description = "IBM Cloud instance image"
  type        = string
  default     = ""
}
variable "ssh_private_key" {
  default     = null
  description = "Provide the private SSH key (named id_rsa) used during the creation and configuration of the bastion server to securely authenticate and connect to the bastion server. This allows access to internal network resources from a secure entry point. Note: The corresponding public SSH key (named id_rsa.pub) must already be available in the ~/.ssh/authorized_keys file on the bastion host to establish authentication."
  type        = string
  sensitive   = true
}

variable "ibmcloud_region" {
  description = "IBM Cloud Region"
  type        = string
  default     = "us-east"
}
variable "ibmcloud_api_key" {
  description = "IBM Cloud API Key"
  type        = string
  sensitive   = true
  default     = ""
}
variable "cluster_url" {
  description = "The URL of the cluster"
  type        = string
  default     = "api.example.com"
}
variable "cert_path" {
  description = "The path to the certificate file"
  type        = string
  default     = "~/certs/cert.pem"
}
variable "key_path" {
  description = "The path to the key file"
  type        = string
  default     = "~/certs/key.pem"
}
variable "user_cert" {
  description = "The contents of the TLS certificate (PEM format)"
  type        = string
}

variable "user_key" {
  description = "The contents of the TLS private key (PEM format)"
  type        = string
}

variable "hugging_face_token" {
  description = "This variable specifies the hf token."
  type        = string
  default     = ""
  sensitive   = true
}
variable "cpu_or_gpu" {
  description = "This variable specifies where the model should be running"
  type        = string
  default     = "gaudi3"
}
variable "models" {
  description = "Model number to be deployed"
  type        = string
  default     = ""
}
variable "vault_pass_code" {
  description = "Vault Pass code for Encryption/Decryption"
  type        = string
  default     = ""
}

# IBM Secrets Manager Integration
variable "use_secrets_manager" {
  description = "Whether to use IBM Secrets Manager for secret management"
  type        = bool
  default     = false
}

variable "secrets_manager_instance_id" {
  description = "IBM Secrets Manager instance ID (GUID). Required if use_secrets_manager is true."
  type        = string
  default     = ""
}

variable "secrets_manager_region" {
  description = "IBM Secrets Manager region. Defaults to ibmcloud_region if not specified."
  type        = string
  default     = ""
}

variable "secrets_manager_secret_name" {
  description = "Name of the secret in IBM Secrets Manager containing vault values"
  type        = string
  default     = "inference-vault-secrets"
}


variable "secrets_manager_secret_group_name" {
  description = "Name of the secret group in IBM Secrets Manager. Required when specifying a secret by name."
  type        = string
  default     = "default"
}

# Vault secret variables - used when NOT using Secrets Manager
variable "litellm_master_key" {
  description = "LiteLLM Master Key - if provided, will automatically update vault"
  type        = string
  default     = ""
  sensitive   = true
}

variable "litellm_salt_key" {
  description = "LiteLLM Salt Key - if provided, will automatically update vault"
  type        = string
  default     = ""
  sensitive   = true
}

variable "redis_password" {
  description = "Redis Password - if provided, will automatically update vault"
  type        = string
  default     = ""
  sensitive   = true
}

variable "langfuse_secret_key" {
  description = "Langfuse Secret Key - if provided, will automatically update vault"
  type        = string
  default     = ""
  sensitive   = true
}

variable "langfuse_public_key" {
  description = "Langfuse Public Key - if provided, will automatically update vault"
  type        = string
  default     = ""
  sensitive   = true
}

variable "database_url" {
  description = "Database URL - if provided, will automatically update vault"
  type        = string
  default     = ""
  sensitive   = true
}

variable "postgresql_username" {
  description = "PostgreSQL Username - if provided, will automatically update vault"
  type        = string
  default     = ""
  sensitive   = true
}

variable "postgresql_password" {
  description = "PostgreSQL Password - if provided, will automatically update vault"
  type        = string
  default     = ""
  sensitive   = true
}

variable "redis_auth_password" {
  description = "Redis Auth Password - if provided, will automatically update vault"
  type        = string
  default     = ""
  sensitive   = true
}

variable "aws_access_key" {
  description = "AWS Access Key - if provided, will automatically update vault"
  type        = string
  default     = ""
  sensitive   = true
}

variable "aws_secret_key" {
  description = "AWS Secret Key - if provided, will automatically update vault"
  type        = string
  default     = ""
  sensitive   = true
}

variable "aws_region" {
  description = "AWS Region - if provided, will automatically update vault"
  type        = string
  default     = ""
  sensitive   = true
}

variable "aws_bucket" {
  description = "AWS Bucket - if provided, will automatically update vault"
  type        = string
  default     = ""
  sensitive   = true
}
variable "clickhouse_username" {
  description = "ClickHouse Username - if provided, will automatically update vault"
  type        = string
  default     = ""
  sensitive   = true
}

variable "clickhouse_password" {
  description = "ClickHouse Password - if provided, will automatically update vault"
  type        = string
  default     = ""
  sensitive   = true
}

variable "langfuse_login" {
  description = "Langfuse Login - if provided, will automatically update vault"
  type        = string
  default     = ""
  sensitive   = true
}

variable "langfuse_user" {
  description = "Langfuse User - if provided, will automatically update vault"
  type        = string
  default     = ""
  sensitive   = true
}

variable "langfuse_password" {
  description = "Langfuse Password - if provided, will automatically update vault"
  type        = string
  default     = ""
  sensitive   = true
}

variable "clickhouse_redis_url" {
  description = "ClickHouse Redis URL - if provided, will automatically update vault"
  type        = string
  default     = ""
  sensitive   = true
}

variable "minio_secret" {
  description = "MinIO Secret - if provided, will automatically update vault"
  type        = string
  default     = ""
  sensitive   = true
}

variable "minio_user" {
  description = "MinIO User - if provided, will automatically update vault"
  type        = string
  default     = ""
  sensitive   = true
}

variable "postgres_user" {
  description = "Postgres User - if provided, will automatically update vault"
  type        = string
  default     = ""
  sensitive   = true
}

variable "postgres_password" {
  description = "Postgres Password - if provided, will automatically update vault"
  type        = string
  default     = ""
  sensitive   = true
}

variable "deploy_kubernetes_fresh" {
  description = "This variable specfies whether to deploy Kubernetes cluster freshly"
  type        = string
  default     = "yes"
}

variable "deploy_ingress_controller" {
  description = "This variable specfies whether to deploy NGNIX ingress controller or not"
  type        = string
  default     = "yes"
}
variable "deploy_keycloak_apisix" {
  description = "This variable specfies whether we need to run keycloak and Apisix components"
  type        = string
  default     = "no"
}
variable "deploy_llm_models" {
  description = "This variable specfies whether we need to deploy LLM models"
  type        = string
  default     = "no"
}
variable "deploy_genai_gateway" {
  description = "This variable specfies whether we need to deploy Gen AI Gateway"
  type        = string
  default     = "yes"
}
variable "deploy_observability" {
  description = "This variable specfies whether we need to run observability"
  type        = string
  default     = "no"
}
variable "deploy_ceph" {
  description = "This variable specfies whether we need to Ceph related storage components"
  type        = string
  default     = "no"
}
variable "deploy_istio" {
  description = "This variable specfies whether we need to Istio related service mesh components"
  type        = string
  default     = "no"
}