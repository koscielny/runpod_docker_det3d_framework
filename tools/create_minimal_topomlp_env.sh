#!/bin/bash

# 创建最小化的TopoMLP环境，避免版本冲突

echo "🔧 Creating Minimal TopoMLP Environment"
echo "====================================="

# 创建临时的最小化YAML文件
cat > /tmp/topomlp_minimal.yaml << 'EOF'
name: mapping_models
channels:
  - conda-forge
  - pytorch
  - defaults
dependencies:
  - python=3.9
  - pip
  - pip:
    # Core ML packages (without strict CUDA versions)
    - torch==1.9.1
    - torchvision==0.10.1
    - torchaudio==0.9.1
    
    # Essential TopoMLP dependencies  
    - numpy==1.23.5
    - opencv-python==4.7.0.72
    - shapely==1.8.5
    - networkx==2.2
    - matplotlib==3.5.2
    - scipy==1.8.0
    - scikit-learn==1.2.2
    - scikit-image==0.19.3
    - plotly==5.13.1
    
    # OR-Tools (compatible version)
    - ortools>=9.0,<10.0
    
    # MMDetection ecosystem
    - mmcv-full==1.5.2
    - mmdet==2.26.0
    - mmcls==0.25.0
    - mmsegmentation==0.29.1
    
    # NuScenes and dataset tools
    - nuscenes-devkit==1.1.10
    - lyft-dataset-sdk==0.0.8
    
    # Development tools (essential only)
    - jupyter==1.0.0
    - ipython==8.11.0
    - tqdm
    - pyyaml
    - pillow==9.4.0
    - requests==2.28.2
    
    # Specific TopoMLP needs
    - einops==0.6.0
    - timm==0.6.12
    - addict==2.4.0
    - terminaltables==3.1.10
    - prettytable==3.6.0
EOF

echo "📋 Minimal environment file created: /tmp/topomlp_minimal.yaml"

# 设置conda
if [ -f "/workspace/miniconda/bin/activate" ]; then
    source /workspace/miniconda/bin/activate base
elif [ -f "/home/ian/miniconda3/bin/activate" ]; then
    source /home/ian/miniconda3/bin/activate base
else
    echo "⚠️  Using system conda"
    # conda should be available in PATH
fi

# 删除现有环境
echo "🗑️  Removing existing environment..."
conda remove -n mapping_models --all -y 2>/dev/null || echo "Environment didn't exist"

# 创建新环境
echo "🚀 Creating minimal TopoMLP environment..."
if conda env create -f /tmp/topomlp_minimal.yaml; then
    echo "✅ Minimal environment created successfully!"
    
    # 验证安装
    if [ -f "/workspace/miniconda/bin/activate" ]; then
        source /workspace/miniconda/bin/activate mapping_models
    elif [ -f "/home/ian/miniconda3/bin/activate" ]; then
        source /home/ian/miniconda3/bin/activate mapping_models
    else
        conda activate mapping_models
    fi
    
    echo "📊 Environment verification:"
    python --version
    
    python -c "
import sys
print(f'Python: {sys.version}')

try:
    import torch
    print(f'✅ PyTorch: {torch.__version__}')
    print(f'✅ CUDA available: {torch.cuda.is_available()}')
except ImportError as e:
    print(f'❌ PyTorch: {e}')

try:
    import mmcv
    print(f'✅ MMCV: {mmcv.__version__}')
except ImportError as e:
    print(f'❌ MMCV: {e}')

try:
    import ortools
    print('✅ OR-Tools: Available')
except ImportError as e:
    print(f'❌ OR-Tools: {e}')

try:
    import numpy, opencv, shapely
    print('✅ Core packages: NumPy, OpenCV, Shapely available')
except ImportError as e:
    print(f'❌ Core packages: {e}')
"
    
    echo ""
    echo "🎉 Minimal TopoMLP environment ready!"
    echo "📋 Installed packages focus on core functionality"
    echo "🚀 You can now continue with model testing"
    
    # 清理临时文件
    rm -f /tmp/topomlp_minimal.yaml
    
else
    echo "❌ Environment creation failed"
    echo "📋 Try manual package installation:"
    echo "  1. conda create -n mapping_models python=3.9 -y"
    echo "  2. conda activate mapping_models" 
    echo "  3. pip install torch==1.9.1 torchvision==0.10.1"
    echo "  4. pip install 'ortools>=9.0,<10.0' mmcv-full==1.5.2"
    exit 1
fi