#!/bin/bash

set -e  # Exit on error

# Define Terraform version
TERRAFORM_VERSION="1.6.6"

# Detect system architecture (for ARM/M1 support)
ARCH=$(uname -m)
if [[ "$ARCH" == "aarch64" ]]; then
    ARCH="arm64"
else
    ARCH="amd64"
fi

# Detect OS type
OS=$(uname -s | tr '[:upper:]' '[:lower:]')

echo "Detected OS: $OS"
echo "Detected Architecture: $ARCH"

# Download Terraform binary
echo "Downloading Terraform $TERRAFORM_VERSION..."
wget -q "https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}/terraform_${TERRAFORM_VERSION}_${OS}_${ARCH}.zip" -O terraform_install.zip

# Extract the binary
echo "Extracting Terraform..."
unzip -o terraform_install.zip

# Move Terraform to a directory in PATH
echo "Moving Terraform to /usr/local/bin..."
sudo mv terraform /usr/local/bin/

# Set executable permission
sudo chmod +x /usr/local/bin/terraform

# Clean up
rm -f terraform_install.zip

# Verify installation
echo "Verifying Terraform installation..."
terraform -version

echo "Terraform installation completed successfully!"
