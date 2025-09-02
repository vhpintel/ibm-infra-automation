provider "ibm" {
  ibmcloud_api_key = var.ibmcloud_api_key
  region           = var.ibmcloud_region
  ibmcloud_timeout = 60
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

data "ibm_is_image" "xeon_image" {
    count = local.is_multi_node ? 1 : 0
    name = var.xeon_image
}

data "ibm_is_image" "gaudi_image" {
    count = local.is_multi_node ? 1 : 0
    name = var.gaudi_image
}

data "ibm_resource_group" "target_rg" {
  name = var.resource_group
}

data "ibm_is_ssh_key" "ssh_key_id" {
    name = var.ssh_key
}

locals {
  is_multi_node = var.deployment_mode == "multi-node"
  
  # Simplified count-based approach - no YAML parsing needed
  control_plane_count = local.is_multi_node ? var.control_plane_count : 0
  worker_gaudi_count = local.is_multi_node ? var.worker_gaudi_count : 0
  
  # Total node counts for provisioning
  total_gaudi_count = local.worker_gaudi_count
}

# Single-node instance (when deployment_mode is single-node)
resource "ibm_is_instance" "instance_name" {
    count   = local.is_multi_node ? 0 : 1
    name    = var.instance_name
    vpc     = data.ibm_is_vpc.existing_vpc.id
    zone    = var.instance_zone
    keys    = [data.ibm_is_ssh_key.ssh_key_id.id]
    image   = data.ibm_is_image.ubuntu.id
    profile = var.instance_profile
    resource_group = data.ibm_resource_group.target_rg.id

    primary_network_interface {
        subnet          = data.ibm_is_subnet.existing_subnet.id
        security_groups = [data.ibm_is_security_group.existing_sg.id]
    }
}

# Multi-node Control Plane instances (Xeon) - only when deployment_mode is multi-node
resource "ibm_is_instance" "control_plane_nodes" {
    count   = local.is_multi_node ? local.control_plane_count : 0
    name    = length(var.control_plane_names) > count.index ? var.control_plane_names[count.index] : "inference-control-plane-${format("%02d", count.index + 1)}"
    vpc     = data.ibm_is_vpc.existing_vpc.id
    zone    = var.instance_zone
    keys    = [data.ibm_is_ssh_key.ssh_key_id.id]
    image   = data.ibm_is_image.xeon_image[0].id
    profile = var.control_plane_instance_profile
    resource_group = data.ibm_resource_group.target_rg.id

    primary_network_interface {
        subnet          = data.ibm_is_subnet.existing_subnet.id
        security_groups = [data.ibm_is_security_group.existing_sg.id]
    }
}

# Multi-node Worker Gaudi instances (for GPU inference) - only when deployment_mode is multi-node
resource "ibm_is_instance" "worker_gaudi_nodes" {
    count   = local.is_multi_node ? local.worker_gaudi_count : 0
    name    = length(var.worker_gaudi_names) > count.index ? var.worker_gaudi_names[count.index] : "inference-workload-gaudi-node-${format("%02d", count.index + 1)}"
    vpc     = data.ibm_is_vpc.existing_vpc.id
    zone    = var.instance_zone
    keys    = [data.ibm_is_ssh_key.ssh_key_id.id]
    image   = data.ibm_is_image.gaudi_image[0].id
    profile = var.instance_profile  # Uses same profile as single-node
    resource_group = data.ibm_resource_group.target_rg.id

    primary_network_interface {
        subnet          = data.ibm_is_subnet.existing_subnet.id
        security_groups = [data.ibm_is_security_group.existing_sg.id]
    }
}

resource "ibm_is_floating_ip" "instance_name" {
    name    = var.instance_name
    target  = local.is_multi_node ? ibm_is_instance.control_plane_nodes[0].primary_network_interface[0].id : ibm_is_instance.instance_name[0].primary_network_interface[0].id
    resource_group = data.ibm_resource_group.target_rg.id
}

locals {
  floating_ip_address = ibm_is_floating_ip.instance_name.address
  
  # All node private IPs for hosts.yaml population
  control_plane_private_ips = local.is_multi_node ? [
    for instance in ibm_is_instance.control_plane_nodes : instance.primary_network_interface[0].primary_ipv4_address
  ] : []
  
  worker_gaudi_private_ips = local.is_multi_node ? [
    for instance in ibm_is_instance.worker_gaudi_nodes : instance.primary_network_interface[0].primary_ipv4_address
  ] : []
  
  # Combined list for passing to script
  all_node_ips = concat(local.control_plane_private_ips, local.worker_gaudi_private_ips)
  
  # Generate multi-node inventory from template
  multi_node_inventory = local.is_multi_node ? templatefile("${path.module}/templates/inventory.yaml.tftpl", {
    control_plane_count = local.control_plane_count
    control_plane_ips = local.control_plane_private_ips
    control_plane_names = [for instance in ibm_is_instance.control_plane_nodes : instance.name]
    worker_gaudi_count = local.worker_gaudi_count
    worker_gaudi_ips = local.worker_gaudi_private_ips
    worker_gaudi_names = [for instance in ibm_is_instance.worker_gaudi_nodes : instance.name]
    ssh_private_key_path = "~/.ssh/${basename(var.ssh_private_key)}"
  }) : ""
}

# Save rendered inventory locally for debugging/reference
resource "local_file" "rendered_inventory" {
  count    = local.is_multi_node ? 1 : 0
  content  = local.multi_node_inventory
  filename = "${path.module}/templates/rendered_inventory.yaml"
  
  # Ensure the file is created before the remote provisioning
  lifecycle {
    create_before_destroy = true
  }
}

output "floating_ip" {
  value = ibm_is_floating_ip.instance_name.address
}
output "reserved_ip" {
  value = local.is_multi_node ? null : ibm_is_instance.instance_name[0].primary_network_interface[0].primary_ipv4_address
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
# Multi-node specific outputs
output "control_plane_private_ips" {
  value = local.is_multi_node ? local.control_plane_private_ips : null
  description = "Private IPs of control plane nodes"
}
output "worker_gaudi_private_ips" {
  value = local.is_multi_node ? local.worker_gaudi_private_ips : null
  description = "Private IPs of Gaudi worker nodes"
}
output "multi_node_config" {
  value = local.is_multi_node ? {
    control_plane_count = local.control_plane_count
    worker_gaudi_count = local.worker_gaudi_count
    all_node_ips = local.all_node_ips
  } : null
  description = "Multi-node deployment configuration"
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
    deploy_llm_models          = var.deploy_llm_models
    deploy_genai_gateway       = var.deploy_genai_gateway
    deploy_keycloak_apisix     = var.deploy_keycloak_apisix
    deploy_observability       = var.deploy_observability
    deploy_ceph                = var.deploy_ceph
    deploy_istio               = var.deploy_istio
  }
}
locals {
  encoded_cert = base64encode(var.user_cert)
  encoded_key  = base64encode(var.user_key)
}
# Single-node SSH wait
resource "null_resource" "wait_for_ssh_single_node" {
  count = local.is_multi_node ? 0 : 1
  
  provisioner "remote-exec" {
    inline = ["echo 'SSH is ready for single-node deployment'"]

    connection {
      type        = "ssh"
      user        = "ubuntu"
      private_key = can(file(var.ssh_private_key)) ? file(var.ssh_private_key) : var.ssh_private_key
      host        = ibm_is_floating_ip.instance_name.address
      timeout     = "20m"  # Total time to keep retrying
    }
  }
  
  triggers = {
    instance_id = ibm_is_instance.instance_name[0].id
    ip_address  = ibm_is_floating_ip.instance_name.address
  }

  depends_on = [
    ibm_is_instance.instance_name,
    ibm_is_floating_ip.instance_name
  ]
}

# Multi-node SSH wait - Control Plane nodes
resource "null_resource" "wait_for_ssh_control_plane" {
  count = local.is_multi_node ? local.control_plane_count : 0
  
  provisioner "remote-exec" {
    inline = [
      count.index == 0 ? "echo 'SSH is ready for control plane node ${count.index + 1} (floating IP)'" : "echo 'SSH is ready for control plane node ${count.index + 1}'"
    ]

    connection {
      type        = "ssh"
      user        = "ubuntu"
      private_key = can(file(var.ssh_private_key)) ? file(var.ssh_private_key) : var.ssh_private_key
      
      # First control plane uses floating IP directly, others use jump host
      host = count.index == 0 ? ibm_is_floating_ip.instance_name.address : ibm_is_instance.control_plane_nodes[count.index].primary_network_interface[0].primary_ipv4_address
      
      # Use jump host for non-first control plane nodes
      bastion_host = count.index == 0 ? null : ibm_is_floating_ip.instance_name.address
      bastion_user = count.index == 0 ? null : "ubuntu"
      bastion_private_key = count.index == 0 ? null : (can(file(var.ssh_private_key)) ? file(var.ssh_private_key) : var.ssh_private_key)
      
      timeout = "20m"
    }
  }
  
  triggers = {
    instance_id = ibm_is_instance.control_plane_nodes[count.index].id
    ip_address  = ibm_is_instance.control_plane_nodes[count.index].primary_network_interface[0].primary_ipv4_address
  }

  depends_on = [
    ibm_is_instance.control_plane_nodes,
    ibm_is_floating_ip.instance_name
  ]
}

# Multi-node SSH wait - Worker Gaudi nodes
resource "null_resource" "wait_for_ssh_worker_gaudi" {
  count = local.is_multi_node ? local.worker_gaudi_count : 0
  
  provisioner "remote-exec" {
    inline = ["echo 'SSH is ready for worker gaudi node ${count.index + 1}'"]

    connection {
      type        = "ssh"
      user        = "ubuntu"
      private_key = can(file(var.ssh_private_key)) ? file(var.ssh_private_key) : var.ssh_private_key
      host        = ibm_is_instance.worker_gaudi_nodes[count.index].primary_network_interface[0].primary_ipv4_address
      
      # Use jump host through first control plane
      bastion_host = ibm_is_floating_ip.instance_name.address
      bastion_user = "ubuntu"
      bastion_private_key = can(file(var.ssh_private_key)) ? file(var.ssh_private_key) : var.ssh_private_key
      
      timeout = "20m"
    }
  }
  
  triggers = {
    instance_id = ibm_is_instance.worker_gaudi_nodes[count.index].id
    ip_address  = ibm_is_instance.worker_gaudi_nodes[count.index].primary_network_interface[0].primary_ipv4_address
  }

  depends_on = [
    ibm_is_instance.worker_gaudi_nodes,
    ibm_is_floating_ip.instance_name,
    null_resource.wait_for_ssh_control_plane[0]  # Ensure jump host is ready
  ]
}

# Aggregator resource to wait for all SSH connectivity
resource "null_resource" "wait_for_all_ssh" {
  triggers = {
    always_run = timestamp()
  }
  
  depends_on = [
    null_resource.wait_for_ssh_single_node,
    null_resource.wait_for_ssh_control_plane,
    null_resource.wait_for_ssh_worker_gaudi
  ]
}

# Setup SSH key for multi-node Ansible connectivity
resource "null_resource" "setup_ansible_ssh_key" {
  count = local.is_multi_node ? 1 : 0
  
  provisioner "file" {
    source      = var.ssh_private_key
    destination = "/home/ubuntu/.ssh/${basename(var.ssh_private_key)}"
    
    connection {
      type        = "ssh"
      user        = "ubuntu"
      private_key = can(file(var.ssh_private_key)) ? file(var.ssh_private_key) : var.ssh_private_key
      host        = ibm_is_floating_ip.instance_name.address
    }
  }
  
  provisioner "remote-exec" {
    inline = [
      "chmod 600 /home/ubuntu/.ssh/${basename(var.ssh_private_key)}"
    ]
    
    connection {
      type        = "ssh"
      user        = "ubuntu"
      private_key = can(file(var.ssh_private_key)) ? file(var.ssh_private_key) : var.ssh_private_key
      host        = ibm_is_floating_ip.instance_name.address
    }
  }
  
  depends_on = [null_resource.wait_for_all_ssh]
}

resource "null_resource" "run_script" {
  triggers = {
    always_run = timestamp()
  }
  depends_on = [
    null_resource.wait_for_all_ssh,
    null_resource.setup_ansible_ssh_key
  ]
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
  
  # Copy generated multi-node inventory file
  provisioner "file" {
    content     = local.is_multi_node ? local.multi_node_inventory : "# Single-node deployment"
    destination = "/tmp/multi_node_hosts.yaml"
    
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
   inline = local.is_multi_node ? [
      "base64 -d /tmp/cert.b64 > ${var.cert_path}",
      "base64 -d /tmp/key.b64 > ${var.key_path}",
      "chmod +x /tmp/run_script.sh",
      # Pass multi-node flag and first control plane IP to script
      "/tmp/run_script.sh 'multi-node' '${ibm_is_instance.control_plane_nodes[0].primary_network_interface[0].primary_ipv4_address}' '${var.cluster_url}' '${var.models}' '${var.cert_path}' '${var.key_path}' '${var.user_cert}' '${var.user_key}'"
    ] : [
      "base64 -d /tmp/cert.b64 > ${var.cert_path}",
      "base64 -d /tmp/key.b64 > ${var.key_path}",
      "chmod +x /tmp/run_script.sh",
      "/tmp/run_script.sh '${ibm_is_instance.instance_name[0].primary_network_interface[0].primary_ipv4_address}' '${var.cluster_url}' '${var.models}' '${var.cert_path}' '${var.key_path}' '${var.user_cert}' '${var.user_key}'"
    ]
  }
}

resource "null_resource" "patch_storage" {
  triggers = {
    always_run = timestamp()
  }
  provisioner "file" {
    source      = "${path.module}/run_script.sh"
    destination = "/tmp/run_script.sh"
    
    connection {
      type        = "ssh"
      user        = "ubuntu"
      private_key = can(file(var.ssh_private_key)) ? file(var.ssh_private_key) : var.ssh_private_key
      host        = local.is_multi_node ? ibm_is_instance.worker_gaudi_nodes[0].primary_network_interface[0].primary_ipv4_address : ibm_is_floating_ip.instance_name.address
      
      # Use control plane as bastion/jump host for multi-node
      bastion_host = local.is_multi_node ? ibm_is_floating_ip.instance_name.address : null
      bastion_user = local.is_multi_node ? "ubuntu" : null
      bastion_private_key = local.is_multi_node ? (can(file(var.ssh_private_key)) ? file(var.ssh_private_key) : var.ssh_private_key) : null
    }
  }

  provisioner "remote-exec" {
    connection {
      type        = "ssh"
      user        = "ubuntu"
      private_key = can(file(var.ssh_private_key)) ? file(var.ssh_private_key) : var.ssh_private_key
      host        = local.is_multi_node ? ibm_is_instance.worker_gaudi_nodes[0].primary_network_interface[0].primary_ipv4_address : ibm_is_floating_ip.instance_name.address
      
      bastion_host = local.is_multi_node ? ibm_is_floating_ip.instance_name.address : null
      bastion_user = local.is_multi_node ? "ubuntu" : null
      bastion_private_key = local.is_multi_node ? (can(file(var.ssh_private_key)) ? file(var.ssh_private_key) : var.ssh_private_key) : null
    }
    inline = local.is_multi_node ? [
      "chmod +x /tmp/run_script.sh",
      "echo 'Running NVMe operations on Gaudi worker node...'",
      "sudo mkfs.ext4 /dev/nvme0n1",
      "sudo mkdir -p /mnt/nvme",
      "sudo mount /dev/nvme0n1 /mnt/nvme",
      "echo '/dev/nvme0n1 /mnt/nvme ext4 defaults 0 2' | sudo tee -a /etc/fstab",
      "echo 'NVMe setup complete on worker node'"
    ] : [
      "chmod +x /tmp/run_script.sh",
      "/tmp/run_script.sh storage-only"
    ]
  }
  provisioner "remote-exec" {
    connection {
      type        = "ssh"
      user        = "ubuntu"
      private_key = can(file(var.ssh_private_key)) ? file(var.ssh_private_key) : var.ssh_private_key
      host        = ibm_is_floating_ip.instance_name.address
    }
    inline = local.is_multi_node ? [
      "echo 'Running kubectl operations on control plane...'",
      "kubectl patch configmap local-path-config -n local-path-storage --type merge -p '{\"data\":{\"config.json\":\"{\\n    \\\"nodePathMap\\\":[\\n    {\\n        \\\"node\\\":\\\"DEFAULT_PATH_FOR_NON_LISTED_NODES\\\",\\n        \\\"paths\\\":[\\\"/mnt/nvme/\\\"]\\n    }\\n    ]\\n}\"}}'",
      "kubectl rollout restart deployment local-path-provisioner -n local-path-storage",
      "kubectl wait --for=condition=available --timeout=60s deployment/local-path-provisioner -n local-path-storage",
      "echo 'Storage patch complete.'"
    ] : [
      "echo 'Single-node deployment - kubectl operations already handled'"
    ]
  }
  depends_on = [
    null_resource.wait_for_ssh_worker_gaudi,
    null_resource.run_script
  ]
}
# Install dedicated Habana runtime version on all Gaudi worker nodes
resource "null_resource" "install_habana_runtime" {
  count = local.is_multi_node ? local.worker_gaudi_count : 0
  
  provisioner "file" {
    source      = "${path.module}/run_script.sh"
    destination = "/tmp/run_script.sh"
    
    connection {
      type        = "ssh"
      user        = "ubuntu"
      private_key = can(file(var.ssh_private_key)) ? file(var.ssh_private_key) : var.ssh_private_key
      host        = ibm_is_instance.worker_gaudi_nodes[count.index].primary_network_interface[0].primary_ipv4_address
      
      bastion_host = ibm_is_floating_ip.instance_name.address
      bastion_user = "ubuntu"
      bastion_private_key = can(file(var.ssh_private_key)) ? file(var.ssh_private_key) : var.ssh_private_key
    }
  }
  
  provisioner "remote-exec" {
    connection {
      type        = "ssh"
      user        = "ubuntu"
      private_key = can(file(var.ssh_private_key)) ? file(var.ssh_private_key) : var.ssh_private_key
      host        = ibm_is_instance.worker_gaudi_nodes[count.index].primary_network_interface[0].primary_ipv4_address
      
      bastion_host = ibm_is_floating_ip.instance_name.address
      bastion_user = "ubuntu"
      bastion_private_key = can(file(var.ssh_private_key)) ? file(var.ssh_private_key) : var.ssh_private_key
    }
    inline = [
      "chmod +x /tmp/run_script.sh",
      "/tmp/run_script.sh install-habana-runtime"
    ]
  }
  
  depends_on = [
    null_resource.wait_for_ssh_worker_gaudi,
    null_resource.patch_storage
  ]
}

resource "null_resource" "model_deploy" {
  triggers = {
    always_run = timestamp()
  }
  depends_on = [
    null_resource.patch_storage,
    null_resource.install_habana_runtime
  ]
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