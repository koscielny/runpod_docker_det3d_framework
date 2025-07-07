#!/bin/bash

# RunPod容器入口点脚本 - 优化版本
# 处理SSH设置和服务启动，减少重复日志

set -e

# 检查是否是第一次启动
FIRST_RUN_FLAG="/tmp/.container_first_run"

if [ ! -f "$FIRST_RUN_FLAG" ]; then
    echo "🚀 初始化RunPod容器..."
    
    # 设置时区
    export TZ=${TZ:-UTC}
    
    # 生成SSH密钥（如果不存在）
    if [ ! -f /etc/ssh/ssh_host_rsa_key ]; then
        echo "📋 生成SSH主机密钥..."
        ssh-keygen -A >/dev/null 2>&1
    fi
    
    # 创建SSH目录
    mkdir -p /root/.ssh
    chmod 700 /root/.ssh
    
    # 从RunPod环境变量设置SSH公钥
    if [ -n "$PUBLIC_KEY" ]; then
        echo "📋 配置SSH公钥..."
        echo "$PUBLIC_KEY" > /root/.ssh/authorized_keys
        chmod 600 /root/.ssh/authorized_keys
        echo "✅ SSH公钥已配置"
    fi
    
    # 启动SSH服务
    echo "📋 启动SSH服务..."
    service ssh start >/dev/null 2>&1
    
    # 验证SSH状态
    if service ssh status >/dev/null 2>&1; then
        echo "✅ SSH服务运行中 (端口22, 用户root)"
    else
        echo "❌ SSH服务启动失败"
    fi
    
    # 启动Jupyter Lab
    echo "📋 启动Jupyter Lab..."
    nohup jupyter lab --ip=0.0.0.0 --port=8888 --no-browser --allow-root \
        --token='' --password='' --NotebookApp.allow_origin='*' \
        --NotebookApp.disable_check_xsrf=True --notebook-dir=/app > /var/log/jupyter.log 2>&1 &
    
    # 等待Jupyter启动
    sleep 3
    if pgrep -f "jupyter-lab" > /dev/null; then
        echo "✅ Jupyter Lab运行中 (端口8888, 无密码访问)"
    else
        echo "❌ Jupyter Lab启动失败"
    fi
    
    # 显示容器信息
    echo "🎯 容器就绪: $(whoami)@$(hostname) - $(pwd)"
    echo "   Python: $(python --version 2>&1) | PyTorch: $(python -c 'import torch; print(torch.__version__)' 2>/dev/null || echo 'N/A') | CUDA: $(python -c 'import torch; print(torch.cuda.is_available())' 2>/dev/null || echo 'N/A')"
    
    # 标记已完成初始化
    touch "$FIRST_RUN_FLAG"
else
    # 非首次运行，只做必要检查
    if ! service ssh status >/dev/null 2>&1; then
        echo "🔄 重启SSH服务..."
        service ssh start >/dev/null 2>&1
    fi
    
    # 检查Jupyter Lab是否运行
    if ! pgrep -f "jupyter-lab" > /dev/null; then
        echo "🔄 重启Jupyter Lab..."
        nohup jupyter lab --ip=0.0.0.0 --port=8888 --no-browser --allow-root \
            --token='' --password='' --NotebookApp.allow_origin='*' \
            --NotebookApp.disable_check_xsrf=True --notebook-dir=/app > /var/log/jupyter.log 2>&1 &
    fi
fi

# 如果有参数，执行指定命令
if [ $# -gt 0 ]; then
    exec "$@"
else
    # 默认保持容器运行
    echo "💡 容器运行中，可通过以下方式访问:"
    echo "   📡 SSH: root@容器IP:22"
    echo "   📓 Jupyter Lab: http://容器IP:8888 (无密码)"
    
    # 保持容器运行的守护进程
    while true; do
        sleep 30
        # 检查SSH服务
        if ! service ssh status >/dev/null 2>&1; then
            echo "⚠️  $(date): SSH服务异常，重新启动..."
            service ssh start >/dev/null 2>&1
        fi
        # 检查Jupyter Lab服务
        if ! pgrep -f "jupyter-lab" > /dev/null; then
            echo "⚠️  $(date): Jupyter Lab异常，重新启动..."
            nohup jupyter lab --ip=0.0.0.0 --port=8888 --no-browser --allow-root \
                --token='' --password='' --NotebookApp.allow_origin='*' \
                --NotebookApp.disable_check_xsrf=True --notebook-dir=/app > /var/log/jupyter.log 2>&1 &
        fi
    done
fi