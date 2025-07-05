#!/bin/bash

# 极简RunPod模型安装脚本
# 直接cd到各个模型目录执行相应的安装命令

set -e

WORKSPACE="/workspace"
MODELS_DIR="$WORKSPACE/models"

echo "🚀 Simple RunPod Model Setup"
echo "=========================="

# 确保conda环境存在
if ! conda env list | grep -q "mapping_models"; then
    echo "📦 Creating conda environment..."
    conda create -n mapping_models python=3.9 -y
fi

# 激活环境
source $(conda info --base)/bin/activate mapping_models

# 创建模型目录
mkdir -p "$MODELS_DIR"
cd "$MODELS_DIR"

# 模型仓库映射
declare -A REPOS=(
    ["MapTR"]="https://github.com/hustvl/MapTR.git"
    ["PETR"]="https://github.com/megvii-research/PETR.git" 
    ["StreamPETR"]="https://github.com/exiawsh/StreamPETR.git"
    ["TopoMLP"]="https://github.com/wudongming97/TopoMLP.git"
    ["VAD"]="https://github.com/hustvl/VAD.git"
)

# 克隆或更新仓库
for model in "${!REPOS[@]}"; do
    echo "📂 Setting up $model..."
    
    if [ -d "$model" ]; then
        cd "$model" && git pull && cd ..
    else
        git clone "${REPOS[$model]}" "$model"
    fi
done

# 安装各模型依赖
echo ""
echo "📦 Installing model dependencies..."

# MapTR - 简单pip安装
echo "🔧 Installing MapTR..."
cd MapTR
pip install -r requirements.txt
cd ..

# PETR - 简单pip安装  
echo "🔧 Installing PETR..."
cd PETR
pip install -r requirements.txt
cd ..

# StreamPETR - 简单pip安装
echo "🔧 Installing StreamPETR..." 
cd StreamPETR
pip install -r requirements.txt
cd ..

# VAD - 需要转换conda export
echo "🔧 Installing VAD..."
cd VAD
if head -5 requirements.txt | grep -q "conda create"; then
    echo "  Converting conda export to pip format..."
    python ../tools/convert_conda_to_pip.py requirements.txt vad_requirements.txt
    pip install -r vad_requirements.txt
    rm vad_requirements.txt
else
    pip install -r requirements.txt
fi
cd ..

# TopoMLP - 使用conda环境文件
echo "🔧 Installing TopoMLP..."
cd TopoMLP
if [ -f "topomlp.yaml" ]; then
    echo "  Using conda environment file..."
    conda env update -n mapping_models -f topomlp.yaml --prune
else
    pip install -r requirements.txt
fi
cd ..

echo ""
echo "✅ All models setup completed!"
echo "🎯 Activate environment: conda activate mapping_models"
echo "📍 Models location: $MODELS_DIR"