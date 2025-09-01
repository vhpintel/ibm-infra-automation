provider "ibm" {
  ibmcloud_api_key = var.ibmcloud_api_key
  region           = var.ibmcloud_region
  ibmcloud_timeout = 60
}

locals {
    BASENAME = "gaudi"
}

data "ibm_resource_group" "target_rg" {
  name = var.resource_group
}

data "ibm_is_image" "packer_image" {
    name = var.image
}

resource "ibm_is_vpc" "new_vpc" {
    name = "${local.BASENAME}-vpc-${random_string.suffix.result}"
    resource_group = data.ibm_resource_group.target_rg.id
}

resource "random_string" "suffix" {
  length  = 3
  special = false
  upper   = false
}

resource "ibm_is_security_group" "new_sg" {
    name = "${local.BASENAME}-sg-${random_string.suffix.result}"
    vpc  = ibm_is_vpc.new_vpc.id
    resource_group = data.ibm_resource_group.target_rg.id
}

# SSH access - restrict to specific IP ranges For production, replace "0.0.0.0/0
resource "ibm_is_security_group_rule" "ingress_ssh_restricted" {
    group     = ibm_is_security_group.new_sg.id
    direction = "inbound"
    remote    = var.ssh_allowed_cidr

    tcp {
      port_min = 22
      port_max = 22
    }
}

# Allow HTTPS outbound (443)
resource "ibm_is_security_group_rule" "egress_https" {
  group     = ibm_is_security_group.new_sg.id
  direction = "outbound"
  remote    = "0.0.0.0/0"

  tcp {
    port_min = 443
    port_max = 443
  }
}

# Allow HTTP outbound (80)
resource "ibm_is_security_group_rule" "egress_http" {
  group     = ibm_is_security_group.new_sg.id
  direction = "outbound"
  remote    = "0.0.0.0/0"

  tcp {
    port_min = 80
    port_max = 80
  }
}

# Allow NTP outbound (123) for time synchronization
resource "ibm_is_security_group_rule" "egress_ntp" {
  group     = ibm_is_security_group.new_sg.id
  direction = "outbound"
  remote    = "0.0.0.0/0"

  udp {
    port_min = 123
    port_max = 123
  }
}

# Allow outbound SSH (22) for git operations
resource "ibm_is_security_group_rule" "egress_ssh" {
  group     = ibm_is_security_group.new_sg.id
  direction = "outbound"
  remote    = "0.0.0.0/0"

  tcp {
    port_min = 22
    port_max = 22
  }
}

# Allow DNS resolution (UDP 53)
resource "ibm_is_security_group_rule" "egress_dns" {
  group     = ibm_is_security_group.new_sg.id
  direction = "outbound"
  remote    = "0.0.0.0/0"

  udp {
    port_min = 53
    port_max = 53
  }
}

# Allow inbound HTTPS for model endpoints and APIs
resource "ibm_is_security_group_rule" "ingress_https" {
  group     = ibm_is_security_group.new_sg.id
  direction = "inbound"
  remote    = "0.0.0.0/0"

  tcp {
    port_min = 443
    port_max = 443
  }
}

# Allow inbound HTTP for initial setup and redirects
resource "ibm_is_security_group_rule" "ingress_http" {
  group     = ibm_is_security_group.new_sg.id
  direction = "inbound"
  remote    = "0.0.0.0/0"

  tcp {
    port_min = 80
    port_max = 80
  }
}

# Create a Public Gateway for the VPC
resource "ibm_is_public_gateway" "new_pgw" {
  name = "${local.BASENAME}-public-gateway-${random_string.suffix.result}"
  vpc  = ibm_is_vpc.new_vpc.id
  zone = var.instance_zone
  resource_group = data.ibm_resource_group.target_rg.id
}

resource "ibm_is_subnet" "new_subnet" {
    name                     = "${local.BASENAME}-subnet-${random_string.suffix.result}"
    vpc                      = ibm_is_vpc.new_vpc.id
    zone                     = var.instance_zone
    total_ipv4_address_count = 256
    public_gateway           = ibm_is_public_gateway.new_pgw.id
    resource_group           = data.ibm_resource_group.target_rg.id
}

data "ibm_is_ssh_key" "ssh_key_id" {
    name = var.ssh_key
}

resource "ibm_is_instance" "vsi" {
    name    = "${local.BASENAME}-vsi-${random_string.suffix.result}"
    vpc     = ibm_is_vpc.new_vpc.id
    zone    = var.instance_zone
    keys    = [data.ibm_is_ssh_key.ssh_key_id.id]
    image   = data.ibm_is_image.packer_image.id
    resource_group = data.ibm_resource_group.target_rg.id
    profile = "gx3d-160x1792x8gaudi3"

    primary_network_interface {
        subnet          = ibm_is_subnet.new_subnet.id
        security_groups = [ibm_is_security_group.new_sg.id]
    }
}

resource "ibm_is_floating_ip" "public_ip" {
    name    = "${local.BASENAME}-fip-${random_string.suffix.result}"
    target = ibm_is_instance.vsi.primary_network_interface[0].id
    resource_group = data.ibm_resource_group.target_rg.id
}

# Kubernetes security group rules (after subnet is defined)
# Allow Kubernetes API server port (6443) for cluster management
resource "ibm_is_security_group_rule" "ingress_k8s_api" {
  group     = ibm_is_security_group.new_sg.id
  direction = "inbound"
  remote    = ibm_is_subnet.new_subnet.ipv4_cidr_block

  tcp {
    port_min = 6443
    port_max = 6443
  }
}

# Allow Kubernetes node communication ports (10250, 10255)
resource "ibm_is_security_group_rule" "ingress_k8s_nodes" {
  group     = ibm_is_security_group.new_sg.id
  direction = "inbound"
  remote    = ibm_is_subnet.new_subnet.ipv4_cidr_block

  tcp {
    port_min = 10250
    port_max = 10255
  }
}

# Allow outbound Kubernetes API calls
resource "ibm_is_security_group_rule" "egress_k8s_api" {
  group     = ibm_is_security_group.new_sg.id
  direction = "outbound"
  remote    = ibm_is_subnet.new_subnet.ipv4_cidr_block

  tcp {
    port_min = 6443
    port_max = 6443
  }
}

# Allow outbound Kubernetes node communication
resource "ibm_is_security_group_rule" "egress_k8s_nodes" {
  group     = ibm_is_security_group.new_sg.id
  direction = "outbound"
  remote    = ibm_is_subnet.new_subnet.ipv4_cidr_block

  tcp {
    port_min = 10250
    port_max = 10255
  }
}

locals {
  floating_ip_address = ibm_is_floating_ip.public_ip.address
}

output "floating_ip" {
  value = ibm_is_floating_ip.public_ip.address
}

output "reserved_ip" {
  value = ibm_is_instance.vsi.primary_network_interface[0].primary_ipv4_address
}

output "model_endpoint" {
  description = "Constructed URL for the selected Llama model endpoint"
  value       = "https://${var.cluster_url}/v1/completions"
}
output "model_id" {
  description = "Model ID based on the models number from terraform.tfvars"
  value = var.models == "1" ? "meta-llama/Llama-3.1-8B-Instruct" : (
    var.models == "11" ? "meta-llama/Llama-3.1-405B-Instruct" : (
      var.models == "12" ? "meta-llama/Llama-3.3-70B-Instruct" : "Unknown model"
    )
  )
}
output "genAI_gateway_url" {
  description = " GenAI Gateway URL to manage , access and interact with models"
  value       = "https://${var.cluster_url}/ui"
}

output "genAI_gateway_url_trace_url" {
  description = " GenAI Gateway Trace URL to manage observability, metrics, evaluations, prompt management for deployed models"
  value       = "https://trace.${var.cluster_url}/"
}

resource "null_resource" "display_vault_content" {
  triggers = {
    always_run = timestamp()
  }
  depends_on = [null_resource.run_script]

  provisioner "remote-exec" {
    connection {
      type        = "ssh"
      user        = "ubuntu"
      private_key = can(file(var.ssh_private_key)) ? file(var.ssh_private_key) : var.ssh_private_key
      host        = ibm_is_floating_ip.public_ip.address
    }
    
    inline = [
      "echo '=========================================='",
      "echo 'DISPLAYING VAULT.YML CONTENT'",
      "echo '=========================================='",
      "cat /home/ubuntu/Enterprise-Inference/core/inventory/metadata/vault.yml || echo 'vault.yml not found'",
      "echo '=========================================='"
    ]
  }
}

output "vault_yml_display_note" {
  description = "Note about vault.yml content being displayed in Terraform logs"
  value       = "The complete vault.yml content is displayed in the Terraform console logs during apply via remote-exec. Check the logs or search for the 'DISPLAYING VAULT.YML CONTENT' section."
  depends_on  = [null_resource.display_vault_content]
}

data "template_file" "inference_config" {
  template = file("${path.module}/inference-config.tpl")
  vars = {
    cluster_url                = var.cluster_url
    cert_file                  = var.cert_path
    key_file                   = var.key_path
    hugging_face_token         = var.hugging_face_token
    cpu_or_gpu                 = var.cpu_or_gpu
    models                     = var.models
    vault_pass_code            = var.vault_pass_code
    deploy_kubernetes_fresh    = var.deploy_kubernetes_fresh
    deploy_ingress_controller  = var.deploy_ingress_controller
    deploy_keycloak_apisix     = var.deploy_keycloak_apisix
    deploy_llm_models          = var.deploy_llm_models
    deploy_genai_gateway       = var.deploy_genai_gateway
    deploy_observability       = var.deploy_observability
    deploy_ceph                = var.deploy_ceph
    deploy_istio               = var.deploy_istio
  }
}
locals {
  encoded_cert = base64encode(var.user_cert)
  encoded_key  = base64encode(var.user_key)
}

resource "null_resource" "wait_for_ssh" {
  provisioner "remote-exec" {
    inline = ["echo 'SSH is ready'"]

    connection {
      type        = "ssh"
      user        = "ubuntu"
      private_key = can(file(var.ssh_private_key)) ? file(var.ssh_private_key) : var.ssh_private_key
      host        = ibm_is_floating_ip.public_ip.address
      timeout     = "20m"  # Total time to keep retrying
    }
  }
  
triggers = {
  instance_id = ibm_is_instance.vsi.id
  ip_address  = ibm_is_floating_ip.public_ip.address
}

depends_on = [
  ibm_is_instance.vsi,
  ibm_is_floating_ip.public_ip
]
}
resource "null_resource" "run_script" {
  triggers = {
    always_run = timestamp()
  }
  depends_on = [null_resource.wait_for_ssh] 
  provisioner "file" {
    source      = "${path.module}/run_script.sh"
    destination = "/tmp/run_script.sh"

    connection {
      type        = "ssh"
      user        = "ubuntu"
      private_key = can(file(var.ssh_private_key)) ? file(var.ssh_private_key) : var.ssh_private_key
      host        = ibm_is_floating_ip.public_ip.address
    }
  }
  provisioner "file" {
    source      = "${path.module}/quickstart-generate-vault-secrets.sh"
    destination = "/home/ubuntu/quickstart-generate-vault-secrets.sh"

    connection {
      type        = "ssh"
      user        = "ubuntu"
      private_key = can(file(var.ssh_private_key)) ? file(var.ssh_private_key) : var.ssh_private_key
      host        = ibm_is_floating_ip.public_ip.address
    }
  }
  provisioner "file" {
    content     = data.template_file.inference_config.rendered
    destination = "/home/ubuntu/inference-config.cfg"

    connection {
      type        = "ssh"
      user        = "ubuntu"
      private_key = can(file(var.ssh_private_key)) ? file(var.ssh_private_key) : var.ssh_private_key
      host        = ibm_is_floating_ip.public_ip.address
    }
  }
  provisioner "file" {
    connection {
      type        = "ssh"
      user        = "ubuntu"
      private_key = can(file(var.ssh_private_key)) ? file(var.ssh_private_key) : var.ssh_private_key
      host        = ibm_is_floating_ip.public_ip.address
    }
    content     = local.encoded_cert
    destination = "/tmp/cert.b64"
  }

  provisioner "file" {
    connection {
      type        = "ssh"
      user        = "ubuntu"
      private_key = can(file(var.ssh_private_key)) ? file(var.ssh_private_key) : var.ssh_private_key
      host        = ibm_is_floating_ip.public_ip.address
    }
    content     = local.encoded_key
    destination = "/tmp/key.b64"
  }
  provisioner "remote-exec" {
    connection {
      type        = "ssh"
      user        = "ubuntu"
      private_key = can(file(var.ssh_private_key)) ? file(var.ssh_private_key) : var.ssh_private_key
      host        = ibm_is_floating_ip.public_ip.address
    }
    inline = [
      "base64 -d /tmp/cert.b64 > ${var.cert_path}",
      "base64 -d /tmp/key.b64 > ${var.key_path}",
      "chmod +x /tmp/run_script.sh",
      "/tmp/run_script.sh '${ibm_is_instance.vsi.primary_network_interface[0].primary_ipv4_address}' '${var.cluster_url}' '${var.models}' '${var.cert_path}' '${var.key_path}' '${var.user_cert}' '${var.user_key}'"
    ]
  }
}

resource "null_resource" "patch_storage" {
  triggers = {
    always_run = timestamp()
  }
  depends_on = [null_resource.run_script]
  provisioner "file" {
    source      = "${path.module}/run_script.sh"
    destination = "/tmp/run_script.sh"
    connection {
      type        = "ssh"
      user        = "ubuntu"
      private_key = can(file(var.ssh_private_key)) ? file(var.ssh_private_key) : var.ssh_private_key
      host        = ibm_is_floating_ip.public_ip.address
    }
  }
  provisioner "remote-exec" {
    connection {
      type        = "ssh"
      user        = "ubuntu"
      private_key = can(file(var.ssh_private_key)) ? file(var.ssh_private_key) : var.ssh_private_key
      host        = ibm_is_floating_ip.public_ip.address
    }
    inline = [
      "chmod +x /tmp/run_script.sh",
      "/tmp/run_script.sh storage-only"
    ]
  }
}

resource "null_resource" "model_deploy" {
  triggers = {
    always_run = timestamp()
  }
  depends_on = [null_resource.patch_storage]
  provisioner "file" {
    source      = "${path.module}/run_script.sh"
    destination = "/tmp/run_script.sh"
    connection {
      type        = "ssh"
      user        = "ubuntu"
      private_key = can(file(var.ssh_private_key)) ? file(var.ssh_private_key) : var.ssh_private_key
      host        = ibm_is_floating_ip.public_ip.address
    }
  }
  provisioner "remote-exec" {
    connection {
      type        = "ssh"
      user        = "ubuntu"
      private_key = can(file(var.ssh_private_key)) ? file(var.ssh_private_key) : var.ssh_private_key
      host        = ibm_is_floating_ip.public_ip.address
    }
    inline = [
      "chmod +x /tmp/run_script.sh",
      "/tmp/run_script.sh model-deploy '${var.models}'"
    ]
  }
}
