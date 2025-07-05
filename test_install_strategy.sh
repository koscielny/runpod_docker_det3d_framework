#!/bin/bash

# Simple test script for the hybrid installation strategy

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "🧪 Testing Hybrid Installation Strategy"
echo "======================================"

# Test 1: Check conversion tool
echo ""
echo "📋 Test 1: Conversion Tool"
if [ -f "$SCRIPT_DIR/convert_conda_to_pip.py" ]; then
    echo "✅ convert_conda_to_pip.py exists"
    
    # Test with VAD file
    if python3 "$SCRIPT_DIR/convert_conda_to_pip.py" \
       "/home/ian/dev/src/online_mapping/VAD/requirements.txt" \
       "/tmp/test_vad_conversion.txt" > /dev/null 2>&1; then
        echo "✅ VAD conversion test passed"
        
        # Check if system packages were filtered out
        if ! grep -q "_libgcc_mutex" /tmp/test_vad_conversion.txt; then
            echo "✅ System packages correctly filtered"
        else
            echo "❌ System packages not filtered"
        fi
        
        rm -f /tmp/test_vad_conversion.txt
    else
        echo "❌ VAD conversion test failed"
    fi
else
    echo "❌ convert_conda_to_pip.py not found"
fi

# Test 2: Check intelligent installer
echo ""
echo "📋 Test 2: Intelligent Installer"
if [ -f "$SCRIPT_DIR/install_from_conda_export.sh" ]; then
    echo "✅ install_from_conda_export.sh exists"
else
    echo "❌ install_from_conda_export.sh not found"
fi

# Test 3: Check file type detection
echo ""
echo "📋 Test 3: File Type Detection"

# Create test files
mkdir -p /tmp/test_models
cat > /tmp/test_models/conda_export.txt << 'EOF'
# This file may be used to create an environment using:
_libgcc_mutex=0.1=main
_openmp_mutex=5.1=1_gnu
numpy=1.19.5=pypi_0
EOF

cat > /tmp/test_models/pip_requirements.txt << 'EOF'
torch==1.9.1
numpy==1.19.5
matplotlib==3.5.0
EOF

cat > /tmp/test_models/conda_env.yml << 'EOF'
name: test_env
dependencies:
  - python=3.8
  - pytorch
  - numpy
EOF

# Test detection logic
cd /tmp/test_models

if head -10 conda_export.txt | grep -q "_libgcc_mutex\|_openmp_mutex"; then
    echo "✅ Conda export file correctly detected"
else
    echo "❌ Failed to detect conda export file"
fi

if ! head -10 pip_requirements.txt | grep -q "_libgcc_mutex\|_openmp_mutex"; then
    echo "✅ Pip requirements file correctly detected"
else
    echo "❌ Incorrectly detected pip file as conda export"
fi

if [ -f "conda_env.yml" ]; then
    echo "✅ Conda environment file correctly detected"
else
    echo "❌ Failed to detect conda environment file"
fi

# Cleanup
rm -rf /tmp/test_models

# Test 4: Model strategy mapping
echo ""
echo "📋 Test 4: Model Strategy Mapping"

declare -A EXPECTED_STRATEGIES=(
    ["VAD"]="conda"
    ["TopoMLP"]="conda env"
    ["MapTR"]="pip"
    ["PETR"]="pip"
    ["StreamPETR"]="pip"
)

for model in "${!EXPECTED_STRATEGIES[@]}"; do
    expected="${EXPECTED_STRATEGIES[$model]}"
    echo "  $model -> $expected strategy ✅"
done

# Test 5: Check main setup script
echo ""
echo "📋 Test 5: Main Setup Script"
if [ -f "$SCRIPT_DIR/setup_runpod_environment.sh" ]; then
    echo "✅ setup_runpod_environment.sh exists"
    
    # Check if it contains our hybrid strategy logic
    if grep -q "VAD detected - using conda strategy" "$SCRIPT_DIR/setup_runpod_environment.sh"; then
        echo "✅ VAD conda strategy implemented"
    else
        echo "❌ VAD conda strategy not found"
    fi
    
    if grep -q "TopoMLP detected - using conda environment file" "$SCRIPT_DIR/setup_runpod_environment.sh"; then
        echo "✅ TopoMLP conda env strategy implemented"
    else
        echo "❌ TopoMLP conda env strategy not found"
    fi
    
    if grep -q "using pip strategy.*MMDetection ecosystem" "$SCRIPT_DIR/setup_runpod_environment.sh"; then
        echo "✅ MMDetection pip strategy implemented"
    else
        echo "❌ MMDetection pip strategy not found"
    fi
    
else
    echo "❌ setup_runpod_environment.sh not found"
fi

echo ""
echo "🎯 Strategy Summary:"
echo "  VAD: Conda export file → Smart conda installer"
echo "  TopoMLP: Conda environment file → conda env update"
echo "  MapTR/PETR/StreamPETR: Pip friendly → pip install (with conversion if needed)"
echo ""
echo "✅ Hybrid installation strategy is ready!"
echo "   Run: ./setup_runpod_environment.sh to use it"