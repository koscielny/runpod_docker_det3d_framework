#!/bin/bash

# 模型应用通用入口点
# 继承基础服务，添加模型特定的初始化

set -e

# 脚本目录路径
BASE_ENTRYPOINTS_DIR="/app/entrypoints"
SHARED_ENTRYPOINTS_DIR="/app/shared/entrypoints"

# 加载工具函数
source "$SHARED_ENTRYPOINTS_DIR/utils.sh"

# 检查并调用基础服务
call_base_services() {
    if [ -f "$BASE_ENTRYPOINTS_DIR/main.sh" ]; then
        print_step "调用基础服务启动脚本..."
        
        # 加载基础服务模块，但不执行主函数
        source "$BASE_ENTRYPOINTS_DIR/ssh.sh"
        
        # 动态加载Jupyter服务（如果可用）
        if [ -f "$BASE_ENTRYPOINTS_DIR/jupyter.sh" ] && command -v jupyter >/dev/null 2>&1; then
            source "$BASE_ENTRYPOINTS_DIR/jupyter.sh"
            ENABLE_JUPYTER=true
        else
            ENABLE_JUPYTER=false
        fi
        
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
        
        print_success "基础服务启动完成"
    else
        print_warning "未找到基础服务脚本，跳过基础服务启动"
    fi
}

# 模型特定初始化
model_specific_init() {
    print_step "模型应用初始化..."
    
    # 检查模型目录
    if [ -d "/app/VAD" ]; then
        echo "   检测到VAD模型目录"
        cd /app/VAD
    elif [ -d "/app/MapTR" ]; then
        echo "   检测到MapTR模型目录"
        cd /app/MapTR
    elif [ -d "/app/PETR" ]; then
        echo "   检测到PETR模型目录"
        cd /app/PETR
    elif [ -d "/app/StreamPETR" ]; then
        echo "   检测到StreamPETR模型目录"
        cd /app/StreamPETR
    elif [ -d "/app/TopoMLP" ]; then
        echo "   检测到TopoMLP模型目录"
        cd /app/TopoMLP
    else
        echo "   使用通用应用目录: /app"
        cd /app
    fi
    
    # 检查推理脚本
    if [ -f "inference.py" ]; then
        echo "   发现推理脚本: inference.py"
    fi
    
    # 检查数据目录
    if [ -d "data" ] || [ -d "/app/data" ]; then
        echo "   数据目录可用"
    fi
    
    # 运行模型特定的依赖检查
    model_dependency_check
    
    print_success "模型应用初始化完成"
}

# 模型依赖检查
model_dependency_check() {
    echo "🔍 模型依赖检查..."
    
    # 检查GPU可用性
    if python -c "import torch; torch.cuda.is_available()" 2>/dev/null; then
        gpu_count=$(python -c "import torch; print(torch.cuda.device_count())" 2>/dev/null)
        print_success "GPU可用 (${gpu_count}个设备)"
    else
        print_warning "GPU不可用或CUDA未正确配置"
    fi
    
    # 检查常用深度学习库
    local missing_deps=()
    
    for lib in torch torchvision numpy opencv-python; do
        if ! python -c "import ${lib}" 2>/dev/null; then
            missing_deps+=("$lib")
        fi
    done
    
    if [ ${#missing_deps[@]} -eq 0 ]; then
        print_success "核心深度学习库检查通过"
    else
        print_warning "缺少依赖: ${missing_deps[*]}"
    fi
    
    # 检查MM系列库（如果适用）
    if python -c "import mmcv" 2>/dev/null; then
        print_success "MMDetection生态系统可用"
        echo "   MMCV: $(python -c 'import mmcv; print(mmcv.__version__)' 2>/dev/null)"
        
        for mm_lib in mmdet mmseg mmdet3d; do
            if python -c "import ${mm_lib}" 2>/dev/null; then
                version=$(python -c "import ${mm_lib}; print(${mm_lib}.__version__)" 2>/dev/null)
                echo "   ${mm_lib}: ${version}"
            fi
        done
    fi
}

# 显示模型应用信息
show_model_info() {
    print_header "模型应用容器就绪"
    
    # 显示当前目录和可用文件
    echo "📁 当前目录: $(pwd)"
    
    if [ -f "inference.py" ]; then
        echo "🚀 运行推理: python inference.py"
    fi
    
    if [ -f "/app/runpod_platform.sh" ]; then
        echo "🚀 平台脚本: /app/runpod_platform.sh"
    fi
    
    # 显示可用的数据集工具
    if [ -d "/app/datasets" ]; then
        echo "📊 数据集工具: ls /app/datasets/"
    fi
    
    # 显示可视化工具
    if [ -d "/app/datasets/visualization" ]; then
        echo "📈 可视化工具: ls /app/datasets/visualization/scripts/"
    fi
    
    echo ""
    echo "💡 使用提示:"
    echo "   - 查看别名: alias"
    echo "   - 系统信息: sysinfo"
    echo "   - GPU信息: gpuinfo"
    echo "   - Jupyter日志: jlog"
    echo ""
}

# 健康检查守护进程（增强版）
enhanced_health_check() {
    print_step "启动增强服务监控..."
    
    while true; do
        sleep 30
        
        # 调用基础服务的健康检查
        if declare -f check_ssh_service >/dev/null; then
            check_ssh_service
        fi
        
        if declare -f check_jupyter_service >/dev/null; then
            check_jupyter_service
        fi
        
        # 额外的GPU监控（如果可用）
        if command -v nvidia-smi >/dev/null 2>&1; then
            if ! nvidia-smi >/dev/null 2>&1; then
                print_warning "GPU状态异常，请检查NVIDIA驱动"
            fi
        fi
        
        # 内存使用监控
        local memory_usage=$(free | awk 'NR==2{printf "%.0f", $3/$2*100}')
        if [ "$memory_usage" -gt 90 ]; then
            print_warning "内存使用率过高: ${memory_usage}%"
        fi
    done
}

# 主函数
main() {
    # 调用基础服务
    call_base_services
    
    # 模型特定初始化
    model_specific_init
    
    # 显示模型应用信息
    show_model_info
    
    # 如果有参数，执行指定命令
    if [ $# -gt 0 ]; then
        print_step "执行指定命令: $*"
        exec "$@"
    else
        # 启动增强的健康检查守护进程
        enhanced_health_check
    fi
}

# 运行主函数
main "$@"