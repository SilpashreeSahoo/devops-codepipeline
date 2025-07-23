#!/bin/bash
set -e

echo "--- CodeDeploy Hook: ApplicationStop (stop_application.sh) ---"
echo "Stopping existing application/web server."

# Example for Nginx:
if systemctl is-active --quiet nginx; then
    sudo systemctl stop nginx
    echo "Nginx stopped successfully."
else
    echo "Nginx not running, nothing to stop."
fi

echo "Finished ApplicationStop hook."