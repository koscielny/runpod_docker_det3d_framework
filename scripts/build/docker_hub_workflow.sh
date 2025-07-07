#!/bin/bash

# Docker Hub Workflow - 本地构建并推送到Docker Hub，供RunPod使用
# 使用方法: ./docker_hub_workflow.sh [action] [model] [options]

set -e
DOCKER_HUB_USERNAME="iankaramazov"  # 设置你的Docker Hub用户名
# 加载配置
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/config.sh"

# Docker Hub配置
DOCKER_HUB_USERNAME="${DOCKER_HUB_USERNAME:-your-username}"  # 设置你的Docker Hub用户名
DOCKER_HUB_REPO="${DOCKER_HUB_REPO:-ai-models}"             # 仓库名称
DOCKER_REGISTRY="${DOCKER_REGISTRY:-docker.io}"             # 镜像仓库
BUILD_PLATFORM="${BUILD_PLATFORM:-linux/amd64}"             # 构建平台

# 颜色输出
print_header() {
    echo ""
    echo "🐳 =================================================="
    echo "🐳 Docker Hub Workflow - $1"
    echo "🐳 =================================================="
    echo ""
}

print_step() {
    echo "📋 Step: $1"
    echo "-----------------------------------"
}

print_success() {
    echo "✅ $1"
}

print_error() {
    echo "❌ $1"
}

# 显示使用方法
show_usage() {
    cat << EOF
🐳 Docker Hub Workflow Usage

用法: $0 [action] [model] [options]

Actions:
  build      构建单个模型的Docker镜像
  build-all  构建所有模型的Docker镜像
  push       推送单个模型镜像到Docker Hub
  push-all   推送所有模型镜像到Docker Hub
  deploy     完整工作流：构建 → 推送 → 生成RunPod命令
  clean      清理本地镜像
  list       列出本地构建的镜像
  login      登录到Docker Hub
  
Models: ${SUPPORTED_MODELS[*]}

Options:
  --tag TAG           指定镜像标签 (默认: latest)
  --platform PLATFORM 指定构建平台 (默认: linux/amd64)
  --push-after-build  构建后自动推送
  --no-cache          不使用缓存构建
  
环境变量:
  DOCKER_HUB_USERNAME  Docker Hub用户名
  DOCKER_HUB_REPO      仓库名称 (默认: ai-models)
  
示例:
  # 构建单个模型
  $0 build MapTR
  
  # 构建并推送
  $0 build MapTR --push-after-build
  
  # 构建所有模型并推送
  $0 deploy
  
  # 推送到自定义仓库
  DOCKER_HUB_USERNAME=myuser $0 push MapTR
  
  # 指定标签
  $0 build MapTR --tag v1.0
EOF
}

# 检查Docker是否安装
check_docker() {
    if ! command -v docker >/dev/null 2>&1; then
        print_error "Docker未安装或不在PATH中"
        exit 1
    fi
    
    if ! docker info >/dev/null 2>&1; then
        print_error "无法连接到Docker daemon，请确保Docker正在运行"
        exit 1
    fi
}

# 检查模型是否支持
check_model_supported() {
    local model="$1"
    if [[ ! " ${SUPPORTED_MODELS[*]} " =~ " $model " ]]; then
        print_error "不支持的模型: $model"
        echo "支持的模型: ${SUPPORTED_MODELS[*]}"
        exit 1
    fi
}

# 生成镜像名称
get_image_name() {
    local model="$1"
    local tag="${2:-latest}"
    echo "${DOCKER_REGISTRY}/${DOCKER_HUB_USERNAME}/${DOCKER_HUB_REPO}:${model,,}-${tag}"
}

# 构建单个模型
build_model() {
    local model="$1"
    local tag="${2:-latest}"
    local no_cache="$3"
    
    check_model_supported "$model"
    
    local model_dir="$SCRIPT_DIR/$model"
    local image_name=$(get_image_name "$model" "$tag")
    
    print_step "构建 $model 模型镜像"
    
    if [ ! -d "$model_dir" ]; then
        print_error "模型目录不存在: $model_dir"
        exit 1
    fi
    
    if [ ! -f "$model_dir/Dockerfile" ]; then
        print_error "Dockerfile不存在: $model_dir/Dockerfile"
        exit 1
    fi
    
    echo "📁 模型目录: $model_dir"
    echo "🐳 镜像名称: $image_name"
    echo "🏗️  构建平台: $BUILD_PLATFORM"
    echo ""
    
    # 构建参数
    local build_args="--platform $BUILD_PLATFORM"
    if [ "$no_cache" = "true" ]; then
        build_args="$build_args --no-cache"
    fi
    
    # 执行构建
    if docker build $build_args -t "$image_name" -f "$model_dir/Dockerfile" "$model_dir"; then
        print_success "镜像构建成功: $image_name"
        echo ""
        echo "📊 镜像信息:"
        docker images "$image_name" --format "table {{.Repository}}\t{{.Tag}}\t{{.Size}}\t{{.CreatedAt}}"
        return 0
    else
        print_error "镜像构建失败: $model"
        return 1
    fi
}

# 推送镜像到Docker Hub
push_model() {
    local model="$1"
    local tag="${2:-latest}"
    
    check_model_supported "$model"
    
    local image_name=$(get_image_name "$model" "$tag")
    
    print_step "推送 $model 镜像到Docker Hub"
    
    # 检查镜像是否存在
    if ! docker images "$image_name" --format "{{.Repository}}:{{.Tag}}" | grep -q "$image_name"; then
        print_error "本地镜像不存在: $image_name"
        echo "请先运行: $0 build $model"
        exit 1
    fi
    
    echo "🐳 推送镜像: $image_name"
    echo ""
    
    if docker push "$image_name"; then
        print_success "镜像推送成功: $image_name"
        echo ""
        echo "🔗 Docker Hub链接:"
        echo "https://hub.docker.com/r/${DOCKER_HUB_USERNAME}/${DOCKER_HUB_REPO}/tags"
        return 0
    else
        print_error "镜像推送失败: $model"
        return 1
    fi
}

# 登录Docker Hub
docker_login() {
    print_step "登录Docker Hub"
    
    if [ -z "$DOCKER_HUB_USERNAME" ] || [ "$DOCKER_HUB_USERNAME" = "your-username" ]; then
        print_error "请设置DOCKER_HUB_USERNAME环境变量"
        echo "例如: export DOCKER_HUB_USERNAME=yourusername"
        exit 1
    fi
    
    echo "🔐 登录用户: $DOCKER_HUB_USERNAME"
    
    if docker login "$DOCKER_REGISTRY" -u "$DOCKER_HUB_USERNAME"; then
        print_success "Docker Hub登录成功"
    else
        print_error "Docker Hub登录失败"
        exit 1
    fi
}

# 构建所有模型
build_all_models() {
    local tag="${1:-latest}"
    local no_cache="$2"
    local push_after_build="$3"
    
    print_header "构建所有模型镜像"
    
    local success_count=0
    local total_count=${#SUPPORTED_MODELS[@]}
    
    for model in "${SUPPORTED_MODELS[@]}"; do
        echo ""
        echo "🚀 [$((success_count + 1))/$total_count] 构建模型: $model"
        echo "=================================="
        
        if build_model "$model" "$tag" "$no_cache"; then
            success_count=$((success_count + 1))
            
            if [ "$push_after_build" = "true" ]; then
                echo ""
                if push_model "$model" "$tag"; then
                    print_success "模型 $model 构建并推送完成"
                else
                    print_error "模型 $model 推送失败"
                fi
            fi
        else
            print_error "模型 $model 构建失败"
        fi
        
        echo ""
        echo "===================================="
    done
    
    echo ""
    print_header "构建总结"
    echo "✅ 成功: $success_count/$total_count"
    echo "❌ 失败: $((total_count - success_count))/$total_count"
    
    if [ $success_count -eq $total_count ]; then
        print_success "所有模型构建成功！"
    else
        print_error "部分模型构建失败"
        exit 1
    fi
}

# 推送所有模型
push_all_models() {
    local tag="${1:-latest}"
    
    print_header "推送所有模型到Docker Hub"
    
    local success_count=0
    local total_count=${#SUPPORTED_MODELS[@]}
    
    for model in "${SUPPORTED_MODELS[@]}"; do
        echo ""
        echo "📤 [$((success_count + 1))/$total_count] 推送模型: $model"
        echo "=================================="
        
        if push_model "$model" "$tag"; then
            success_count=$((success_count + 1))
        else
            print_error "模型 $model 推送失败"
        fi
        
        echo ""
        echo "===================================="
    done
    
    echo ""
    print_header "推送总结"
    echo "✅ 成功: $success_count/$total_count"
    echo "❌ 失败: $((total_count - success_count))/$total_count"
}

# 生成RunPod部署命令
generate_runpod_commands() {
    local tag="${1:-latest}"
    
    print_header "RunPod部署命令"
    
    echo "📋 复制以下命令到RunPod中使用:"
    echo ""
    
    for model in "${SUPPORTED_MODELS[@]}"; do
        local image_name=$(get_image_name "$model" "$tag")
        echo "# $model 模型"
        echo "docker run -d --gpus all --name ${model,,}-container \\"
        echo "  -p 8080:8080 -p 22:22 \\"
        echo "  -v /workspace/data:/app/data \\"
        echo "  $image_name"
        echo ""
    done
    
    echo "🔗 Docker Hub仓库:"
    echo "https://hub.docker.com/r/${DOCKER_HUB_USERNAME}/${DOCKER_HUB_REPO}"
}

# 清理本地镜像
clean_images() {
    local tag="${1:-latest}"
    
    print_header "清理本地镜像"
    
    echo "🗑️  清理匹配的镜像模式: ${DOCKER_HUB_USERNAME}/${DOCKER_HUB_REPO}:*-${tag}"
    echo ""
    
    for model in "${SUPPORTED_MODELS[@]}"; do
        local image_name=$(get_image_name "$model" "$tag")
        
        if docker images "$image_name" --format "{{.Repository}}:{{.Tag}}" | grep -q "$image_name"; then
            echo "🗑️  删除镜像: $image_name"
            docker rmi "$image_name" 2>/dev/null || echo "   ⚠️  删除失败或镜像不存在"
        else
            echo "⏭️  跳过 (不存在): $image_name"
        fi
    done
    
    print_success "清理完成"
}

# 列出本地镜像
list_images() {
    print_header "本地AI模型镜像"
    
    echo "📋 匹配模式: ${DOCKER_HUB_USERNAME}/${DOCKER_HUB_REPO}:*"
    echo ""
    
    # 查找匹配的镜像
    local images_found=false
    for model in "${SUPPORTED_MODELS[@]}"; do
        local pattern="${DOCKER_HUB_USERNAME}/${DOCKER_HUB_REPO}"
        local model_images=$(docker images "$pattern" --format "{{.Repository}}:{{.Tag}}\t{{.Size}}\t{{.CreatedAt}}" | grep "${model,,}")
        
        if [ -n "$model_images" ]; then
            if [ "$images_found" = false ]; then
                echo "Repository:Tag\t\t\t\tSize\t\tCreated"
                echo "================================================================"
                images_found=true
            fi
            echo "$model_images"
        fi
    done
    
    if [ "$images_found" = false ]; then
        echo "❌ 没有找到本地AI模型镜像"
        echo ""
        echo "💡 提示:"
        echo "  1. 检查DOCKER_HUB_USERNAME是否正确设置"
        echo "  2. 运行 '$0 build [model]' 来构建镜像"
    fi
}

# 完整部署工作流
deploy_workflow() {
    local tag="${1:-latest}"
    local no_cache="$2"
    
    print_header "完整部署工作流"
    
    echo "🎯 工作流程:"
    echo "  1. 检查Docker环境"
    echo "  2. 登录Docker Hub"
    echo "  3. 构建所有模型镜像"
    echo "  4. 推送到Docker Hub"
    echo "  5. 生成RunPod部署命令"
    echo ""
    
    # 步骤1: 检查Docker
    check_docker
    print_success "Docker环境检查通过"
    
    # 步骤2: 登录
    docker_login
    
    # 步骤3: 构建所有模型
    build_all_models "$tag" "$no_cache" "false"
    
    # 步骤4: 推送所有模型
    push_all_models "$tag"
    
    # 步骤5: 生成RunPod命令
    generate_runpod_commands "$tag"
    
    print_header "部署工作流完成"
    print_success "所有模型已构建并推送到Docker Hub"
    print_success "可以在RunPod中使用上述命令部署"
}

# 解析命令行参数
parse_args() {
    ACTION=""
    MODEL=""
    TAG="latest"
    NO_CACHE="false"
    PUSH_AFTER_BUILD="false"
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            build|build-all|push|push-all|deploy|clean|list|login)
                ACTION="$1"
                shift
                ;;
            --tag)
                TAG="$2"
                shift 2
                ;;
            --platform)
                BUILD_PLATFORM="$2"
                shift 2
                ;;
            --push-after-build)
                PUSH_AFTER_BUILD="true"
                shift
                ;;
            --no-cache)
                NO_CACHE="true"
                shift
                ;;
            --help|-h)
                show_usage
                exit 0
                ;;
            -*)
                print_error "未知选项: $1"
                show_usage
                exit 1
                ;;
            *)
                if [ -z "$MODEL" ] && [[ " ${SUPPORTED_MODELS[*]} " =~ " $1 " ]]; then
                    MODEL="$1"
                else
                    print_error "未知参数: $1"
                    show_usage
                    exit 1
                fi
                shift
                ;;
        esac
    done
}

# 主函数
main() {
    parse_args "$@"
    
    # 检查基本环境
    check_docker
    
    # 显示配置信息
    if [ "$ACTION" != "login" ] && [ "$ACTION" != "list" ]; then
        echo "📋 Docker Hub配置:"
        echo "  用户名: $DOCKER_HUB_USERNAME"
        echo "  仓库: $DOCKER_HUB_REPO"
        echo "  注册表: $DOCKER_REGISTRY"
        echo "  平台: $BUILD_PLATFORM"
        echo "  标签: $TAG"
        echo ""
    fi
    
    case "$ACTION" in
        build)
            if [ -z "$MODEL" ]; then
                print_error "请指定模型名称"
                show_usage
                exit 1
            fi
            build_model "$MODEL" "$TAG" "$NO_CACHE"
            if [ "$PUSH_AFTER_BUILD" = "true" ]; then
                push_model "$MODEL" "$TAG"
            fi
            ;;
        build-all)
            build_all_models "$TAG" "$NO_CACHE" "$PUSH_AFTER_BUILD"
            ;;
        push)
            if [ -z "$MODEL" ]; then
                print_error "请指定模型名称"
                show_usage
                exit 1
            fi
            push_model "$MODEL" "$TAG"
            ;;
        push-all)
            push_all_models "$TAG"
            ;;
        deploy)
            deploy_workflow "$TAG" "$NO_CACHE"
            ;;
        clean)
            clean_images "$TAG"
            ;;
        list)
            list_images
            ;;
        login)
            docker_login
            ;;
        *)
            print_error "请指定操作"
            show_usage
            exit 1
            ;;
    esac
}

# 如果没有参数，显示使用方法
if [ $# -eq 0 ]; then
    show_usage
    exit 1
fi

main "$@"