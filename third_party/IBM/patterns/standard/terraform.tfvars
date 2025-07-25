ibmcloud_api_key=""
models=2
hugging_face_token=""
# For Development/Testing: Use "api.example.com" to skip certificate requirements
# For Production: Use your custom domain name (e.g., "ai.yourcompany.com")
cluster_url="api.example.com"
ssh_key=""
instance_zone="us-east-2"
keycloak_admin_user="admin"
keycloak_admin_password=""
image="gaudi3-os-u22-01-21-0"
ssh_private_key=""
ibmcloud_region=""
resource_group="Default"
# For Production = Use company network range
# For Development/Testing = 0.0.0.0/0
ssh_allowed_cidr="0.0.0.0/0"
# For Development/Testing: Leave default placeholder certificates when using cluster_url="api.example.com"
# For Production: Replace with your actual certificate content
user_cert  = <<EOF
-----BEGIN CERTIFICATE-----
-----END CERTIFICATE-----
EOF

user_key = <<EOF
-----BEGIN PRIVATE KEY-----
-----END PRIVATE KEY-----
EOF
