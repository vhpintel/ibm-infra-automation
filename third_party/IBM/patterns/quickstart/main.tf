provider "ibm" {
  ibmcloud_api_key = var.ibmcloud_api_key
  region           = var.ibmcloud_region
  ibmcloud_timeout = 60
}

locals {
  BASENAME = "gaudi"
}

data "ibm_is_vpc" "existing_vpc" {
  name = var.vpc
}

data "ibm_is_security_group" "existing_sg" {
  name = var.security_group
  vpc  = data.ibm_is_vpc.existing_vpc.id
}

data "ibm_is_public_gateway" "existing_pgw" {
  name = var.public_gateway
}

data "ibm_is_subnet" "existing_subnet" {
  name = var.subnet
}

data "ibm_is_image" "ubuntu" {
  name = var.image
}

data "ibm_resource_group" "target_rg" {
  name = var.resource_group
}

data "ibm_is_ssh_key" "ssh_key_id" {
  name = var.ssh_key
}

resource "ibm_is_instance" "instance_name" {
  name           = var.instance_name
  vpc            = data.ibm_is_vpc.existing_vpc.id
  zone           = var.instance_zone
  keys           = [data.ibm_is_ssh_key.ssh_key_id.id]
  image          = data.ibm_is_image.ubuntu.id
  profile        = var.instance_profile
  resource_group = data.ibm_resource_group.target_rg.id

  primary_network_interface {
    subnet          = data.ibm_is_subnet.existing_subnet.id
    security_groups = [data.ibm_is_security_group.existing_sg.id]
  }
}

resource "ibm_is_floating_ip" "instance_name" {
  name           = var.instance_name
  target         = ibm_is_instance.instance_name.primary_network_interface[0].id
  resource_group = data.ibm_resource_group.target_rg.id
}

locals {
  floating_ip_address = ibm_is_floating_ip.instance_name.address
}

output "floating_ip" {
  value = ibm_is_floating_ip.instance_name.address
}
output "reserved_ip" {
  value = ibm_is_instance.instance_name.primary_network_interface[0].primary_ipv4_address
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
output "genai_gateway_url" {
  description = " GenAI Gateway URL to manage , access and interact with models"
  value       = "https://${var.cluster_url}/ui"
}
output "genai_gateway_trace_url" {
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
      host        = ibm_is_floating_ip.instance_name.address
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
    cluster_url               = var.cluster_url
    cert_file                 = var.cert_path
    key_file                  = var.key_path
    hugging_face_token        = var.hugging_face_token
    cpu_or_gpu                = var.cpu_or_gpu
    models                    = var.models
    vault_pass_code           = var.vault_pass_code
    deploy_kubernetes_fresh   = var.deploy_kubernetes_fresh
    deploy_ingress_controller = var.deploy_ingress_controller
    deploy_keycloak_apisix    = var.deploy_keycloak_apisix
    deploy_llm_models         = var.deploy_llm_models
    deploy_genai_gateway      = var.deploy_genai_gateway
    deploy_observability      = var.deploy_observability
    deploy_ceph               = var.deploy_ceph
    deploy_istio              = var.deploy_istio
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
      host        = ibm_is_floating_ip.instance_name.address
      timeout     = "20m" # Total time to keep retrying
    }
  }

  triggers = {
    instance_id = ibm_is_instance.instance_name.id
    ip_address  = ibm_is_floating_ip.instance_name.address
  }

  depends_on = [
    ibm_is_instance.instance_name,
    ibm_is_floating_ip.instance_name
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
      host        = ibm_is_floating_ip.instance_name.address
    }
  }

  provisioner "file" {
    source      = "${path.module}/quickstart-generate-vault-secrets.sh"
    destination = "/home/ubuntu/quickstart-generate-vault-secrets.sh"

    connection {
      type        = "ssh"
      user        = "ubuntu"
      private_key = can(file(var.ssh_private_key)) ? file(var.ssh_private_key) : var.ssh_private_key
      host        = ibm_is_floating_ip.instance_name.address
    }
  }

  provisioner "file" {
    content     = data.template_file.inference_config.rendered
    destination = "/home/ubuntu/inference-config.cfg"

    connection {
      type        = "ssh"
      user        = "ubuntu"
      private_key = can(file(var.ssh_private_key)) ? file(var.ssh_private_key) : var.ssh_private_key
      host        = ibm_is_floating_ip.instance_name.address
    }
  }
  provisioner "file" {
    connection {
      type        = "ssh"
      user        = "ubuntu"
      private_key = can(file(var.ssh_private_key)) ? file(var.ssh_private_key) : var.ssh_private_key
      host        = ibm_is_floating_ip.instance_name.address
    }
    content     = local.encoded_cert
    destination = "/tmp/cert.b64"
  }

  provisioner "file" {
    connection {
      type        = "ssh"
      user        = "ubuntu"
      private_key = can(file(var.ssh_private_key)) ? file(var.ssh_private_key) : var.ssh_private_key
      host        = ibm_is_floating_ip.instance_name.address
    }
    content     = local.encoded_key
    destination = "/tmp/key.b64"
  }
  provisioner "remote-exec" {
    connection {
      type        = "ssh"
      user        = "ubuntu"
      private_key = can(file(var.ssh_private_key)) ? file(var.ssh_private_key) : var.ssh_private_key
      host        = ibm_is_floating_ip.instance_name.address
    }
    inline = [
      "base64 -d /tmp/cert.b64 > ${var.cert_path}",
      "base64 -d /tmp/key.b64 > ${var.key_path}",
      "chmod +x /tmp/run_script.sh",
      "chmod +x /home/ubuntu/Enterprise-Inference/third_party/IBM/patterns/quickstart/quickstart-generate-vault-secrets.sh",
      "/tmp/run_script.sh '${ibm_is_instance.instance_name.primary_network_interface[0].primary_ipv4_address}' '${var.cluster_url}' '${var.models}' '${var.cert_path}' '${var.key_path}' '${var.user_cert}' '${var.user_key}'"
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
      host        = ibm_is_floating_ip.instance_name.address
    }
  }
  provisioner "remote-exec" {
    connection {
      type        = "ssh"
      user        = "ubuntu"
      private_key = can(file(var.ssh_private_key)) ? file(var.ssh_private_key) : var.ssh_private_key
      host        = ibm_is_floating_ip.instance_name.address
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
      host        = ibm_is_floating_ip.instance_name.address
    }
  }
  provisioner "remote-exec" {
    connection {
      type        = "ssh"
      user        = "ubuntu"
      private_key = can(file(var.ssh_private_key)) ? file(var.ssh_private_key) : var.ssh_private_key
      host        = ibm_is_floating_ip.instance_name.address
    }
    inline = [
      "chmod +x /tmp/run_script.sh",
      "/tmp/run_script.sh model-deploy '${var.models}'"
    ]
  }
}
