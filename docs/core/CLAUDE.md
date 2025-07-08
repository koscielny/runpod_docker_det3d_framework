# RunPod多模型AI评测平台

## 🎯 项目概述

基于Docker和RunPod的多模型评测平台，支持5个先进的3D检测和地图构建模型：
- **MapTR**: 在线矢量化高精地图构建
- **PETR**: 多视角3D目标检测
- **StreamPETR**: 时序建模的高效3D检测
- **TopoMLP**: 自动驾驶拓扑推理
- **VAD**: 矢量化场景表示

## 🚀 快速开始

### 本地开发使用
```bash
# 统一主入口脚本
./runpod_platform.sh setup          # 环境检查
./runpod_platform.sh build all      # 构建镜像  
./runpod_platform.sh health         # 健康检查
./runpod_platform.sh compare        # 模型比较
```

### 🐳 RunPod容器内使用 (便捷别名)
SSH进入容器后立即可用：
```bash
# 🎯 核心别名
platform status                    # 系统状态
health-check                       # 健康诊断  
quick-test                         # 快速验证
model-compare                      # 性能比较

# 🛠️ 完整工具库  
python /app/tools/dependency_checker.py    # 依赖检查
python /app/tools/memory_optimizer.py      # 内存优化
python /app/tools/health_check.py          # 健康监控
```

### 传统脚本方式 (仍支持)
```bash
# 1. 健康检查所有模型
./scripts/evaluation/run_model_evaluation.sh --health-check

# 2. 完整评测流程  
./scripts/evaluation/run_model_evaluation.sh --full-evaluation

# 3. 单模型测试
./scripts/evaluation/run_model_evaluation.sh --single-model MapTR --data-path /data/sample.txt
```

## 🏗️ 项目架构

### 核心功能
- **标准化输出**: 统一的模型输出格式，便于比较分析
- **健康检查**: 快速诊断模型容器和依赖状态
- **性能对比**: 多维度性能分析和可视化图表
- **自动化评测**: 一键完成多模型评测流程

### 项目结构
```
runpod_docker/
├── 🐳 模型容器 (MapTR, PETR, StreamPETR, TopoMLP, VAD)
├── 📊 评测系统 (run_model_evaluation.sh, model_comparison.py)
├── 🔧 工具库 (health_check.py, gpu_utils.py)
└── 📚 文档 (claude_doc/, 核心管理文档)
```

## 📊 主要功能

### 1. 健康检查
```bash
# 检查所有模型状态
./scripts/evaluation/run_model_evaluation.sh --health-check

# 系统快速验证
./scripts/utils/quick_test.sh
```

### 2. 模型评测
```bash
# 单模型推理
./scripts/evaluation/run_model_evaluation.sh --single-model MapTR --data-path /data/sample.txt

# 多模型比较
./scripts/evaluation/run_model_evaluation.sh --compare-models --models MapTR,PETR,VAD
```

### 3. 性能分析
- **推理时间**: 端到端处理速度
- **GPU内存**: 峰值和平均内存使用
- **检测精度**: 置信度和准确率
- **可视化图表**: 雷达图和性能排名

## 🔧 项目状态

### 完成度 (90%)
- ✅ **Docker化部署**: 5个模型的完整容器镜像
- ✅ **评测系统**: 统一的性能分析和比较框架
- ✅ **健康检查**: 全面的系统状态监控
- ✅ **可视化**: 多维度性能分析图表
- ✅ **文档**: 完整的使用指南和技术文档

### 标准化输出格式
```json
{
  "metadata": {
    "model_name": "MapTR",
    "inference_time": 0.25,
    "gpu_memory_used": 2048.0
  },
  "detections_3d": [...],
  "map_elements": [...]
}
```

## 🛠️ 技术特点

### 设计原则
- **标准化接口**: 统一的输入输出格式
- **容器隔离**: 独立的Docker环境
- **资源管理**: GPU内存监控和清理
- **开发友好**: VS Code Remote SSH支持

### 配置管理
```bash
# 列出可用配置
./scripts/utils/list_model_configs.sh

# 验证配置文件
python scripts/utils/validate_config.py --config /path/to/config.py --model MapTR
```

## 📚 核心文档

### 项目管理文档
- **initiative.md**: 项目需求和目标规划
- **todo.md**: 待办事项和进度跟踪
- **version.md**: 版本记录和更新日志
- **CLAUDE.md**: 项目功能总结

### 技术文档
- **CONTAINER_TOOLS_GUIDE.md**: 容器内工具和别名完整指南 🔥 **最新**
- **EVALUATION_GUIDE.md**: 完整评测使用指南
- **RUNPOD_SETUP_GUIDE.md**: RunPod部署指南
- **DOCKER_NAMING_CONVENTIONS.md**: Docker镜像命名规范
- **IMPLEMENTATION_DETAILS.md**: 实现技术细节

## 🎯 容器内便捷工具特色

### 预配置别名系统
- ✅ `platform` - 统一平台管理
- ✅ `health-check` - 一键健康诊断
- ✅ `quick-test` - 快速依赖验证  
- ✅ `model-compare` - 性能比较分析

### 完整工具生态
- 🔍 **dependency_checker.py** - 全面依赖检查
- 💾 **memory_optimizer.py** - 智能内存优化
- 🏥 **health_check.py** - 系统健康监控
- 📊 **model_comparison.py** - 深度性能分析
- ✅ **validate_datasets.py** - 数据集验证

**详细使用**: 查看 [容器内工具指南](../guides/CONTAINER_TOOLS_GUIDE.md)

---

**项目状态**: 核心功能完成，处于优化完善阶段  
**完成度**: 95% (新增完整工具文档)  
**最后更新**: 2025-01-07