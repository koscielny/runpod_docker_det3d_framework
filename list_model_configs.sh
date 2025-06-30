#!/bin/bash

# 列出各模型可用的配置文件
# 帮助用户选择合适的配置文件用于推理

echo "🔧 模型配置文件列表"
echo "=================="

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MODELS=("MapTR" "PETR" "StreamPETR" "TopoMLP" "VAD")

# 显示使用说明
show_usage() {
    echo ""
    echo "📝 使用方法:"
    echo "  ./run_model_with_mount.sh <ModelName> <PathToPthFile> <PathToInputDataDir> <PathToOutputResultsDir> <SampleToken> [ConfigFile]"
    echo ""
    echo "示例:"
    echo "  # 使用默认配置"
    echo "  ./run_model_with_mount.sh PETR /path/to/model.pth /input /output sample_token"
    echo ""
    echo "  # 使用自定义配置"
    echo "  ./run_model_with_mount.sh PETR /path/to/model.pth /input /output sample_token /path/to/custom_config.py"
}

# 显示每个模型的配置文件信息
for MODEL in "${MODELS[@]}"; do
    echo ""
    echo "📦 ${MODEL}"
    echo "-------------------"
    
    case "${MODEL}" in
        "MapTR")
            echo "默认配置: /app/MapTR/projects/configs/maptr/maptr_tiny_r50_24e.py"
            echo "配置类型: MapTR 3D object detection and map reconstruction"
            echo "数据集: nuScenes"
            echo "主干网络: ResNet-50"
            echo "特点: 地图构建和3D目标检测"
            ;;
        "PETR")
            echo "默认配置: /app/PETR/projects/configs/petr/petr_r50dcn_gridmask_p4.py"
            echo "配置类型: PETR 3D object detection"
            echo "数据集: nuScenes"
            echo "主干网络: ResNet-50 with DCN"
            echo "特点: 位置编码Transformer, GridMask数据增强"
            ;;
        "StreamPETR")
            echo "默认配置: /app/StreamPETR/projects/configs/streampetr/streampetr_r50_flash_704_bs2_seq_24e.py"
            echo "配置类型: StreamPETR temporal 3D detection"
            echo "数据集: nuScenes"
            echo "主干网络: ResNet-50"
            echo "特点: 时序信息融合, Flash Attention"
            ;;
        "TopoMLP")
            echo "默认配置: /app/TopoMLP/configs/topomlp/topomlp_r50_8x1_24e_bs2_4key_256_lss.py"
            echo "配置类型: TopoMLP topology-aware detection"
            echo "数据集: nuScenes"
            echo "主干网络: ResNet-50"
            echo "特点: 拓扑感知的多层感知机"
            ;;
        "VAD")
            echo "默认配置: /app/VAD/projects/configs/VAD/VAD_base.py"
            echo "配置类型: VAD planning and prediction"
            echo "数据集: nuScenes"
            echo "主干网络: ResNet-50"
            echo "特点: 端到端自动驾驶决策"
            ;;
    esac
done

echo ""
echo "🔍 配置文件详细信息"
echo "=================="
echo ""
echo "各模型配置文件包含以下关键参数:"
echo "  • 数据集路径和预处理设置"
echo "  • 模型架构和超参数"
echo "  • 训练和推理设置"
echo "  • 评估指标配置"
echo ""
echo "⚠️  注意事项:"
echo "  • 确保配置文件与模型权重匹配"
echo "  • 自定义配置文件应基于对应模型的默认配置修改"
echo "  • 数据路径需要根据实际挂载情况调整"

# 创建示例自定义配置
echo ""
echo "📄 创建自定义配置文件示例"
echo "========================="
echo ""
echo "如需创建自定义配置，可以:"
echo "1. 从容器中复制默认配置文件"
echo "2. 根据需要修改参数"
echo "3. 在运行时指定自定义配置路径"
echo ""
echo "复制默认配置的命令示例:"
for MODEL in "${MODELS[@]}"; do
    image_name="${MODEL,,}-model:latest"
    
    case "${MODEL}" in
        "MapTR")
            config_path="/app/MapTR/projects/configs/maptr/maptr_tiny_r50_24e.py"
            ;;
        "PETR")
            config_path="/app/PETR/projects/configs/petr/petr_r50dcn_gridmask_p4.py"
            ;;
        "StreamPETR")
            config_path="/app/StreamPETR/projects/configs/streampetr/streampetr_r50_flash_704_bs2_seq_24e.py"
            ;;
        "TopoMLP")
            config_path="/app/TopoMLP/configs/topomlp/topomlp_r50_8x1_24e_bs2_4key_256_lss.py"
            ;;
        "VAD")
            config_path="/app/VAD/projects/configs/VAD/VAD_base.py"
            ;;
    esac
    
    echo "# ${MODEL}"
    echo "docker run --rm ${image_name} cat \"${config_path}\" > ${MODEL,,}_custom_config.py"
done

show_usage

echo ""
echo "💡 提示: 运行 './run_model_with_mount.sh' 查看完整的使用帮助"