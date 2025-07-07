#!/bin/bash

# Host Deploy Tool - 模型部署脚本
# 支持在任意主机环境部署AI模型，直接cd到各个模型目录执行相应的安装命令

set -e

# 加载配置文件
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/config.sh"

echo "🚀 Host Deploy Tool - AI Model Setup"
echo "====================================="

# 显示配置信息
print_config
echo ""

# 确保conda环境存在
if ! conda env list | grep -q "$CONDA_ENV_NAME"; then
    echo "📦 Creating conda environment: $CONDA_ENV_NAME..."
    conda create -n "$CONDA_ENV_NAME" python=3.9 -y
fi

# 激活环境
CONDA_ACTIVATE_CMD=$(get_conda_activate)
$CONDA_ACTIVATE_CMD "$CONDA_ENV_NAME"

# 创建模型目录
mkdir -p "$MODEL_BASE_DIR"
cd "$MODEL_BASE_DIR"

# 克隆或更新仓库
for model in "${SUPPORTED_MODELS[@]}"; do
    echo "📂 Setting up $model..."
    
    if [ -d "$model" ]; then
        cd "$model" && git pull && cd ..
    else
        git clone "${MODEL_REPOS[$model]}" "$model"
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
    python "$TOOLS_DIR/convert_conda_to_pip.py" requirements.txt vad_requirements.txt
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
echo "🎯 Activate environment: conda activate $CONDA_ENV_NAME"
echo "📍 Models location: $MODEL_BASE_DIR"
echo ""
echo "🚀 Usage examples:"
echo "  # 激活环境"
echo "  conda activate $CONDA_ENV_NAME"
echo ""
echo "  # 运行单个模型测试"
echo "  cd $MODEL_BASE_DIR/MapTR && python demo.py"
echo ""
echo "  # 重新安装单个模型"
echo "  $SCRIPT_DIR/install_single_model.sh TopoMLP"