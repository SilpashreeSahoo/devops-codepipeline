#!/bin/bash
set -e

echo "--- CodeDeploy Hook: AfterInstall (start_application.sh) ---"
echo "Starting the application/web server and configuring it."

sudo systemctl start nginx
echo "Nginx started successfully."

echo "Finished AfterInstall hook."