#!/bin/bash

# 自动驾驶数据集批量下载脚本 (改进版)
# 支持 nuScenes (Mini/Trainval)、Waymo Open Dataset、Argoverse 2
# 明确标注子集类型，支持全量版本下载

set -e  # 出错时退出

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 智能选择数据目录，优先使用/workspace，然后/data，最后用户目录
if [ -d "/workspace" ] && [ -w "/workspace" ] 2>/dev/null; then
    BASE_DATA_DIR="/workspace/datasets"
elif [ -w "/data" ] 2>/dev/null || mkdir -p "/data" 2>/dev/null; then
    BASE_DATA_DIR="/data/datasets"
elif [ -w "/workspace" ] 2>/dev/null || mkdir -p "/workspace" 2>/dev/null; then
    BASE_DATA_DIR="/workspace/datasets"
    echo "⚠️  无法访问/data目录，使用/workspace/datasets作为数据目录"
else
    BASE_DATA_DIR="$HOME/datasets"
    echo "⚠️  使用用户主目录 $HOME/datasets 作为数据目录"
fi

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
    
    # 创建目标目录（如果不存在）
    mkdir -p "$target_dir" 2>/dev/null || true
    
    # 更健壮的磁盘空间检查
    local available_gb
    if command -v df >/dev/null 2>&1; then
        # 尝试多种df格式
        available_gb=$(df -BG "$target_dir" 2>/dev/null | tail -1 | awk '{print $4}' | sed 's/G//' 2>/dev/null)
        
        # 如果第一种方法失败，尝试其他格式
        if [ -z "$available_gb" ] || ! [[ "$available_gb" =~ ^[0-9]+$ ]]; then
            available_gb=$(df -h "$target_dir" 2>/dev/null | tail -1 | awk '{print $4}' | sed 's/G.*//' 2>/dev/null)
        fi
        
        # 如果还是失败，跳过检查
        if [ -z "$available_gb" ] || ! [[ "$available_gb" =~ ^[0-9]+$ ]]; then
            warn "无法检查磁盘空间，跳过检查"
            return 0
        fi
    else
        warn "df命令不可用，跳过磁盘空间检查"
        return 0
    fi
    
    info "检测到可用空间: ${available_gb}GB，需要: ${required_gb}GB"
    info "🔍 DEBUG: available_gb='$available_gb', required_gb='$required_gb'"
    
    if [ "$available_gb" -lt "$required_gb" ]; then
        error "存储空间不足。需要 ${required_gb}GB，可用 ${available_gb}GB"
        error "🔍 DEBUG: 存储空间检查失败，返回1"
        return 1
    fi
    
    info "✅ 存储空间检查通过"
    info "🔍 DEBUG: 存储空间检查成功，返回0"
    return 0
}

# 创建改进的目录结构 (明确标注子集类型)
setup_directories() {
    log "创建数据集目录结构..."
    info "目标数据目录: $BASE_DATA_DIR"
    
    # 检查并创建基础目录
    if ! mkdir -p "$BASE_DATA_DIR" 2>/dev/null; then
        error "无法创建数据目录: $BASE_DATA_DIR"
        error "请检查权限或手动创建目录"
        return 1
    fi
    
    # nuScenes 目录 (区分子集类型)
    mkdir -p "$BASE_DATA_DIR"/nuscenes/{mini_subset,trainval_full,test_subset,maps,can_bus}
    mkdir -p "$BASE_DATA_DIR"/nuscenes/mini_subset/{maps,samples,sweeps,v1.0-mini}
    mkdir -p "$BASE_DATA_DIR"/nuscenes/trainval_full/{maps,samples,sweeps,v1.0-trainval}
    mkdir -p "$BASE_DATA_DIR"/nuscenes/test_subset/{maps,samples,sweeps,v1.0-test}
    
    # Waymo 目录 (区分子集类型)
    mkdir -p "$BASE_DATA_DIR"/waymo/{validation_subset,training_subset,testing_subset}
    
    # Argoverse2 目录 (区分子集类型)
    mkdir -p "$BASE_DATA_DIR"/argoverse2/{motion_forecasting_subset,sensor_subset,lidar_subset,map_change_subset}
    
    log "目录结构创建完成"
    info "可用空间: $(df -h "$BASE_DATA_DIR" | tail -1 | awk '{print $4}')"
}

# 下载 nuScenes Mini 数据集 (子集)
download_nuscenes_mini() {
    log "开始下载 nuScenes Mini 数据集 (子集版本)..."
    
    local nuscenes_dir="$BASE_DATA_DIR/nuscenes/mini_subset"
    
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
    
    # 提供多个下载源
    local download_urls=(
        "https://www.nuscenes.org/data/v1.0-mini.tgz"
        "https://s3.amazonaws.com/download.nuscenes.org/v1.0/v1.0-mini.tgz"
    )
    
    local download_success=false
    for url in "${download_urls[@]}"; do
        info "尝试从 $url 下载 nuScenes v1.0-mini.tgz (约4GB)..."
        if wget -c -t 3 -T 30 "$url"; then
            download_success=true
            break
        else
            warn "从 $url 下载失败，尝试下一个源..."
        fi
    done
    
    if [ "$download_success" = false ]; then
        error "❌ 所有下载源均失败"
        warn "请手动下载: https://www.nuscenes.org/download"
        return 1
    fi
    
    info "下载完成，开始自动解压..."
    if tar -xzf v1.0-mini.tgz; then
        # 验证解压结果
        if [ -d "v1.0-mini" ]; then
            log "✅ nuScenes Mini 数据集 (子集) 下载和解压成功"
            info "场景数量: $(find v1.0-mini -name "scene.json" -exec jq length {} \; 2>/dev/null || echo "10")"
            
            # 解压成功后删除压缩包
            info "解压成功，删除原压缩包 v1.0-mini.tgz..."
            rm -f v1.0-mini.tgz
            log "✅ 压缩包已删除，节省存储空间"
        else
            error "❌ nuScenes Mini 数据集解压失败"
            return 1
        fi
    else
        error "❌ nuScenes Mini 数据集解压失败"
        return 1
    fi
}

# 下载 nuScenes Trainval 全量数据集
download_nuscenes_trainval() {
    log "开始下载 nuScenes Trainval 全量数据集..."
    info "🔍 DEBUG: 进入download_nuscenes_trainval函数"
    
    local nuscenes_dir="$BASE_DATA_DIR/nuscenes/trainval_full"
    info "🔍 DEBUG: 设置目标目录 = $nuscenes_dir"
    
    # 检查存储空间 (350GB)
    info "🔍 DEBUG: 开始检查存储空间..."
    if ! check_disk_space 350 "$nuscenes_dir"; then
        error "nuScenes 全量数据集需要约350GB存储空间"
        return 1
    fi
    info "🔍 DEBUG: 存储空间检查完成"
    
    info "🔍 DEBUG: 尝试切换到目录: $nuscenes_dir"
    if cd "$nuscenes_dir"; then
        info "🔍 DEBUG: 成功切换到目录: $(pwd)"
    else
        error "🔍 DEBUG: 无法切换到目录: $nuscenes_dir"
        return 1
    fi
    
    info "使用AWS S3直接下载方式（无需注册）..."
    info "🔍 DEBUG: 开始设置下载参数..."
    
    # AWS S3 直接下载配置
    local base_url="https://motional-nuscenes.s3.amazonaws.com/public/v1.0"
    info "🔍 DEBUG: base_url = $base_url"
    
    local blob_files=(
        "v1.0-trainval01_blobs.tgz"
        "v1.0-trainval02_blobs.tgz"
        "v1.0-trainval03_blobs.tgz"
        "v1.0-trainval04_blobs.tgz"
        "v1.0-trainval05_blobs.tgz"
        "v1.0-trainval06_blobs.tgz"
        "v1.0-trainval07_blobs.tgz"
        "v1.0-trainval08_blobs.tgz"
        "v1.0-trainval09_blobs.tgz"
        "v1.0-trainval10_blobs.tgz"
    )
    info "🔍 DEBUG: blob_files数组长度 = ${#blob_files[@]}"
    
    # 可选：下载metadata和maps
    local meta_files=(
        "v1.0-trainval_meta.tgz"
        "v1.0-maps.tgz"
    )
    info "🔍 DEBUG: meta_files数组长度 = ${#meta_files[@]}"
    
    info "开始下载 nuScenes Trainval blob文件 (10个文件, 约300GB)..."
    
    local success_count=0
    local total_files=$((${#blob_files[@]} + ${#meta_files[@]}))
    info "🔍 DEBUG: success_count = $success_count, total_files = $total_files"
    
    # 下载blob文件
    info "🔍 DEBUG: 开始blob文件下载循环..."
    for file in "${blob_files[@]}"; do
        info "🔍 DEBUG: 处理文件: $file"
        
        if [ -f "$file" ]; then
            info "文件 $file 已存在，跳过"
            info "🔍 DEBUG: 文件已存在，success_count++: $((success_count+1))"
            ((success_count++))
            continue
        fi
        
        info "🔍 DEBUG: 文件不存在，准备下载"
        info "🔍 DEBUG: 构建URL: $base_url/$file"
        
        info "下载 $file (约30GB)..."
        info "🔍 DEBUG: 执行wget命令..."
        
        if wget -c -t 3 -T 300 "$base_url/$file"; then
            info "✅ $file 下载成功"
            info "🔍 DEBUG: 下载成功，success_count++: $((success_count+1))"
            ((success_count++))
        else
            error "❌ $file 下载失败"
            error "🔍 DEBUG: wget返回错误，但继续下载其他文件"
            # 继续下载其他文件，不要因为一个文件失败就停止
        fi
        
        info "🔍 DEBUG: 当前success_count = $success_count"
    done
    
    info "🔍 DEBUG: blob文件下载循环结束"
    
    # 下载metadata和maps
    info "🔍 DEBUG: 开始meta文件下载循环..."
    for file in "${meta_files[@]}"; do
        info "🔍 DEBUG: 处理meta文件: $file"
        
        if [ -f "$file" ]; then
            info "文件 $file 已存在，跳过"
            info "🔍 DEBUG: meta文件已存在，success_count++: $((success_count+1))"
            ((success_count++))
            continue
        fi
        
        info "🔍 DEBUG: meta文件不存在，准备下载"
        info "下载 $file..."
        info "🔍 DEBUG: 执行wget meta文件..."
        
        if wget -c -t 3 -T 60 "$base_url/$file"; then
            info "✅ $file 下载成功"
            info "🔍 DEBUG: meta下载成功，success_count++: $((success_count+1))"
            ((success_count++))
        else
            error "❌ $file 下载失败"
            error "🔍 DEBUG: meta文件wget返回错误，但继续"
            # 继续下载其他文件，不要因为一个文件失败就停止
        fi
        
        info "🔍 DEBUG: meta文件处理后success_count = $success_count"
    done
    
    info "🔍 DEBUG: meta文件下载循环结束"
    info "下载完成统计: $success_count/$total_files 个文件成功"
    info "🔍 DEBUG: 最终统计 - success_count=$success_count, total_files=$total_files"
    
    if [ $success_count -gt 0 ]; then
        if [ $success_count -eq $total_files ]; then
            log "✅ nuScenes Trainval 全量数据集下载完成"
            
            # 只有当所有文件都下载成功后才进行解压
            info "所有文件下载完成，开始自动解压..."
            local extract_success=0
            local extract_total=$((${#blob_files[@]} + ${#meta_files[@]}))
            
            # 解压文件
            for file in "${blob_files[@]}" "${meta_files[@]}"; do
                if [ -f "$file" ]; then
                    info "解压 $file..."
                    if tar -xzf "$file"; then
                        info "✅ $file 解压成功"
                        # 解压成功后删除压缩包
                        info "删除压缩包 $file..."
                        rm -f "$file"
                        ((extract_success++))
                    else
                        error "❌ $file 解压失败，保留压缩包"
                    fi
                fi
            done
            
            if [ $extract_success -eq $extract_total ]; then
                log "✅ 所有文件解压完成，压缩包已删除，节省存储空间"
            else
                warn "部分文件解压失败 ($extract_success/$extract_total)"
            fi
        else
            warn "⚠️  部分文件下载失败 ($success_count/$total_files)"
            warn "请重新运行脚本以下载缺失的文件"
            warn "只有当所有文件都下载完成后，脚本才会自动解压"
            warn "脚本会自动跳过已下载的文件，只下载缺失的部分"
            
            info "当前已下载的文件:"
            for file in "${blob_files[@]}" "${meta_files[@]}"; do
                if [ -f "$file" ]; then
                    info "✅ $file"
                else
                    info "❌ $file (待下载)"
                fi
            done
        fi
    else
        error "❌ 所有文件下载失败，请检查网络连接后重试"
        return 1
    fi
    
    return 0
}

# 下载 nuScenes Test 数据集
download_nuscenes_test() {
    log "开始下载 nuScenes Test 数据集..."
    
    local nuscenes_dir="$BASE_DATA_DIR/nuscenes/test_subset"
    
    # 检查存储空间 (30GB)
    if ! check_disk_space 30 "$nuscenes_dir"; then
        error "nuScenes Test 数据集需要约30GB存储空间"
        return 1
    fi
    
    mkdir -p "$nuscenes_dir"
    cd "$nuscenes_dir"
    
    info "使用AWS S3直接下载方式（无需注册）..."
    
    # AWS S3 直接下载配置
    local base_url="https://motional-nuscenes.s3.amazonaws.com/public/v1.0"
    local test_file="v1.0-test_blobs.tgz"
    
    if [ -f "$test_file" ]; then
        warn "nuScenes Test 数据集已存在，跳过下载"
        return 0
    fi
    
    info "下载 $test_file (约25GB)..."
    
    if wget -c -t 3 -T 300 "$base_url/$test_file"; then
        log "✅ nuScenes Test 数据集下载成功"
        
        # 自动解压
        info "开始自动解压 $test_file..."
        if tar -xzf "$test_file"; then
            log "✅ nuScenes Test 数据集解压成功"
            
            # 解压成功后删除压缩包
            info "解压成功，删除原压缩包 $test_file..."
            rm -f "$test_file"
            log "✅ 压缩包已删除，节省存储空间"
        else
            error "❌ nuScenes Test 数据集解压失败，保留压缩包"
            return 1
        fi
    else
        error "❌ nuScenes Test 数据集下载失败"
        return 1
    fi
    
    return 0
}

# 下载 Waymo 验证子集
download_waymo_validation() {
    log "开始下载 Waymo Open Dataset 验证子集..."
    
    local waymo_dir="$BASE_DATA_DIR/waymo/validation_subset"
    
    # 检查 gsutil 命令
    if ! check_command gsutil; then
        error "请先安装 Google Cloud SDK: https://cloud.google.com/sdk/docs/install"
        return 1
    fi
    
    # 检查存储空间 (20GB)
    if ! check_disk_space 20 "$waymo_dir"; then
        return 1
    fi
    
    cd "$waymo_dir"
    
    # 下载前10个验证文件 (约15GB)
    info "下载 Waymo 验证集前10个文件 (约15GB) - 子集版本..."
    
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
    
    local av2_dir="$BASE_DATA_DIR/argoverse2/motion_forecasting_subset"
    
    # 检查存储空间 (8GB)
    if ! check_disk_space 8 "$av2_dir"; then
        return 1
    fi
    
    cd "$av2_dir"
    
    # 创建 Motion Forecasting 目录
    mkdir -p motion_forecasting/{train,val,test}
    
    warn "⚠️  Argoverse 2 数据集需要先在官网注册:"
    warn "   1. 访问 https://www.argoverse.org/av2.html"
    warn "   2. 注册账户并同意使用条款"
    warn "   3. 获取下载链接"
    warn "   4. 手动下载或使用官方 API"
    
    info "尝试使用 av2 API 下载小型验证集 (子集版本)..."
    
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
    
    # 验证 nuScenes Mini (子集)
    if [ -d "$BASE_DATA_DIR/nuscenes/mini_subset/v1.0-mini" ]; then
        local scene_count=$(find "$BASE_DATA_DIR/nuscenes/mini_subset/v1.0-mini" -name "scene.json" -exec jq length {} \; 2>/dev/null || echo "10")
        info "✅ nuScenes Mini (子集): 可用 (场景数: $scene_count)"
    else
        warn "❌ nuScenes Mini (子集): 未找到"
    fi
    
    # 验证 nuScenes Trainval (全量)
    if [ -d "$BASE_DATA_DIR/nuscenes/trainval_full/v1.0-trainval" ]; then
        local scene_count=$(find "$BASE_DATA_DIR/nuscenes/trainval_full/v1.0-trainval" -name "scene.json" -exec jq length {} \; 2>/dev/null || echo "unknown")
        info "✅ nuScenes Trainval (全量): 可用 (场景数: $scene_count)"
    else
        warn "❌ nuScenes Trainval (全量): 未找到"
    fi
    
    # 验证 nuScenes Test (测试集)
    if [ -d "$BASE_DATA_DIR/nuscenes/test_subset/v1.0-test" ]; then
        local scene_count=$(find "$BASE_DATA_DIR/nuscenes/test_subset/v1.0-test" -name "scene.json" -exec jq length {} \; 2>/dev/null || echo "unknown")
        info "✅ nuScenes Test (测试集): 可用 (场景数: $scene_count)"
    else
        warn "❌ nuScenes Test (测试集): 未找到"
    fi
    
    # 验证 Waymo (子集)
    local waymo_files=$(find "$BASE_DATA_DIR/waymo/validation_subset" -name "*.tfrecord" | wc -l)
    if [ $waymo_files -gt 0 ]; then
        info "✅ Waymo 验证集 (子集): $waymo_files 个文件"
    else
        warn "❌ Waymo 验证集 (子集): 未找到"
    fi
    
    # 验证 Argoverse 2 (子集)
    local av2_files=$(find "$BASE_DATA_DIR/argoverse2/motion_forecasting_subset" -name "*.parquet" | wc -l 2>/dev/null || echo 0)
    if [ $av2_files -gt 0 ]; then
        info "✅ Argoverse 2 Motion (子集): $av2_files 个场景文件"
    else
        warn "❌ Argoverse 2 Motion (子集): 未找到"
    fi
}

# 生成数据集配置文件
generate_dataset_configs() {
    log "生成数据集配置文件..."
    
    local config_file="$SCRIPT_DIR/dataset_paths.yaml"
    
    cat > "$config_file" << EOF
# 数据集路径配置 (改进版)
# 此文件由 download_datasets_improved.sh 自动生成
# 明确区分子集和全量版本

datasets:
  nuscenes:
    root: "$BASE_DATA_DIR/nuscenes"
    mini_subset:
      path: "$BASE_DATA_DIR/nuscenes/mini_subset"
      version: "v1.0-mini"
      available: $([ -d "$BASE_DATA_DIR/nuscenes/mini_subset/v1.0-mini" ] && echo "true" || echo "false")
      type: "subset"
      scenes: 10
      size_gb: 4
    trainval_full:
      path: "$BASE_DATA_DIR/nuscenes/trainval_full"
      version: "v1.0-trainval"
      available: $([ -d "$BASE_DATA_DIR/nuscenes/trainval_full/v1.0-trainval" ] && echo "true" || echo "false")
      type: "full"
      scenes: 850
      size_gb: 350
    test_subset:
      path: "$BASE_DATA_DIR/nuscenes/test_subset"
      version: "v1.0-test"
      available: $([ -d "$BASE_DATA_DIR/nuscenes/test_subset/v1.0-test" ] && echo "true" || echo "false")
      type: "test"
      scenes: 150
      size_gb: 30
    
  waymo:
    root: "$BASE_DATA_DIR/waymo"
    validation_subset:
      path: "$BASE_DATA_DIR/waymo/validation_subset"
      files: $(find "$BASE_DATA_DIR/waymo/validation_subset" -name "*.tfrecord" | wc -l 2>/dev/null || echo 0)
      type: "subset"
      size_gb: 15
    
  argoverse2:
    root: "$BASE_DATA_DIR/argoverse2"
    motion_forecasting_subset:
      path: "$BASE_DATA_DIR/argoverse2/motion_forecasting_subset"
      scenario_files: $(find "$BASE_DATA_DIR/argoverse2/motion_forecasting_subset" -name "*.parquet" | wc -l 2>/dev/null || echo 0)
      type: "subset"
      size_gb: 8

# 更新时间: $(date)
# 版本: improved_v1.0
EOF
    
    info "配置文件已生成: $config_file"
}

# 显示使用帮助
show_help() {
    echo "用法: $0 [选项]"
    echo ""
    echo "选项:"
    echo "  --all              下载所有验证数据集 (子集版本)"
    echo "  --nuscenes-mini    下载 nuScenes Mini (子集)"
    echo "  --nuscenes-full    下载 nuScenes Trainval (全量)"
    echo "  --nuscenes-test    下载 nuScenes Test (测试集)"
    echo "  --waymo            下载 Waymo 验证集 (子集)"
    echo "  --argoverse        下载 Argoverse 2 (子集)"
    echo "  --install-only     仅安装开发工具包，不下载数据"
    echo "  --validate         验证已下载的数据集"
    echo "  --data-dir DIR     指定数据集根目录 (默认: /data/datasets)"
    echo "  --help             显示此帮助信息"
    echo ""
    echo "数据集类型说明:"
    echo "  子集 (subset): 用于开发和测试的小型数据集"
    echo "  全量 (full):   完整的训练和验证数据集"
    echo ""
    echo "解压行为:"
    echo "  nuScenes:     先完成所有文件下载，再统一解压并删除压缩包"
    echo "  其他数据集:   保持原始格式，无需解压"
    echo ""
    echo "示例:"
    echo "  $0 --all                        # 下载所有验证数据集 (子集)"
    echo "  $0 --nuscenes-mini             # 仅下载 nuScenes Mini (子集)"
    echo "  $0 --nuscenes-full             # 下载 nuScenes 全量训练集"
    echo "  $0 --nuscenes-test             # 下载 nuScenes 测试集"
    echo "  $0 --data-dir /my/data         # 使用自定义数据目录"
    echo ""
    echo "存储需求:"
    echo "  nuScenes Mini (子集):      ~5GB"
    echo "  nuScenes Trainval (全量):  ~350GB"
    echo "  nuScenes Test (测试集):    ~30GB"
    echo "  Waymo 验证集 (子集):       ~20GB"
    echo "  Argoverse 2 (子集):        ~8GB"
}

# 主函数
main() {
    log "=== 自动驾驶数据集下载脚本启动 (改进版) ==="
    log "日志文件: $LOG_FILE"
    log "数据目录: $BASE_DATA_DIR"
    
    # 解析命令行参数
    local download_nuscenes_mini=false
    local download_nuscenes_full=false
    local download_nuscenes_test=false
    local download_waymo=false
    local download_argoverse=false
    local install_only=false
    local validate_only=false
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            --all)
                download_nuscenes_mini=true
                download_nuscenes_full=true
                download_nuscenes_test=true                
                download_waymo=true
                download_argoverse=true
                shift
                ;;
            --nuscenes-mini)
                download_nuscenes_mini=true
                shift
                ;;
            --nuscenes-full)
                download_nuscenes_full=true
                shift
                ;;
            --nuscenes-test)
                download_nuscenes_test=true
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
    
    # 如果没有指定选项，默认下载所有子集
    if [ "$download_nuscenes_mini" = false ] && [ "$download_nuscenes_full" = false ] && [ "$download_nuscenes_test" = false ] && [ "$download_waymo" = false ] && [ "$download_argoverse" = false ] && [ "$install_only" = false ] && [ "$validate_only" = false ]; then
        download_nuscenes_mini=true
        download_waymo=true
        download_argoverse=true
    fi
    
    # 检查基本命令
    check_command wget || exit 1
    check_command python || exit 1
    check_command pip || exit 1
    
    # 创建改进的目录结构
    setup_directories
    
    # 仅验证模式
    if [ "$validate_only" = true ]; then
        validate_datasets
        exit 0
    fi
    
    # 安装开发工具包
    if [ "$download_nuscenes_mini" = true ] || [ "$download_nuscenes_full" = true ] || [ "$download_nuscenes_test" = true ] || [ "$install_only" = true ]; then
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
    if [ "$download_nuscenes_mini" = true ]; then
        download_nuscenes_mini
    fi
    
    if [ "$download_nuscenes_full" = true ]; then
        download_nuscenes_trainval
    fi
    
    if [ "$download_nuscenes_test" = true ]; then
        download_nuscenes_test
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
    info "目录结构 (改进版):"
    info "├── nuscenes/"
    info "│   ├── mini_subset/     (子集, ~5GB)"
    info "│   ├── trainval_full/   (全量, ~350GB)"
    info "│   └── test_subset/     (测试集, ~30GB)"
    info "├── waymo/"
    info "│   └── validation_subset/ (子集, ~20GB)"
    info "└── argoverse2/"
    info "    └── motion_forecasting_subset/ (子集, ~8GB)"
    info ""
    info "下一步："
    info "1. 运行验证脚本: python validate_datasets.py"
    info "2. 更新模型配置文件以使用新的数据路径"
    info "3. 运行模型验证和评估流水线"
}

# 运行主函数
main "$@"