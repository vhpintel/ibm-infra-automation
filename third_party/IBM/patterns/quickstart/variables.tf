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
  description = "IBM Cloud instance profile for single-node deployment and worker nodes in multi-node deployment"
  type        = string
  default     = "gx3d-160x1792x8gaudi3"
}

variable "control_plane_instance_profile" {
  description = "IBM Cloud instance profile for control plane nodes in multi-node deployment"
  type        = string
  default     = "cx2d-32x64"
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
  description = "IBM Cloud instance image (for single-node or default multi-node image)"
  type        = string
  default     = ""
}

variable "xeon_image" {
  description = "IBM Cloud instance image for Xeon/CPU nodes in multi-node deployment"
  type        = string
  default     = "ibm-ubuntu-22-04-5-minimal-amd64-2"  # Default Ubuntu image for CPU nodes
}

variable "gaudi_image" {
  description = "IBM Cloud instance image for Gaudi nodes in multi-node deployment"
  type        = string
  default     = "gaudi3-os-u22-01-21-0"  # Default Gaudi image
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
variable "models" {
  description = "Model number to be deployed"
  type        = string
  default     = "1"
}
variable "vault_pass_code" {
  description = "Vault Pass code for Encryption/Decryption"
  type        = string
  default     = ""
  sensitive   = true
}
variable "cpu_or_gpu" {
  description = "This variable specifies where the model should be running"
  type        = string
  default     = "gaudi3"
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
variable "deploy_genai_gateway" {
  description = "This variable specfies whether we need to deploy Gen AI Gateway"
  type        = string
  default     = "yes"
}
variable "deploy_llm_models" {
  description = "This variable specfies whether we need to deploy LLM models"
  type        = string
  default     = "no"
}
variable "deploy_keycloak_apisix" {
  description = "This variable specfies whether we need to run keycloak and Apisix components"
  type        = string
  default     = "no"
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
variable "deployment_mode" {
  description = "Deployment mode for the infrastructure (single-node or multi-node)"
  type        = string
  default     = "single-node"
  validation {
    condition     = contains(["single-node", "multi-node"], var.deployment_mode)
    error_message = "deployment_mode must be either 'single-node' or 'multi-node'"
  }
}

variable "control_plane_count" {
  description = "Number of control plane nodes (1 for single or 3 for HA) - only used in multi-node mode"
  type        = number
  default     = 3
  validation {
    condition     = contains([1, 3], var.control_plane_count)
    error_message = "control_plane_count must be either 1 (single) or 3 (HA)"
  }
}

variable "worker_gaudi_count" {
  description = "Number of Gaudi worker nodes for inference - only used in multi-node mode"
  type        = number
  default     = 2
  validation {
    condition     = var.worker_gaudi_count >= 0 && var.worker_gaudi_count <= 10
    error_message = "worker_gaudi_count must be between 0 and 10"
  }
}

variable "control_plane_names" {
  description = "Optional custom names for control plane nodes. If not provided, defaults to 'inference-control-plane-01', etc."
  type        = list(string)
  default     = []
}

variable "worker_gaudi_names" {
  description = "Optional custom names for Gaudi worker nodes. If not provided, defaults to 'inference-workload-gaudi-node-01', etc."
  type        = list(string)
  default     = []
}