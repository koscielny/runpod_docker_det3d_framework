#!/bin/bash

# 基础服务启动脚本 - 只负责SSH和基础服务
# 被上层entrypoint调用，不直接作为ENTRYPOINT使用

set -e

# 基础服务启动标志
BASE_SERVICES_FLAG="/tmp/.base_services_started"

start_base_services() {
    if [ -f "$BASE_SERVICES_FLAG" ]; then
        echo "✅ 基础服务已启动，跳过初始化"
        return 0
    fi

    echo "🚀 启动基础服务..."
    
    # 内存优化设置
    echo "💾 配置内存优化..."
    export PYTHONDONTWRITEBYTECODE=1
    export PYTHONUNBUFFERED=1
    export MALLOC_TRIM_THRESHOLD_=10000
    
    # 设置时区
    export TZ=${TZ:-UTC}
    
    # 生成SSH密钥
    if [ ! -f /etc/ssh/ssh_host_rsa_key ]; then
        echo "📋 生成SSH主机密钥..."
        ssh-keygen -A >/dev/null 2>&1
    fi
    
    # 创建SSH目录
    mkdir -p /root/.ssh
    chmod 700 /root/.ssh
    
    # SSH公钥配置
    if [ -n "$PUBLIC_KEY" ]; then
        echo "📋 配置SSH公钥..."
        echo "$PUBLIC_KEY" > /root/.ssh/authorized_keys
        chmod 600 /root/.ssh/authorized_keys
        echo "✅ SSH公钥已配置"
    fi
    
    # 启动SSH服务
    echo "📋 启动SSH服务..."
    service ssh start >/dev/null 2>&1
    
    if service ssh status >/dev/null 2>&1; then
        echo "✅ SSH服务运行中 (端口22)"
    else
        echo "❌ SSH服务启动失败"
    fi
    
    # 标记基础服务已启动
    touch "$BASE_SERVICES_FLAG"
    echo "✅ 基础服务启动完成"
}

# 基础服务健康检查
check_base_services() {
    if ! service ssh status >/dev/null 2>&1; then
        echo "🔄 重启SSH服务..."
        service ssh start >/dev/null 2>&1
    fi
}

# 导出函数供其他脚本使用
export -f start_base_services
export -f check_base_services