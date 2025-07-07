#!/bin/bash

# 测试所有模型的推理接口
# 用于验证Docker容器内模型是否正常工作

set -e

echo "🧪 测试所有模型的推理接口"
echo "=" * 50

# 创建必要的目录
mkdir -p /tmp/test_input /tmp/test_output

# 准备测试输入文件
echo "sample_token_test_001" > /tmp/test_input/sample.txt

# 测试结果统计
TOTAL_MODELS=0
SUCCESS_MODELS=0
FAILED_MODELS=()

# 测试函数
test_model() {
    local model_name=$1
    local script_path=$2
    local config_path=$3
    local checkpoint_path=$4
    local work_dir=$5
    
    TOTAL_MODELS=$((TOTAL_MODELS + 1))
    
    echo ""
    echo "🔍 测试 $model_name"
    echo "-" * 30
    
    # 检查脚本是否存在
    if [ ! -f "$script_path" ]; then
        echo "❌ 推理脚本不存在: $script_path"
        FAILED_MODELS+=("$model_name: 脚本不存在")
        return 1
    fi
    
    # 检查配置文件是否存在
    if [ ! -f "$config_path" ]; then
        echo "⚠️  配置文件不存在: $config_path"
        echo "   创建模拟配置文件..."
        mkdir -p $(dirname "$config_path")
        echo "# Mock config for testing" > "$config_path"
    fi
    
    # 设置输出文件
    local output_file="/tmp/test_output/${model_name,,}_test_result.json"
    
    echo "📝 运行推理测试..."
    echo "   脚本: $script_path"
    echo "   配置: $config_path"
    echo "   输出: $output_file"
    
    # 切换工作目录
    cd "$work_dir" 2>/dev/null || {
        echo "❌ 无法切换到工作目录: $work_dir"
        FAILED_MODELS+=("$model_name: 工作目录不存在")
        return 1
    }
    
    # 运行推理（添加超时保护）
    local start_time=$(date +%s)
    
    timeout 30s python "$script_path" \
        --config "$config_path" \
        --model-path "$checkpoint_path" \
        --input /tmp/test_input/sample.txt \
        --output "$output_file" \
        --dataroot /app/data/nuscenes 2>&1 | head -20
    
    local exit_code=$?
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    echo "   耗时: ${duration}秒"
    
    # 检查结果
    if [ $exit_code -eq 0 ]; then
        if [ -f "$output_file" ]; then
            echo "✅ $model_name 测试成功"
            echo "   输出文件大小: $(du -h "$output_file" | cut -f1)"
            SUCCESS_MODELS=$((SUCCESS_MODELS + 1))
            return 0
        else
            echo "⚠️  $model_name 运行完成但未生成输出文件"
            FAILED_MODELS+=("$model_name: 无输出文件")
            return 1
        fi
    elif [ $exit_code -eq 124 ]; then
        echo "⏰ $model_name 测试超时 (30秒)"
        FAILED_MODELS+=("$model_name: 超时")
        return 1
    else
        echo "❌ $model_name 测试失败 (退出码: $exit_code)"
        FAILED_MODELS+=("$model_name: 运行失败")
        return 1
    fi
}

# 测试所有模型
echo "开始测试所有模型接口..."

# MapTR
test_model "MapTR" \
    "/app/MapTR/inference.py" \
    "/app/MapTR/projects/configs/maptr/maptr_nusc_r50_24e.py" \
    "/app/models/maptr_nusc_r50_24e.pth" \
    "/app/MapTR"

# PETR
test_model "PETR" \
    "/app/PETR/inference.py" \
    "/app/PETR/projects/configs/petr/petr_r50dcn_gridmask_p4.py" \
    "/app/models/petr_r50dcn_gridmask_p4.pth" \
    "/app/PETR"

# StreamPETR
test_model "StreamPETR" \
    "/app/StreamPETR/inference.py" \
    "/app/StreamPETR/projects/configs/streampetr/streampetr_r50_flash_704_bs2_seq_24e.py" \
    "/app/models/streampetr_r50_flash_704_bs2_seq_24e.pth" \
    "/app/StreamPETR"

# TopoMLP
test_model "TopoMLP" \
    "/app/TopoMLP/inference.py" \
    "/app/TopoMLP/config/topomlp.yaml" \
    "/app/models/topomlp_model.pth" \
    "/app/TopoMLP"

# VAD
test_model "VAD" \
    "/app/VAD/inference.py" \
    "/app/VAD/projects/configs/VAD/VAD_base.py" \
    "/app/models/VAD_base.pth" \
    "/app/VAD"

# 生成测试报告
echo ""
echo "📊 测试完成报告"
echo "=" * 50
echo "总模型数: $TOTAL_MODELS"
echo "成功模型数: $SUCCESS_MODELS"
echo "失败模型数: $((TOTAL_MODELS - SUCCESS_MODELS))"

if [ ${#FAILED_MODELS[@]} -gt 0 ]; then
    echo ""
    echo "❌ 失败的模型:"
    for failure in "${FAILED_MODELS[@]}"; do
        echo "   - $failure"
    done
fi

echo ""
echo "📁 测试输出文件:"
if [ -d "/tmp/test_output" ]; then
    ls -la /tmp/test_output/
else
    echo "   无输出文件"
fi

# 清理测试文件
echo ""
echo "🧹 清理测试文件..."
rm -rf /tmp/test_input /tmp/test_output

# 设置退出码
if [ $SUCCESS_MODELS -eq $TOTAL_MODELS ]; then
    echo "✅ 所有模型测试通过"
    exit 0
else
    echo "⚠️  部分模型测试失败"
    exit 1
fi