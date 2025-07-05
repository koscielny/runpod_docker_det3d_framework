#!/bin/bash

# 修复PyTorch CUDA版本问题

echo "🔧 Fixing PyTorch CUDA Version Issues"
echo "===================================="

TOPOMLP_YAML="/home/ian/dev/src/online_mapping/TopoMLP/topomlp.yaml"

if [ ! -f "$TOPOMLP_YAML" ]; then
    echo "❌ Error: $TOPOMLP_YAML not found"
    exit 1
fi

echo "📋 Fixing PyTorch CUDA versions in topomlp.yaml..."

# 修复PyTorch相关的CUDA版本
sed -i 's/torch==1.9.1+cu111/torch==1.9.1/g' "$TOPOMLP_YAML"
sed -i 's/torchvision==0.10.1+cu111/torchvision==0.10.1/g' "$TOPOMLP_YAML"

echo "✅ PyTorch CUDA versions fixed"

# 验证修复
echo "📋 Verification:"
if grep -q "torch==1.9.1+cu111\|torchvision==0.10.1+cu111" "$TOPOMLP_YAML"; then
    echo "❌ CUDA versions still present"
    grep -n "torch.*+cu111\|torchvision.*+cu111" "$TOPOMLP_YAML"
else
    echo "✅ No CUDA-specific versions found"
fi

# 显示当前PyTorch相关行
echo ""
echo "📋 Current PyTorch entries:"
grep -n "torch\|pytorch" "$TOPOMLP_YAML"

echo ""
echo "🎯 Summary of changes:"
echo "  torch==1.9.1+cu111 → torch==1.9.1"
echo "  torchvision==0.10.1+cu111 → torchvision==0.10.1"
echo ""
echo "🚀 Now you can try: ./create_minimal_topomlp_env.sh"