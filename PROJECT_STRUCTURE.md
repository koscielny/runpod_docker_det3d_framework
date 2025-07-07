# 🏗️ RunPod Docker项目结构

## 📂 目录结构

```
runpod_docker/
├── 📋 项目文档
│   ├── CLAUDE.md                    # 项目概述和使用指南
│   ├── RUNPOD_SETUP_GUIDE.md       # RunPod环境配置
│   ├── initiative.md               # 项目需求文档
│   ├── todo.md                     # 待办事项管理
│   └── version.md                  # 版本记录和项目总结
│
├── 🐳 Docker镜像
│   ├── Dockerfile.vscode-base      # VS Code兼容基础镜像
│   ├── MapTR/
│   │   ├── Dockerfile              # 统一VS Code Ready镜像
│   │   ├── inference.py            # 推理脚本
│   │   └── gpu_utils.py            # GPU监控工具
│   ├── PETR/
│   │   ├── Dockerfile              # 统一VS Code Ready镜像
│   │   ├── inference.py            # 推理脚本
│   │   └── gpu_utils.py            # GPU监控工具
│   ├── StreamPETR/
│   │   ├── Dockerfile              # 统一VS Code Ready镜像
│   │   ├── inference.py            # 推理脚本
│   │   └── gpu_utils.py            # GPU监控工具
│   ├── TopoMLP/
│   │   ├── Dockerfile              # 统一镜像
│   │   ├── inference.py            # 推理脚本
│   │   └── gpu_utils.py            # GPU监控工具
│   ├── VAD/
│   │   ├── Dockerfile              # 统一镜像
│   │   ├── inference.py            # 推理脚本
│   │   └── gpu_utils.py            # GPU监控工具
│   └── models/
│       └── README_TEMPLATE.md      # 统一模型文档模板
│
├── 🛠️ 核心脚本
│   ├── entrypoint_optimized.sh     # 优化的容器入口点
│   ├── gpu_utils.py                # GPU工具库
│   ├── docker_hub_workflow.sh      # Docker Hub工作流
│   └── build_model_image.sh        # 镜像构建脚本
│
├── 🔧 管理工具
│   ├── setup_runpod_environment.sh # RunPod环境安装
│   ├── quick_test.sh               # 快速测试
│   ├── validate_config.py          # 配置验证
│   ├── validate_images.sh          # 镜像验证
│   └── models_config.json          # 模型配置
│
├── 📊 评估系统
│   ├── run_model_evaluation.sh     # 模型评估主脚本
│   ├── run_model_with_mount.sh     # 带挂载的运行
│   ├── run_comparison.py           # 模型对比
│   └── test_evaluation_system.sh   # 评估系统测试
│
├── 📚 文档库 (claude_doc/)
│   ├── EVALUATION_GUIDE.md         # 评估指南
│   ├── DATASET_DOWNLOAD_GUIDE.md   # 数据集下载指南
│   ├── IMPLEMENTATION_DETAILS.md   # 实现细节
│   ├── health_check.py             # 健康检查
│   ├── model_comparison.py         # 模型对比工具
│   └── validate_datasets.py        # 数据集验证
│
└── 🧪 测试数据 (test_results/)
    └── test_data/                  # 测试用模拟数据
```

## 🎯 主要组件说明

### Docker镜像特性
- **精简结构**: 每个模型只保留一个主要Dockerfile
- **VS Code Ready**: 完整支持VS Code Remote SSH (GLIBC 2.31+)  
- **Root权限**: 直接root用户，无需runpod用户切换
- **SSH内置**: 完整SSH服务器配置
- **循环启动修复**: 优化的entrypoint避免重复初始化

### 核心功能
- **基础镜像**: `iankaramazov/ai-models:vscode-base` - VS Code兼容
- **优化入口点**: 防止容器循环启动
- **GPU监控**: 内置GPU使用率监控
- **SSH支持**: 完整的Remote开发环境

### 已推送镜像 (Docker Hub)
```bash
# 基础镜像
iankaramazov/ai-models:vscode-base      # VS Code兼容基础镜像

# 模型镜像 (All-in-One)
iankaramazov/ai-models:maptr-vscode     # MapTR完整版
iankaramazov/ai-models:petr-vscode      # PETR完整版

# 备注: 旧版runpod-ssh镜像已被vscode版本取代
```

## 🚀 快速使用

```bash
# 1. 测试环境
./quick_test.sh

# 2. 构建镜像
./build_model_image.sh

# 3. 运行评估
./run_model_evaluation.sh --health-check

# 4. RunPod部署
# 使用 RUNPOD_DEPLOYMENT_COMMANDS.md 中的命令
```

## 📝 文档精简成果

### 已完成的优化 (2025-01-07)
- ✅ **合并模型文档**: 5个重复的模型README → 1个统一模板 (减少90%重复)
- ✅ **删除重复部署文档**: 2个部署指南 → 1个主要指南 (减少60%重复)
- ✅ **整合项目总结**: SYSTEM_SUMMARY.md → version.md (统一版本管理)
- ✅ **文档数量优化**: 从16个文档 → 10个文档 (减少37.5%)

### 文档结构优化
- ✅ 核心管理文档: initiative.md, todo.md, version.md, CLAUDE.md
- ✅ 统一模型文档: models/README_TEMPLATE.md
- ✅ 保留重要技术文档: EVALUATION_GUIDE.md, DATASET_DOWNLOAD_GUIDE.md
- ✅ VS Code兼容性问题已解决
- ✅ 所有镜像支持SSH Remote开发

---
*最后更新: 2025-01-07 (文档精简版)*