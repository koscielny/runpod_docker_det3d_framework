#!/bin/bash

# 配置文件 - 统一管理路径和设置
# 其他脚本通过source config.sh来获取配置

# 获取当前脚本目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 模型目录配置
# 1. 相对路径优先：模型目录在脚本父目录 
# 2. RunPod环境检测：如果是RunPod环境，使用/workspace
# 3. 用户自定义：可通过环境变量MODELS_DIR覆盖

if [ -n "$MODELS_DIR" ]; then
    # 用户通过环境变量指定
    MODEL_BASE_DIR="$MODELS_DIR"
elif [ -d "/workspace" ] && [ -w "/workspace" ]; then
    # RunPod环境检测
    MODEL_BASE_DIR="/workspace/models"
else
    # 默认相对路径：../（脚本的父目录）
    MODEL_BASE_DIR="$(dirname "$SCRIPT_DIR")"
fi

# Conda环境名称
CONDA_ENV_NAME="mapping_models"

# 工具目录（相对于脚本目录）
TOOLS_DIR="$SCRIPT_DIR/tools"

# 文档目录（相对于脚本目录）  
DOCS_DIR="$SCRIPT_DIR/docs"

# 支持的模型列表
SUPPORTED_MODELS=("MapTR" "PETR" "StreamPETR" "TopoMLP" "VAD")

# 模型仓库映射
declare -A MODEL_REPOS=(
    ["MapTR"]="https://github.com/hustvl/MapTR.git"
    ["PETR"]="https://github.com/megvii-research/PETR.git" 
    ["StreamPETR"]="https://github.com/exiawsh/StreamPETR.git"
    ["TopoMLP"]="https://github.com/wudongming97/TopoMLP.git"
    ["VAD"]="https://github.com/hustvl/VAD.git"
)

# 工具函数：获取conda激活命令
get_conda_activate() {
    if [ -f "/workspace/miniconda/bin/activate" ]; then
        echo "source /workspace/miniconda/bin/activate"
    elif [ -f "/home/$(whoami)/miniconda3/bin/activate" ]; then
        echo "source /home/$(whoami)/miniconda3/bin/activate" 
    else
        echo "conda activate"
    fi
}

# 工具函数：检测conda是否可用
check_conda_available() {
    if command -v conda >/dev/null 2>&1; then
        return 0
    else
        return 1
    fi
}

# 工具函数：打印配置信息
print_config() {
    echo "📋 Configuration Info:"
    echo "  Script Directory: $SCRIPT_DIR"
    echo "  Models Directory: $MODEL_BASE_DIR"
    echo "  Tools Directory: $TOOLS_DIR"
    echo "  Conda Environment: $CONDA_ENV_NAME"
    echo "  Supported Models: ${SUPPORTED_MODELS[*]}"
}

# 导出主要变量供其他脚本使用
export SCRIPT_DIR
export MODEL_BASE_DIR  
export CONDA_ENV_NAME
export TOOLS_DIR
export DOCS_DIR
export SUPPORTED_MODELS
export MODEL_REPOS