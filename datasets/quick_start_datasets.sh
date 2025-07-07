#!/bin/bash

# 快速开始脚本 - 下载最小验证数据集
# 适用于快速验证模型和调试评估流水线

set -e

echo "🚀 快速开始 - 下载最小验证数据集"
echo "=================================="

# 颜色输出
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

BASE_DIR="/data/datasets"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo -e "${BLUE}数据目录:${NC} $BASE_DIR"
echo -e "${BLUE}预计总大小:${NC} ~25GB"
echo ""

# 检查存储空间
echo "🔍 检查存储空间..."
AVAILABLE_GB=$(df -BG "$PWD" | awk 'NR==2 {print $4}' | sed 's/G//')

if [ "$AVAILABLE_GB" -lt 30 ]; then
    echo -e "${YELLOW}⚠️  警告: 可用空间 ${AVAILABLE_GB}GB < 30GB，可能空间不足${NC}"
    read -p "是否继续? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

echo -e "${GREEN}✅ 存储空间检查通过${NC}"
echo ""

# 1. 创建目录结构
echo "📁 创建目录结构..."
mkdir -p "$BASE_DIR"/{nuscenes,waymo/validation,argoverse2/motion_forecasting}

# 2. 下载 nuScenes Mini (最快开始)
echo ""
echo "📦 下载 nuScenes Mini 数据集 (~4GB)..."
cd "$BASE_DIR/nuscenes"

if [ ! -f "v1.0-mini.tgz" ]; then
    echo "下载中..."
    wget -c -t 3 "https://www.nuscenes.org/data/v1.0-mini.tgz"
else
    echo "文件已存在，跳过下载"
fi

if [ ! -d "v1.0-mini" ]; then
    echo "解压中..."
    tar -xzf v1.0-mini.tgz
fi

echo -e "${GREEN}✅ nuScenes Mini 完成${NC}"

# 3. 安装必要的Python包
echo ""
echo "🐍 安装Python开发工具包..."

# nuScenes
if ! python -c "import nuscenes" 2>/dev/null; then
    echo "安装 nuscenes-devkit..."
    pip install nuscenes-devkit
fi

# Argoverse 2
if ! python -c "import av2" 2>/dev/null; then
    echo "安装 av2..."
    pip install av2
fi

echo -e "${GREEN}✅ Python包安装完成${NC}"

# 4. 验证 nuScenes
echo ""
echo "🔍 验证 nuScenes 数据集..."
python3 -c "
from nuscenes.nuscenes import NuScenes
nusc = NuScenes(version='v1.0-mini', dataroot='$BASE_DIR/nuscenes', verbose=False)
print(f'✅ nuScenes 验证成功')
print(f'   场景数: {len(nusc.scene)}')
print(f'   样本数: {len(nusc.sample)}')
"

# 5. 创建快速配置文件
echo ""
echo "📝 生成配置文件..."
cat > "$SCRIPT_DIR/quick_dataset_config.yaml" << EOF
# 快速验证数据集配置
# 生成时间: $(date)

datasets:
  nuscenes:
    dataroot: "$BASE_DIR/nuscenes"
    version: "v1.0-mini"
    available: true
    scenes: 10
    samples: ~4000
    
  waymo:
    dataroot: "$BASE_DIR/waymo"
    available: false
    note: "需要Google Cloud认证，请手动下载"
    
  argoverse2:
    dataroot: "$BASE_DIR/argoverse2"
    available: false
    note: "需要官网注册，请手动下载"

# 下一步操作建议:
next_steps:
  - "运行模型验证: 使用 nuScenes mini 数据集测试 MapTR/PETR/VAD 模型"
  - "下载更多数据: 如需要，运行 ./download_datasets.sh --waymo --argoverse"
  - "完整验证: 运行 python validate_datasets.py"
EOF

echo -e "${GREEN}✅ 配置文件已生成: quick_dataset_config.yaml${NC}"

# 6. 显示摘要
echo ""
echo "🎉 快速开始完成！"
echo "=================="
echo -e "${BLUE}已完成:${NC}"
echo "  ✅ nuScenes Mini (4GB) - 可用于所有模型验证"
echo "  ✅ Python 开发工具包"
echo "  ✅ 数据集验证"
echo ""
echo -e "${BLUE}数据集路径:${NC}"
echo "  nuScenes: $BASE_DIR/nuscenes"
echo ""
echo -e "${BLUE}下一步建议:${NC}"
echo "  1. 测试模型推理: 使用 nuScenes mini 数据集"
echo "  2. 下载更多数据: ./download_datasets.sh --waymo --argoverse"
echo "  3. 完整验证: python validate_datasets.py"
echo ""
echo -e "${YELLOW}💡 提示:${NC}"
echo "  - nuScenes mini 包含10个场景，约4000个样本"
echo "  - 足够用于验证模型加载和基本推理功能"
echo "  - 如需完整评估，请下载完整数据集"