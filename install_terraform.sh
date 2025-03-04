#!/bin/bash

# Exit on error
set -e

echo "Updating package lists..."
sudo apt update && sudo apt install -y gnupg software-properties-common

echo "Adding HashiCorp GPG key..."
wget -O- https://apt.releases.hashicorp.com/gpg | sudo tee /usr/share/keyrings/hashicorp-archive-keyring.gpg

echo "Adding HashiCorp repository..."
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list

echo "Updating package lists again..."
sudo apt update

echo "Installing Terraform..."
sudo apt install -y terraform

echo "Verifying Terraform installation..."
terraform -version

echo "Terraform installation completed successfully!"
