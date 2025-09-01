variable "ssh_key" {
  description = "SSH key name"
  type        = string
  default     = ""
}

variable "resource_group" {
  description = "IBM Cloud resource_group"
  type        = string
  default     = ""
}

variable "ssh_private_key" {
  default     = null
  description = "Provide the private SSH key (named id_rsa) used during the creation and configuration of the bastion server to securely authenticate and connect to the bastion server. This allows access to internal network resources from a secure entry point."
  type        = string
  sensitive   = true
}

variable "ibmcloud_region" {
  description = "IBM Cloud Region"
  type        = string
  default     = "us-east"
}

variable "instance_zone" {
  description = "IBM Cloud instance zone"
  type        = string
  default     = ""
}

variable "ssh_allowed_cidr" {
  description = "CIDR block allowed for SSH access. Use your organization's IP range for better security."
  type        = string
  default     = "0.0.0.0/0"
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
  default     = ""
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
variable "image" {
  description = "IBM Cloud instance image"
  type        = string
  default     = "gaudi3-os-u22-01-21-0"
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
  default     = "1"
}
variable "vault_pass_code" {
  description = "Vault Pass code for Encryption/Decryption"
  type        = string
  default     = "test"
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
  default     = "yes"
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