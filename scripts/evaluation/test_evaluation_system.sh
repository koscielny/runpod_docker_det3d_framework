#!/bin/bash

# 多模型评测系统快速测试脚本
# 验证整个评测和比较系统是否正常工作

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEST_DIR="$SCRIPT_DIR/test_results"

log() {
    echo -e "${GREEN}[TEST]${NC} $1"
}

info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 清理测试环境
cleanup() {
    if [ -d "$TEST_DIR" ]; then
        rm -rf "$TEST_DIR"
    fi
}

# 创建测试数据
create_test_data() {
    log "创建测试数据..."
    
    mkdir -p "$TEST_DIR/test_data"
    
    # 创建测试样本文件
    echo "sample_token_test_001" > "$TEST_DIR/test_data/sample.txt"
    
    # 创建模拟的模型输出数据
    cat > "$TEST_DIR/test_data/mock_maptr_output.json" << 'EOF'
[
    {
        "id": 0,
        "class_name": "divider",
        "class_id": 0,
        "confidence": 0.85,
        "bbox": [10.2, 15.3, 25.7, 18.9],
        "pts": [[10.5, 16.0], [11.2, 16.1], [12.0, 16.2]],
        "num_pts": 20
    },
    {
        "id": 1,
        "class_name": "car",
        "class_id": 1,
        "confidence": 0.92,
        "bbox": [20.1, 30.2, 35.5, 45.8],
        "pts": [],
        "num_pts": 0
    }
]
EOF

    cat > "$TEST_DIR/test_data/mock_petr_output.json" << 'EOF'
{
    "pts_bbox": {
        "boxes_3d": [[0, 0, 0, 2, 3, 1, 0.1], [5, 5, 0, 2, 3, 1, 0.2]],
        "scores_3d": [0.88, 0.75],
        "labels_3d": [0, 1]
    }
}
EOF

    info "测试数据创建完成"
}

# 测试输出标准化
test_output_standardization() {
    log "测试输出标准化功能..."
    
    cd "$SCRIPT_DIR"
    
    # 测试MapTR标准化
    python3 -c "
import sys
sys.path.append('$SCRIPT_DIR/../tools')
from model_output_standard import create_standardizer
import json

# 加载测试数据
with open('$TEST_DIR/test_data/mock_maptr_output.json') as f:
    maptr_data = json.load(f)

metadata = {
    'model_version': 'test_v1.0',
    'config_file': 'test_config.py',
    'checkpoint_file': 'test_model.pth',
    'inference_time': 0.25,
    'gpu_memory_used': 2048.0
}

# 标准化
standardizer = create_standardizer('MapTR')
result = standardizer.standardize(maptr_data, metadata)

# 验证结果
assert result.metadata.model_name == 'MAPTR'
assert result.map_elements is not None
assert len(result.map_elements) == 1  # 只有一个divider
assert result.detections_3d is not None
assert len(result.detections_3d) == 1  # 只有一个car

# 保存结果
with open('$TEST_DIR/maptr_standardized.json', 'w') as f:
    f.write(result.to_json())

print('✅ MapTR 标准化测试通过')
"

    # 测试PETR标准化
    python3 -c "
import sys
sys.path.append('$SCRIPT_DIR/../tools')
from model_output_standard import create_standardizer
import json

# 加载测试数据
with open('$TEST_DIR/test_data/mock_petr_output.json') as f:
    petr_data = json.load(f)

metadata = {
    'model_version': 'test_v1.0',
    'config_file': 'test_config.py',
    'checkpoint_file': 'test_model.pth',
    'inference_time': 0.18,
    'gpu_memory_used': 1800.0
}

# 标准化
standardizer = create_standardizer('PETR')
result = standardizer.standardize(petr_data, metadata)

# 验证结果
assert result.metadata.model_name == 'PETR'
assert result.detections_3d is not None
assert len(result.detections_3d) == 2  # 两个检测目标

# 保存结果
with open('$TEST_DIR/petr_standardized.json', 'w') as f:
    f.write(result.to_json())

print('✅ PETR 标准化测试通过')
"

    info "输出标准化测试完成"
}

# 测试模型比较
test_model_comparison() {
    log "测试模型比较功能..."
    
    python3 -c "
import sys
sys.path.append('$SCRIPT_DIR/../tools')
from model_comparison import ModelComparator
from model_output_standard import StandardOutput, ModelMetadata, Detection3D, VectorElement, BoundingBox3D
import json

# 创建比较器
comparator = ModelComparator('$TEST_DIR/comparison_test')

# 创建模拟的标准化结果
maptr_metadata = ModelMetadata(
    model_name='MapTR',
    model_version='test_v1.0',
    config_file='test_config.py',
    checkpoint_file='test_model.pth',
    inference_time=0.25,
    gpu_memory_used=2048.0,
    timestamp='2024-01-01T00:00:00'
)

petr_metadata = ModelMetadata(
    model_name='PETR',
    model_version='test_v1.0',
    config_file='test_config.py',
    checkpoint_file='test_model.pth',
    inference_time=0.18,
    gpu_memory_used=1800.0,
    timestamp='2024-01-01T00:00:00'
)

# 创建检测结果
maptr_detections = [Detection3D(
    id=0,
    class_name='car',
    class_id=0,
    bbox_3d=BoundingBox3D([0, 0, 0], [2, 3, 1], [0, 0, 0.1], 0.92),
    confidence=0.92,
    attributes={}
)]

maptr_map_elements = [VectorElement(
    id=0,
    type='divider',
    points=[[10.5, 16.0], [11.2, 16.1]],
    confidence=0.85,
    attributes={}
)]

petr_detections = [
    Detection3D(
        id=0,
        class_name='car',
        class_id=0,
        bbox_3d=BoundingBox3D([0, 0, 0], [2, 3, 1], [0, 0, 0.1], 0.88),
        confidence=0.88,
        attributes={}
    ),
    Detection3D(
        id=1,
        class_name='truck',
        class_id=1,
        bbox_3d=BoundingBox3D([5, 5, 0], [2, 3, 1], [0, 0, 0.2], 0.75),
        confidence=0.75,
        attributes={}
    )
]

# 创建标准化输出
maptr_result = StandardOutput(
    metadata=maptr_metadata,
    detections_3d=maptr_detections,
    map_elements=maptr_map_elements
)

petr_result = StandardOutput(
    metadata=petr_metadata,
    detections_3d=petr_detections
)

# 添加到比较器
comparator.add_result(maptr_result)
comparator.add_result(petr_result)

# 生成比较报告
report = comparator.generate_comparison_report()

# 验证结果
assert report['summary']['total_models'] == 2
assert report['summary']['successful_models'] == 2
assert 'performance_ranking' in report
assert 'fastest_inference' in report['performance_ranking']

# 保存结果
comparator.save_results()

print('✅ 模型比较测试通过')
print(f'比较了 {report[\"summary\"][\"total_models\"]} 个模型')
"

    info "模型比较测试完成"
}

# 测试健康检查
test_health_check() {
    log "测试健康检查功能..."
    
    # 测试基础健康检查
    python3 "$SCRIPT_DIR/../tools/health_check.py" --model MapTR --mode check > "$TEST_DIR/health_test.json"
    
    # 验证输出
    if [ -f "$TEST_DIR/health_test.json" ]; then
        python3 -c "
import json
with open('$TEST_DIR/health_test.json') as f:
    health = json.load(f)

# 验证基本字段存在
assert 'timestamp' in health
assert 'system' in health
assert 'gpu' in health
assert 'status' in health

print('✅ 健康检查测试通过')
print(f'系统状态: {health[\"status\"]}')
"
    else
        error "健康检查输出文件未生成"
        return 1
    fi
    
    info "健康检查测试完成"
}

# 测试配置管理
test_config_management() {
    log "测试配置管理功能..."
    
    # 测试配置列表
    if [ -f "$SCRIPT_DIR/list_model_configs.sh" ]; then
        bash "$SCRIPT_DIR/list_model_configs.sh" > "$TEST_DIR/config_list_test.txt"
        
        if grep -q "MapTR" "$TEST_DIR/config_list_test.txt"; then
            info "✅ 配置列表测试通过"
        else
            warn "配置列表可能不完整"
        fi
    else
        warn "配置列表脚本不存在"
    fi
    
    # 测试脚本语法
    if bash -n "$SCRIPT_DIR/run_model_with_mount.sh"; then
        info "✅ 运行脚本语法检查通过"
    else
        error "运行脚本语法错误"
        return 1
    fi
    
    info "配置管理测试完成"
}

# 主测试函数
run_tests() {
    log "🚀 开始多模型评测系统测试"
    
    # 清理和准备
    cleanup
    mkdir -p "$TEST_DIR"
    
    # 运行各项测试
    create_test_data
    test_output_standardization
    test_model_comparison
    test_health_check
    test_config_management
    
    log "🎉 所有测试完成！"
    
    # 显示测试结果摘要
    echo ""
    echo "📊 测试结果摘要:"
    echo "  ✅ 输出标准化功能正常"
    echo "  ✅ 模型比较功能正常"
    echo "  ✅ 健康检查功能正常"
    echo "  ✅ 配置管理功能正常"
    echo ""
    echo "📁 测试文件保存在: $TEST_DIR"
    
    # 列出生成的文件
    echo "生成的测试文件:"
    find "$TEST_DIR" -type f | head -10 | while read file; do
        echo "  $(basename "$file")"
    done
    
    echo ""
    echo "🚀 系统已准备就绪，可以开始使用多模型评测功能！"
    echo ""
    echo "快速开始命令:"
    echo "  ./run_model_evaluation.sh --health-check"
    echo "  ./run_model_evaluation.sh --help"
}

# 错误处理
trap 'error "测试过程中出现错误"; exit 1' ERR

# 运行测试
run_tests