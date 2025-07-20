#!/bin/bash

# Jupyter Lab服务启动脚本
# 被上层entrypoint调用，专门负责Jupyter Lab服务

set -e

# Jupyter服务启动标志  
JUPYTER_SERVICES_FLAG="/tmp/.jupyter_services_started"

start_jupyter_services() {
    if [ -f "$JUPYTER_SERVICES_FLAG" ]; then
        echo "✅ Jupyter服务已启动，跳过初始化"
        return 0
    fi

    echo "🚀 启动Jupyter Lab服务..."
    
    # 启动Jupyter Lab
    echo "📋 启动Jupyter Lab..."
    nohup jupyter lab --ip=0.0.0.0 --port=8888 --no-browser --allow-root \
        --ServerApp.token='' --ServerApp.password='' \
        --ServerApp.allow_origin='*' --ServerApp.disable_check_xsrf=True \
        --notebook-dir=/app > /var/log/jupyter.log 2>&1 &
    
    # 等待Jupyter启动
    sleep 3
    if pgrep -f "jupyter-lab" > /dev/null; then
        echo "✅ Jupyter Lab运行中 (端口8888, 无密码访问)"
    else
        echo "❌ Jupyter Lab启动失败"
        echo "📋 检查日志: cat /var/log/jupyter.log"
    fi
    
    # 标记Jupyter服务已启动
    touch "$JUPYTER_SERVICES_FLAG"
    echo "✅ Jupyter服务启动完成"
}

# Jupyter服务健康检查
check_jupyter_services() {
    if ! pgrep -f "jupyter-lab" > /dev/null; then
        echo "🔄 重启Jupyter Lab..."
        nohup jupyter lab --ip=0.0.0.0 --port=8888 --no-browser --allow-root \
            --ServerApp.token='' --ServerApp.password='' \
            --ServerApp.allow_origin='*' --ServerApp.disable_check_xsrf=True \
            --notebook-dir=/app > /var/log/jupyter.log 2>&1 &
    fi
}

# 导出函数供其他脚本使用
export -f start_jupyter_services
export -f check_jupyter_services