#!/bin/bash

# 自动驾驶数据集批量下载脚本
# 支持 nuScenes、Waymo Open Dataset、Argoverse 2
# 优先下载验证子集用于模型调试和评估流水线验证

set -e  # 出错时退出

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DATA_DIR="/data/datasets"
LOG_FILE="$SCRIPT_DIR/download_log_$(date +%Y%m%d_%H%M%S).log"

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 日志函数
log() {
    echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $1" | tee -a "$LOG_FILE"
}

warn() {
    echo -e "${YELLOW}[$(date '+%Y-%m-%d %H:%M:%S')] WARNING:${NC} $1" | tee -a "$LOG_FILE"
}

error() {
    echo -e "${RED}[$(date '+%Y-%m-%d %H:%M:%S')] ERROR:${NC} $1" | tee -a "$LOG_FILE"
}

info() {
    echo -e "${BLUE}[$(date '+%Y-%m-%d %H:%M:%S')] INFO:${NC} $1" | tee -a "$LOG_FILE"
}

# 检查命令是否存在
check_command() {
    if ! command -v $1 &> /dev/null; then
        error "命令 '$1' 未找到，请先安装"
        return 1
    fi
    return 0
}

# 检查存储空间
check_disk_space() {
    local required_gb=$1
    local target_dir=$2
    
    local available_gb=$(df -BG "$target_dir" | awk 'NR==2 {print $4}' | sed 's/G//')
    
    if [ "$available_gb" -lt "$required_gb" ]; then
        error "存储空间不足。需要 ${required_gb}GB，可用 ${available_gb}GB"
        return 1
    fi
    
    info "存储空间检查通过：可用 ${available_gb}GB / 需要 ${required_gb}GB"
    return 0
}

# 创建目录结构
setup_directories() {
    log "创建数据集目录结构..."
    
    mkdir -p "$BASE_DATA_DIR"/{nuscenes,waymo,argoverse2}
    mkdir -p "$BASE_DATA_DIR"/nuscenes/{maps,samples,sweeps}
    mkdir -p "$BASE_DATA_DIR"/waymo/{training,validation,testing}
    mkdir -p "$BASE_DATA_DIR"/argoverse2/{sensor,motion_forecasting,lidar,map_change}
    
    log "目录结构创建完成"
}

# 下载 nuScenes Mini 数据集
download_nuscenes_mini() {
    log "开始下载 nuScenes Mini 数据集..."
    
    local nuscenes_dir="$BASE_DATA_DIR/nuscenes"
    
    # 检查存储空间 (5GB)
    if ! check_disk_space 5 "$nuscenes_dir"; then
        return 1
    fi
    
    cd "$nuscenes_dir"
    
    # 检查是否已经下载
    if [ -d "v1.0-mini" ] && [ -f "v1.0-mini.tgz" ]; then
        warn "nuScenes Mini 数据集已存在，跳过下载"
        return 0
    fi
    
    # 下载 Mini 数据集
    info "下载 nuScenes v1.0-mini.tgz (约4GB)..."
    if wget -c -t 3 -T 30 "https://www.nuscenes.org/data/v1.0-mini.tgz"; then
        info "下载完成，开始解压..."
        tar -xzf v1.0-mini.tgz
        
        # 验证解压结果
        if [ -d "v1.0-mini" ]; then
            log "✅ nuScenes Mini 数据集下载和解压成功"
            info "场景数量: $(find v1.0-mini -name "*.json" | wc -l)"
        else
            error "❌ nuScenes Mini 数据集解压失败"
            return 1
        fi
    else
        error "❌ nuScenes Mini 数据集下载失败"
        return 1
    fi
}

# 安装 nuScenes 开发工具包
install_nuscenes_devkit() {
    log "安装 nuScenes 开发工具包..."
    
    if python -c "import nuscenes" &> /dev/null; then
        warn "nuScenes devkit 已安装，跳过"
        return 0
    fi
    
    if pip install nuscenes-devkit; then
        log "✅ nuScenes devkit 安装成功"
    else
        error "❌ nuScenes devkit 安装失败"
        return 1
    fi
}

# 下载 Waymo 验证子集
download_waymo_validation() {
    log "开始下载 Waymo Open Dataset 验证子集..."
    
    local waymo_dir="$BASE_DATA_DIR/waymo"
    
    # 检查 gsutil 命令
    if ! check_command gsutil; then
        error "请先安装 Google Cloud SDK: https://cloud.google.com/sdk/docs/install"
        return 1
    fi
    
    # 检查存储空间 (20GB)
    if ! check_disk_space 20 "$waymo_dir"; then
        return 1
    fi
    
    cd "$waymo_dir/validation"
    
    # 下载前10个验证文件 (约15GB)
    info "下载 Waymo 验证集前10个文件 (约15GB)..."
    
    local download_success=0
    for i in $(seq -w 0000 0009); do
        local filename="validation_${i}.tfrecord"
        
        if [ -f "$filename" ]; then
            info "文件 $filename 已存在，跳过"
            continue
        fi
        
        info "下载 $filename..."
        if gsutil -m cp "gs://waymo_open_dataset_v_1_4_2/individual_files/validation/$filename" .; then
            info "✅ $filename 下载成功"
            ((download_success++))
        else
            error "❌ $filename 下载失败"
        fi
    done
    
    if [ $download_success -gt 0 ]; then
        log "✅ Waymo 验证子集下载完成，成功下载 $download_success 个文件"
    else
        error "❌ Waymo 验证子集下载失败"
        return 1
    fi
}

# 安装 Waymo 开发工具包
install_waymo_devkit() {
    log "安装 Waymo Open Dataset 开发工具包..."
    
    if python -c "import waymo_open_dataset" &> /dev/null; then
        warn "Waymo Open Dataset 已安装，跳过"
        return 0
    fi
    
    # 检查 TensorFlow 版本并安装对应的 Waymo 工具包
    local tf_version=$(python -c "import tensorflow as tf; print(tf.__version__)" 2>/dev/null | cut -d. -f1,2 || echo "")
    
    if [ -n "$tf_version" ]; then
        info "检测到 TensorFlow 版本: $tf_version"
        
        case "$tf_version" in
            "2.11")
                pip install waymo-open-dataset-tf-2-11-0
                ;;
            "2.12")
                pip install waymo-open-dataset-tf-2-12-0
                ;;
            *)
                warn "未找到匹配的 Waymo 工具包，尝试从源码安装..."
                pip install git+https://github.com/waymo-research/waymo-open-dataset.git
                ;;
        esac
    else
        warn "未检测到 TensorFlow，安装默认版本..."
        pip install waymo-open-dataset-tf-2-11-0
    fi
    
    if python -c "import waymo_open_dataset" &> /dev/null; then
        log "✅ Waymo Open Dataset 安装成功"
    else
        error "❌ Waymo Open Dataset 安装失败"
        return 1
    fi
}

# 下载 Argoverse 2 Motion Forecasting 子集
download_argoverse2_motion() {
    log "开始下载 Argoverse 2 Motion Forecasting 验证子集..."
    
    local av2_dir="$BASE_DATA_DIR/argoverse2"
    
    # 检查存储空间 (8GB)
    if ! check_disk_space 8 "$av2_dir"; then
        return 1
    fi
    
    cd "$av2_dir"
    
    # 创建 Motion Forecasting 目录
    mkdir -p motion_forecasting/{train,val,test}
    
    # 注意：Argoverse 2 数据集需要先注册才能下载
    # 这里提供示例命令，实际需要用户先获取授权
    
    warn "⚠️  Argoverse 2 数据集需要先在官网注册:"
    warn "   1. 访问 https://www.argoverse.org/av2.html"
    warn "   2. 注册账户并同意使用条款"
    warn "   3. 获取下载链接"
    warn "   4. 手动下载或使用官方 API"
    
    info "尝试使用 av2 API 下载小型验证集..."
    
    # 检查是否有可用的下载脚本
    if python -c "from av2.datasets.motion_forecasting import download" &> /dev/null; then
        info "使用 av2 API 下载 100 个验证场景..."
        
        if python -c "
from av2.datasets.motion_forecasting.download import download_scenarios
download_scenarios(
    split='val',
    target_dir='$av2_dir/motion_forecasting',
    max_scenarios=100
)"; then
            log "✅ Argoverse 2 Motion Forecasting 验证子集下载成功"
        else
            warn "❌ 自动下载失败，请手动下载"
            info "手动下载命令示例:"
            info "python -m av2.datasets.motion_forecasting.download --split val --target-dir $av2_dir --max-scenarios 100"
        fi
    else
        warn "av2 API 未安装或不可用，请手动下载"
    fi
}

# 安装 Argoverse 2 开发工具包
install_argoverse2_devkit() {
    log "安装 Argoverse 2 开发工具包..."
    
    if python -c "import av2" &> /dev/null; then
        warn "Argoverse 2 API 已安装，跳过"
        return 0
    fi
    
    if pip install av2; then
        log "✅ Argoverse 2 API 安装成功"
    else
        error "❌ Argoverse 2 API 安装失败"
        return 1
    fi
}

# 验证下载的数据集
validate_datasets() {
    log "验证已下载的数据集..."
    
    # 验证 nuScenes
    if [ -d "$BASE_DATA_DIR/nuscenes/v1.0-mini" ]; then
        local scene_count=$(find "$BASE_DATA_DIR/nuscenes/v1.0-mini" -name "scene.json" -exec cat {} \; | jq length 2>/dev/null || echo "unknown")
        info "✅ nuScenes Mini: 可用 (场景数: $scene_count)"
    else
        warn "❌ nuScenes Mini: 未找到"
    fi
    
    # 验证 Waymo
    local waymo_files=$(find "$BASE_DATA_DIR/waymo/validation" -name "*.tfrecord" | wc -l)
    if [ $waymo_files -gt 0 ]; then
        info "✅ Waymo 验证集: $waymo_files 个文件"
    else
        warn "❌ Waymo 验证集: 未找到"
    fi
    
    # 验证 Argoverse 2
    local av2_files=$(find "$BASE_DATA_DIR/argoverse2/motion_forecasting" -name "*.parquet" | wc -l 2>/dev/null || echo 0)
    if [ $av2_files -gt 0 ]; then
        info "✅ Argoverse 2 Motion: $av2_files 个场景文件"
    else
        warn "❌ Argoverse 2 Motion: 未找到"
    fi
}

# 生成数据集配置文件
generate_dataset_configs() {
    log "生成数据集配置文件..."
    
    local config_file="$SCRIPT_DIR/dataset_paths.yaml"
    
    cat > "$config_file" << EOF
# 数据集路径配置
# 此文件由 download_datasets.sh 自动生成

datasets:
  nuscenes:
    root: "$BASE_DATA_DIR/nuscenes"
    version: "v1.0-mini"
    mini_available: $([ -d "$BASE_DATA_DIR/nuscenes/v1.0-mini" ] && echo "true" || echo "false")
    
  waymo:
    root: "$BASE_DATA_DIR/waymo"
    validation_files: $(find "$BASE_DATA_DIR/waymo/validation" -name "*.tfrecord" | wc -l)
    
  argoverse2:
    root: "$BASE_DATA_DIR/argoverse2"
    motion_forecasting: "$BASE_DATA_DIR/argoverse2/motion_forecasting"
    scenario_files: $(find "$BASE_DATA_DIR/argoverse2/motion_forecasting" -name "*.parquet" | wc -l 2>/dev/null || echo 0)

# 更新时间: $(date)
EOF
    
    info "配置文件已生成: $config_file"
}

# 显示使用帮助
show_help() {
    echo "用法: $0 [选项]"
    echo ""
    echo "选项:"
    echo "  --all              下载所有验证数据集"
    echo "  --nuscenes         仅下载 nuScenes Mini"
    echo "  --waymo            仅下载 Waymo 验证集"
    echo "  --argoverse        仅下载 Argoverse 2"
    echo "  --install-only     仅安装开发工具包，不下载数据"
    echo "  --validate         验证已下载的数据集"
    echo "  --data-dir DIR     指定数据集根目录 (默认: /data/datasets)"
    echo "  --help             显示此帮助信息"
    echo ""
    echo "示例:"
    echo "  $0 --all                    # 下载所有验证数据集"
    echo "  $0 --nuscenes              # 仅下载 nuScenes"
    echo "  $0 --data-dir /my/data     # 使用自定义数据目录"
}

# 主函数
main() {
    log "=== 自动驾驶数据集下载脚本启动 ==="
    log "日志文件: $LOG_FILE"
    log "数据目录: $BASE_DATA_DIR"
    
    # 解析命令行参数
    local download_nuscenes=false
    local download_waymo=false
    local download_argoverse=false
    local install_only=false
    local validate_only=false
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            --all)
                download_nuscenes=true
                download_waymo=true
                download_argoverse=true
                shift
                ;;
            --nuscenes)
                download_nuscenes=true
                shift
                ;;
            --waymo)
                download_waymo=true
                shift
                ;;
            --argoverse)
                download_argoverse=true
                shift
                ;;
            --install-only)
                install_only=true
                shift
                ;;
            --validate)
                validate_only=true
                shift
                ;;
            --data-dir)
                BASE_DATA_DIR="$2"
                shift 2
                ;;
            --help)
                show_help
                exit 0
                ;;
            *)
                error "未知选项: $1"
                show_help
                exit 1
                ;;
        esac
    done
    
    # 如果没有指定选项，默认下载所有
    if [ "$download_nuscenes" = false ] && [ "$download_waymo" = false ] && [ "$download_argoverse" = false ] && [ "$install_only" = false ] && [ "$validate_only" = false ]; then
        download_nuscenes=true
        download_waymo=true
        download_argoverse=true
    fi
    
    # 检查基本命令
    check_command wget || exit 1
    check_command python || exit 1
    check_command pip || exit 1
    
    # 创建目录结构
    setup_directories
    
    # 仅验证模式
    if [ "$validate_only" = true ]; then
        validate_datasets
        exit 0
    fi
    
    # 安装开发工具包
    if [ "$download_nuscenes" = true ] || [ "$install_only" = true ]; then
        install_nuscenes_devkit
    fi
    
    if [ "$download_waymo" = true ] || [ "$install_only" = true ]; then
        install_waymo_devkit
    fi
    
    if [ "$download_argoverse" = true ] || [ "$install_only" = true ]; then
        install_argoverse2_devkit
    fi
    
    # 仅安装模式
    if [ "$install_only" = true ]; then
        log "开发工具包安装完成"
        exit 0
    fi
    
    # 下载数据集
    if [ "$download_nuscenes" = true ]; then
        download_nuscenes_mini
    fi
    
    if [ "$download_waymo" = true ]; then
        download_waymo_validation
    fi
    
    if [ "$download_argoverse" = true ]; then
        download_argoverse2_motion
    fi
    
    # 验证下载结果
    validate_datasets
    
    # 生成配置文件
    generate_dataset_configs
    
    log "=== 数据集下载完成 ==="
    info "总结:"
    info "- 日志文件: $LOG_FILE"
    info "- 配置文件: $SCRIPT_DIR/dataset_paths.yaml"
    info "- 数据目录: $BASE_DATA_DIR"
    info ""
    info "下一步："
    info "1. 运行验证脚本: python validate_datasets.py"
    info "2. 更新模型配置文件以使用新的数据路径"
    info "3. 运行模型验证和评估流水线"
}

# 运行主函数
main "$@"