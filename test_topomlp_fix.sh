#!/bin/bash

# 测试TopoMLP环境文件修复

echo "🧪 Testing TopoMLP Environment File Fixes"
echo "========================================"

TOPOMLP_YAML="/home/ian/dev/src/online_mapping/TopoMLP/topomlp.yaml"

# 检查1: Python版本
echo "📋 Test 1: Python Version"
if grep -q "python=3.9" "$TOPOMLP_YAML"; then
    echo "✅ Python version upgraded to 3.9"
else
    echo "❌ Python version not updated"
fi

# 检查2: OR-Tools版本修复
echo ""
echo "📋 Test 2: OR-Tools Version Fix"
if grep -q "ortools>=9.0,<10.0" "$TOPOMLP_YAML"; then
    echo "✅ OR-Tools version fixed to use compatible range"
else
    echo "❌ OR-Tools version not fixed"
fi

# 检查3: 系统包移除
echo ""
echo "📋 Test 3: System Packages Removal"
if ! grep -q "_libgcc_mutex\|_openmp_mutex" "$TOPOMLP_YAML"; then
    echo "✅ System packages removed successfully"
else
    echo "❌ System packages still present"
fi

# 检查4: 依赖数量对比
echo ""
echo "📋 Test 4: Dependencies Count"
deps_count=$(grep -c "    - " "$TOPOMLP_YAML")
echo "📊 Total dependencies: $deps_count"

# 检查5: 关键包是否仍然存在
echo ""
echo "📋 Test 5: Key Packages Verification"
key_packages=("torch" "mmcv-full" "numpy" "opencv-python" "shapely" "nuscenes-devkit")

for pkg in "${key_packages[@]}"; do
    if grep -q "$pkg" "$TOPOMLP_YAML"; then
        echo "✅ $pkg: Present"
    else
        echo "❌ $pkg: Missing"
    fi
done

# 检查6: 基本格式验证
echo ""
echo "📋 Test 6: Basic Format Validation"
if [ ! -z "$(grep -E "^name:|^channels:|^dependencies:" "$TOPOMLP_YAML")" ]; then
    echo "✅ YAML basic structure looks correct"
else
    echo "❌ YAML basic structure has issues"
fi

echo ""
echo "🎯 Summary of Changes:"
echo "  ✅ Python: 3.8.16 → 3.9"
echo "  ✅ OR-Tools: 9.2.9972 → >=9.0,<10.0"
echo "  ✅ Removed system packages causing conflicts"
echo "  ✅ Simplified conda dependencies"
echo ""
echo "🚀 Ready to test with: conda env update -n mapping_models -f topomlp.yaml"