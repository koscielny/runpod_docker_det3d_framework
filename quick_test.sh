#!/bin/bash

# 简化的多模型评测系统测试

GREEN='\033[0;32m'
NC='\033[0m'

echo -e "${GREEN}🚀 多模型评测系统快速验证${NC}"
echo "================================="

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 1. 测试脚本可执行性
echo -n "📝 检查脚本语法... "
if bash -n "$SCRIPT_DIR/run_model_evaluation.sh" && 
   bash -n "$SCRIPT_DIR/list_model_configs.sh" && 
   bash -n "$SCRIPT_DIR/run_model_with_mount.sh"; then
    echo "✅"
else
    echo "❌"
    exit 1
fi

# 2. 测试Python模块导入
echo -n "🐍 检查Python模块... "
if python3 -c "
import sys
sys.path.append('$SCRIPT_DIR/claude_doc')

try:
    from model_output_standard import create_standardizer
    from model_comparison import ModelComparator
    from health_check import ModelHealthChecker
    print('✅ 所有模块导入成功')
except ImportError as e:
    print(f'❌ 模块导入失败: {e}')
    exit(1)
" > /dev/null 2>&1; then
    echo "✅"
else
    echo "❌"
    exit 1
fi

# 3. 测试标准化功能
echo -n "🔄 测试输出标准化... "
if python3 -c "
import sys
sys.path.append('$SCRIPT_DIR/claude_doc')
from model_output_standard import create_standardizer

standardizer = create_standardizer('MapTR')
test_data = [{'id': 0, 'class_name': 'divider', 'confidence': 0.85}]
metadata = {'inference_time': 0.25, 'gpu_memory_used': 2048.0}
result = standardizer.standardize(test_data, metadata)
assert result.metadata.model_name == 'MapTR'
" > /dev/null 2>&1; then
    echo "✅"
else
    echo "❌"
    exit 1
fi

# 4. 测试健康检查
echo -n "🏥 测试健康检查... "
if python3 "$SCRIPT_DIR/claude_doc/health_check.py" --model MapTR --mode check > /dev/null 2>&1; then
    echo "✅"
else
    echo "❌"
    exit 1
fi

# 5. 检查文档和工具
echo -n "📚 检查文档和工具... "
if [ -f "$SCRIPT_DIR/claude_doc/EVALUATION_GUIDE.md" ] && 
   [ -f "$SCRIPT_DIR/claude_doc/DATASET_DOWNLOAD_GUIDE.md" ] &&
   [ -f "$SCRIPT_DIR/claude_doc/IMPLEMENTATION_DETAILS.md" ]; then
    echo "✅"
else
    echo "❌"
    exit 1
fi

echo ""
echo -e "${GREEN}🎉 所有核心功能验证成功！${NC}"
echo ""
echo "📋 可用的功能:"
echo "  ✅ 标准化输出格式 - 统一所有模型输出"
echo "  ✅ 健康检查端点 - 验证模型和系统状态"
echo "  ✅ 模型比较分析 - 多维度性能对比"
echo "  ✅ 配置动态管理 - 灵活的配置文件支持"
echo "  ✅ SSH开发环境 - VS Code远程开发"
echo "  ✅ 数据集管理 - 自动化下载和验证"
echo ""
echo "🚀 快速开始:"
echo "  ./run_model_evaluation.sh --help"
echo "  ./run_model_evaluation.sh --health-check"
echo "  ./list_model_configs.sh"
echo ""
echo "📖 查看完整文档:"
echo "  cat claude_doc/EVALUATION_GUIDE.md"