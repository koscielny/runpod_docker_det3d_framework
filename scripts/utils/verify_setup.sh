#!/bin/bash

# Setup Verification Script for RunPod Environment
# This script verifies that the environment is correctly set up

BASE_DIR="/workspace"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_status() {
    local status=$1
    local message=$2
    case $status in
        "PASS") echo -e "${GREEN}✅ $message${NC}" ;;
        "FAIL") echo -e "${RED}❌ $message${NC}" ;;
        "WARN") echo -e "${YELLOW}⚠️  $message${NC}" ;;
        "INFO") echo -e "${BLUE}ℹ️  $message${NC}" ;;
    esac
}

check_gpu() {
    print_status "INFO" "Checking GPU availability..."
    
    if command -v nvidia-smi &> /dev/null; then
        gpu_info=$(nvidia-smi --query-gpu=name,memory.total --format=csv,noheader,nounits | head -1)
        print_status "PASS" "GPU detected: $gpu_info"
        
        # Check GPU memory
        gpu_memory=$(echo "$gpu_info" | cut -d',' -f2 | tr -d ' ')
        if [ "$gpu_memory" -ge 10000 ]; then
            print_status "PASS" "GPU memory sufficient: ${gpu_memory}MB"
        else
            print_status "WARN" "GPU memory may be limited: ${gpu_memory}MB"
        fi
    else
        print_status "FAIL" "No GPU detected"
        return 1
    fi
}

check_conda() {
    print_status "INFO" "Checking Conda environment..."
    
    if [ -f "/workspace/miniconda/bin/conda" ]; then
        print_status "PASS" "Miniconda installed"
        
        if /workspace/miniconda/bin/conda env list | grep -q "mapping_models"; then
            print_status "PASS" "mapping_models environment exists"
        else
            print_status "FAIL" "mapping_models environment not found"
            return 1
        fi
    else
        print_status "FAIL" "Miniconda not found"
        return 1
    fi
}

check_pytorch() {
    print_status "INFO" "Checking PyTorch installation..."
    
    source /workspace/miniconda/bin/activate mapping_models 2>/dev/null
    
    if python -c "import torch; print(f'PyTorch {torch.__version__} installed')" 2>/dev/null; then
        print_status "PASS" "PyTorch installed"
        
        if python -c "import torch; assert torch.cuda.is_available()" 2>/dev/null; then
            print_status "PASS" "PyTorch CUDA support working"
        else
            print_status "FAIL" "PyTorch CUDA support not working"
            return 1
        fi
    else
        print_status "FAIL" "PyTorch not installed"
        return 1
    fi
}

check_models() {
    print_status "INFO" "Checking model installations..."
    
    models=("MapTR" "PETR" "StreamPETR" "TopoMLP" "VAD")
    models_found=0
    
    for model in "${models[@]}"; do
        if [ -d "$BASE_DIR/models/$model" ]; then
            print_status "PASS" "$model found"
            ((models_found++))
        else
            print_status "FAIL" "$model not found"
        fi
    done
    
    if [ $models_found -eq ${#models[@]} ]; then
        print_status "PASS" "All models installed"
    else
        print_status "WARN" "$models_found/${#models[@]} models installed"
    fi
}

check_scripts() {
    print_status "INFO" "Checking utility scripts..."
    
    scripts=(
        "/workspace/setup_data.sh"
        "/workspace/quick_test_models.sh"
        "/workspace/testing/model_tester.py"
    )
    
    for script in "${scripts[@]}"; do
        if [ -f "$script" ] && [ -x "$script" ]; then
            print_status "PASS" "$(basename $script) exists and executable"
        else
            print_status "FAIL" "$(basename $script) missing or not executable"
        fi
    done
}

check_data() {
    print_status "INFO" "Checking data setup..."
    
    if [ -d "$BASE_DIR/data" ]; then
        print_status "PASS" "Data directory exists"
        
        if [ -d "$BASE_DIR/data/sample" ]; then
            print_status "PASS" "Sample data directory exists"
        else
            print_status "WARN" "Sample data not set up (run: /workspace/setup_data.sh)"
        fi
    else
        print_status "FAIL" "Data directory not found"
    fi
}

run_quick_test() {
    print_status "INFO" "Running quick functionality test..."
    
    source /workspace/miniconda/bin/activate mapping_models 2>/dev/null
    
    # Test Python imports
    if python -c "
import torch
import numpy as np
import cv2
print('Basic imports successful')
" 2>/dev/null; then
        print_status "PASS" "Basic Python imports working"
    else
        print_status "FAIL" "Basic Python imports failed"
        return 1
    fi
    
    # Test MMCV import
    if python -c "import mmcv; print(f'MMCV {mmcv.__version__} imported')" 2>/dev/null; then
        print_status "PASS" "MMCV import working"
    else
        print_status "FAIL" "MMCV import failed"
        return 1
    fi
}

main() {
    print_status "INFO" "=== RunPod Environment Verification ==="
    echo ""
    
    local checks_passed=0
    local total_checks=7
    
    # Run all checks
    if check_gpu; then ((checks_passed++)); fi
    if check_conda; then ((checks_passed++)); fi
    if check_pytorch; then ((checks_passed++)); fi
    if check_models; then ((checks_passed++)); fi
    if check_scripts; then ((checks_passed++)); fi
    if check_data; then ((checks_passed++)); fi
    if run_quick_test; then ((checks_passed++)); fi
    
    echo ""
    print_status "INFO" "=== Verification Summary ==="
    
    if [ $checks_passed -eq $total_checks ]; then
        print_status "PASS" "All checks passed ($checks_passed/$total_checks)"
        print_status "INFO" "Environment is ready for model testing!"
        echo ""
        echo "Next steps:"
        echo "  1. Activate environment: source /workspace/miniconda/bin/activate mapping_models"
        echo "  2. Setup data: /workspace/setup_data.sh"
        echo "  3. Run tests: /workspace/quick_test_models.sh"
    else
        print_status "FAIL" "Some checks failed ($checks_passed/$total_checks)"
        print_status "INFO" "Please run setup script again: ./setup_runpod_environment.sh"
        exit 1
    fi
}

main "$@"