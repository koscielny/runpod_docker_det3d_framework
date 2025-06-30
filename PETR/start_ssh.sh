#!/bin/bash

# SSH Server Startup Script for RunPod Docker Container
# This script starts the SSH server for VS Code Remote SSH development

echo "=== Starting SSH Server ==="

# Generate SSH host keys if they don't exist
if [ ! -f /etc/ssh/ssh_host_rsa_key ]; then
    echo "Generating SSH host keys..."
    sudo ssh-keygen -A
fi

# Start SSH service
echo "Starting SSH daemon..."
sudo service ssh start

# Check SSH service status
if sudo service ssh status >/dev/null 2>&1; then
    echo "✅ SSH service started successfully"
    echo "You can now connect via VS Code Remote SSH using:"
    echo "  Host: [RunPod_IP]"
    echo "  Port: 22"
    echo "  User: runpod"
    echo "  Password: runpod123"
else
    echo "❌ Failed to start SSH service"
    exit 1
fi

# Keep the container running
echo "SSH server is ready for connections..."
echo "Container will remain active. Use Ctrl+C to stop."

# Trap SIGTERM and SIGINT to gracefully shutdown
trap 'echo "Shutting down SSH server..."; sudo service ssh stop; exit 0' SIGTERM SIGINT

# Keep the script running
while true; do
    sleep 60
    # Check if SSH is still running
    if ! sudo service ssh status >/dev/null 2>&1; then
        echo "SSH service stopped unexpectedly, restarting..."
        sudo service ssh start
    fi
done