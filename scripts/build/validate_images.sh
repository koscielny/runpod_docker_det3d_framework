#!/bin/bash

# 镜像验证脚本
echo "🔍 验证Docker镜像构建质量..."
echo ""

MODELS=("maptr" "petr" "streampetr")
TOTAL_TESTS=0
PASSED_TESTS=0

validate_image() {
    local model=$1
    local image_name="iankaramazov/ai-models:${model}-latest"
    
    echo "📋 验证 $model 镜像..."
    echo "镜像名: $image_name"
    
    # 测试1: 基本运行
    if docker run --rm "$image_name" echo "Container starts successfully" > /dev/null 2>&1; then
        echo "✅ 基本运行测试通过"
        ((PASSED_TESTS++))
    else
        echo "❌ 基本运行测试失败"
    fi
    ((TOTAL_TESTS++))
    
    # 测试2: Python可用性
    if docker run --rm "$image_name" python --version > /dev/null 2>&1; then
        echo "✅ Python可用性测试通过"
        ((PASSED_TESTS++))
    else
        echo "❌ Python可用性测试失败"
    fi
    ((TOTAL_TESTS++))
    
    # 测试3: PyTorch可用性
    if docker run --rm "$image_name" python -c "import torch; print(torch.__version__)" > /dev/null 2>&1; then
        echo "✅ PyTorch可用性测试通过"
        ((PASSED_TESTS++))
    else
        echo "❌ PyTorch可用性测试失败"
    fi
    ((TOTAL_TESTS++))
    
    # 测试4: 模型目录存在
    local model_upper=$(echo "$model" | tr '[:lower:]' '[:upper:]')
    if [ "$model" = "maptr" ]; then
        model_upper="MapTR"
    elif [ "$model" = "petr" ]; then
        model_upper="PETR"
    elif [ "$model" = "streampetr" ]; then
        model_upper="StreamPETR"
    fi
    
    if docker run --rm "$image_name" test -d "/app/$model_upper" > /dev/null 2>&1; then
        echo "✅ 模型目录存在测试通过"
        ((PASSED_TESTS++))
    else
        echo "❌ 模型目录存在测试失败"
    fi
    ((TOTAL_TESTS++))
    
    # 测试5: inference.py文件存在
    if docker run --rm "$image_name" test -f "/app/$model_upper/inference.py" > /dev/null 2>&1; then
        echo "✅ inference.py文件存在测试通过"
        ((PASSED_TESTS++))
    else
        echo "❌ inference.py文件存在测试失败"
    fi
    ((TOTAL_TESTS++))
    
    # 测试6: runpod用户权限
    if docker run --rm "$image_name" whoami | grep -q "runpod"; then
        echo "✅ runpod用户权限测试通过"
        ((PASSED_TESTS++))
    else
        echo "❌ runpod用户权限测试失败"
    fi
    ((TOTAL_TESTS++))
    
    # 测试7: 文件所有权
    if docker run --rm "$image_name" stat -c "%U" "/app/$model_upper" | grep -q "runpod"; then
        echo "✅ 文件所有权测试通过"
        ((PASSED_TESTS++))
    else
        echo "❌ 文件所有权测试失败"
    fi
    ((TOTAL_TESTS++))
    
    echo ""
}

# 验证所有镜像
for model in "${MODELS[@]}"; do
    validate_image "$model"
done

# 总结报告
echo "🎯 验证总结报告"
echo "=================="
echo "总测试数: $TOTAL_TESTS"
echo "通过测试: $PASSED_TESTS"
echo "失败测试: $((TOTAL_TESTS - PASSED_TESTS))"
echo "成功率: $((PASSED_TESTS * 100 / TOTAL_TESTS))%"

if [ $PASSED_TESTS -eq $TOTAL_TESTS ]; then
    echo ""
    echo "🎉 所有镜像验证通过！可以安全推送到Docker Hub。"
    exit 0
else
    echo ""
    echo "⚠️  存在验证失败的测试，请检查镜像构建。"
    exit 1
fi