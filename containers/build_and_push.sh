#!/bin/bash

# 完整的Docker镜像构建和推送脚本 (基础镜像 + 模型镜像)
# 用法: ./build_and_push.sh [action] [target] [options]

set -e

# Docker Hub配置 (与现有scripts一致)
DOCKER_HUB_USERNAME="iankaramazov"
DOCKER_HUB_REPO="ai-models"
DOCKER_REGISTRY="docker.io"
BUILD_PLATFORM="linux/amd64"

# 获取项目根目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# 支持的基础镜像
BASE_IMAGES=("vscode" "jupyterlab")

# 支持的模型镜像
MODEL_IMAGES=("VAD" "MapTR" "PETR" "StreamPETR" "TopoMLP")

# 支持的模型库镜像（mmlibs）
MMLIB_IMAGES=("vad-mmlibs" "maptr-mmlibs" "petr-mmlibs" "streampetr-mmlibs" "topomlp-mmlibs")

# 颜色输出函数
print_header() {
    echo ""
    echo "🐳 =================================================="
    echo "🐳 Docker镜像构建和推送 - $1"
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
🐳 Docker镜像构建和推送工具 (基础镜像 + 模型镜像)

用法: $0 [action] [target] [options]

Actions:
  build         构建指定镜像
  push          推送指定镜像  
  build-push    构建并推送镜像
  build-all     构建所有镜像
  build-base    构建所有基础镜像
  build-models  构建所有模型镜像
  push-all      推送所有镜像
  push-base     推送所有基础镜像
  push-models   推送所有模型镜像
  deploy        完整工作流：构建并推送所有镜像
  list          列出本地镜像
  login         登录Docker Hub

基础镜像:
  vscode        VSCode开发环境镜像
  jupyterlab    Jupyter Lab数据科学环境镜像

模型镜像:
  VAD           VAD模型应用镜像
  MapTR         MapTR模型应用镜像
  PETR          PETR模型应用镜像
  StreamPETR    StreamPETR模型应用镜像
  TopoMLP       TopoMLP模型应用镜像

模型库镜像:
  vad-mmlibs         VAD + MM系列库环境
  maptr-mmlibs       MapTR + MM系列库环境
  petr-mmlibs        PETR + MM系列库环境
  streampetr-mmlibs  StreamPETR + MM系列库环境
  topomlp-mmlibs     TopoMLP + MM系列库环境

Options:
  --tag TAG           指定镜像标签 (默认: latest)
  --no-cache          不使用缓存构建
  --platform PLATFORM 指定构建平台 (默认: linux/amd64)

示例:
  # 构建基础镜像
  $0 build jupyterlab
  $0 build-base
  
  # 构建模型镜像
  $0 build VAD
  $0 build-models
  
  # 构建并推送特定模型
  $0 build-push MapTR
  
  # 构建并推送所有镜像
  $0 deploy
  
  # 只推送模型镜像
  $0 push-models --tag v1.0
EOF
}

# 检查Docker环境
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

# 获取镜像名称
get_image_name() {
    local image="$1"
    local tag="${2:-latest}"
    echo "${DOCKER_HUB_USERNAME}/${DOCKER_HUB_REPO}:${image}"
}

# 检查镜像类型
get_image_type() {
    local image="$1"
    
    for base_img in "${BASE_IMAGES[@]}"; do
        if [ "$image" = "$base_img" ]; then
            echo "base"
            return 0
        fi
    done
    
    for model_img in "${MODEL_IMAGES[@]}"; do
        if [ "$image" = "$model_img" ]; then
            echo "model"
            return 0
        fi
    done
    
    for mmlib_img in "${MMLIB_IMAGES[@]}"; do
        if [ "$image" = "$mmlib_img" ]; then
            echo "mmlib"
            return 0
        fi
    done
    
    echo "unknown"
    return 1
}

# 获取Dockerfile路径
get_dockerfile_path() {
    local image="$1"
    local image_type="$2"
    
    case "$image_type" in
        "base")
            echo "$PROJECT_ROOT/containers/base/Dockerfile.$image"
            ;;
        "model")
            echo "$PROJECT_ROOT/containers/models/$image/Dockerfile"
            ;;
        "mmlib")
            # 解析mmlib镜像名称 (如 vad-mmlibs -> VAD)
            local model_name=$(echo "$image" | sed 's/-mmlibs$//' | tr '[:lower:]' '[:upper:]')
            echo "$PROJECT_ROOT/containers/models/$model_name/Dockerfile.mmlibs"
            ;;
        *)
            echo ""
            return 1
            ;;
    esac
}

# 通用镜像构建函数
build_image() {
    local image="$1"
    local tag="${2:-latest}"
    local no_cache="$3"
    
    # 检查镜像类型
    local image_type=$(get_image_type "$image")
    if [ "$image_type" = "unknown" ]; then
        print_error "不支持的镜像: $image"
        return 1
    fi
    
    print_step "构建 $image 镜像 (类型: $image_type)"

    # 获取Dockerfile路径
    local dockerfile_path=$(get_dockerfile_path "$image" "$image_type")
    local image_name=$(get_image_name "$image" "$tag")
    
    if [ ! -f "$dockerfile_path" ]; then
        print_error "Dockerfile不存在: $dockerfile_path"
        return 1
    fi
    
    echo "📁 Dockerfile: $dockerfile_path"
    echo "🐳 镜像名称: $image_name"
    echo "🏗️  构建平台: $BUILD_PLATFORM"
    echo "📂 镜像类型: $image_type"
    echo ""
    
    # 构建参数
    local build_args="--platform $BUILD_PLATFORM"
    if [ "$no_cache" = "true" ]; then
        build_args="$build_args --no-cache"
    fi
    
    # 执行构建
    if docker build $build_args -t "$image_name" -f "$dockerfile_path" "$PROJECT_ROOT"; then
        print_success "镜像构建成功: $image_name"
        echo ""
        echo "📊 镜像信息:"
        docker images "$image_name" --format "table {{.Repository}}\t{{.Tag}}\t{{.Size}}\t{{.CreatedAt}}"
        return 0
    else
        print_error "镜像构建失败: $image"
        return 1
    fi
}

# 兼容性函数 - 构建基础镜像
build_base_image() {
    build_image "$1" "$2" "$3"
}

# 通用镜像推送函数
push_image() {
    local image="$1"
    local tag="${2:-latest}"
    
    print_step "推送 $image 镜像到Docker Hub"
    
    local image_name=$(get_image_name "$image" "$tag")
    
    # 检查镜像是否存在
    if ! docker images "$image_name" --format "{{.Repository}}:{{.Tag}}" | grep -q "$image_name"; then
        print_error "本地镜像不存在: $image_name"
        echo "请先运行: $0 build $image"
        return 1
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
        print_error "镜像推送失败: $image"
        return 1
    fi
}

# 兼容性函数 - 推送基础镜像
push_base_image() {
    push_image "$1" "$2"
}

# 登录Docker Hub
docker_login() {
    print_step "登录Docker Hub"
    
    echo "🔐 登录用户: $DOCKER_HUB_USERNAME"
    
    if docker login "$DOCKER_REGISTRY" -u "$DOCKER_HUB_USERNAME"; then
        print_success "Docker Hub登录成功"
    else
        print_error "Docker Hub登录失败"
        exit 1
    fi
}

# 构建所有基础镜像
build_all_images() {
    local tag="${1:-latest}"
    local no_cache="$2"
    
    print_header "构建所有基础镜像"
    
    local images=("vscode" "jupyterlab")
    local success_count=0
    local total_count=${#images[@]}
    
    for image in "${images[@]}"; do
        echo ""
        echo "🚀 [$((success_count + 1))/$total_count] 构建镜像: $image"
        echo "=================================="
        
        if build_image "$image" "$tag" "$no_cache"; then
            success_count=$((success_count + 1))
        else
            print_error "镜像 $image 构建失败"
        fi
        
        echo ""
        echo "===================================="
    done
    
    echo ""
    print_header "构建总结"
    echo "✅ 成功: $success_count/$total_count"
    echo "❌ 失败: $((total_count - success_count))/$total_count"
    
    if [ $success_count -eq $total_count ]; then
        print_success "所有基础镜像构建成功！"
        return 0
    else
        print_error "部分基础镜像构建失败"
        return 1
    fi
}

# 推送所有基础镜像
push_all_images() {
    local tag="${1:-latest}"
    
    print_header "推送所有基础镜像"
    
    local images=("vscode" "jupyterlab")
    local success_count=0
    local total_count=${#images[@]}
    
    for image in "${images[@]}"; do
        echo ""
        echo "📤 [$((success_count + 1))/$total_count] 推送镜像: $image"
        echo "=================================="
        
        if push_image "$image" "$tag"; then
            success_count=$((success_count + 1))
        else
            print_error "镜像 $image 推送失败"
        fi
        
        echo ""
        echo "===================================="
    done
    
    echo ""
    print_header "推送总结"
    echo "✅ 成功: $success_count/$total_count"
    echo "❌ 失败: $((total_count - success_count))/$total_count"
}

# 构建所有模型镜像
build_all_models() {
    local tag="${1:-latest}"
    local no_cache="$2"
    
    print_header "构建所有模型镜像"
    
    local success_count=0
    local total_count=${#MODEL_IMAGES[@]}
    
    for image in "${MODEL_IMAGES[@]}"; do
        echo ""
        echo "🚀 [$((success_count + 1))/$total_count] 构建模型: $image"
        echo "=================================="
        
        if build_image "$image" "$tag" "$no_cache"; then
            success_count=$((success_count + 1))
        else
            print_error "模型 $image 构建失败"
        fi
        
        echo ""
        echo "===================================="
    done
    
    echo ""
    print_header "模型构建总结"
    echo "✅ 成功: $success_count/$total_count"
    echo "❌ 失败: $((total_count - success_count))/$total_count"
    
    if [ $success_count -eq $total_count ]; then
        print_success "所有模型镜像构建成功！"
        return 0
    else
        print_error "部分模型镜像构建失败"
        return 1
    fi
}

# 推送所有模型镜像
push_all_models() {
    local tag="${1:-latest}"
    
    print_header "推送所有模型镜像"
    
    local success_count=0
    local total_count=${#MODEL_IMAGES[@]}
    
    for image in "${MODEL_IMAGES[@]}"; do
        echo ""
        echo "📤 [$((success_count + 1))/$total_count] 推送模型: $image"
        echo "=================================="
        
        if push_image "$image" "$tag"; then
            success_count=$((success_count + 1))
        else
            print_error "模型 $image 推送失败"
        fi
        
        echo ""
        echo "===================================="
    done
    
    echo ""
    print_header "模型推送总结"
    echo "✅ 成功: $success_count/$total_count"
    echo "❌ 失败: $((total_count - success_count))/$total_count"
}

# 构建所有镜像（基础 + 模型）
build_all_complete() {
    local tag="${1:-latest}"
    local no_cache="$2"
    
    print_header "构建所有镜像（基础镜像 + 模型镜像）"
    
    # 先构建基础镜像
    if build_all_images "$tag" "$no_cache"; then
        # 再构建模型镜像
        build_all_models "$tag" "$no_cache"
    else
        print_error "基础镜像构建失败，停止构建模型镜像"
        return 1
    fi
}

# 推送所有镜像（基础 + 模型）
push_all_complete() {
    local tag="${1:-latest}"
    
    print_header "推送所有镜像（基础镜像 + 模型镜像）"
    
    # 推送基础镜像
    push_all_images "$tag"
    
    # 推送模型镜像  
    push_all_models "$tag"
}

# 列出所有镜像
list_images() {
    print_header "本地Docker镜像"
    
    echo "📋 匹配模式: ${DOCKER_HUB_USERNAME}/${DOCKER_HUB_REPO}:*"
    echo ""
    
    local pattern="${DOCKER_HUB_USERNAME}/${DOCKER_HUB_REPO}"
    
    # 基础镜像
    echo "🏗️  基础镜像:"
    local base_images=$(docker images "$pattern" --format "{{.Repository}}:{{.Tag}}\t{{.Size}}\t{{.CreatedAt}}" | grep -E "(vscode|jupyterlab)")
    if [ -n "$base_images" ]; then
        echo "Repository:Tag\t\t\t\tSize\t\tCreated"
        echo "================================================================"
        echo "$base_images"
    else
        echo "   ❌ 没有找到基础镜像"
    fi
    
    echo ""
    
    # 模型镜像
    echo "🤖 模型镜像:"
    local model_pattern="$(echo "${MODEL_IMAGES[@]}" | tr ' ' '|')"
    local model_images=$(docker images "$pattern" --format "{{.Repository}}:{{.Tag}}\t{{.Size}}\t{{.CreatedAt}}" | grep -E "($model_pattern)")
    if [ -n "$model_images" ]; then
        echo "Repository:Tag\t\t\t\tSize\t\tCreated"
        echo "================================================================"
        echo "$model_images"
    else
        echo "   ❌ 没有找到模型镜像"
    fi
    
    echo ""
    
    # 模型库镜像
    echo "📚 模型库镜像:"
    local mmlib_images=$(docker images "$pattern" --format "{{.Repository}}:{{.Tag}}\t{{.Size}}\t{{.CreatedAt}}" | grep -E "mmlibs")
    if [ -n "$mmlib_images" ]; then
        echo "Repository:Tag\t\t\t\tSize\t\tCreated"
        echo "================================================================"
        echo "$mmlib_images"
    else
        echo "   ❌ 没有找到模型库镜像"
    fi
    
    echo ""
    echo "💡 使用提示:"
    echo "   构建基础镜像: $0 build [vscode|jupyterlab]"
    echo "   构建模型镜像: $0 build [VAD|MapTR|PETR|StreamPETR|TopoMLP]"
    echo "   构建所有镜像: $0 build-all"
}

# 完整部署工作流
deploy_workflow() {
    local tag="${1:-latest}"
    local no_cache="$2"
    
    print_header "完整部署工作流"
    
    echo "🎯 工作流程:"
    echo "  1. 检查Docker环境"
    echo "  2. 登录Docker Hub"
    echo "  3. 构建所有基础镜像"
    echo "  4. 构建所有模型镜像"
    echo "  5. 推送所有镜像到Docker Hub"
    echo ""
    
    # 步骤1: 检查Docker
    check_docker
    print_success "Docker环境检查通过"
    
    # 步骤2: 登录
    docker_login
    
    # 步骤3 & 4: 构建所有镜像
    if build_all_complete "$tag" "$no_cache"; then
        # 步骤5: 推送所有镜像
        push_all_complete "$tag"
        
        print_header "部署工作流完成"
        print_success "所有镜像已构建并推送到Docker Hub"
        print_success "基础镜像: iankaramazov/ai-models:vscode, iankaramazov/ai-models:jupyterlab"
        print_success "模型镜像: iankaramazov/ai-models:VAD, iankaramazov/ai-models:MapTR, etc."
    else
        print_error "构建失败，停止推送"
        exit 1
    fi
}

# 解析命令行参数
parse_args() {
    ACTION=""
    IMAGE=""
    TAG="latest"
    NO_CACHE="false"
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            build|push|build-push|build-all|build-base|build-models|push-all|push-base|push-models|deploy|list|login)
                ACTION="$1"
                shift
                ;;
            vscode|jupyterlab|VAD|MapTR|PETR|StreamPETR|TopoMLP|vad-mmlibs|maptr-mmlibs|petr-mmlibs|streampetr-mmlibs|topomlp-mmlibs)
                IMAGE="$1"
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
                print_error "未知参数: $1"
                show_usage
                exit 1
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
            if [ -z "$IMAGE" ]; then
                print_error "请指定镜像名称"
                show_usage
                exit 1
            fi
            build_image "$IMAGE" "$TAG" "$NO_CACHE"
            ;;
        push)
            if [ -z "$IMAGE" ]; then
                print_error "请指定镜像名称"
                show_usage
                exit 1
            fi
            push_image "$IMAGE" "$TAG"
            ;;
        build-push)
            if [ -z "$IMAGE" ]; then
                print_error "请指定镜像名称"
                show_usage
                exit 1
            fi
            if build_image "$IMAGE" "$TAG" "$NO_CACHE"; then
                push_image "$IMAGE" "$TAG"
            fi
            ;;
        build-all)
            build_all_complete "$TAG" "$NO_CACHE"
            ;;
        build-base)
            build_all_images "$TAG" "$NO_CACHE"
            ;;
        build-models)
            build_all_models "$TAG" "$NO_CACHE"
            ;;
        push-all)
            push_all_complete "$TAG"
            ;;
        push-base)
            push_all_images "$TAG"
            ;;
        push-models)
            push_all_models "$TAG"
            ;;
        deploy)
            deploy_workflow "$TAG" "$NO_CACHE"
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