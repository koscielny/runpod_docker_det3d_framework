#!/bin/bash

# 模型应用通用entrypoint
# 组合调用基础服务和专用服务

set -e

# 获取脚本目录
SCRIPT_DIR="/app/shared"

# 加载基础服务模块
source "$SCRIPT_DIR/entrypoint_base.sh"

# 动态加载可选服务模块
load_optional_services() {
    # 检查是否需要Jupyter服务
    if [ -f "$SCRIPT_DIR/entrypoint_jupyter.sh" ] && command -v jupyter >/dev/null 2>&1; then
        echo "📋 检测到Jupyter Lab，加载Jupyter服务..."
        source "$SCRIPT_DIR/entrypoint_jupyter.sh"
        ENABLE_JUPYTER=true
    else
        ENABLE_JUPYTER=false
    fi
}

# 启动所有服务
start_all_services() {
    echo "🐳 =================================================="
    echo "🐳 RunPod 模型容器启动 - $(date)"
    echo "🐳 =================================================="
    
    # 启动基础服务
    start_base_services
    
    # 启动可选服务
    if [ "$ENABLE_JUPYTER" = true ]; then
        start_jupyter_services
    fi
    
    # 显示容器信息
    echo "🎯 容器就绪: $(whoami)@$(hostname) - $(pwd)"
    echo "   Python: $(python --version 2>&1)"
    
    # 检查PyTorch和CUDA
    if python -c "import torch" 2>/dev/null; then
        echo "   PyTorch: $(python -c 'import torch; print(torch.__version__)' 2>/dev/null)"
        echo "   CUDA: $(python -c 'import torch; print(torch.cuda.is_available())' 2>/dev/null)"
    fi
    
    # 运行依赖检查
    run_dependency_check
    
    # 显示访问信息
    show_access_info
}

# 依赖检查
run_dependency_check() {
    echo "🔍 运行依赖检查..."
    
    if [ -f /app/scripts/utils/quick_dependency_check.sh ]; then
        /app/scripts/utils/quick_dependency_check.sh || echo "⚠️ 依赖检查发现问题"
    elif [ -f /app/tools/dependency_checker.py ]; then
        python /app/tools/dependency_checker.py --quick || echo "⚠️ 依赖检查发现问题"
    else
        # 基础检查
        echo "   正在进行基础依赖检查..."
        python -c "import torch, numpy; print('✅ 核心依赖正常')" 2>/dev/null || echo "❌ 核心依赖缺失"
    fi
}

# 显示访问信息
show_access_info() {
    echo ""
    echo "💡 容器服务访问信息:"
    echo "   📡 SSH: root@容器IP:22"
    
    if [ "$ENABLE_JUPYTER" = true ]; then
        echo "   📓 Jupyter Lab: http://容器IP:8888 (无密码)"
    fi
    
    if [ -f /app/runpod_platform.sh ]; then
        echo "   🚀 模型服务: 使用 /app/runpod_platform.sh"
    fi
    
    echo ""
}

# 健康检查守护进程
health_check_daemon() {
    while true; do
        sleep 30
        
        # 检查基础服务
        check_base_services
        
        # 检查可选服务
        if [ "$ENABLE_JUPYTER" = true ]; then
            check_jupyter_services
        fi
    done
}

# 主函数
main() {
    # 加载服务模块
    load_optional_services
    
    # 启动所有服务
    start_all_services
    
    # 如果有参数，执行指定命令
    if [ $# -gt 0 ]; then
        echo "🔧 执行指定命令: $*"
        exec "$@"
    else
        # 启动健康检查守护进程
        echo "🔄 启动服务监控..."
        health_check_daemon
    fi
}

# 运行主函数
main "$@"