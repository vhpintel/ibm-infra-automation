# Quickstart Prerequisites

Before deploying Intel® AI for Enterprise Inference (Enterprise Inference) using the Quickstart pattern, ensure you have all the required components ready. The Quickstart pattern assumes you already have IBM Cloud infrastructure in place.

## Overview

The Quickstart pattern requires existing IBM Cloud infrastructure components. This reduces deployment time but requires more initial setup and knowledge of your current infrastructure.

## Required Prerequisites

### 1. IBM Cloud API Key (ibmcloud_api_key)
**What it is:** Your authentication credential for IBM Cloud  
**How to get it:**
1. Go to [IBM Cloud API Keys](https://cloud.ibm.com/iam/apikeys)
2. Click "Create"
3. Give it a name like "Enterprise-Inference-Key"
4. Copy and save the key securely

**Example value:** `ExAmPlE-API-KEY-abc123def456ghi789`

### 2. IBM Cloud CLI Installation
**What it is:** Command-line tool for managing IBM Cloud resources  
**How to install:** Follow the [official IBM Cloud CLI installation guide](https://cloud.ibm.com/docs/cli?topic=cli-getting-started)

**After installation, login with your API key:**
```bash
ibmcloud login --apikey YOUR_API_KEY -r <us-east|us-south|eu-de>
```

### 3. IBM Cloud SSH Key (ssh_key)
**What it is:** Your SSH key for secure access to the virtual machine  
**How to get it:**
```bash
# Generate a new key pair (if you don't have one)
ssh-keygen -t rsa -b 4096 -f ~/.ssh/ibm-inference-key

# Upload the public key to IBM Cloud via CLI
ibmcloud is key-create my-inference-key @~/.ssh/ibm-inference-key.pub
```
**Or upload via UI:** [VPC SSH Keys console](https://cloud.ibm.com/vpc-ext/compute/sshKeys)

**Example values:**
- SSH key name: `my-inference-key`
- Private key location: `~/.ssh/ibm-inference-key`

### 3. SSH Private Key (ssh_private_key)
**What it is:** The private SSH key file content for connecting to your instance  
**How to get it:**
- Use the private key you generated in step 2
- This is the content of your `~/.ssh/ibm-inference-key` file
- Must match the public key uploaded to IBM Cloud

**Example:** Content of your private key file (keep this secure!)

### 4. Existing Infrastructure Details
**What you need:** Names of your existing IBM Cloud resources  
**How to find them:**

> **Important:** Use resource **names**, not IDs. The deployment looks up resources by name.

#### VPC (vpc)
```bash
# Find your VPC name
ibmcloud is vpcs
# Copy the NAME from the output (not the ID)
# Example: "my-vpc" or "production-vpc"
```

#### Subnet (subnet)
```bash
# Find your subnet name (in the right zone)
ibmcloud is subnets --vpc YOUR_VPC_NAME
# Copy the subnet NAME in your target zone
# Example: "subnet-us-east-1" or "my-subnet"
```

#### Security Group (security_group)
```bash
# Find your security group name
ibmcloud is security-groups --vpc YOUR_VPC_NAME
# Copy the security group NAME (not ID)
# Make sure it allows ports 22, 80, 443
# Example: "default-sg" or "my-security-group"
```

**Required Security Group Rules:**
Your security group must allow:

| Port | Protocol | Direction | Purpose |
|------|----------|-----------|---------|
| 22 | TCP | Inbound | SSH access |
| 80 | TCP | Inbound | HTTP (redirects to HTTPS) |
| 443 | TCP | Inbound | HTTPS API access |
| All | All | Outbound | Internet access |

#### Public Gateway (public_gateway)
```bash
# Find your public gateway name
ibmcloud is public-gateways
# Copy the NAME attached to your subnet
# Example: "my-pgw" or "gateway-us-east"
```

**Example values:**
- VPC: `my-vpc`
- Subnet: `subnet-us-east-1`
- Security Group: `default-sg`
- Public Gateway: `gateway-us-east`

### 5. Resource Group (resource_group)
**What it is:** Organizational container for your resources  
**How to find it:**
```bash
ibmcloud resource groups
```
**Example value:** `Default` or `production-rg`

### 6. Instance Configuration
**What you need:** Zone and instance details  
**How to choose:**

#### Region (ibmcloud_region)
**Default:** `us-east`  
**Options:** `us-east`, `us-south`, `eu-de`

> **Note:** These are the only regions where Intel® Gaudi® 3 AI accelerator instances are currently available.

#### Zone (instance_zone)
- Choose based on your existing infrastructure
- Must match your VPC and subnet location
- Popular zones: `us-east-3`, `us-south-2`, `eu-de-1`

#### Instance Name (instance_name)
- Choose a descriptive name
- Must be unique within your account
- Example: `enterprise-inference-prod`

#### Instance Profile (instance_profile)
**Default:** `gx3d-160x1792x8gaudi3`  
**Purpose:** The Intel Gaudi 3 AI accelerator-enabled instance type

#### Image (image)
**What it is:** The operating system image for your instance  
**Default:** Automatically selected based on region
**How to specify:** Usually leave empty to use default Ubuntu 22.04 image

### 7. Hugging Face Token (hugging_face_token)
**What it is:** Access token to download AI models  
**How to get it:**
1. Go to [Hugging Face Tokens](https://huggingface.co/settings/tokens) to generate tokens
3. Create a new token with "Read" permissions
4. Accept the license for your chosen model:
   - [Llama-3.1-8B](https://huggingface.co/meta-llama/Llama-3.1-8B-Instruct)
   - [Llama-3.3-70B](https://huggingface.co/meta-llama/Llama-3.3-70B-Instruct)
   - [Llama-3.1-405B](https://huggingface.co/meta-llama/Llama-3.1-405B-Instruct)

**Example value:** `hf_AbCdEfGhIjKlMnOpQrStUvWxYz1234567890`

> **Note:** In terraform.tfvars, this is referred to as `hf_token`

### 8. Model Selection (models)
**What it is:** Which AI model you want to deploy  

| Model Name | Num Cards | Disk | Model ID |
|------------|-----------|------|----------|
| meta-llama/Llama-3.1-8B-Instruct | 1 | 20GB | 1 |
| meta-llama/Llama-3.3-70B-Instruct | 4 | 150GB | 12 |
| meta-llama/Llama-3.1-405B-Instruct | 8 | 900GB | 11 |

**For CLI deployment:** Use the Model ID as a string value (`"1"`, `"12"`, or `"11"`) in your terraform.tfvars file.  
**For UI deployment:** Select from the dropdown - the values will be mapped automatically.

> **Note:** After deployment is complete, you can SSH into the node to deploy additional models not listed above or undeploy existing models as needed.

### 9. Cluster URL (cluster_url)
**What it is:** The domain name for your cluster API endpoint  
**How to configure:**
- **For Development/Testing:** Use `api.example.com` (default)
- **For Production:** Use your custom domain (e.g., `ai.yourcompany.com`)

**Example values:**
- Development: `api.example.com`
- Production: `ai.yourcompany.com`

### 10. Keycloak Admin Credentials

#### keycloak_admin_user
**What it is:** Admin username for Keycloak identity management  
**Default:** `admin`  
**Purpose:** Administrative access to Keycloak console

#### keycloak_admin_password
**What it is:** Admin password for Keycloak identity management   
**Purpose:** Administrative access to Keycloak console

> **Security Note:** Use strong, unique credentials for production deployments!

### 11. TLS Configuration (user_cert, user_key)

**For Development/Testing:** You can skip certificates completely when using the default `api.example.com` cluster URL. The deployment will work without providing actual certificate values.

**For Production:** You need a custom domain and SSL certificate  

**If you want external access in production:**
- **Domain:** `ai.yourcompany.com`
- **Certificate:** Valid SSL certificate in PEM format
- **Private Key:** Certificate's private key in PEM format

**DNS and SSL/TLS Setup:**
For detailed instructions on domain configuration and certificate setup, see: [Production Environment Setup](https://github.com/opea-project/Enterprise-Inference/blob/main/docs/prerequisites.md#production-environment)


## Development/Testing Note

For development or testing environments, you can skip the domain name and TLS certificate requirements. The system will automatically use `api.example.com` as the cluster URL, which works for internal cluster access and testing. However, external access will require port forwarding or SSH tunneling.

## Infrastructure Verification Checklist

Before proceeding with deployment, verify your infrastructure:

### VPC Setup
- [ ] VPC exists and is active
- [ ] VPC has internet gateway attached
- [ ] VPC CIDR doesn't conflict with other networks

### Subnet Configuration
- [ ] Subnet exists in target availability zone
- [ ] Subnet has available IP addresses
- [ ] Subnet is attached to public gateway
- [ ] Subnet routing table allows internet access

### Security Group Rules
- [ ] Inbound rule: Port 22 (SSH)
- [ ] Inbound rule: Port 80 (HTTP)
- [ ] Inbound rule: Port 443 (HTTPS)
- [ ] Outbound rule: All traffic allowed

### Access and Permissions
- [ ] API key has sufficient permissions
- [ ] SSH key is uploaded to IBM Cloud
- [ ] Resource group permissions verified

### Quota and Limits
- [ ] Sufficient quota for Intel Gaudi 3 AI accelerator instances
- [ ] Region supports your chosen instance profile
- [ ] No conflicting resource names


## Next Steps

Once you have all prerequisites ready:
**Start Deployment:** [Quickstart Deployment Guide](./quickstart-deployment.md)

---