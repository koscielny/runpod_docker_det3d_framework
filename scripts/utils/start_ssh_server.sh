#!/bin/bash

# Main SSH Server Management Script for RunPod Docker Containers
# This script helps manage SSH servers across all model containers

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MODELS=("MapTR" "PETR" "StreamPETR" "TopoMLP" "VAD")

show_usage() {
    echo "Usage: $0 [command] [options]"
    echo ""
    echo "Commands:"
    echo "  start <model>     Start SSH server for specific model container"
    echo "  stop <model>      Stop SSH server for specific model container"
    echo "  status <model>    Check SSH server status for specific model container"
    echo "  list              List all available models"
    echo "  help              Show this help message"
    echo ""
    echo "Models: ${MODELS[*]}"
    echo ""
    echo "Example:"
    echo "  $0 start MapTR    # Start SSH server for MapTR container"
    echo "  $0 status PETR    # Check SSH status for PETR container"
    echo ""
    echo "SSH Connection Details:"
    echo "  Port: 22"
    echo "  User: runpod"
    echo "  Password: runpod123"
    echo "  Root User: root"
    echo "  Root Password: runpod123"
}

validate_model() {
    local model="$1"
    for valid_model in "${MODELS[@]}"; do
        if [[ "$valid_model" == "$model" ]]; then
            return 0
        fi
    done
    return 1
}

start_ssh() {
    local model="$1"
    
    if ! validate_model "$model"; then
        echo "❌ Error: Invalid model '$model'"
        echo "Available models: ${MODELS[*]}"
        exit 1
    fi
    
    echo "=== Starting SSH Server for $model ==="
    
    # Check if container is running
    if ! docker ps --format "table {{.Names}}" | grep -q "${model,,}"; then
        echo "❌ Error: $model container is not running"
        echo "Start the container first, then run this script inside the container:"
        echo "  docker exec -it ${model,,} /usr/local/bin/start_ssh.sh"
        exit 1
    fi
    
    # Execute SSH startup script inside the container
    docker exec -d "${model,,}" /usr/local/bin/start_ssh.sh
    
    if [ $? -eq 0 ]; then
        echo "✅ SSH server started successfully for $model"
        echo "You can now connect via VS Code Remote SSH:"
        echo "  Host: localhost (or RunPod external IP)"
        echo "  Port: 22"
        echo "  User: runpod"
        echo "  Password: runpod123"
    else
        echo "❌ Failed to start SSH server for $model"
        exit 1
    fi
}

stop_ssh() {
    local model="$1"
    
    if ! validate_model "$model"; then
        echo "❌ Error: Invalid model '$model'"
        echo "Available models: ${MODELS[*]}"
        exit 1
    fi
    
    echo "=== Stopping SSH Server for $model ==="
    
    docker exec "${model,,}" sudo service ssh stop
    
    if [ $? -eq 0 ]; then
        echo "✅ SSH server stopped successfully for $model"
    else
        echo "❌ Failed to stop SSH server for $model"
        exit 1
    fi
}

check_status() {
    local model="$1"
    
    if ! validate_model "$model"; then
        echo "❌ Error: Invalid model '$model'"
        echo "Available models: ${MODELS[*]}"
        exit 1
    fi
    
    echo "=== SSH Server Status for $model ==="
    
    # Check if container is running
    if ! docker ps --format "table {{.Names}}" | grep -q "${model,,}"; then
        echo "❌ Container is not running"
        exit 1
    fi
    
    # Check SSH service status inside container
    docker exec "${model,,}" sudo service ssh status
}

list_models() {
    echo "Available models:"
    for model in "${MODELS[@]}"; do
        echo "  - $model"
    done
}

# Main script logic
case "$1" in
    start)
        if [ -z "$2" ]; then
            echo "❌ Error: Model name required"
            show_usage
            exit 1
        fi
        start_ssh "$2"
        ;;
    stop)
        if [ -z "$2" ]; then
            echo "❌ Error: Model name required"
            show_usage
            exit 1
        fi
        stop_ssh "$2"
        ;;
    status)
        if [ -z "$2" ]; then
            echo "❌ Error: Model name required"
            show_usage
            exit 1
        fi
        check_status "$2"
        ;;
    list)
        list_models
        ;;
    help|--help|-h)
        show_usage
        ;;
    *)
        echo "❌ Error: Unknown command '$1'"
        echo ""
        show_usage
        exit 1
        ;;
esac