#!/bin/bash

# 测试脚本：验证entrypoint文件在Docker容器中的路径
# 这个脚本可以在Docker容器内运行来验证文件是否正确复制

echo "🔍 验证EntryPoint文件路径..."
echo ""

# 检查基础entrypoints目录
echo "📁 检查基础entrypoints目录 (/app/entrypoints/):"
if [ -d "/app/entrypoints" ]; then
    echo "✅ 目录存在"
    ls -la /app/entrypoints/ || echo "❌ 无法列出文件"
else
    echo "❌ 目录不存在"
fi
echo ""

# 检查共享entrypoints目录
echo "📁 检查共享entrypoints目录 (/app/shared/entrypoints/):"
if [ -d "/app/shared/entrypoints" ]; then
    echo "✅ 目录存在"
    ls -la /app/shared/entrypoints/ || echo "❌ 无法列出文件"
else
    echo "❌ 目录不存在"
fi
echo ""

# 检查关键文件
echo "🔍 检查关键文件:"
files_to_check=(
    "/app/entrypoints/main.sh"
    "/app/entrypoints/ssh.sh" 
    "/app/entrypoints/jupyter.sh"
    "/app/shared/entrypoints/model.sh"
    "/app/shared/entrypoints/utils.sh"
)

for file in "${files_to_check[@]}"; do
    if [ -f "$file" ]; then
        if [ -x "$file" ]; then
            echo "✅ $file (可执行)"
        else
            echo "⚠️  $file (不可执行)"
        fi
    else
        echo "❌ $file (不存在)"
    fi
done

echo ""
echo "🎯 测试完成！"