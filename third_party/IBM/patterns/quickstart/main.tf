provider "ibm" {
  ibmcloud_api_key = var.ibmcloud_api_key
  region           = var.ibmcloud_region
  ibmcloud_timeout = 60
}

data "ibm_sm_kv_secret" "vault_secrets" {
  count              = var.use_secrets_manager ? 1 : 0
  instance_id        = var.secrets_manager_instance_id
  region             = var.secrets_manager_region != "" ? var.secrets_manager_region : var.ibmcloud_region
  name               = var.secrets_manager_secret_name
  secret_group_name  = var.secrets_manager_secret_group_name
  endpoint_type      = "private"
}

locals {
  # Parse secrets from Secrets Manager KV secret or use individual variables
  secrets_from_manager = var.use_secrets_manager ? data.ibm_sm_kv_secret.vault_secrets[0].data : {}
  vault_secrets = {
    litellm_master_key      = var.use_secrets_manager ? lookup(local.secrets_from_manager, "litellm_master_key", "") : var.litellm_master_key
    litellm_salt_key        = var.use_secrets_manager ? lookup(local.secrets_from_manager, "litellm_salt_key", "") : var.litellm_salt_key
    redis_password          = var.use_secrets_manager ? lookup(local.secrets_from_manager, "redis_password", "") : var.redis_password
    langfuse_secret_key     = var.use_secrets_manager ? lookup(local.secrets_from_manager, "langfuse_secret_key", "") : var.langfuse_secret_key
    langfuse_public_key     = var.use_secrets_manager ? lookup(local.secrets_from_manager, "langfuse_public_key", "") : var.langfuse_public_key
    database_url            = var.use_secrets_manager ? lookup(local.secrets_from_manager, "database_url", "") : var.database_url
    postgresql_username     = var.use_secrets_manager ? lookup(local.secrets_from_manager, "postgresql_username", "") : var.postgresql_username
    postgresql_password     = var.use_secrets_manager ? lookup(local.secrets_from_manager, "postgresql_password", "") : var.postgresql_password
    redis_auth_password     = var.use_secrets_manager ? lookup(local.secrets_from_manager, "redis_auth_password", "") : var.redis_auth_password
    aws_access_key          = var.use_secrets_manager ? lookup(local.secrets_from_manager, "aws_access_key", "") : var.aws_access_key
    aws_secret_key          = var.use_secrets_manager ? lookup(local.secrets_from_manager, "aws_secret_key", "") : var.aws_secret_key
    aws_region              = var.use_secrets_manager ? lookup(local.secrets_from_manager, "aws_region", "") : var.aws_region
    aws_bucket              = var.use_secrets_manager ? lookup(local.secrets_from_manager, "aws_bucket", "") : var.aws_bucket
    clickhouse_username     = var.use_secrets_manager ? lookup(local.secrets_from_manager, "clickhouse_username", "") : var.clickhouse_username
    clickhouse_password     = var.use_secrets_manager ? lookup(local.secrets_from_manager, "clickhouse_password", "") : var.clickhouse_password
    langfuse_login          = var.use_secrets_manager ? lookup(local.secrets_from_manager, "langfuse_login", "") : var.langfuse_login
    langfuse_user           = var.use_secrets_manager ? lookup(local.secrets_from_manager, "langfuse_user", "") : var.langfuse_user
    langfuse_password       = var.use_secrets_manager ? lookup(local.secrets_from_manager, "langfuse_password", "") : var.langfuse_password
    clickhouse_redis_url    = var.use_secrets_manager ? lookup(local.secrets_from_manager, "clickhouse_redis_url", "") : var.clickhouse_redis_url
    minio_secret            = var.use_secrets_manager ? lookup(local.secrets_from_manager, "minio_secret", "") : var.minio_secret
    minio_user              = var.use_secrets_manager ? lookup(local.secrets_from_manager, "minio_user", "") : var.minio_user
    postgres_user           = var.use_secrets_manager ? lookup(local.secrets_from_manager, "postgres_user", "") : var.postgres_user
    postgres_password       = var.use_secrets_manager ? lookup(local.secrets_from_manager, "postgres_password", "") : var.postgres_password
  }
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

resource "ibm_is_floating_ip" "instance_name" {
    name    = var.instance_name
    target = ibm_is_instance.instance_name.primary_network_interface[0].id
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

locals {
  model_map = {
    "1"  = "Llama-3.1-8B-Instruct"
    "11" = "Llama-3.1-405B-Instruct"
    "12"  = "Llama-3.3-70B-Instruct"
  }

  selected_model = lookup(local.model_map, var.models, "unknown-model")
}


output "model_endpoint" {
  description = "Constructed URL for the selected Llama model endpoint"
  value       = "https://${var.cluster_url}/${local.selected_model}/v1/completions"
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
    # Vault secrets from Secrets Manager or variables
    litellm_master_key         = local.vault_secrets.litellm_master_key
    litellm_salt_key           = local.vault_secrets.litellm_salt_key
    redis_password             = local.vault_secrets.redis_password
    langfuse_secret_key        = local.vault_secrets.langfuse_secret_key
    langfuse_public_key        = local.vault_secrets.langfuse_public_key
    database_url               = local.vault_secrets.database_url
    postgresql_username        = local.vault_secrets.postgresql_username
    postgresql_password        = local.vault_secrets.postgresql_password
    redis_auth_password        = local.vault_secrets.redis_auth_password
    clickhouse_username        = local.vault_secrets.clickhouse_username
    clickhouse_password        = local.vault_secrets.clickhouse_password
    langfuse_login             = local.vault_secrets.langfuse_login
    langfuse_user              = local.vault_secrets.langfuse_user
    langfuse_password          = local.vault_secrets.langfuse_password
    clickhouse_redis_url       = local.vault_secrets.clickhouse_redis_url
    minio_secret               = local.vault_secrets.minio_secret
    minio_user                 = local.vault_secrets.minio_user
    postgres_user              = local.vault_secrets.postgres_user
    postgres_password          = local.vault_secrets.postgres_password
    aws_access_key             = local.vault_secrets.aws_access_key
    aws_secret_key             = local.vault_secrets.aws_secret_key
    aws_region                 = local.vault_secrets.aws_region
    aws_bucket                 = local.vault_secrets.aws_bucket
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
      host        = ibm_is_floating_ip.instance_name.address
      timeout     = "20m"  # Total time to keep retrying
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
    source      = "${path.module}/manage_vault.sh"
    destination = "/home/ubuntu/manage_vault.sh"

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
