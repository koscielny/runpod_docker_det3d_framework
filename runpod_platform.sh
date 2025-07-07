#!/bin/bash

# RunPod多模型AI评测平台 - 统一主入口脚本
# 版本: v1.0.2
# 作者: Claude Code Assistant
# 用途: 提供统一的命令行接口来管理和使用RunPod多模型评测平台

set -e

# 脚本信息
SCRIPT_VERSION="1.0.2"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 支持的模型
SUPPORTED_MODELS=("MapTR" "PETR" "StreamPETR" "TopoMLP" "VAD")

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# 日志函数
info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

header() {
    echo -e "${PURPLE}================================${NC}"
    echo -e "${PURPLE} $1${NC}"
    echo -e "${PURPLE}================================${NC}"
}

# 显示版本信息
show_version() {
    echo "RunPod多模型AI评测平台 v${SCRIPT_VERSION}"
    echo "统一命令行接口"
}

# 显示帮助信息
show_help() {
    show_version
    echo ""
    echo "用法: $0 [COMMAND] [OPTIONS] [ARGS]"
    echo ""
    echo -e "${CYAN}可用命令:${NC}"
    echo "  setup      环境初始化和检查"
    echo "  status     查看系统状态"
    echo "  build      构建Docker镜像"
    echo "  health     健康检查和诊断"
    echo "  test       单模型测试"
    echo "  compare    多模型比较"
    echo "  clean      清理资源"
    echo "  check      依赖和健康检查"
    echo "  version    显示版本信息"
    echo "  help       显示帮助信息"
    echo ""
    echo -e "${CYAN}支持的模型:${NC}"
    for model in "${SUPPORTED_MODELS[@]}"; do
        echo "  - $model"
    done
    echo ""
    echo -e "${CYAN}示例:${NC}"
    echo "  $0 setup                    # 初始化环境"
    echo "  $0 status                   # 查看系统状态"
    echo "  $0 build MapTR              # 构建MapTR镜像"
    echo "  $0 health                   # 健康检查所有模型"
    echo "  $0 test MapTR               # 测试MapTR模型"
    echo "  $0 compare                  # 比较所有模型"
    echo "  $0 help build               # 查看build命令帮助"
    echo ""
    echo -e "${CYAN}更多信息:${NC}"
    echo "  文档: docs/guides/evaluation_guide.md"
    echo "  配置: config/models_config.json"
}

# 显示特定命令的帮助
show_command_help() {
    local command="$1"
    case "$command" in
        setup)
            echo -e "${CYAN}setup - 环境初始化和检查${NC}"
            echo ""
            echo "用法: $0 setup [OPTIONS]"
            echo ""
            echo "选项:"
            echo "  --check-only    仅检查环境，不进行安装"
            echo "  --force         强制重新安装"
            echo ""
            echo "功能:"
            echo "  - 检查Docker环境"
            echo "  - 验证模型配置文件"
            echo "  - 检查必要的依赖"
            echo "  - 初始化工作目录"
            ;;
        build)
            echo -e "${CYAN}build - 构建Docker镜像${NC}"
            echo ""
            echo "用法: $0 build [MODEL|all] [OPTIONS]"
            echo ""
            echo "参数:"
            echo "  MODEL       模型名称 ($(IFS=\|; echo "${SUPPORTED_MODELS[*]}"))"
            echo "  all         构建所有模型"
            echo ""
            echo "选项:"
            echo "  --no-cache  不使用缓存构建"
            echo "  --push      构建后推送到Docker Hub"
            echo "  --tag TAG   指定镜像标签 (默认: latest)"
            echo ""
            echo "示例:"
            echo "  $0 build MapTR              # 构建MapTR镜像"
            echo "  $0 build all --no-cache     # 无缓存构建所有镜像"
            echo "  $0 build PETR --push        # 构建并推送PETR镜像"
            ;;
        health)
            echo -e "${CYAN}health - 健康检查和诊断${NC}"
            echo ""
            echo "用法: $0 health [MODEL] [OPTIONS]"
            echo ""
            echo "参数:"
            echo "  MODEL       检查特定模型 (可选)"
            echo ""
            echo "选项:"
            echo "  --detailed  显示详细信息"
            echo "  --fix       尝试自动修复问题"
            echo ""
            echo "功能:"
            echo "  - 检查Docker容器状态"
            echo "  - 验证模型文件完整性"
            echo "  - 检查GPU和系统资源"
            echo "  - 诊断常见问题"
            ;;
        test)
            echo -e "${CYAN}test - 单模型测试${NC}"
            echo ""
            echo "用法: $0 test <MODEL> [OPTIONS]"
            echo ""
            echo "参数:"
            echo "  MODEL       要测试的模型名称"
            echo ""
            echo "选项:"
            echo "  --data PATH     指定测试数据路径"
            echo "  --output PATH   指定输出目录"
            echo "  --config PATH   指定配置文件"
            echo "  --quick         快速测试模式"
            echo ""
            echo "示例:"
            echo "  $0 test MapTR --quick       # 快速测试MapTR"
            echo "  $0 test PETR --data /data   # 使用指定数据测试PETR"
            ;;
        compare)
            echo -e "${CYAN}compare - 多模型比较${NC}"
            echo ""
            echo "用法: $0 compare [OPTIONS]"
            echo ""
            echo "选项:"
            echo "  --models LIST   指定模型列表 (逗号分隔)"
            echo "  --data PATH     指定测试数据路径"
            echo "  --output PATH   指定输出目录"
            echo "  --format TYPE   输出格式 (json|html|text)"
            echo ""
            echo "功能:"
            echo "  - 运行多模型评测"
            echo "  - 生成性能对比报告"
            echo "  - 创建可视化图表"
            echo "  - 导出比较结果"
            ;;
        clean)
            echo -e "${CYAN}clean - 清理资源${NC}"
            echo ""
            echo "用法: $0 clean [OPTIONS]"
            echo ""
            echo "选项:"
            echo "  --images    清理Docker镜像"
            echo "  --cache     清理构建缓存"
            echo "  --logs      清理日志文件"
            echo "  --all       清理所有资源"
            echo ""
            echo "功能:"
            echo "  - 清理未使用的Docker镜像"
            echo "  - 删除临时文件和缓存"
            echo "  - 重置环境状态"
            ;;
        check)
            echo -e "${CYAN}check - 依赖和健康检查${NC}"
            echo ""
            echo "用法: $0 check [OPTIONS]"
            echo ""
            echo "选项:"
            echo "  --quick        快速检查模式"
            echo "  --full         完整依赖检查"
            echo "  --json         JSON格式输出"
            echo "  --model MODEL  指定模型检查"
            echo ""
            echo "功能:"
            echo "  - 检查Python环境和依赖"
            echo "  - 验证GPU和CUDA支持"
            echo "  - 检查模型文件完整性"
            echo "  - 系统资源状况分析"
            echo "  - 运行基础功能测试"
            ;;
        *)
            error "未知命令: $command"
            echo "运行 '$0 help' 查看可用命令"
            exit 1
            ;;
    esac
}

# 检查模型是否支持
check_model_supported() {
    local model="$1"
    for supported in "${SUPPORTED_MODELS[@]}"; do
        if [[ "${model}" == "${supported}" ]]; then
            return 0
        fi
    done
    error "不支持的模型: $model"
    echo -e "支持的模型: ${SUPPORTED_MODELS[*]}"
    exit 1
}

# 检查Docker环境
check_docker() {
    if ! command -v docker &> /dev/null; then
        error "Docker未安装或不在PATH中"
        return 1
    fi
    
    if ! docker info &> /dev/null; then
        error "Docker服务未运行或无权限访问"
        return 1
    fi
    
    return 0
}

# 检查GPU环境
check_gpu() {
    if ! command -v nvidia-smi &> /dev/null; then
        warn "nvidia-smi未找到，可能无GPU支持"
        return 1
    fi
    
    if ! nvidia-smi &> /dev/null; then
        warn "GPU不可用或驱动问题"
        return 1
    fi
    
    return 0
}

# 环境初始化
cmd_setup() {
    local check_only=false
    local force=false
    
    # 解析参数
    while [[ $# -gt 0 ]]; do
        case $1 in
            --check-only)
                check_only=true
                shift
                ;;
            --force)
                force=true
                shift
                ;;
            *)
                error "未知选项: $1"
                show_command_help setup
                exit 1
                ;;
        esac
    done
    
    header "环境初始化和检查"
    
    info "检查Docker环境..."
    if check_docker; then
        success "Docker环境正常"
    else
        error "Docker环境检查失败"
        exit 1
    fi
    
    info "检查GPU环境..."
    if check_gpu; then
        success "GPU环境正常"
    else
        warn "GPU环境可能有问题，某些功能可能受限"
    fi
    
    info "检查项目文件..."
    local required_dirs=("scripts" "containers" "tools" "config" "docs")
    for dir in "${required_dirs[@]}"; do
        if [[ -d "$SCRIPT_DIR/$dir" ]]; then
            success "目录存在: $dir"
        else
            error "缺少必要目录: $dir"
            exit 1
        fi
    done
    
    info "检查配置文件..."
    if [[ -f "$SCRIPT_DIR/config/models_config.json" ]]; then
        success "模型配置文件存在"
    else
        error "模型配置文件不存在: config/models_config.json"
        exit 1
    fi
    
    if [[ "$check_only" == "true" ]]; then
        success "环境检查完成"
        return 0
    fi
    
    info "初始化工作目录..."
    mkdir -p "$SCRIPT_DIR"/{logs,temp,evaluation_results}
    success "工作目录初始化完成"
    
    success "环境设置完成！可以开始使用RunPod平台"
}

# 系统状态查看
cmd_status() {
    header "系统状态"
    
    echo -e "${CYAN}Docker环境:${NC}"
    if check_docker; then
        echo "  ✅ Docker: $(docker --version | cut -d' ' -f3 | tr -d ',')"
        echo "  ✅ 服务状态: 运行中"
    else
        echo "  ❌ Docker: 不可用"
    fi
    
    echo ""
    echo -e "${CYAN}GPU环境:${NC}"
    if check_gpu; then
        echo "  ✅ NVIDIA驱动: $(nvidia-smi --query-gpu=driver_version --format=csv,noheader,nounits)"
        echo "  ✅ GPU数量: $(nvidia-smi --list-gpus | wc -l)"
    else
        echo "  ❌ GPU: 不可用"
    fi
    
    echo ""
    echo -e "${CYAN}项目信息:${NC}"
    echo "  📁 项目目录: $SCRIPT_DIR"
    echo "  📊 支持模型: ${#SUPPORTED_MODELS[@]}个"
    echo "  🐳 本地镜像: $(docker images | grep -E "(model|ai-models)" | wc -l)个"
    
    echo ""
    echo -e "${CYAN}磁盘使用:${NC}"
    echo "  💾 项目大小: $(du -sh "$SCRIPT_DIR" 2>/dev/null | cut -f1)"
    echo "  🐳 Docker: $(docker system df --format "table {{.Type}}\t{{.TotalCount}}\t{{.Size}}" | tail -n +2)"
}

# 构建命令
cmd_build() {
    local model=""
    local no_cache=false
    local push=false
    local tag="latest"
    
    # 解析参数
    while [[ $# -gt 0 ]]; do
        case $1 in
            --no-cache)
                no_cache=true
                shift
                ;;
            --push)
                push=true
                shift
                ;;
            --tag)
                tag="$2"
                shift 2
                ;;
            -*)
                error "未知选项: $1"
                show_command_help build
                exit 1
                ;;
            *)
                if [[ -z "$model" ]]; then
                    model="$1"
                else
                    error "只能指定一个模型"
                    exit 1
                fi
                shift
                ;;
        esac
    done
    
    if [[ -z "$model" ]]; then
        error "请指定模型名称或使用 'all'"
        show_command_help build
        exit 1
    fi
    
    header "构建Docker镜像"
    
    if [[ "$model" == "all" ]]; then
        info "构建所有模型镜像..."
        for m in "${SUPPORTED_MODELS[@]}"; do
            info "构建 $m..."
            if [[ "$push" == "true" ]]; then
                "$SCRIPT_DIR/scripts/build/docker_hub_workflow.sh" build "$m" --tag "$tag"
                "$SCRIPT_DIR/scripts/build/docker_hub_workflow.sh" push "$m" --tag "$tag"
            else
                "$SCRIPT_DIR/scripts/build/build_model_image.sh" "$m"
            fi
        done
    else
        check_model_supported "$model"
        info "构建 $model 镜像..."
        if [[ "$push" == "true" ]]; then
            "$SCRIPT_DIR/scripts/build/docker_hub_workflow.sh" build "$model" --tag "$tag"
            "$SCRIPT_DIR/scripts/build/docker_hub_workflow.sh" push "$model" --tag "$tag"
        else
            "$SCRIPT_DIR/scripts/build/build_model_image.sh" "$model"
        fi
    fi
    
    success "构建完成！"
}

# 健康检查命令
cmd_health() {
    local model=""
    local detailed=false
    local fix=false
    
    # 解析参数
    while [[ $# -gt 0 ]]; do
        case $1 in
            --detailed)
                detailed=true
                shift
                ;;
            --fix)
                fix=true
                shift
                ;;
            -*)
                error "未知选项: $1"
                show_command_help health
                exit 1
                ;;
            *)
                if [[ -z "$model" ]]; then
                    model="$1"
                    check_model_supported "$model"
                else
                    error "只能指定一个模型"
                    exit 1
                fi
                shift
                ;;
        esac
    done
    
    header "健康检查"
    
    if [[ -n "$model" ]]; then
        info "检查 $model 模型..."
        "$SCRIPT_DIR/scripts/evaluation/run_model_evaluation.sh" --health-check --models "$model"
    else
        info "检查所有模型..."
        "$SCRIPT_DIR/scripts/evaluation/run_model_evaluation.sh" --health-check
    fi
    
    success "健康检查完成！"
}

# 测试命令
cmd_test() {
    local model=""
    local data_path=""
    local output_path=""
    local config_path=""
    local quick=false
    
    # 解析参数
    while [[ $# -gt 0 ]]; do
        case $1 in
            --data)
                data_path="$2"
                shift 2
                ;;
            --output)
                output_path="$2"
                shift 2
                ;;
            --config)
                config_path="$2"
                shift 2
                ;;
            --quick)
                quick=true
                shift
                ;;
            -*)
                error "未知选项: $1"
                show_command_help test
                exit 1
                ;;
            *)
                if [[ -z "$model" ]]; then
                    model="$1"
                    check_model_supported "$model"
                else
                    error "只能指定一个模型"
                    exit 1
                fi
                shift
                ;;
        esac
    done
    
    if [[ -z "$model" ]]; then
        error "请指定要测试的模型"
        show_command_help test
        exit 1
    fi
    
    header "模型测试: $model"
    
    # 设置默认值
    if [[ -z "$data_path" ]]; then
        data_path="$SCRIPT_DIR/tests/test_results/test_data/sample.txt"
    fi
    
    if [[ -z "$output_path" ]]; then
        output_path="$SCRIPT_DIR/evaluation_results/$(date +%Y%m%d_%H%M%S)"
    fi
    
    info "数据路径: $data_path"
    info "输出路径: $output_path"
    
    if [[ "$quick" == "true" ]]; then
        info "运行快速测试..."
        "$SCRIPT_DIR/scripts/utils/quick_test.sh"
    else
        info "运行完整测试..."
        "$SCRIPT_DIR/scripts/evaluation/run_model_evaluation.sh" --single-model "$model" --data-path "$data_path" --output-dir "$output_path"
    fi
    
    success "测试完成！结果保存在: $output_path"
}

# 比较命令
cmd_compare() {
    local models=""
    local data_path=""
    local output_path=""
    local format="json"
    
    # 解析参数
    while [[ $# -gt 0 ]]; do
        case $1 in
            --models)
                models="$2"
                shift 2
                ;;
            --data)
                data_path="$2"
                shift 2
                ;;
            --output)
                output_path="$2"
                shift 2
                ;;
            --format)
                format="$2"
                shift 2
                ;;
            -*)
                error "未知选项: $1"
                show_command_help compare
                exit 1
                ;;
            *)
                error "未知参数: $1"
                show_command_help compare
                exit 1
                ;;
        esac
    done
    
    header "多模型比较"
    
    # 设置默认值
    if [[ -z "$output_path" ]]; then
        output_path="$SCRIPT_DIR/evaluation_results/comparison_$(date +%Y%m%d_%H%M%S)"
    fi
    
    info "输出路径: $output_path"
    
    if [[ -n "$models" ]]; then
        info "比较指定模型: $models"
        "$SCRIPT_DIR/scripts/evaluation/run_model_evaluation.sh" --compare-models --models "$models" --output-dir "$output_path"
    else
        info "比较所有模型..."
        "$SCRIPT_DIR/scripts/evaluation/run_model_evaluation.sh" --full-evaluation --output-dir "$output_path"
    fi
    
    success "比较完成！结果保存在: $output_path"
}

# 清理命令
cmd_clean() {
    local clean_images=false
    local clean_cache=false
    local clean_logs=false
    local clean_all=false
    
    # 解析参数
    while [[ $# -gt 0 ]]; do
        case $1 in
            --images)
                clean_images=true
                shift
                ;;
            --cache)
                clean_cache=true
                shift
                ;;
            --logs)
                clean_logs=true
                shift
                ;;
            --all)
                clean_all=true
                shift
                ;;
            -*)
                error "未知选项: $1"
                show_command_help clean
                exit 1
                ;;
            *)
                error "未知参数: $1"
                show_command_help clean
                exit 1
                ;;
        esac
    done
    
    if [[ "$clean_all" == "false" && "$clean_images" == "false" && "$clean_cache" == "false" && "$clean_logs" == "false" ]]; then
        clean_all=true
    fi
    
    header "清理资源"
    
    if [[ "$clean_all" == "true" || "$clean_images" == "true" ]]; then
        info "清理Docker镜像..."
        docker image prune -f
        docker system prune -f
        success "Docker镜像清理完成"
    fi
    
    if [[ "$clean_all" == "true" || "$clean_cache" == "true" ]]; then
        info "清理构建缓存..."
        rm -rf "$SCRIPT_DIR/temp"/*
        mkdir -p "$SCRIPT_DIR/temp"
        success "构建缓存清理完成"
    fi
    
    if [[ "$clean_all" == "true" || "$clean_logs" == "true" ]]; then
        info "清理日志文件..."
        rm -rf "$SCRIPT_DIR/logs"/*
        mkdir -p "$SCRIPT_DIR/logs"
        success "日志文件清理完成"
    fi
    
    success "清理完成！"
}

# 依赖检查命令
cmd_check() {
    local quick=false
    local full=false
    local json=false
    local model=""
    
    # 解析参数
    while [[ $# -gt 0 ]]; do
        case $1 in
            --quick)
                quick=true
                shift
                ;;
            --full)
                full=true
                shift
                ;;
            --json)
                json=true
                shift
                ;;
            --model)
                model="$2"
                check_model_supported "$model"
                shift 2
                ;;
            -*) 
                error "未知选项: $1"
                show_command_help check
                exit 1
                ;;
            *)
                error "未知参数: $1"
                show_command_help check
                exit 1
                ;;
        esac
    done
    
    header "依赖和健康检查"
    
    # 选择检查方式
    if [[ "$quick" == "true" ]]; then
        info "运行快速依赖检查..."
        if [[ -f "$SCRIPT_DIR/scripts/utils/quick_dependency_check.sh" ]]; then
            "$SCRIPT_DIR/scripts/utils/quick_dependency_check.sh"
        else
            warn "快速检查脚本不存在，使用详细检查..."
            python "$SCRIPT_DIR/tools/dependency_checker.py" --quick
        fi
    elif [[ "$full" == "true" ]]; then
        info "运行完整依赖检查..."
        if [[ -f "$SCRIPT_DIR/tools/dependency_checker.py" ]]; then
            local args=""
            [[ -n "$model" ]] && args="$args --model $model"
            [[ "$json" == "true" ]] && args="$args --json"
            python "$SCRIPT_DIR/tools/dependency_checker.py" $args
        else
            error "依赖检查工具不存在"
            exit 1
        fi
    else
        # 默认运行快速检查
        info "运行默认依赖检查（快速模式）..."
        if [[ -f "$SCRIPT_DIR/scripts/utils/quick_dependency_check.sh" ]]; then
            "$SCRIPT_DIR/scripts/utils/quick_dependency_check.sh"
        elif [[ -f "$SCRIPT_DIR/tools/dependency_checker.py" ]]; then
            python "$SCRIPT_DIR/tools/dependency_checker.py" --quick
        else
            warn "检查工具不可用，执行基础检查..."
            echo "检查Python环境:"
            python --version
            echo "检查核心依赖:"
            python -c "import torch, numpy; print('✅ 核心依赖正常')" 2>/dev/null || echo "❌ 核心依赖缺失"
        fi
    fi
    
    success "依赖检查完成！"
}

# 主函数
main() {
    local command="${1:-help}"
    
    case "$command" in
        setup)
            shift
            cmd_setup "$@"
            ;;
        status)
            shift
            cmd_status "$@"
            ;;
        build)
            shift
            cmd_build "$@"
            ;;
        health)
            shift
            cmd_health "$@"
            ;;
        test)
            shift
            cmd_test "$@"
            ;;
        compare)
            shift
            cmd_compare "$@"
            ;;
        clean)
            shift
            cmd_clean "$@"
            ;;
        check)
            shift
            cmd_check "$@"
            ;;
        version)
            show_version
            ;;
        help)
            if [[ -n "$2" ]]; then
                show_command_help "$2"
            else
                show_help
            fi
            ;;
        *)
            error "未知命令: $command"
            echo ""
            show_help
            exit 1
            ;;
    esac
}

# 运行主函数
main "$@"