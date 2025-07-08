# 容器内工具和别名使用指南

## 🚀 概述

当您SSH进入RunPod Docker容器后，您将拥有一整套预配置的工具和便捷别名，让您能够轻松管理和使用AI模型评测平台。

## 🎯 便捷别名命令

所有别名都已经预配置在容器的 `.bashrc` 中，SSH进入容器后立即可用：

### 核心管理别名

```bash
# 🔧 统一平台管理
platform                    # 等价于 /app/runpod_platform.sh
platform status              # 查看系统状态
platform build all          # 构建所有镜像
platform health             # 健康检查

# 🧪 快速测试
quick-test                   # 等价于 /app/scripts/utils/quick_test.sh
quick-test --detailed        # 详细测试报告

# 🏥 健康检查
health-check                 # 等价于 python /app/tools/health_check.py
health-check --gpu          # GPU专项检查
health-check --memory       # 内存状态检查

# 📊 模型比较
model-compare               # 等价于 python /app/tools/model_comparison.py
model-compare --all        # 比较所有可用模型
```

## 🛠️ 完整工具库

### 1. 核心工具目录 `/app/tools/`

#### **dependency_checker.py** - 全面依赖检查
```bash
# 完整依赖检查
python /app/tools/dependency_checker.py

# 检查特定组件
python /app/tools/dependency_checker.py --component gpu
python /app/tools/dependency_checker.py --component python
python /app/tools/dependency_checker.py --component models
```

**功能**：
- 🐍 Python环境验证
- 📦 核心依赖包检查
- 🎮 GPU和CUDA支持
- 🔧 系统工具验证
- 📁 关键文件检查
- 💾 资源状态监控

#### **health_check.py** - 系统健康监控
```bash
# 基础健康检查
python /app/tools/health_check.py
# 或使用别名
health-check

# 详细检查报告
health-check --detailed --output /tmp/health_report.json

# GPU专项检查
health-check --gpu --verbose
```

**功能**：
- 🎯 GPU状态和温度监控
- 💾 内存使用分析
- 🔄 进程状态检查
- 📊 性能指标收集
- ⚠️ 异常情况告警

#### **memory_optimizer.py** - 内存优化工具
```bash
# 内存状态报告
python /app/tools/memory_optimizer.py --report

# 自动内存清理
python /app/tools/memory_optimizer.py --cleanup

# 内存监控模式
python /app/tools/memory_optimizer.py --monitor --interval 30
```

**功能**：
- 📈 内存使用详细分析
- 🧹 自动垃圾回收
- 🔍 内存泄漏检测
- 📊 优化建议生成
- 💡 缓存管理策略

#### **model_comparison.py** - 模型性能比较
```bash
# 比较所有模型
python /app/tools/model_comparison.py
# 或使用别名
model-compare

# 比较特定模型
model-compare --models MapTR,PETR,VAD --output /tmp/comparison.html

# 生成性能报告
model-compare --report --format json --save /tmp/performance.json
```

**功能**：
- 🏃 推理速度对比
- 💾 内存占用分析
- 🎯 精度指标比较
- 📊 可视化图表生成
- 📝 自动报告生成

#### **model_output_standard.py** - 输出格式标准化
```bash
# 标准化模型输出
python /app/tools/model_output_standard.py --input raw_output.json --model MapTR

# 批量标准化
python /app/tools/model_output_standard.py --batch --input-dir /data/outputs/
```

**功能**：
- 🔄 统一输出格式
- ✅ 数据结构验证
- 📊 结果后处理
- 🔍 输出质量检查

#### **validate_datasets.py** - 数据集验证工具
```bash
# 验证数据集完整性
python /app/tools/validate_datasets.py --dataset /data/nuscenes

# 快速验证
python /app/tools/validate_datasets.py --quick --path /data/sample/
```

**功能**：
- 📁 文件完整性检查
- 🔍 数据格式验证
- 📊 统计信息生成
- ✅ 质量评估报告

### 2. 脚本工具库 `/app/scripts/`

#### **评测脚本** `/app/scripts/evaluation/`
```bash
# 完整评测流程
/app/scripts/evaluation/run_model_evaluation.sh --full-evaluation

# 单模型评测
/app/scripts/evaluation/run_model_evaluation.sh --single-model MapTR --data /data/test

# 性能比较
/app/scripts/evaluation/run_comparison.py --models all --output /tmp/results/
```

#### **工具脚本** `/app/scripts/utils/`
```bash
# 快速依赖检查
/app/scripts/utils/quick_dependency_check.sh
# 或使用别名
quick-test

# 模型接口测试
/app/scripts/utils/test_model_interfaces.sh

# 配置验证
/app/scripts/utils/validate_config.py --config /app/config/models_config.json
```

#### **构建脚本** `/app/scripts/build/`
```bash
# 构建单个模型镜像
/app/scripts/build/build_model_image.sh MapTR

# Docker Hub工作流
/app/scripts/build/docker_hub_workflow.sh --push-all
```

### 3. 数据集管理 `/app/datasets/`
```bash
# 下载标准数据集
/app/datasets/download_datasets.sh --dataset nuscenes --target /data/

# 快速开始数据集
/app/datasets/quick_start_datasets.sh --setup-sample-data
```

## 📁 工作目录结构

容器内的标准目录结构：
```
/app/
├── 🔧 tools/                    # 所有工具脚本
├── 📜 scripts/                  # 管理脚本
├── ⚙️  config/                   # 配置文件
├── 📊 datasets/                 # 数据集管理
├── 🧪 test_data/                # 测试样本
├── 🚀 runpod_platform.sh        # 统一入口
├── 🐳 MapTR/                    # 模型目录
├── 🔍 health_check.py (已弃用)  # 改用 tools/health_check.py
└── 📋 entrypoint.sh             # 容器入口点
```

## 🎯 典型使用场景

### 场景1：快速健康检查
```bash
# SSH进入容器后
health-check                     # 快速检查
platform status                 # 系统状态
quick-test                      # 依赖验证
```

### 场景2：模型性能分析
```bash
# 运行完整性能比较
model-compare --all --detailed

# 生成优化报告
python /app/tools/memory_optimizer.py --report

# 检查GPU使用情况
health-check --gpu --monitor
```

### 场景3：问题诊断和优化
```bash
# 全面依赖检查
python /app/tools/dependency_checker.py --verbose

# 内存优化
python /app/tools/memory_optimizer.py --cleanup --monitor

# 生成诊断报告
health-check --detailed --output /tmp/diagnosis.json
```

### 场景4：开发和调试
```bash
# 验证模型输出
python /app/tools/model_output_standard.py --input model_output.json --validate

# 测试数据集
python /app/tools/validate_datasets.py --dataset /data/custom --report

# 接口测试
/app/scripts/utils/test_model_interfaces.sh --model MapTR
```

## 💡 高级使用技巧

### 1. 别名组合使用
```bash
# 完整检查流程
health-check && quick-test && model-compare --quick
```

### 2. 输出重定向
```bash
# 保存检查结果
health-check --detailed > /tmp/health_$(date +%Y%m%d).log
model-compare --report --output /tmp/performance_report.html
```

### 3. 后台监控
```bash
# 启动内存监控
python /app/tools/memory_optimizer.py --monitor --interval 60 &

# GPU监控
watch -n 30 'health-check --gpu'
```

### 4. 自动化脚本
```bash
#!/bin/bash
# 每日健康检查脚本
echo "=== Daily Health Check $(date) ===" >> /tmp/daily_check.log
health-check --detailed >> /tmp/daily_check.log 2>&1
model-compare --quick >> /tmp/daily_check.log 2>&1
echo "=== Check Complete ===" >> /tmp/daily_check.log
```

## 🔍 故障排除

### 常见问题和解决方案

1. **别名不可用**
   ```bash
   # 重新加载别名
   source ~/.bashrc
   ```

2. **工具路径错误**
   ```bash
   # 检查PATH设置
   echo $PATH
   # 应该包含：/app/scripts/utils:/app/scripts/evaluation:/app/tools
   ```

3. **权限问题**
   ```bash
   # 检查文件权限
   ls -la /app/tools/
   ls -la /app/scripts/utils/
   ```

4. **Python模块找不到**
   ```bash
   # 检查Python路径
   python -c "import sys; print('\n'.join(sys.path))"
   ```

## 📚 相关文档

- [快速开始指南](QUICK_START_GUIDE.md) - 基础使用入门
- [RunPod部署指南](RUNPOD_SETUP_GUIDE.md) - 云端部署详解
- [评测使用指南](evaluation_guide.md) - 评测功能详解
- [Docker镜像命名规范](../technical/DOCKER_NAMING_CONVENTIONS.md) - 镜像管理

---

💡 **提示**: 运行 `platform help` 或任何工具的 `--help` 参数获取详细帮助信息！

**最后更新**: 2025-01-07 | **版本**: v1.0.5