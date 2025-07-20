#!/bin/bash

# EntryPoint通用工具函数
# 提供各种通用的实用函数

set -e

# 颜色输出函数
print_header() {
    echo ""
    echo "🐳 =================================================="
    echo "🐳 $1"
    echo "🐳 =================================================="
    echo ""
}

print_step() {
    echo "📋 $1"
}

print_success() {
    echo "✅ $1"
}

print_error() {
    echo "❌ $1"
}

print_warning() {
    echo "⚠️  $1"
}

# 系统信息显示
show_system_info() {
    echo "🎯 容器信息:"
    echo "   主机: $(whoami)@$(hostname)"
    echo "   目录: $(pwd)"
    echo "   时间: $(date)"
    echo "   Python: $(python --version 2>&1)"
    
    # PyTorch信息
    if python -c "import torch" 2>/dev/null; then
        echo "   PyTorch: $(python -c 'import torch; print(torch.__version__)' 2>/dev/null)"
        echo "   CUDA: $(python -c 'import torch; print("可用" if torch.cuda.is_available() else "不可用")' 2>/dev/null)"
        
        # GPU信息
        if python -c "import torch; torch.cuda.is_available()" 2>/dev/null; then
            echo "   GPU数量: $(python -c 'import torch; print(torch.cuda.device_count())' 2>/dev/null)"
        fi
    fi
}

# 内存状态检查
show_memory_info() {
    echo "💾 内存状态:"
    if [ -f /app/tools/memory_optimizer.py ]; then
        python /app/tools/memory_optimizer.py --report | grep -E "(系统内存|状态评估)" || true
    else
        # 简单内存检查
        MEMORY_INFO=$(free -h | awk 'NR==2{printf "使用率%.1f%%, 已用%s, 可用%s", $3/$2*100, $3, $7}')
        echo "   系统内存: $MEMORY_INFO"
    fi
}

# 依赖检查
run_dependency_check() {
    echo "🔍 运行依赖检查..."
    
    if [ -f /app/scripts/utils/quick_dependency_check.sh ]; then
        /app/scripts/utils/quick_dependency_check.sh || print_warning "依赖检查发现问题，请查看上方输出"
    elif [ -f /app/tools/dependency_checker.py ]; then
        python /app/tools/dependency_checker.py --quick || print_warning "依赖检查发现问题，建议运行: python /app/tools/dependency_checker.py"
    else
        # 基础检查
        echo "   正在进行基础依赖检查..."
        if python -c "import torch, numpy" 2>/dev/null; then
            print_success "核心依赖正常"
        else
            print_error "核心依赖缺失 (torch, numpy)"
        fi
    fi
}

# 显示访问信息
show_access_info() {
    echo ""
    echo "💡 容器服务访问信息:"
    echo "   📡 SSH: root@容器IP:22"
    
    # 检查Jupyter服务
    if pgrep -f "jupyter-lab" > /dev/null; then
        echo "   📓 Jupyter Lab: http://容器IP:8888 (无密码)"
    fi
    
    # 检查其他服务
    if [ -f /app/runpod_platform.sh ]; then
        echo "   🚀 模型服务: 使用 /app/runpod_platform.sh"
    fi
    
    # 显示端口信息
    echo "   🔌 开放端口: 22 (SSH)"
    if pgrep -f "jupyter-lab" > /dev/null; then
        echo "                8888 (Jupyter Lab)"
    fi
    
    echo ""
}

# 等待服务启动
wait_for_service() {
    local service_name="$1"
    local check_command="$2"
    local max_wait="${3:-30}"
    local wait_time=0
    
    echo "⏳ 等待 $service_name 启动..."
    
    while [ $wait_time -lt $max_wait ]; do
        if eval "$check_command" >/dev/null 2>&1; then
            print_success "$service_name 已启动"
            return 0
        fi
        
        sleep 1
        wait_time=$((wait_time + 1))
        
        if [ $((wait_time % 5)) -eq 0 ]; then
            echo "   等待中... (${wait_time}s/${max_wait}s)"
        fi
    done
    
    print_error "$service_name 启动超时"
    return 1
}

# 检查端口占用
check_port() {
    local port="$1"
    if netstat -tuln 2>/dev/null | grep -q ":$port "; then
        return 0
    else
        return 1
    fi
}

# 获取容器IP地址
get_container_ip() {
    # 尝试多种方法获取IP
    local ip=""
    
    # 方法1: hostname -I
    ip=$(hostname -I 2>/dev/null | awk '{print $1}')
    if [ -n "$ip" ]; then
        echo "$ip"
        return 0
    fi
    
    # 方法2: ip route
    ip=$(ip route get 1 2>/dev/null | awk '{print $7; exit}')
    if [ -n "$ip" ]; then
        echo "$ip"
        return 0
    fi
    
    # 方法3: 默认值
    echo "localhost"
}

# 创建快捷方式
create_aliases() {
    local alias_file="/root/.bash_aliases"
    
    echo "📋 创建便捷别名..."
    
    cat > "$alias_file" << 'EOF'
# Container便捷别名
alias ll='ls -la'
alias la='ls -A'
alias l='ls -CF'
alias ..='cd ..'
alias ...='cd ../..'

# 服务管理
alias jlab='jupyter lab list'
alias jlog='tail -f /var/log/jupyter.log'
alias sshlog='tail -f /var/log/auth.log'

# 系统信息
alias sysinfo='echo "=== 系统信息 ==="; free -h; echo; df -h; echo; ps aux --sort=-%cpu | head -10'
alias gpuinfo='nvidia-smi 2>/dev/null || echo "GPU信息不可用"'

# 快速目录跳转
alias app='cd /app'
alias data='cd /app/data'
alias logs='cd /var/log'
EOF

    # 立即生效
    source "$alias_file" 2>/dev/null || true
    print_success "便捷别名已创建"
}

# 导出所有函数
export -f print_header print_step print_success print_error print_warning
export -f show_system_info show_memory_info run_dependency_check show_access_info
export -f wait_for_service check_port get_container_ip create_aliases