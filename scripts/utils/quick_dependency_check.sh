#!/bin/bash

# 快速依赖检查脚本
# 用于在Docker容器首次运行时快速验证基本依赖

set -e

echo "🔍 Docker容器快速依赖检查"
echo "================================"

# 检查Python
echo "🐍 检查Python..."
if command -v python3 >/dev/null 2>&1; then
    PYTHON_VERSION=$(python3 --version)
    echo "✅ Python: $PYTHON_VERSION"
else
    echo "❌ Python3未找到"
    exit 1
fi

# 检查pip
echo "📦 检查pip..."
if python3 -m pip --version >/dev/null 2>&1; then
    PIP_VERSION=$(python3 -m pip --version | cut -d' ' -f2)
    echo "✅ pip: 版本 $PIP_VERSION"
else
    echo "❌ pip不可用"
    exit 1
fi

# 检查核心Python包
echo "🧩 检查核心包..."
CORE_PACKAGES=("torch" "numpy" "cv2" "PIL")
MISSING_PACKAGES=()

for package in "${CORE_PACKAGES[@]}"; do
    if python3 -c "import $package" >/dev/null 2>&1; then
        VERSION=$(python3 -c "import $package; print(getattr($package, '__version__', 'Unknown'))" 2>/dev/null || echo "Unknown")
        echo "✅ $package: $VERSION"
    else
        echo "❌ $package: 未安装"
        MISSING_PACKAGES+=("$package")
    fi
done

# 检查PyTorch和CUDA
echo "🎮 检查GPU支持..."
if python3 -c "import torch; print(f'PyTorch: {torch.__version__}, CUDA可用: {torch.cuda.is_available()}')" 2>/dev/null; then
    CUDA_INFO=$(python3 -c "import torch; print('✅ CUDA可用' if torch.cuda.is_available() else '⚠️ 仅CPU模式')")
    echo "$CUDA_INFO"
    
    if python3 -c "import torch; exit(0 if torch.cuda.is_available() else 1)" 2>/dev/null; then
        GPU_COUNT=$(python3 -c "import torch; print(torch.cuda.device_count())")
        GPU_NAME=$(python3 -c "import torch; print(torch.cuda.get_device_name(0) if torch.cuda.device_count() > 0 else 'Unknown')")
        echo "🎯 GPU: $GPU_COUNT个设备 - $GPU_NAME"
    fi
else
    echo "❌ PyTorch检查失败"
    MISSING_PACKAGES+=("torch")
fi

# 检查nvidia-smi
echo "🖥️  检查NVIDIA驱动..."
if command -v nvidia-smi >/dev/null 2>&1; then
    DRIVER_VERSION=$(nvidia-smi --query-gpu=driver_version --format=csv,noheader,nounits 2>/dev/null | head -1 || echo "Unknown")
    echo "✅ NVIDIA驱动: $DRIVER_VERSION"
else
    echo "⚠️ nvidia-smi不可用 (CPU模式)"
fi

# 检查关键文件
echo "📁 检查关键文件..."
KEY_FILES=(
    "/app"
    "/app/tools/health_check.py"
    "/app/tools/model_output_standard.py"
    "/app/tools/dependency_checker.py"
    "/app/runpod_platform.sh"
)

for file in "${KEY_FILES[@]}"; do
    if [ -e "$file" ]; then
        echo "✅ $file"
    else
        echo "⚠️ $file 不存在"
    fi
done

# 检查内存
echo "💾 检查系统资源..."
if command -v free >/dev/null 2>&1; then
    MEMORY_INFO=$(free -h | awk 'NR==2{printf "%s总量, %s可用 (%.1f%%使用)", $2, $7, $3/$2*100}')
    echo "✅ 内存: $MEMORY_INFO"
    
    # 检查内存使用率
    MEMORY_PCT=$(free | awk 'NR==2{printf "%.0f", $3/$2*100}')
    if [ "$MEMORY_PCT" -gt 85 ]; then
        echo "⚠️ 内存使用率较高 ($MEMORY_PCT%)"
    fi
else
    echo "⚠️ 无法检查内存状态"
fi

# 检查磁盘空间
if command -v df >/dev/null 2>&1; then
    DISK_INFO=$(df -h / | awk 'NR==2{printf "%s可用空间 (%s使用)", $4, $5}')
    echo "✅ 磁盘: $DISK_INFO"
else
    echo "⚠️ 无法检查磁盘空间"
fi

# 快速模型测试
echo "🧪 快速功能测试..."
if python3 -c "
import torch
import numpy as np
try:
    # 基础张量测试
    x = torch.randn(2, 3)
    y = torch.randn(3, 2)
    result = torch.mm(x, y)
    assert result.shape == (2, 2)
    print('✅ PyTorch张量运算正常')
    
    # NumPy测试
    arr = np.random.rand(3, 3)
    assert arr.shape == (3, 3)
    print('✅ NumPy数组运算正常')
    
    print('✅ 基础功能测试通过')
except Exception as e:
    print(f'❌ 功能测试失败: {e}')
    exit(1)
" 2>/dev/null; then
    echo "🎉 基础功能测试通过"
else
    echo "❌ 基础功能测试失败"
    exit 1
fi

# 结果汇总
echo ""
echo "📊 检查结果汇总"
echo "================================"

if [ ${#MISSING_PACKAGES[@]} -eq 0 ]; then
    echo "🎉 状态: 依赖检查通过！"
    echo "✅ 所有核心依赖都已安装"
    echo "🚀 容器可以正常运行模型"
    
    # 显示使用建议
    echo ""
    echo "💡 使用建议:"
    echo "   • 运行完整检查: python /app/tools/dependency_checker.py"
    echo "   • 内存优化: python /app/tools/memory_optimizer.py --report"
    echo "   • 健康检查: python /app/health_check.py"
    
    exit 0
else
    echo "⚠️ 状态: 发现缺失依赖"
    echo "❌ 缺失的包: ${MISSING_PACKAGES[*]}"
    echo ""
    echo "🛠️ 解决方案:"
    echo "   pip install ${MISSING_PACKAGES[*]}"
    echo ""
    echo "或运行详细检查获取更多信息:"
    echo "   python /app/tools/dependency_checker.py"
    
    exit 1
fi