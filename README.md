# RunPod多模型AI评测平台

欢迎使用RunPod多模型AI评测平台！这是一个基于Docker的多模型评测和比较系统，支持5个先进的3D检测和地图构建模型。

## 🚀 快速开始

### 本地开发 (统一入口)
```bash
# 🆕 使用统一主入口脚本 (推荐)
./runpod_platform.sh setup          # 环境检查和初始化
./runpod_platform.sh build all      # 构建所有模型镜像
./runpod_platform.sh health         # 健康检查所有模型
./runpod_platform.sh compare        # 多模型性能比较

# 查看帮助
./runpod_platform.sh help
```

### 🐳 RunPod容器内使用 (便捷别名)
SSH进入RunPod容器后，享受预配置的便捷工具：
```bash
# 🎯 核心别名 (立即可用)
platform status                    # 系统状态检查
health-check                       # 健康诊断
quick-test                         # 快速依赖验证
model-compare                      # 模型性能比较

# 🛠️ 完整工具库
python /app/tools/dependency_checker.py      # 全面依赖检查
python /app/tools/memory_optimizer.py        # 内存优化
python /app/tools/model_comparison.py        # 详细性能分析

# 📖 查看完整工具指南
cat /app/docs/guides/CONTAINER_TOOLS_GUIDE.md
```

### 传统方式 (仍然支持)
```bash
# 1. 健康检查所有模型
./scripts/evaluation/run_model_evaluation.sh --health-check

# 2. 完整评测流程
./scripts/evaluation/run_model_evaluation.sh --full-evaluation

# 3. 单模型测试
./scripts/evaluation/run_model_evaluation.sh --single-model MapTR --data-path /data/sample.txt
```

## 📁 项目结构

```
runpod_docker/
├── 📋 docs/                     # 统一文档目录
│   ├── core/                    # 核心管理文档
│   ├── guides/                  # 使用指南
│   └── technical/               # 技术文档
├── 🛠️ scripts/                  # 统一脚本目录
│   ├── build/                   # 构建相关
│   ├── setup/                   # 环境设置
│   ├── evaluation/              # 评测相关
│   └── utils/                   # 工具脚本
├── 🐳 containers/               # 容器相关
│   ├── base/                    # 基础镜像
│   ├── models/                  # 模型容器
│   ├── shared/                  # 共享组件
│   └── README_TEMPLATE.md       # 模型文档模板
├── 🔧 tools/                    # 评测工具
├── 📊 datasets/                 # 数据集相关
├── 🧪 tests/                    # 测试相关
└── 📝 config/                   # 配置文件
```

## 🎯 支持的模型

- **MapTR**: 在线矢量化高精地图构建
- **PETR**: 多视角3D目标检测
- **StreamPETR**: 时序建模的高效3D检测
- **TopoMLP**: 自动驾驶拓扑推理
- **VAD**: 矢量化场景表示

## 📚 详细文档

### 核心管理文档
- [项目需求规划](docs/core/initiative.md)
- [待办事项管理](docs/core/todo.md)
- [版本记录](docs/core/version.md)
- [项目总览](docs/core/CLAUDE.md)

### 使用指南
- [快速开始指南](docs/guides/QUICK_START_GUIDE.md) 🆕
- [容器内工具指南](docs/guides/CONTAINER_TOOLS_GUIDE.md) 🔥 **最新**
- [RunPod部署指南](docs/guides/RUNPOD_SETUP_GUIDE.md)
- [评测使用指南](docs/guides/evaluation_guide.md)
- [数据集指南](docs/guides/dataset_guide.md)

### 技术文档
- [项目结构说明](docs/technical/PROJECT_STRUCTURE.md)
- [Docker镜像命名规范](docs/technical/DOCKER_NAMING_CONVENTIONS.md)
- [实现技术细节](docs/technical/IMPLEMENTATION_DETAILS.md)

## 🛠️ 主要功能

### 标准化输出格式
统一所有模型的输出结构，便于比较分析

### 健康检查系统
快速诊断模型容器和依赖状态

### 性能对比分析
多维度性能分析和可视化图表

### 自动化评测
一键完成多模型评测流程

## 🔧 项目状态

**完成度**: 90%
- ✅ Docker化部署
- ✅ 评测系统
- ✅ 健康检查
- ✅ 可视化分析
- ✅ 文档精简和重组
- ✅ 项目结构优化

## 📊 项目优化成果

### 文档精简 (已完成)
- 从16个文档精简到10个 (减少37.5%)
- 合并5个重复的模型README (减少90%重复)
- 统一版本管理和项目总结

### 结构重组 (已完成)
- 清晰的功能模块划分
- 统一的脚本和工具组织
- 改善的项目可维护性

---

**项目状态**: 核心功能完成，处于优化完善阶段
**最后更新**: 2025-01-07