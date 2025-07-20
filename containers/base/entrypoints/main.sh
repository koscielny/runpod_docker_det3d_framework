#!/bin/bash

# 基础镜像主入口点
# 组合SSH和Jupyter服务，提供完整的基础服务

set -e

# 脚本目录路径
SCRIPT_DIR="/app/entrypoints"

# 加载工具函数
source "$SCRIPT_DIR/../shared/entrypoints/utils.sh"

# 加载基础服务
source "$SCRIPT_DIR/ssh.sh"

# 动态加载Jupyter服务（如果可用）
ENABLE_JUPYTER=false
if [ -f "$SCRIPT_DIR/jupyter.sh" ] && command -v jupyter >/dev/null 2>&1; then
    source "$SCRIPT_DIR/jupyter.sh"
    ENABLE_JUPYTER=true
fi

# 启动所有基础服务
start_base_services() {
    print_header "基础服务启动 - $(date)"
    
    # 启动SSH服务
    start_ssh_service
    
    # 启动Jupyter服务（如果可用）
    if [ "$ENABLE_JUPYTER" = true ]; then
        start_jupyter_service
    fi
    
    # 显示系统信息
    show_system_info
    
    # 运行依赖检查
    run_dependency_check
    
    # 显示内存状态
    show_memory_info
    
    # 创建便捷别名
    create_aliases
    
    # 显示访问信息
    show_access_info
    
    print_success "基础服务启动完成"
}

# 健康检查守护进程
health_check_daemon() {
    print_step "启动服务监控..."
    
    while true; do
        sleep 30
        
        # 检查SSH服务
        check_ssh_service
        
        # 检查Jupyter服务
        if [ "$ENABLE_JUPYTER" = true ]; then
            check_jupyter_service
        fi
    done
}

# 主函数
main() {
    # 启动所有基础服务
    start_base_services
    
    # 如果有参数，执行指定命令
    if [ $# -gt 0 ]; then
        print_step "执行指定命令: $*"
        exec "$@"
    else
        # 启动健康检查守护进程
        health_check_daemon
    fi
}

# 运行主函数
main "$@"