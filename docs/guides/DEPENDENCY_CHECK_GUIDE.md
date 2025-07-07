# Docker依赖检查指南

## 🎯 目标
确保在首次运行Docker容器时，所有依赖都健全，模型可以正常运行。

## 🚀 快速开始

### 方法1: 自动检查（推荐）
容器首次启动时会自动运行依赖检查：
```bash
# 启动容器，自动进行依赖检查
docker run -it iankaramazov/ai-models:maptr-latest
```

### 方法2: 手动快速检查
```bash
# 在容器内运行快速检查
/app/scripts/utils/quick_dependency_check.sh
```

### 方法3: 详细依赖检查
```bash
# 完整的依赖分析
python /app/tools/dependency_checker.py

# 指定模型检查
python /app/tools/dependency_checker.py --model MapTR

# 快速模式（跳过网络测试）
python /app/tools/dependency_checker.py --quick

# JSON格式输出
python /app/tools/dependency_checker.py --json
```

## 📋 检查项目详解

### 1. Python环境检查 🐍
- **Python版本**: 要求 >= 3.8
- **pip可用性**: 确保包管理器正常
- **路径配置**: 验证Python解释器路径

```bash
# 手动检查
python --version  # 应该显示 Python 3.8+
pip --version      # 确认pip可用
which python       # 检查Python路径
```

### 2. 核心依赖检查 📦
检查AI模型必需的核心库：

| 包名 | 用途 | 重要性 |
|------|------|--------|
| torch | PyTorch深度学习框架 | 🔴 必需 |
| torchvision | PyTorch视觉库 | 🔴 必需 |
| numpy | 数值计算 | 🔴 必需 |
| opencv-python | 计算机视觉 | 🔴 必需 |
| pillow | 图像处理 | 🔴 必需 |
| matplotlib | 绘图 | 🟡 建议 |
| psutil | 系统监控 | 🟡 建议 |

```bash
# 手动检查核心依赖
python -c "import torch; print(f'PyTorch: {torch.__version__}')"
python -c "import numpy; print(f'NumPy: {numpy.__version__}')"
python -c "import cv2; print(f'OpenCV: {cv2.__version__}')"
```

### 3. AI框架检查 🤖
检查专业AI库的可用性：

- **mmcv**: OpenMMLab计算机视觉基础库
- **scipy**: 科学计算库
- **scikit-image**: 图像处理
- **shapely**: 几何计算
- **timm**: PyTorch图像模型库

### 4. GPU支持检查 🎮
验证CUDA和GPU环境：

```bash
# 检查CUDA可用性
python -c "import torch; print(f'CUDA可用: {torch.cuda.is_available()}')"

# 检查GPU信息
python -c "
import torch
if torch.cuda.is_available():
    print(f'GPU数量: {torch.cuda.device_count()}')
    print(f'GPU名称: {torch.cuda.get_device_name(0)}')
    print(f'GPU内存: {torch.cuda.get_device_properties(0).total_memory / 1e9:.1f}GB')
"

# 检查NVIDIA驱动
nvidia-smi
```

### 5. 模型文件检查 📁
验证关键文件和目录：

- `/app`: 应用根目录
- `/app/{MODEL_NAME}`: 模型特定目录
- `/app/health_check.py`: 健康检查脚本
- `/app/model_output_standard.py`: 标准输出脚本
- `/app/{MODEL_NAME}/inference.py`: 模型推理脚本

### 6. 系统资源检查 💾
检查内存、磁盘空间和CPU：

```bash
# 内存检查
free -h

# 磁盘空间检查
df -h

# CPU信息
nproc
```

### 7. 网络连接检查 🌐
测试关键服务的网络连接：

- Hugging Face Hub
- PyTorch下载服务器
- Python包索引(PyPI)

### 8. 基础功能测试 🧪
运行简单的模型功能测试：

```python
# PyTorch张量运算测试
import torch
x = torch.randn(2, 3)
y = torch.randn(3, 2)
result = torch.mm(x, y)
print(f"张量运算测试: {result.shape}")

# GPU测试（如果可用）
if torch.cuda.is_available():
    x_gpu = x.cuda()
    print(f"GPU测试: {x_gpu.device}")
```

## 📊 结果解读

### 成功状态 ✅
```
🎉 状态: 容器依赖健全，模型可以运行！
✅ 通过: 15/15 (100%)
📝 建议: 可以开始使用模型进行推理
```

### 警告状态 ⚠️
```
⚠️ 状态: 发现一些警告，但基本可运行
✅ 通过: 12/15 (80%)
⚠️ 警告 (3个):
   • 网络连接-Hugging Face: 连接超时
   • GPU张量运算: 跳过 (无GPU)
   • 内存使用率较高 (85%)
```

### 错误状态 ❌
```
⚠️ 状态: 发现问题，需要修复后才能运行模型
✅ 通过: 8/15 (53%)
❌ 严重问题 (3个):
   • torch: PyTorch深度学习框架 - 未安装
   • 系统内存: 内存不足，需要至少1GB
   • 模型目录: /app/MapTR 不存在
```

## 🛠️ 常见问题解决

### 1. 依赖缺失
```bash
# 安装缺失的Python包
pip install torch torchvision numpy opencv-python pillow matplotlib

# 或从requirements.txt安装
pip install -r requirements.txt
```

### 2. GPU不可用
```bash
# 检查NVIDIA驱动
nvidia-smi

# 检查Docker GPU支持
docker run --gpus all nvidia/cuda:11.7-base nvidia-smi
```

### 3. 内存不足
```bash
# 增加Docker容器内存
docker run --memory=2g --memory-swap=4g ...

# 或使用内存优化工具
python /app/tools/memory_optimizer.py --cleanup
```

### 4. 文件缺失
```bash
# 检查容器构建
docker build -t test-image .

# 检查文件复制
docker run -it test-image ls -la /app/
```

## 🔄 持续监控

### 定期检查
```bash
# 添加到crontab进行定期检查
0 */6 * * * python /app/tools/dependency_checker.py --quick --json > /tmp/health_check.json
```

### 监控脚本
```bash
#!/bin/bash
# 监控脚本示例

while true; do
    echo "$(date): 运行依赖检查..."
    if python /app/tools/dependency_checker.py --quick; then
        echo "✅ 依赖检查通过"
    else
        echo "❌ 依赖检查失败，发送告警..."
        # 这里可以添加告警逻辑
    fi
    sleep 3600  # 每小时检查一次
done
```

## 📝 自定义检查

### 添加自定义检查项
可以在`dependency_checker.py`中添加特定于您模型的检查：

```python
def check_custom_requirements(self) -> bool:
    """检查自定义需求"""
    print("\n🔧 检查自定义需求...")
    
    # 检查特定配置文件
    config_file = "/app/config/model_config.yaml"
    exists = os.path.exists(config_file)
    self.log_result("模型配置文件", exists, config_file)
    
    # 检查特定环境变量
    api_key = os.environ.get("MODEL_API_KEY")
    has_key = api_key is not None and len(api_key) > 0
    self.log_result("API密钥", has_key, "环境变量已设置" if has_key else "缺少MODEL_API_KEY")
    
    return exists and has_key
```

## 📚 相关文档
- [内存优化指南](MEMORY_OPTIMIZATION_GUIDE.md)
- [RunPod部署指南](RUNPOD_SETUP_GUIDE.md)
- [健康检查文档](../technical/HEALTH_CHECK.md)
- [故障排除指南](../technical/TROUBLESHOOTING.md)

---

💡 **提示**: 定期运行依赖检查可以提前发现问题，确保模型始终处于可运行状态！