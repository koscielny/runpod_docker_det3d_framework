#!/bin/bash
# VAD资源快速下载脚本
# 使用gdown下载VAD项目所需的模型权重、数据集注释文件和预训练权重

set -e  # 遇到错误立即退出

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 基础路径
BASE_PATH="/workspace/data/vad_demo"

echo -e "${BLUE}🎯 VAD资源下载脚本${NC}"
echo -e "${BLUE}📂 Base directory: ${BASE_PATH}${NC}"

# 创建目录结构
echo -e "\n${YELLOW}📁 Creating directory structure...${NC}"
mkdir -p "${BASE_PATH}/models"
mkdir -p "${BASE_PATH}/pretrained" 
mkdir -p "${BASE_PATH}/nuscenes_annotations"
mkdir -p "${BASE_PATH}/datasets"

echo -e "${GREEN}✅ Directories created${NC}"

# 安装gdown
echo -e "\n${YELLOW}📦 Installing gdown...${NC}"
pip install gdown

# 下载函数
download_gdrive() {
    local file_id=$1
    local output_path=$2
    local description=$3
    
    echo -e "\n${BLUE}⬇️  Downloading ${description}...${NC}"
    echo -e "   Output: ${output_path}"
    
    if [ -f "${output_path}" ]; then
        echo -e "${YELLOW}⚠️  File already exists, skipping...${NC}"
        return 0
    fi
    
    if gdown "https://drive.google.com/uc?id=${file_id}" -O "${output_path}"; then
        echo -e "${GREEN}✅ Downloaded ${description}${NC}"
        return 0
    else
        echo -e "${RED}❌ Failed to download ${description}${NC}"
        return 1
    fi
}

download_url() {
    local url=$1
    local output_path=$2
    local description=$3
    
    echo -e "\n${BLUE}⬇️  Downloading ${description}...${NC}"
    echo -e "   URL: ${url}"
    echo -e "   Output: ${output_path}"
    
    if [ -f "${output_path}" ]; then
        echo -e "${YELLOW}⚠️  File already exists, skipping...${NC}"
        return 0
    fi
    
    if wget -O "${output_path}" "${url}"; then
        echo -e "${GREEN}✅ Downloaded ${description}${NC}"
        return 0
    else
        echo -e "${RED}❌ Failed to download ${description}${NC}"
        return 1
    fi
}

# 执行下载
echo -e "\n${YELLOW}🚀 Starting downloads...${NC}"
echo "==========================================="

success_count=0
total_count=5

# VAD模型权重
echo -e "\n[1/5] VAD-Tiny Model"
echo "----------------------------------------"
if download_gdrive "1KgCC_wFqPH0CQqdr6Pp2smBX5ARPaqne" "${BASE_PATH}/models/vad_tiny_stage_2.pth" "VAD-Tiny Model (R50 backbone)"; then
    ((success_count++))
fi

echo -e "\n[2/5] VAD-Base Model" 
echo "----------------------------------------"
if download_gdrive "1FLX-4LVm4z-RskghFbxGuYlcYOQmV5bS" "${BASE_PATH}/models/vad_base_stage_2.pth" "VAD-Base Model (R50 backbone)"; then
    ((success_count++))
fi

# nuScenes注释文件
echo -e "\n[3/5] nuScenes Train Annotations"
echo "----------------------------------------"
if download_gdrive "1OVd6Rw2wYjT_ylihCixzF6_olrAQsctx" "${BASE_PATH}/nuscenes_annotations/vad_nuscenes_infos_temporal_train.pkl" "nuScenes Train Annotations"; then
    ((success_count++))
fi

echo -e "\n[4/5] nuScenes Val Annotations"
echo "----------------------------------------"  
if download_gdrive "16DZeA-iepMCaeyi57XSXL3vYyhrOQI9S" "${BASE_PATH}/nuscenes_annotations/vad_nuscenes_infos_temporal_val.pkl" "nuScenes Val Annotations"; then
    ((success_count++))
fi

# 预训练权重
echo -e "\n[5/5] ResNet50 Pretrained Weights"
echo "----------------------------------------"
if download_url "https://download.pytorch.org/models/resnet50-19c8e357.pth" "${BASE_PATH}/pretrained/resnet50-19c8e357.pth" "ResNet50 Pretrained Weights"; then
    ((success_count++))
fi

# 输出结果统计
echo -e "\n==========================================="
echo -e "${BLUE}📊 Download Summary:${NC}"
echo -e "   ${GREEN}✅ Successful: ${success_count}/${total_count}${NC}"
echo -e "   ${RED}❌ Failed: $((total_count - success_count))/${total_count}${NC}"

if [ $success_count -eq $total_count ]; then
    echo -e "${GREEN}🎉 All files downloaded successfully!${NC}"
else
    echo -e "${YELLOW}⚠️  Some downloads failed. Please check the logs above.${NC}"
fi

# 显示目录结构
echo -e "\n${BLUE}📁 Final directory structure:${NC}"
echo "models:"
ls -lh "${BASE_PATH}/models/" 2>/dev/null || echo "  (empty)"
echo "pretrained:"
ls -lh "${BASE_PATH}/pretrained/" 2>/dev/null || echo "  (empty)"
echo "nuscenes_annotations:"
ls -lh "${BASE_PATH}/nuscenes_annotations/" 2>/dev/null || echo "  (empty)"

echo -e "\n${GREEN}🔧 Setup Instructions:${NC}"
echo "1. For VAD training/inference, copy the model files to your VAD project:"
echo "   cp ${BASE_PATH}/models/* /path/to/VAD/ckpts/"
echo "   cp ${BASE_PATH}/pretrained/* /path/to/VAD/ckpts/"
echo ""
echo "2. For nuScenes dataset, copy annotation files to your data directory:"
echo "   cp ${BASE_PATH}/nuscenes_annotations/* /path/to/VAD/data/nuscenes/"
echo ""
echo "3. For Docker container usage:"
echo "   Mount ${BASE_PATH} to your container and copy files as needed"

echo -e "\n${GREEN}✨ Download completed!${NC}"