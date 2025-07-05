#!/bin/bash

# Host Deploy Tool - 单个模型安装脚本  
# 用法: ./install_single_model.sh ModelName

MODEL_NAME="$1"

# 加载配置文件
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/config.sh"

if [ -z "$MODEL_NAME" ]; then
    echo "用法: $0 <ModelName>"
    echo "支持的模型: ${SUPPORTED_MODELS[*]}"
    echo ""
    echo "📋 Current configuration:"
    print_config
    exit 1
fi

# 检查模型是否支持
if [[ ! " ${SUPPORTED_MODELS[*]} " =~ " $MODEL_NAME " ]]; then
    echo "❌ 不支持的模型: $MODEL_NAME"
    echo "📋 支持的模型: ${SUPPORTED_MODELS[*]}"
    exit 1
fi

# 激活conda环境
CONDA_ACTIVATE_CMD=$(get_conda_activate)
$CONDA_ACTIVATE_CMD "$CONDA_ENV_NAME"

# 进入模型目录
cd "$MODEL_BASE_DIR/$MODEL_NAME" || { echo "模型目录不存在: $MODEL_BASE_DIR/$MODEL_NAME"; exit 1; }

echo "🔧 Installing $MODEL_NAME dependencies..."

case $MODEL_NAME in
    "MapTR"|"PETR"|"StreamPETR")
        # 简单情况：直接pip install
        pip install -r requirements.txt
        ;;
    "VAD") 
        # VAD特殊情况：conda export文件
        if head -5 requirements.txt | grep -q "conda create"; then
            echo "  Converting conda export..."
            python "$TOOLS_DIR/convert_conda_to_pip.py" requirements.txt temp_requirements.txt
            pip install -r temp_requirements.txt
            rm temp_requirements.txt
        else
            pip install -r requirements.txt
        fi
        ;;
    "TopoMLP")
        # TopoMLP：优先使用conda env文件
        if [ -f "topomlp.yaml" ]; then
            conda env update -n mapping_models -f topomlp.yaml --prune
        else
            pip install -r requirements.txt  
        fi
        ;;
    *)
        echo "未知模型: $MODEL_NAME"
        exit 1
        ;;
esac

echo "✅ $MODEL_NAME installation completed!"