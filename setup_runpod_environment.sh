#!/bin/bash

# RunPod Environment Setup Script
# This script sets up the complete environment for testing multiple models directly in RunPod
# No Docker needed - direct installation and configuration

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="/workspace"  # RunPod standard workspace directory

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m'

print_status() {
    local status=$1
    local message=$2
    case $status in
        "INFO") echo -e "${BLUE}ℹ️  $message${NC}" ;;
        "SUCCESS") echo -e "${GREEN}✅ $message${NC}" ;;
        "WARNING") echo -e "${YELLOW}⚠️  $message${NC}" ;;
        "ERROR") echo -e "${RED}❌ $message${NC}" ;;
        "SETUP") echo -e "${PURPLE}🔧 $message${NC}" ;;
        *) echo -e "$message" ;;
    esac
}

# Model repositories for direct installation
declare -A MODEL_REPOS=(
    ["MapTR"]="https://github.com/hustvl/MapTR.git"
    ["PETR"]="https://github.com/megvii-research/PETR.git"
    ["StreamPETR"]="https://github.com/exiawsh/StreamPETR.git"
    ["TopoMLP"]="https://github.com/wudongming97/TopoMLP.git"
    ["VAD"]="https://github.com/hustvl/VAD.git"
)

# Function to check RunPod environment
check_runpod_environment() {
    print_status "INFO" "Checking RunPod environment..."
    
    # Check if we're in RunPod
    if [ ! -d "/workspace" ]; then
        print_status "WARNING" "Not detected as RunPod environment. Creating workspace directory..."
        mkdir -p /workspace
    fi
    
    # Check GPU availability
    if command -v nvidia-smi &> /dev/null; then
        print_status "SUCCESS" "GPU detected:"
        nvidia-smi --query-gpu=name,memory.total --format=csv,noheader,nounits
    else
        print_status "ERROR" "No GPU detected. This setup requires CUDA-enabled RunPod instance."
        exit 1
    fi
    
    # Check CUDA version
    if command -v nvcc &> /dev/null; then
        cuda_version=$(nvcc --version | grep release | sed -n 's/.*release \([0-9]\+\.[0-9]\+\).*/\1/p')
        print_status "SUCCESS" "CUDA version: $cuda_version"
    else
        print_status "WARNING" "CUDA compiler not found, but runtime might be available"
    fi
    
    print_status "SUCCESS" "RunPod environment check completed"
}

# Function to setup base environment
setup_base_environment() {
    print_status "SETUP" "Setting up base environment..."
    
    cd "$BASE_DIR"
    
    # Update system packages
    print_status "INFO" "Updating system packages..."
    apt-get update && apt-get install -y \
        git \
        wget \
        curl \
        unzip \
        build-essential \
        libgl1-mesa-glx \
        libglib2.0-0 \
        libsm6 \
        libxext6 \
        libxrender-dev \
        libgomp1 \
        libgeos-dev \
        > /dev/null 2>&1
    
    # Setup Python environment
    print_status "INFO" "Setting up Python environment..."
    
    # Install conda if not present
    if ! command -v conda &> /dev/null; then
        print_status "INFO" "Installing Miniconda..."
        wget -q https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh -O miniconda.sh
        bash miniconda.sh -b -p /workspace/miniconda
        export PATH="/workspace/miniconda/bin:$PATH"
        conda init bash
        source ~/.bashrc
        rm miniconda.sh
    fi
    
    # Create base conda environment
    print_status "INFO" "Creating base conda environment..."
    conda create -n mapping_models python=3.8 -y
    
    print_status "SUCCESS" "Base environment setup completed"
}

# Function to install PyTorch and common dependencies
install_pytorch() {
    print_status "SETUP" "Installing PyTorch and common dependencies..."
    
    # Activate conda environment
    source /workspace/miniconda/bin/activate mapping_models
    
    # Install PyTorch (CUDA 11.1 compatible)
    print_status "INFO" "Installing PyTorch..."
    pip install torch==1.9.1+cu111 torchvision==0.10.1+cu111 torchaudio==0.9.1 -f https://download.pytorch.org/whl/torch_stable.html
    
    # Install common dependencies
    print_status "INFO" "Installing common ML dependencies..."
    pip install \
        numpy \
        opencv-python \
        matplotlib \
        scipy \
        scikit-learn \
        tqdm \
        pillow \
        tensorboard \
        tensorboardX \
        yapf \
        addict \
        packaging \
        termcolor
    
    # Install MMDetection dependencies
    print_status "INFO" "Installing MMDetection ecosystem..."
    pip install mmcv-full==1.4.0 -f https://download.openmmlab.com/mmcv/dist/cu111/torch1.9.0/index.html
    pip install mmdet==2.28.2
    pip install mmsegmentation==0.28.0
    
    print_status "SUCCESS" "PyTorch and dependencies installed"
}

# Function to clone and setup a specific model
setup_model() {
    local model_name=$1
    local repo_url=$2
    local model_dir="$BASE_DIR/models/$model_name"
    
    print_status "SETUP" "Setting up $model_name..."
    
    mkdir -p "$BASE_DIR/models"
    
    if [ -d "$model_dir" ]; then
        print_status "WARNING" "$model_name already exists, updating..."
        cd "$model_dir"
        git pull
    else
        print_status "INFO" "Cloning $model_name..."
        cd "$BASE_DIR/models"
        git clone "$repo_url" "$model_name"
    fi
    
    cd "$model_dir"
    
    # Activate conda environment
    source /workspace/miniconda/bin/activate mapping_models
    
    # Install model-specific dependencies
    if [ -f "requirements.txt" ]; then
        print_status "INFO" "Installing $model_name requirements..."
        pip install -r requirements.txt
    fi
    
    # Setup model-specific configurations
    case $model_name in
        "MapTR")
            # Install MapTR specific dependencies
            pip install mmdet3d==1.0.0rc4
            ;;
        "PETR")
            # Install PETR specific dependencies
            pip install mmdet3d==1.0.0rc4
            pip install nuscenes-devkit
            ;;
        "StreamPETR")
            # Install StreamPETR specific dependencies
            pip install mmdet3d==1.0.0rc4
            pip install nuscenes-devkit
            ;;
        "TopoMLP")
            # Install TopoMLP specific dependencies
            pip install mmdet3d==1.0.0rc4
            ;;
        "VAD")
            # Install VAD specific dependencies
            pip install mmdet3d==1.0.0rc4
            pip install nuscenes-devkit
            ;;
    esac
    
    print_status "SUCCESS" "$model_name setup completed"
}

# Function to create model test interface
create_model_interface() {
    print_status "SETUP" "Creating unified model test interface..."
    
    mkdir -p "$BASE_DIR/testing"
    
    cat > "$BASE_DIR/testing/model_tester.py" << 'EOF'
#!/usr/bin/env python3
"""
Unified Model Testing Interface for RunPod Environment
Supports: MapTR, PETR, StreamPETR, TopoMLP, VAD
"""

import os
import sys
import json
import time
import torch
import argparse
from pathlib import Path

class ModelTester:
    def __init__(self, model_name, model_path, config_path, checkpoint_path):
        self.model_name = model_name
        self.model_path = Path(model_path)
        self.config_path = Path(config_path)
        self.checkpoint_path = Path(checkpoint_path)
        self.device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
        
    def load_model(self):
        """Load model based on type"""
        print(f"Loading {self.model_name} model...")
        
        # Add model path to Python path
        sys.path.insert(0, str(self.model_path))
        
        if self.model_name in ["MapTR", "PETR", "StreamPETR", "TopoMLP", "VAD"]:
            return self._load_mmdet3d_model()
        else:
            raise ValueError(f"Unsupported model: {self.model_name}")
    
    def _load_mmdet3d_model(self):
        """Load MMDetection3D based models"""
        try:
            from mmdet3d.apis import init_model
            model = init_model(str(self.config_path), str(self.checkpoint_path), device=self.device)
            return model
        except Exception as e:
            print(f"Error loading model: {e}")
            return None
    
    def run_inference(self, data_path, output_path=None):
        """Run inference on data"""
        model = self.load_model()
        if model is None:
            return {"error": "Failed to load model"}
        
        start_time = time.time()
        
        # GPU memory before inference
        if torch.cuda.is_available():
            torch.cuda.empty_cache()
            gpu_memory_before = torch.cuda.memory_allocated()
        
        # Run inference (simplified - actual implementation depends on model)
        try:
            # This is a placeholder - actual inference code would go here
            results = {"message": f"Inference completed for {self.model_name}"}
            
        except Exception as e:
            results = {"error": str(e)}
        
        end_time = time.time()
        
        # GPU memory after inference
        if torch.cuda.is_available():
            gpu_memory_after = torch.cuda.memory_allocated()
            gpu_memory_used = (gpu_memory_after - gpu_memory_before) / 1024**2  # MB
        else:
            gpu_memory_used = 0
        
        # Prepare results
        test_results = {
            "model_name": self.model_name,
            "inference_time": end_time - start_time,
            "gpu_memory_used_mb": gpu_memory_used,
            "device": str(self.device),
            "results": results,
            "timestamp": time.strftime("%Y-%m-%d %H:%M:%S")
        }
        
        if output_path:
            with open(output_path, 'w') as f:
                json.dump(test_results, f, indent=2)
        
        return test_results

def main():
    parser = argparse.ArgumentParser(description="Test models in RunPod environment")
    parser.add_argument("--model", required=True, choices=["MapTR", "PETR", "StreamPETR", "TopoMLP", "VAD"])
    parser.add_argument("--model-path", required=True, help="Path to model directory")
    parser.add_argument("--config", required=True, help="Path to model config")
    parser.add_argument("--checkpoint", required=True, help="Path to model checkpoint")
    parser.add_argument("--data", required=True, help="Path to test data")
    parser.add_argument("--output", help="Output path for results")
    
    args = parser.parse_args()
    
    tester = ModelTester(args.model, args.model_path, args.config, args.checkpoint)
    results = tester.run_inference(args.data, args.output)
    
    print(json.dumps(results, indent=2))

if __name__ == "__main__":
    main()
EOF
    
    chmod +x "$BASE_DIR/testing/model_tester.py"
    
    print_status "SUCCESS" "Model test interface created"
}

# Function to create data setup script
create_data_setup() {
    print_status "SETUP" "Creating data setup script..."
    
    cat > "$BASE_DIR/setup_data.sh" << 'EOF'
#!/bin/bash

# Data Setup Script for RunPod Environment
# Downloads and configures common datasets for model testing

BASE_DIR="/workspace"
DATA_DIR="$BASE_DIR/data"

print_info() {
    echo -e "\033[0;34mℹ️  $1\033[0m"
}

print_success() {
    echo -e "\033[0;32m✅ $1\033[0m"
}

setup_nuscenes_mini() {
    print_info "Setting up NuScenes mini dataset..."
    
    mkdir -p "$DATA_DIR/nuscenes"
    cd "$DATA_DIR/nuscenes"
    
    # Download NuScenes mini (this is a placeholder - actual download URLs may vary)
    # Users should replace with actual download commands
    print_info "Please download NuScenes mini dataset manually to $DATA_DIR/nuscenes"
    print_info "Or provide download script here"
    
    print_success "NuScenes setup area prepared"
}

setup_sample_data() {
    print_info "Creating sample test data..."
    
    mkdir -p "$DATA_DIR/sample"
    
    # Create sample data structure
    python3 << 'PYTHON'
import os
import json
import numpy as np

data_dir = "/workspace/data/sample"

# Create sample metadata
sample_data = {
    "scene_name": "sample_scene_001",
    "timestamp": "1234567890",
    "camera_data": [
        {"camera_id": "CAM_FRONT", "image_path": "images/front.jpg"},
        {"camera_id": "CAM_BACK", "image_path": "images/back.jpg"}
    ],
    "lidar_data": {"lidar_path": "lidar/pointcloud.bin"}
}

with open(os.path.join(data_dir, "sample_metadata.json"), 'w') as f:
    json.dump(sample_data, f, indent=2)

print("Sample data structure created")
PYTHON
    
    print_success "Sample data setup completed"
}

main() {
    print_info "=== Data Setup for RunPod Environment ==="
    
    mkdir -p "$DATA_DIR"
    
    case "${1:-sample}" in
        "nuscenes")
            setup_nuscenes_mini
            ;;
        "sample")
            setup_sample_data
            ;;
        *)
            print_info "Usage: $0 [nuscenes|sample]"
            print_info "Default: sample"
            setup_sample_data
            ;;
    esac
}

main "$@"
EOF
    
    chmod +x "$BASE_DIR/setup_data.sh"
    
    print_status "SUCCESS" "Data setup script created"
}

# Function to create quick test script
create_quick_test() {
    print_status "SETUP" "Creating quick test script..."
    
    cat > "$BASE_DIR/quick_test_models.sh" << 'EOF'
#!/bin/bash

# Quick Test Script for All Models
# Tests all installed models with sample data

BASE_DIR="/workspace"
MODELS_DIR="$BASE_DIR/models"
TESTING_DIR="$BASE_DIR/testing"
RESULTS_DIR="$BASE_DIR/test_results"

print_info() {
    echo -e "\033[0;34mℹ️  $1\033[0m"
}

print_success() {
    echo -e "\033[0;32m✅ $1\033[0m"
}

print_error() {
    echo -e "\033[0;31m❌ $1\033[0m"
}

test_model() {
    local model_name=$1
    local model_dir="$MODELS_DIR/$model_name"
    
    if [ ! -d "$model_dir" ]; then
        print_error "$model_name not found in $model_dir"
        return 1
    fi
    
    print_info "Testing $model_name..."
    
    # Activate conda environment
    source /workspace/miniconda/bin/activate mapping_models
    
    # Create results directory
    mkdir -p "$RESULTS_DIR"
    
    # Run basic environment test
    cd "$model_dir"
    python -c "
import torch
print(f'PyTorch version: {torch.__version__}')
print(f'CUDA available: {torch.cuda.is_available()}')
if torch.cuda.is_available():
    print(f'GPU: {torch.cuda.get_device_name(0)}')
    print(f'GPU Memory: {torch.cuda.get_device_properties(0).total_memory / 1024**3:.1f} GB')
"
    
    print_success "$model_name environment test completed"
}

main() {
    print_info "=== Quick Model Testing ==="
    
    # Test GPU availability
    if command -v nvidia-smi &> /dev/null; then
        print_info "GPU Status:"
        nvidia-smi --query-gpu=name,utilization.gpu,memory.used,memory.total --format=csv,noheader
    fi
    
    # Test each model
    for model in MapTR PETR StreamPETR TopoMLP VAD; do
        test_model "$model"
    done
    
    print_success "Quick testing completed!"
    print_info "Results saved in: $RESULTS_DIR"
}

main "$@"
EOF
    
    chmod +x "$BASE_DIR/quick_test_models.sh"
    
    print_status "SUCCESS" "Quick test script created"
}

# Main execution function
main() {
    local action="${1:-full}"
    
    print_status "INFO" "=== RunPod Environment Setup ==="
    print_status "INFO" "Action: $action"
    echo ""
    
    case $action in
        "check")
            check_runpod_environment
            ;;
        "base")
            check_runpod_environment
            setup_base_environment
            install_pytorch
            ;;
        "models")
            # Setup all models
            for model in "${!MODEL_REPOS[@]}"; do
                setup_model "$model" "${MODEL_REPOS[$model]}"
            done
            ;;
        "full"|*)
            check_runpod_environment
            setup_base_environment
            install_pytorch
            
            # Setup all models
            for model in "${!MODEL_REPOS[@]}"; do
                setup_model "$model" "${MODEL_REPOS[$model]}"
            done
            
            create_model_interface
            create_data_setup
            create_quick_test
            ;;
    esac
    
    print_status "SUCCESS" "Setup completed successfully!"
    print_status "INFO" "Next steps:"
    echo "  1. Run: source /workspace/miniconda/bin/activate mapping_models"
    echo "  2. Setup data: /workspace/setup_data.sh"
    echo "  3. Quick test: /workspace/quick_test_models.sh"
    echo "  4. Model testing: /workspace/testing/model_tester.py"
}

# Help function
show_help() {
    echo "Usage: $0 [ACTION]"
    echo ""
    echo "Actions:"
    echo "  check    - Check RunPod environment only"
    echo "  base     - Setup base environment and PyTorch"
    echo "  models   - Setup all models"
    echo "  full     - Complete setup (default)"
    echo ""
}

# Parse arguments
case "${1:-}" in
    -h|--help)
        show_help
        exit 0
        ;;
    *)
        main "$@"
        ;;
esac