#!/bin/bash

# 强制重新创建TopoMLP环境来解决版本冲突

echo "🔄 Force Recreating TopoMLP Environment"
echo "======================================"

# 设置路径
TOPOMLP_YAML="/home/ian/dev/src/online_mapping/TopoMLP/topomlp.yaml"
CONDA_CMD="/workspace/miniconda/bin/conda"

# 检查文件是否存在
if [ ! -f "$TOPOMLP_YAML" ]; then
    echo "❌ Error: $TOPOMLP_YAML not found"
    exit 1
fi

# 检查修复是否已应用
echo "📋 Verifying fixes in topomlp.yaml..."
if grep -q "python=3.9" "$TOPOMLP_YAML" && grep -q "ortools>=9.0,<10.0" "$TOPOMLP_YAML"; then
    echo "✅ Fixes confirmed in topomlp.yaml"
else
    echo "❌ Fixes not found in topomlp.yaml"
    echo "Please run the manual fix first:"
    echo "  1. Edit $TOPOMLP_YAML"
    echo "  2. Change python=3.8.16 to python=3.9"
    echo "  3. Change ortools==9.2.9972 to ortools>=9.0,<10.0"
    exit 1
fi

# 激活conda
echo "🔧 Setting up conda..."
source /workspace/miniconda/bin/activate base

# 删除现有环境（如果存在）
echo "🗑️  Removing existing mapping_models environment..."
conda remove -n mapping_models --all -y 2>/dev/null || echo "Environment didn't exist"

# 从修复后的YAML文件创建新环境
echo "🚀 Creating new environment from fixed topomlp.yaml..."
conda env create -n mapping_models -f "$TOPOMLP_YAML"

if [ $? -eq 0 ]; then
    echo "✅ Environment created successfully!"
    
    # 验证安装
    echo "🔍 Verifying installation..."
    source /workspace/miniconda/bin/activate mapping_models
    
    echo "📊 Python version:"
    python --version
    
    echo "📦 Key packages verification:"
    python -c "
try:
    import torch; print(f'✅ PyTorch: {torch.__version__}')
except ImportError: print('❌ PyTorch not found')

try:
    import mmcv; print(f'✅ MMCV: {mmcv.__version__}')
except ImportError: print('❌ MMCV not found')

try:
    import numpy; print(f'✅ NumPy: {numpy.__version__}')
except ImportError: print('❌ NumPy not found')

try:
    import ortools; print('✅ OR-Tools: Available')
except ImportError: print('❌ OR-Tools not found')

try:
    import shapely; print('✅ Shapely: Available') 
except ImportError: print('❌ Shapely not found')
"
    
    echo ""
    echo "🎉 TopoMLP environment successfully recreated!"
    echo "🚀 You can now continue with: ./setup_runpod_environment.sh"
    
else
    echo "❌ Environment creation failed"
    echo "📋 Troubleshooting steps:"
    echo "  1. Check conda installation: conda --version"
    echo "  2. Verify YAML syntax: cat $TOPOMLP_YAML"
    echo "  3. Check network connectivity for package downloads"
    exit 1
fi