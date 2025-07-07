# 内存优化指南

## 📊 内存使用分析

### 当前状况评估
- **78%内存使用率分析**: 对于AI模型容器来说是偏高但可接受的水平
- **488MB总内存**: 对于深度学习模型来说偏小，推荐至少1-2GB

## 🎯 优化目标
- 降低内存使用率到60%以下
- 提高系统稳定性和响应速度
- 预防内存不足导致的模型加载失败

## 🛠️ 优化方案

### 1. 容器内存配置优化

#### RunPod部署推荐配置
```bash
# 推荐内存配置
--memory=2g --memory-swap=4g
```

#### Docker运行配置
```bash
# 基础配置 (1GB内存)
docker run --memory=1g --memory-swap=2g \
  iankaramazov/ai-models:maptr-latest

# 推荐配置 (2GB内存)  
docker run --memory=2g --memory-swap=4g \
  --oom-kill-disable=false \
  iankaramazov/ai-models:maptr-latest

# 高性能配置 (4GB内存)
docker run --memory=4g --memory-swap=8g \
  --oom-kill-disable=false \
  iankaramazov/ai-models:maptr-latest
```

### 2. 运行时内存优化

#### 使用内存优化工具
```bash
# 检查内存状态
python /app/tools/memory_optimizer.py --report

# 执行内存清理
python /app/tools/memory_optimizer.py --cleanup

# 持续监控内存
python /app/tools/memory_optimizer.py --monitor 60
```

#### 模型推理时优化
```python
# 在模型推理前
from gpu_utils import cleanup_gpu_memory, monitor_memory_usage

# 清理内存
cleanup_gpu_memory()
monitor_memory_usage("before_inference")

# 执行推理
result = model.inference(data)

# 推理后清理
cleanup_gpu_memory()
monitor_memory_usage("after_inference")
```

### 3. 系统级优化

#### 环境变量配置
```bash
# 添加到容器启动环境变量
export PYTHONDONTWRITEBYTECODE=1  # 不生成.pyc文件
export PYTHONUNBUFFERED=1         # 不缓冲输出
export MALLOC_TRIM_THRESHOLD_=10000  # 更积极的内存回收
```

#### Python内存优化
```python
import gc
import sys

# 更激进的垃圾回收
gc.set_threshold(700, 10, 10)

# 定期手动GC
def periodic_cleanup():
    collected = gc.collect()
    print(f"回收了 {collected} 个对象")
```

### 4. 模型加载优化

#### 懒加载策略
```python
# 只在需要时加载模型
class LazyModelLoader:
    def __init__(self):
        self._model = None
    
    @property
    def model(self):
        if self._model is None:
            self._model = self.load_model()
        return self._model
    
    def unload_model(self):
        del self._model
        self._model = None
        gc.collect()
```

## 📊 内存监控指标

### 正常运行指标
- **系统内存使用率**: < 70% (正常), < 80% (可接受)
- **可用内存**: > 200MB (最低), > 500MB (推荐)
- **内存碎片**: 定期清理，避免长期运行导致碎片化

### 告警阈值
- **🟡 警告**: 内存使用率 > 80%
- **🟠 严重**: 内存使用率 > 90%
- **🔴 危险**: 可用内存 < 50MB

## 🚀 快速诊断和解决

### 问题诊断脚本
```bash
#!/bin/bash
# 快速内存诊断

echo "=== 内存诊断报告 ==="
echo "当前时间: $(date)"
echo

# 系统内存
free -h

# 容器内存限制
if [ -f /sys/fs/cgroup/memory/memory.limit_in_bytes ]; then
    echo "容器内存限制: $(cat /sys/fs/cgroup/memory/memory.limit_in_bytes | numfmt --to=iec)"
fi

# 进程内存排序
echo "内存使用最高的进程:"
ps aux --sort=-%mem | head -6

# GPU内存 (如果有)
if command -v nvidia-smi &> /dev/null; then
    echo "GPU内存:"
    nvidia-smi --query-gpu=memory.used,memory.total --format=csv,nounits,noheader
fi
```

### 紧急内存释放
```bash
# 1. 清理Python缓存
python -c "import gc; print(f'回收: {gc.collect()}'); import torch; torch.cuda.empty_cache() if torch.cuda.is_available() else None"

# 2. 清理系统缓存 (如果有权限)
sync && echo 3 > /proc/sys/vm/drop_caches 2>/dev/null || echo "需要管理员权限清理系统缓存"

# 3. 强制垃圾回收
python /app/tools/memory_optimizer.py --cleanup
```

## 📈 性能对比

### 内存配置建议

| 模型类型 | 最小内存 | 推荐内存 | 最佳内存 | 说明 |
|---------|---------|---------|---------|------|
| MapTR   | 1GB     | 2GB     | 4GB     | 地图构建模型 |
| PETR    | 1GB     | 2GB     | 4GB     | 3D检测模型 |
| StreamPETR | 1.5GB | 3GB     | 6GB     | 时序模型，内存需求较高 |
| TopoMLP | 1GB     | 2GB     | 4GB     | 拓扑推理模型 |
| VAD     | 1.5GB   | 3GB     | 6GB     | 场景表示模型 |

### 优化效果预期
- **内存使用率**: 78% → 50-60%
- **响应时间**: 提升20-30%
- **稳定性**: 显著改善，减少OOM错误
- **并发能力**: 支持更多同时推理请求

## 🔧 故障排除

### 常见问题

#### 1. 内存使用率持续高于90%
```bash
# 解决方案
docker restart <container_name>  # 重启容器
# 或增加内存配置
docker update --memory=2g <container_name>
```

#### 2. OOM (Out of Memory) 错误
```bash
# 查看内存限制
cat /sys/fs/cgroup/memory/memory.limit_in_bytes

# 增加swap
fallocate -l 2G /swapfile
chmod 600 /swapfile
mkswap /swapfile
swapon /swapfile
```

#### 3. 内存泄漏检测
```python
import tracemalloc

# 启动内存跟踪
tracemalloc.start()

# 运行代码...

# 获取内存使用统计
current, peak = tracemalloc.get_traced_memory()
print(f"当前内存: {current / 1024 / 1024:.1f}MB")
print(f"峰值内存: {peak / 1024 / 1024:.1f}MB")
tracemalloc.stop()
```

## 📚 相关文档
- [RunPod内存配置文档](RUNPOD_SETUP_GUIDE.md)
- [模型性能优化指南](../technical/PERFORMANCE_OPTIMIZATION.md)
- [GPU内存管理](../technical/GPU_MEMORY_MANAGEMENT.md)