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

## 🐳 Docker镜像构建和推送

### 新的统一构建工具 🆕
使用我们改进的 `build_and_push.sh` 脚本，支持所有类型的镜像：

```bash
# 进入containers目录
cd containers/

# 查看帮助
./build_and_push.sh --help
```

### 🎯 支持的镜像类型

#### **基础镜像**
- `vscode` - VSCode开发环境镜像
- `jupyterlab` - Jupyter Lab数据科学环境镜像

#### **模型镜像** 
- `VAD` - VAD模型应用镜像
- `MapTR` - MapTR模型应用镜像
- `PETR` - PETR模型应用镜像
- `StreamPETR` - StreamPETR模型应用镜像
- `TopoMLP` - TopoMLP模型应用镜像

#### **模型库镜像**
- `vad-mmlibs` - VAD + MM系列库环境
- `maptr-mmlibs` - MapTR + MM系列库环境
- `petr-mmlibs` - PETR + MM系列库环境
- `streampetr-mmlibs` - StreamPETR + MM系列库环境
- `topomlp-mmlibs` - TopoMLP + MM系列库环境

### 🚀 构建操作

#### **单个镜像构建**
```bash
# 构建特定镜像
./build_and_push.sh build jupyterlab
./build_and_push.sh build VAD
./build_and_push.sh build maptr-mmlibs

# 构建并推送
./build_and_push.sh build-push MapTR
```

#### **批量构建操作** 🆕
```bash
# 构建所有基础镜像
./build_and_push.sh build-base

# 构建所有模型镜像
./build_and_push.sh build-models

# 构建所有镜像（基础 + 模型）
./build_and_push.sh build-all
```

#### **推送操作**
```bash
# 推送所有基础镜像
./build_and_push.sh push-base

# 推送所有模型镜像
./build_and_push.sh push-models

# 推送所有镜像
./build_and_push.sh push-all
```

#### **完整部署工作流** 🔥
```bash
# 一键构建并推送所有镜像到Docker Hub
./build_and_push.sh deploy

# 使用自定义标签
./build_and_push.sh deploy --tag v1.0

# 不使用缓存构建
./build_and_push.sh deploy --no-cache
```

### 📊 镜像管理

```bash
# 查看所有本地镜像
./build_and_push.sh list

# 登录Docker Hub
./build_and_push.sh login
```

### ⚡ 高级选项

```bash
# 自定义标签
./build_and_push.sh build VAD --tag v2.0

# 指定构建平台
./build_and_push.sh build-all --platform linux/arm64

# 不使用缓存
./build_and_push.sh build-models --no-cache

# 组合选项
./build_and_push.sh deploy --tag v1.0 --no-cache
```

## 🏗️ EntryPoint架构 🆕

### 新的分层EntryPoint设计
我们采用了全新的分层entrypoint架构，提供更好的服务管理和避免重复初始化：

#### **架构层次**
```
基础层 (base/entrypoints/):
├── ssh.sh          # SSH服务专用
├── jupyter.sh      # Jupyter Lab服务专用
└── main.sh         # 基础层主入口

共享层 (shared/entrypoints/):
├── utils.sh        # 通用工具函数库
└── model.sh        # 模型应用通用入口
```

#### **智能特性**
- ✅ **避免重复初始化**: 通过标志文件防止重复启动服务
- ✅ **智能服务检测**: 自动检测可用服务（如Jupyter）
- ✅ **模块化设计**: 各层职责清晰，易于维护
- ✅ **健康监控**: 自动监控和重启异常服务
- ✅ **丰富工具**: 完整的工具函数库和便捷别名

#### **容器启动流程**
```
模型容器启动 → 检测服务类型 → 启动基础服务 → 启动专用服务 → 健康监控
```

所有现有模型项目已迁移到新架构！

## 📈 nuScenes数据集可视化工具 🆕

新增强大的数据集可视化工具，帮助理解和分析nuScenes数据：

### 🛠️ 可视化工具

位置：`datasets/visualization/scripts/`

#### **场景信息工具**
```bash
# 列出所有场景
python scripts/list_scenes.py --dataroot /data/nuscenes

# 导出场景信息为JSON
python scripts/list_scenes.py --dataroot /data/nuscenes --save-json scenes_info.json
```

#### **相机视频生成**
```bash
# 生成前置相机视频
python scripts/generate_camera_video.py \
    --dataroot /data/nuscenes \
    --scene scene-0001 \
    --camera CAM_FRONT

# 支持的相机: CAM_FRONT, CAM_BACK, CAM_FRONT_LEFT, CAM_FRONT_RIGHT, CAM_BACK_LEFT, CAM_BACK_RIGHT
```

#### **LiDAR BEV视频生成**
```bash
# 生成LiDAR鸟瞰图视频
python scripts/generate_lidar_bev_video.py \
    --dataroot /data/nuscenes \
    --scene scene-0001 \
    --colormap height

# 支持的着色方式: intensity, height, distance
```

#### **数据集分析**
```bash
# 生成完整的数据集分析报告
python scripts/analyze_dataset.py --dataroot /data/nuscenes
```

#### **批量处理**
```bash
# 批量生成多个场景的可视化
python scripts/batch_visualize.py \
    --dataroot /data/nuscenes \
    --scenes scene-0001 scene-0002 scene-0003 \
    --max-workers 8
```

### 📋 建议的额外可视化功能
- 多传感器融合可视化
- 轨迹和动态分析
- 场景理解可视化 
- 数据质量分析
- 交互式Web界面

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
│   │   └── entrypoints/         # 基础层entrypoint脚本 🆕
│   ├── models/                  # 模型容器
│   ├── shared/                  # 共享组件
│   │   └── entrypoints/         # 共享层entrypoint脚本 🆕
│   ├── build_and_push.sh        # 统一构建推送脚本 🆕
│   ├── ENTRYPOINT_*.md          # EntryPoint架构文档 🆕
│   └── README.md                # 本文档 🆕
├── 🔧 tools/                    # 评测工具
├── 📊 datasets/                 # 数据集相关
│   └── visualization/           # 数据集可视化工具 🆕
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
- [项目需求规划](../docs/core/initiative.md)
- [待办事项管理](../docs/core/todo.md)
- [版本记录](../docs/core/version.md)
- [项目总览](../docs/core/CLAUDE.md)

### 使用指南
- [快速开始指南](../docs/guides/QUICK_START_GUIDE.md) 🆕
- [容器内工具指南](../docs/guides/CONTAINER_TOOLS_GUIDE.md) 🔥 **最新**
- [RunPod部署指南](../docs/guides/RUNPOD_SETUP_GUIDE.md)
- [评测使用指南](../docs/guides/evaluation_guide.md)
- [数据集指南](../docs/guides/dataset_guide.md)

### 技术文档
- [项目结构说明](../docs/technical/PROJECT_STRUCTURE.md)
- [Docker镜像命名规范](../docs/technical/DOCKER_NAMING_CONVENTIONS.md)
- [实现技术细节](../docs/technical/IMPLEMENTATION_DETAILS.md)
- [EntryPoint架构设计](ENTRYPOINT_ARCHITECTURE.md) 🆕
- [EntryPoint清理计划](ENTRYPOINT_CLEANUP.md) 🆕

## 🛠️ 主要功能

### 统一Docker构建系统 🆕
- 支持所有类型镜像的构建和推送
- 智能镜像类型检测
- 批量操作和完整部署工作流
- 错误处理和详细日志

### 分层EntryPoint架构 🆕  
- 模块化服务管理
- 避免重复初始化
- 智能服务检测
- 增强健康监控

### nuScenes数据可视化 🆕
- 场景信息分析
- 相机视频生成
- LiDAR BEV可视化
- 批量处理工具

### 标准化输出格式
统一所有模型的输出结构，便于比较分析

### 健康检查系统
快速诊断模型容器和依赖状态

### 性能对比分析
多维度性能分析和可视化图表

### 自动化评测
一键完成多模型评测流程

## 🔧 项目状态

**完成度**: 95% 🆕
- ✅ Docker化部署
- ✅ 评测系统
- ✅ 健康检查
- ✅ 可视化分析
- ✅ 文档精简和重组
- ✅ 项目结构优化
- ✅ 统一Docker构建系统 🆕
- ✅ 分层EntryPoint架构 🆕
- ✅ nuScenes数据可视化 🆕

## 📊 项目优化成果

### 最新优化 (2025-01-20) 🆕
- **Docker构建系统**: 统一构建脚本，支持所有镜像类型
- **EntryPoint架构**: 分层设计，避免重复初始化，提高启动效率
- **数据可视化**: 完整的nuScenes数据集可视化工具套件
- **项目迁移**: 所有模型项目已迁移到新架构

### 文档精简 (已完成)
- 从16个文档精简到10个 (减少37.5%)
- 合并5个重复的模型README (减少90%重复)
- 统一版本管理和项目总结

### 结构重组 (已完成)
- 清晰的功能模块划分
- 统一的脚本和工具组织
- 改善的项目可维护性

---

**项目状态**: 核心功能完成，新增重要功能，处于高度完善阶段 🚀  
**最后更新**: 2025-01-20