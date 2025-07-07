# 🏗️ RunPod Docker项目结构

## 📂 目录结构

```
runpod_docker/
├── 📋 docs/                        # 统一文档目录
│   ├── core/                       # 核心管理文档
│   │   ├── CLAUDE.md               # 项目概述和使用指南
│   │   ├── initiative.md           # 项目需求文档
│   │   ├── todo.md                 # 待办事项管理
│   │   └── version.md              # 版本记录和项目总结
│   ├── guides/                     # 使用指南
│   │   ├── RUNPOD_SETUP_GUIDE.md   # RunPod环境配置
│   │   ├── evaluation_guide.md     # 评估指南
│   │   └── dataset_guide.md        # 数据集下载指南
│   └── technical/                  # 技术文档
│       ├── PROJECT_STRUCTURE.md    # 项目结构说明
│       ├── DOCKER_NAMING_CONVENTIONS.md # Docker镜像命名规范
│       └── IMPLEMENTATION_DETAILS.md # 实现细节
│
├── 🛠️ scripts/                     # 统一脚本目录
│   ├── build/                      # 构建相关
│   │   ├── build_model_image.sh    # 镜像构建脚本
│   │   ├── docker_hub_workflow.sh  # Docker Hub工作流
│   │   └── validate_images.sh      # 镜像验证
│   ├── setup/                      # 环境设置
│   │   ├── setup_runpod_environment.sh # RunPod环境安装
│   │   ├── simple_setup.sh         # 简单设置
│   │   └── install_single_model.sh # 单模型安装
│   ├── evaluation/                 # 评测相关
│   │   ├── run_model_evaluation.sh # 模型评估主脚本
│   │   ├── run_comparison.py       # 模型对比
│   │   └── test_evaluation_system.sh # 评估系统测试
│   └── utils/                      # 工具脚本
│       ├── quick_test.sh           # 快速测试
│       ├── validate_config.py      # 配置验证
│       ├── list_model_configs.sh   # 配置管理
│       ├── run_model_with_mount.sh # 带挂载的运行
│       └── ...                     # 其他工具脚本
│
├── 🐳 containers/                  # 容器相关
│   ├── base/                       # 基础镜像
│   │   └── Dockerfile.vscode-base  # VS Code兼容基础镜像
│   ├── models/                     # 模型容器
│   │   ├── MapTR/
│   │   │   ├── Dockerfile          # 统一VS Code Ready镜像
│   │   │   ├── inference.py        # 推理脚本
│   │   │   ├── gpu_utils.py        # GPU监控工具
│   │   │   └── requirements.txt    # 依赖文件
│   │   ├── PETR/                   # 类似结构
│   │   ├── StreamPETR/             # 类似结构
│   │   ├── TopoMLP/                # 类似结构
│   │   └── VAD/                    # 类似结构
│   ├── shared/                     # 共享组件
│   │   ├── entrypoint_optimized.sh # 优化的容器入口点
│   │   └── gpu_utils.py            # GPU工具库
│   └── README_TEMPLATE.md          # 统一模型文档模板
│
├── 🔧 tools/                       # 评测工具
│   ├── health_check.py             # 健康检查
│   ├── model_comparison.py         # 模型对比工具
│   ├── model_output_standard.py    # 输出标准化
│   └── validate_datasets.py        # 数据集验证
│
├── 📊 datasets/                    # 数据集相关
│   ├── download_datasets.sh        # 数据集下载
│   └── quick_start_datasets.sh     # 快速数据集启动
│
├── 🧪 tests/                       # 测试相关
│   └── test_results/               # 测试结果
│       └── test_data/              # 测试用模拟数据
│
├── 📝 config/                      # 配置文件
│   ├── models_config.json          # 模型配置
│   └── config.sh                   # 系统配置
│
└── README.md                       # 项目主入口文档
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

## 📝 项目优化成果

### 文档精简 (2025-01-07)
- ✅ **合并模型文档**: 5个重复的模型README → 1个统一模板 (减少90%重复)
- ✅ **删除重复部署文档**: 2个部署指南 → 1个主要指南 (减少60%重复)
- ✅ **整合项目总结**: SYSTEM_SUMMARY.md → version.md (统一版本管理)
- ✅ **文档数量优化**: 从16个文档 → 10个文档 (减少37.5%)

### 目录结构重组 (2025-01-07)
- ✅ **清晰的功能模块划分**: docs/, scripts/, containers/, tools/, datasets/, tests/, config/
- ✅ **统一的脚本组织**: build/, setup/, evaluation/, utils/
- ✅ **改善的项目可维护性**: 逻辑清晰的目录结构
- ✅ **核心管理文档**: docs/core/ 统一管理
- ✅ **技术文档分类**: guides/, technical/ 分类管理

### 结构优化效果
- 🔧 **开发体验**: 更容易找到相关文件和脚本
- 📚 **文档管理**: 分类清晰，职责明确
- 🛠️ **脚本组织**: 功能分组，便于维护
- 🐳 **容器管理**: base/, models/, shared/ 分层清晰
- ⚡ **可扩展性**: 模块化设计便于添加新功能

---
*最后更新: 2025-01-07 (结构重组版)*