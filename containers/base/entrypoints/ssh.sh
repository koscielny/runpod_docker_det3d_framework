#!/bin/bash

# SSH基础服务启动脚本
# 专门负责SSH服务的配置和启动

set -e

# SSH服务启动标志
SSH_SERVICES_FLAG="/tmp/.ssh_services_started"

start_ssh_service() {
    if [ -f "$SSH_SERVICES_FLAG" ]; then
        echo "✅ SSH服务已启动，跳过初始化"
        return 0
    fi

    echo "🚀 启动SSH基础服务..."
    
    # 内存优化设置
    echo "💾 配置内存优化..."
    export PYTHONDONTWRITEBYTECODE=1
    export PYTHONUNBUFFERED=1
    export MALLOC_TRIM_THRESHOLD_=10000
    
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
        return 1
    fi
    
    # 标记SSH服务已启动
    touch "$SSH_SERVICES_FLAG"
    echo "✅ SSH服务启动完成"
}

# SSH服务健康检查
check_ssh_service() {
    if ! service ssh status >/dev/null 2>&1; then
        echo "⚠️  $(date): SSH服务异常，重新启动..."
        service ssh start >/dev/null 2>&1
    fi
}

# 导出函数供其他脚本使用
export -f start_ssh_service
export -f check_ssh_service