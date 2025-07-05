#!/bin/bash

# 单个模型安装脚本 - 你提到的最简化方案
# 用法: ./install_single_model.sh ModelName

MODEL_NAME="$1"
WORKSPACE="/workspace/models"

if [ -z "$MODEL_NAME" ]; then
    echo "用法: $0 <ModelName>"
    echo "支持的模型: MapTR, PETR, StreamPETR, TopoMLP, VAD"
    exit 1
fi

# 激活conda环境
source $(conda info --base)/bin/activate mapping_models

# 进入模型目录
cd "$WORKSPACE/$MODEL_NAME" || { echo "模型目录不存在: $WORKSPACE/$MODEL_NAME"; exit 1; }

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
            python ../tools/convert_conda_to_pip.py requirements.txt temp_requirements.txt
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