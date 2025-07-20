#!/bin/bash

# 基础镜像构建和推送脚本 (VSCode & Jupyter Lab)
# 用法: ./build_and_push.sh [action] [options]

set -e

# Docker Hub配置 (与现有scripts一致)
DOCKER_HUB_USERNAME="iankaramazov"
DOCKER_HUB_REPO="ai-models"
DOCKER_REGISTRY="docker.io"
BUILD_PLATFORM="linux/amd64"

# 获取项目根目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$SCRIPT_DIR"

# 颜色输出函数
print_header() {
    echo ""
    echo "🐳 =================================================="
    echo "🐳 基础镜像构建和推送 - $1"
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
🐳 基础镜像构建和推送工具

用法: $0 [action] [image] [options]

Actions:
  build      构建指定基础镜像
  push       推送指定基础镜像
  build-push 构建并推送基础镜像
  build-all  构建所有基础镜像
  push-all   推送所有基础镜像
  deploy     完整工作流：构建所有镜像并推送
  list       列出本地基础镜像
  login      登录Docker Hub

Images:
  vscode     VSCode开发环境镜像
  jupyterlab Jupyter Lab数据科学环境镜像

Options:
  --tag TAG           指定镜像标签 (默认: latest)
  --no-cache          不使用缓存构建
  --platform PLATFORM 指定构建平台 (默认: linux/amd64)

示例:
  # 构建Jupyter Lab镜像
  $0 build jupyterlab
  
  # 构建并推送VSCode镜像
  $0 build-push vscode
  
  # 构建并推送所有基础镜像
  $0 deploy
  
  # 推送Jupyter Lab镜像
  $0 push jupyterlab --tag v1.0
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

# 构建基础镜像
build_base_image() {
    local image="$1"
    local tag="${2:-latest}"
    local no_cache="$3"
    
    print_step "构建 $image 基础镜像"
    
    local dockerfile_path="containers/base/Dockerfile.$image"
    local image_name=$(get_image_name "$image" "$tag")
    
    if [ ! -f "$dockerfile_path" ]; then
        print_error "Dockerfile不存在: $dockerfile_path"
        exit 1
    fi
    
    echo "📁 Dockerfile: $dockerfile_path"
    echo "🐳 镜像名称: $image_name"
    echo "🏗️  构建平台: $BUILD_PLATFORM"
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

# 推送基础镜像
push_base_image() {
    local image="$1"
    local tag="${2:-latest}"
    
    print_step "推送 $image 镜像到Docker Hub"
    
    local image_name=$(get_image_name "$image" "$tag")
    
    # 检查镜像是否存在
    if ! docker images "$image_name" --format "{{.Repository}}:{{.Tag}}" | grep -q "$image_name"; then
        print_error "本地镜像不存在: $image_name"
        echo "请先运行: $0 build $image"
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
        print_error "镜像推送失败: $image"
        return 1
    fi
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
        
        if build_base_image "$image" "$tag" "$no_cache"; then
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
        
        if push_base_image "$image" "$tag"; then
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

# 列出基础镜像
list_images() {
    print_header "本地基础镜像"
    
    echo "📋 匹配模式: ${DOCKER_HUB_USERNAME}/${DOCKER_HUB_REPO}:*"
    echo ""
    
    local pattern="${DOCKER_HUB_USERNAME}/${DOCKER_HUB_REPO}"
    local base_images=$(docker images "$pattern" --format "{{.Repository}}:{{.Tag}}\t{{.Size}}\t{{.CreatedAt}}" | grep -E "(vscode|jupyterlab)")
    
    if [ -n "$base_images" ]; then
        echo "Repository:Tag\t\t\t\tSize\t\tCreated"
        echo "================================================================"
        echo "$base_images"
    else
        echo "❌ 没有找到本地基础镜像"
        echo ""
        echo "💡 提示: 运行 '$0 build [vscode|jupyterlab]' 来构建镜像"
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
    echo "  3. 构建所有基础镜像"
    echo "  4. 推送到Docker Hub"
    echo ""
    
    # 步骤1: 检查Docker
    check_docker
    print_success "Docker环境检查通过"
    
    # 步骤2: 登录
    docker_login
    
    # 步骤3: 构建所有镜像
    if build_all_images "$tag" "$no_cache"; then
        # 步骤4: 推送所有镜像
        push_all_images "$tag"
        
        print_header "部署工作流完成"
        print_success "所有基础镜像已构建并推送到Docker Hub"
        print_success "现在可以在RunPod中使用: iankaramazov/ai-models:vscode 和 iankaramazov/ai-models:jupyterlab"
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
            build|push|build-push|build-all|push-all|deploy|list|login)
                ACTION="$1"
                shift
                ;;
            vscode|jupyterlab)
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
                print_error "请指定镜像名称: vscode 或 jupyterlab"
                show_usage
                exit 1
            fi
            build_base_image "$IMAGE" "$TAG" "$NO_CACHE"
            ;;
        push)
            if [ -z "$IMAGE" ]; then
                print_error "请指定镜像名称: vscode 或 jupyterlab"
                show_usage
                exit 1
            fi
            push_base_image "$IMAGE" "$TAG"
            ;;
        build-push)
            if [ -z "$IMAGE" ]; then
                print_error "请指定镜像名称: vscode 或 jupyterlab"
                show_usage
                exit 1
            fi
            if build_base_image "$IMAGE" "$TAG" "$NO_CACHE"; then
                push_base_image "$IMAGE" "$TAG"
            fi
            ;;
        build-all)
            build_all_images "$TAG" "$NO_CACHE"
            ;;
        push-all)
            push_all_images "$TAG"
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