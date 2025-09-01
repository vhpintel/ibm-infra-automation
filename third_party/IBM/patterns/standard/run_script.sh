#!/bin/bash

# Enable strict error handling and logging
set -e
set -o pipefail

# Enable verbose logging
set -x

# Log kernel information for debugging
echo "[$(date)] Current kernel version: $(uname -r)"
echo "[$(date)] System information: $(uname -a)"
echo "[$(date)] Starting run_script.sh with parameters: $@"

expand_path() {
  local path="$1"
  if [[ "$path" == ~* ]]; then
    eval echo "$path"
  else
    echo "$path"
  fi
}


reserved_ip=$1
cluster_url=$2
models=$3
cert_path=$(expand_path "$4")
key_path=$(expand_path "$5")
user_cert="$6"
user_key="$7"

# Add this block at the top to support storage-only mode
if [[ "$1" == "storage-only" ]]; then
  echo "Running storage patch only..."
  sudo mkfs.ext4 /dev/nvme0n1
  sudo mkdir -p /mnt/nvme
  sudo mount /dev/nvme0n1 /mnt/nvme
  echo "/dev/nvme0n1 /mnt/nvme ext4 defaults 0 2" | sudo tee -a /etc/fstab
  kubectl patch configmap local-path-config -n local-path-storage --type merge -p '{"data":{"config.json":"{\n    \"nodePathMap\":[\n    {\n        \"node\":\"DEFAULT_PATH_FOR_NON_LISTED_NODES\",\n        \"paths\":[\"/mnt/nvme/\"]\n    }\n    ]\n}"}}'
  kubectl rollout restart deployment local-path-provisioner -n local-path-storage
  kubectl wait --for=condition=available --timeout=60s deployment/local-path-provisioner -n local-path-storage
  echo "Storage patch complete."
  exit 0
fi

# Model deploy code
if [[ "$1" == "model-deploy" ]]; then
  echo "[$(date)] Phase 2: Deploying models with PVC support"
  cd /home/ubuntu/Enterprise-Inference/core
  echo -e '3\n2\n1\nyes\ny\n' | bash inference-stack-deploy.sh --models "$2"
  kubectl delete pods -l app.kubernetes.io/component=device-plugin,app.kubernetes.io/name=habana-ai -n habana-ai-operator --ignore-not-found=true
  
  echo "[$(date)] Installing habanalabs-container-runtime..."
  if sudo DEBIAN_FRONTEND=noninteractive apt install -y habanalabs-container-runtime=1.21.0-555; then
    echo "[$(date)] habanalabs-container-runtime installation successful"
  else
    echo "[$(date)] WARNING: habanalabs-container-runtime installation failed, continuing with scaling..."
  fi
  
  echo "[$(date)] Starting scaling logic for model $2..."
  # scaling logic
  if [[ "$2" == "1" ]]; then
    kubectl scale deployment vllm-llama-8b --replicas=8
    echo "[$(date)] Scaled vllm-llama-8b to 8 replicas"
  elif [[ "$2" == "12" ]]; then
    kubectl scale deployment vllm-llama-3-3-70b --replicas=2
    echo "[$(date)] Scaled vllm-llama-3-3-70b to 2 replicas"
  elif [[ "$2" == "11" ]]; then
    kubectl scale deployment vllm-llama3-405b --replicas=1
    echo "[$(date)] Scaled vllm-llama3-405b to 1 replica"
  else
    echo "Unsupported model selected: $2"
  fi
  echo "[$(date)] Model deployment and scaling complete"
  exit 0
fi


# Set non-interactive mode and configure apt to avoid hanging
export DEBIAN_FRONTEND=noninteractive
export NEEDRESTART_MODE=a
export NEEDRESTART_SUSPEND=1

# Ensure no leftover lock files cause issues
sudo rm -f /var/lib/dpkg/lock-frontend /var/lib/apt/lists/lock || true
sudo dpkg --configure -a || true

# Configure needrestart to automatically restart services without prompting
echo '$nrconf{restart} = "a";' | sudo tee /etc/needrestart/conf.d/50local.conf
echo '$nrconf{kernelhints} = 0;' | sudo tee -a /etc/needrestart/conf.d/50local.conf

echo "[$(date)] Updating package lists and installing dependencies..."
sudo apt-get update -yq
sudo apt-get install -yq \
    git \
    unzip \
    ansible-core

echo "[$(date)] Package installation completed"
echo "$reserved_ip $cluster_url" | sudo tee -a /etc/hosts > /dev/null
echo -e 'y\n' | ssh-keygen -t rsa -b 4096 -N '' -f ~/.ssh/id_rsa -q && cat ~/.ssh/id_rsa.pub >> ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys

# SSL/TLS Certificate setup
mkdir -p "$(dirname "$cert_path")"
mkdir -p "$(dirname "$key_path")"

if [[ -n "$cluster_url" && "$cluster_url" != *"api.example.com"* ]]; then
    echo "[INFO] DNS provided: $cluster_url"
    echo "[INFO] Writing user-provided cert/key to $cert_path and $key_path"

    if [[ -z "$user_cert" || -z "$user_key" ]]; then
        echo "[ERROR] This DNS requires certificate content to be provided."
        exit 1
    fi

    echo "$user_cert" > "$cert_path"
    echo "$user_key" > "$key_path"
    chmod 600 "$key_path"
else
    echo "[INFO] Using self-signed certificate for $cluster_url"
    openssl req -x509 -newkey rsa:4096 \
        -keyout "$key_path" \
        -out "$cert_path" \
        -days 365 -nodes \
        -subj "/CN=$cluster_url"
    chmod 600 "$key_path"
fi

cd ~
rm -rf /home/ubuntu/Enterprise-Inference
git clone https://github.com/vhpintel/ibm-infra-automation.git /home/ubuntu/Enterprise-Inference
cd /home/ubuntu/Enterprise-Inference
cp -f docs/examples/single-node/hosts.yaml core/inventory/hosts.yaml
cp -f /home/ubuntu/inference-config.cfg core/inference-config.cfg
cp -f /home/ubuntu/quickstart-generate-vault-secrets.sh /home/ubuntu/Enterprise-Inference/third_party/IBM/patterns/quickstart/
chmod +x /home/ubuntu/Enterprise-Inference/third_party/IBM/patterns/quickstart/quickstart-generate-vault-secrets.sh
/home/ubuntu/Enterprise-Inference/third_party/IBM/patterns/quickstart/quickstart-generate-vault-secrets.sh
echo "[$(date)] Vault secrets generated successfully"

chmod +x core/inference-stack-deploy.sh
cd core

# Deploys infrastructure only (no models)
echo "[$(date)] Phase 1: Deploying entire infrastructure stack without models"
echo -e '1\nyes\n' | bash inference-stack-deploy.sh