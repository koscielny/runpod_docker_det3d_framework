#!/bin/bash

# 为所有模型仓库提交更改并推送到 runpod/init 分支
# 这个脚本会检查每个仓库的状态，添加更改，创建commit，并推送到远程

set -e

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# 日志函数
log() {
    echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[$(date '+%Y-%m-%d %H:%M:%S')] WARNING:${NC} $1"
}

error() {
    echo -e "${RED}[$(date '+%Y-%m-%d %H:%M:%S')] ERROR:${NC} $1"
}

info() {
    echo -e "${BLUE}[$(date '+%Y-%m-%d %H:%M:%S')] INFO:${NC} $1"
}

# 仓库配置
PARENT_DIR="/home/ian/dev/src/online_mapping"
MODELS=("MapTR" "PETR" "StreamPETR" "TopoMLP" "VAD")

# 检查是否在正确的分支上
check_branch() {
    local repo_path="$1"
    local current_branch=$(git -C "$repo_path" branch --show-current)
    
    if [ "$current_branch" != "runpod/init" ]; then
        warn "Repository is on branch '$current_branch', not 'runpod/init'"
        
        # 检查是否存在runpod/init分支
        if git -C "$repo_path" show-ref --verify --quiet refs/heads/runpod/init; then
            info "Switching to existing runpod/init branch..."
            git -C "$repo_path" checkout runpod/init
        else
            info "Creating new runpod/init branch from current branch..."
            git -C "$repo_path" checkout -b runpod/init
        fi
    fi
}

# 检查仓库状态并添加更改
process_repository() {
    local model="$1"
    local repo_path="$PARENT_DIR/$model"
    
    log "Processing $model repository..."
    
    if [ ! -d "$repo_path" ]; then
        error "Repository directory not found: $repo_path"
        return 1
    fi
    
    if [ ! -d "$repo_path/.git" ]; then
        error "Not a git repository: $repo_path"
        return 1
    fi
    
    cd "$repo_path"
    
    # 检查并切换到正确的分支
    check_branch "$repo_path"
    
    # 检查是否有未提交的更改
    if [ -n "$(git status --porcelain)" ]; then
        info "Found uncommitted changes in $model:"
        git status --short
        
        # 显示具体的更改
        echo ""
        info "Detailed changes:"
        git diff --name-only
        
        # 添加所有更改
        info "Adding all changes..."
        git add .
        
        # 创建详细的commit信息
        local commit_message="Add RunPod Docker deployment improvements

- Update Dockerfile for RunPod compatibility
- Add SSH server and development tools support
- Fix security configurations with non-root user
- Add GPU monitoring and memory cleanup utilities
- Optimize Docker build context with .dockerignore
- Update git remote to koscielny repositories
- Switch to runpod/init deployment branch

🤖 Generated with [Claude Code](https://claude.ai/code)

Co-Authored-By: Claude <noreply@anthropic.com>"

        # 创建commit
        info "Creating commit for $model..."
        git commit -m "$commit_message"
        
        # 检查远程分支是否存在
        if git ls-remote --heads origin runpod/init | grep -q runpod/init; then
            info "Remote runpod/init branch exists, pushing changes..."
            git push origin runpod/init
        else
            info "Creating new remote runpod/init branch..."
            git push -u origin runpod/init
        fi
        
        log "✅ Successfully committed and pushed changes for $model"
        
    else
        info "No uncommitted changes found in $model"
        
        # 检查是否需要推送已有的commit
        local ahead_count=$(git rev-list --count origin/runpod/init..HEAD 2>/dev/null || echo "0")
        if [ "$ahead_count" -gt 0 ]; then
            info "Found $ahead_count unpushed commits, pushing..."
            git push origin runpod/init
            log "✅ Pushed existing commits for $model"
        else
            info "Repository is up to date"
        fi
    fi
    
    echo ""
}

# 主函数
main() {
    log "=== Starting commit and push process for all model repositories ==="
    
    local success_count=0
    local total_count=${#MODELS[@]}
    
    for model in "${MODELS[@]}"; do
        if process_repository "$model"; then
            ((success_count++))
        else
            error "Failed to process $model repository"
        fi
    done
    
    echo ""
    log "=== Summary ==="
    info "Successfully processed: $success_count/$total_count repositories"
    
    if [ $success_count -eq $total_count ]; then
        log "🎉 All repositories have been successfully updated!"
        echo ""
        info "All models are now ready for RunPod deployment with the latest improvements:"
        info "  • SSH and Git support for development"
        info "  • Security hardening with non-root users"
        info "  • GPU monitoring and memory management"
        info "  • Optimized Docker builds"
        info "  • Dynamic configuration file management"
        echo ""
        info "Next steps:"
        info "  1. Test Docker builds: docker build -t model-name:latest ./ModelName/"
        info "  2. Deploy to RunPod with the updated runpod/init branch"
        info "  3. Validate end-to-end deployment pipeline"
    else
        warn "Some repositories failed to update. Please check the errors above."
        exit 1
    fi
}

# 运行主函数
main "$@"