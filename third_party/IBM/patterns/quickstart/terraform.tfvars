ibmcloud_api_key=""
models=1
hugging_face_token=""
# For Development/Testing: Use "api.example.com" to skip certificate requirements
# For Production: Use your custom domain name (e.g., "ai.yourcompany.com")
cluster_url="api.example.com"
ssh_key=""
instance_name=""
instance_zone="us-east-2"
instance_profile="gx3d-160x1792x8gaudi3"
keycloak_admin_user="admin"
keycloak_admin_password=""
vpc=""
security_group=""
public_gateway=""
subnet=""
resource_group="Default"
image="gaudi3-os-u22-01-21-0"
ssh_private_key=""
ibmcloud_region="us-east"
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
