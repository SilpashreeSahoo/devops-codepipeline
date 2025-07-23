#!/bin/bash
set -e # Exit immediately if a command exits with a non-zero status

echo "--- CodeDeploy Hook: BeforeInstall (install_dependencies.sh) ---"
echo "Installing/Updating necessary OS packages (e.g., Nginx)."

# Example for Ubuntu/Debian EC2 instance:
sudo apt-get update -y
sudo apt-get install -y nginx

# Ensure the deployment directory exists (matches appspec.yml destination)
sudo mkdir -p /var/www/html/my-app

echo "Finished BeforeInstall hook."