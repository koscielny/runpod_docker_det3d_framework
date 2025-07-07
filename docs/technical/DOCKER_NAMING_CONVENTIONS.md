# Docker镜像命名规范

## 📋 命名规则总览

本项目使用统一的Docker镜像命名规范，确保本地构建和Docker Hub推送的一致性。

## 🏷️ 本地构建命名

### 格式
```
${MODEL_NAME,,}-model:latest
```

### 说明
- `${MODEL_NAME,,}`: 模型名称转为小写
- `-model`: 固定后缀标识
- `:latest`: 默认标签

### 示例
| 模型名称 | 本地镜像名称 |
|----------|-------------|
| MapTR | `maptr-model:latest` |
| PETR | `petr-model:latest` |
| StreamPETR | `streampetr-model:latest` |
| TopoMLP | `topomlp-model:latest` |
| VAD | `vad-model:latest` |

### 构建命令
```bash
# 使用build_model_image.sh脚本
./scripts/build/build_model_image.sh MapTR
# 生成镜像: maptr-model:latest
```

## 🌐 Docker Hub推送命名

### 格式
```
${DOCKER_REGISTRY}/${DOCKER_HUB_USERNAME}/${DOCKER_HUB_REPO}:${model,,}-${tag}
```

### 配置参数
- **DOCKER_REGISTRY**: `docker.io`
- **DOCKER_HUB_USERNAME**: `iankaramazov`
- **DOCKER_HUB_REPO**: `ai-models`
- **model**: 模型名称（小写）
- **tag**: 版本标签（默认`latest`）

### 完整示例
| 模型名称 | Docker Hub镜像名称 |
|----------|-------------------|
| MapTR | `docker.io/iankaramazov/ai-models:maptr-latest` |
| PETR | `docker.io/iankaramazov/ai-models:petr-latest` |
| StreamPETR | `docker.io/iankaramazov/ai-models:streampetr-latest` |
| TopoMLP | `docker.io/iankaramazov/ai-models:topomlp-latest` |
| VAD | `docker.io/iankaramazov/ai-models:vad-latest` |

### 推送命令
```bash
# 使用docker_hub_workflow.sh脚本
./scripts/build/docker_hub_workflow.sh push MapTR
# 推送到: docker.io/iankaramazov/ai-models:maptr-latest

# 指定版本标签
./scripts/build/docker_hub_workflow.sh push MapTR --tag v1.0
# 推送到: docker.io/iankaramazov/ai-models:maptr-v1.0
```

## 🔖 版本标签策略

### 标签类型
1. **latest**: 最新稳定版本（默认）
2. **vX.Y.Z**: 语义化版本号（如v1.0.0, v1.1.0）
3. **dev**: 开发版本
4. **experimental**: 实验性版本

### 版本标签示例
```bash
# 最新版本
docker.io/iankaramazov/ai-models:maptr-latest

# 特定版本
docker.io/iankaramazov/ai-models:maptr-v1.0.0
docker.io/iankaramazov/ai-models:maptr-v1.1.0

# 开发版本
docker.io/iankaramazov/ai-models:maptr-dev
```

## 🛠️ 脚本工具

### 构建脚本
- **本地构建**: `scripts/build/build_model_image.sh`
- **Docker Hub工作流**: `scripts/build/docker_hub_workflow.sh`

### 使用示例
```bash
# 构建本地镜像
./scripts/build/build_model_image.sh PETR

# 构建并推送到Docker Hub
./scripts/build/docker_hub_workflow.sh build PETR
./scripts/build/docker_hub_workflow.sh push PETR

# 构建所有模型
./scripts/build/docker_hub_workflow.sh build-all

# 推送所有模型
./scripts/build/docker_hub_workflow.sh push-all

# 指定版本标签
./scripts/build/docker_hub_workflow.sh build MapTR --tag v1.1
./scripts/build/docker_hub_workflow.sh push MapTR --tag v1.1
```

## 📊 配置文件位置

### 主要配置
- **Docker Hub配置**: `scripts/build/docker_hub_workflow.sh` (第7-16行)
- **本地构建配置**: `scripts/build/build_model_image.sh` (第16行)

### 可修改的配置
```bash
# 在docker_hub_workflow.sh中
DOCKER_HUB_USERNAME="iankaramazov"    # Docker Hub用户名
DOCKER_HUB_REPO="ai-models"           # 仓库名称
DOCKER_REGISTRY="docker.io"           # 镜像仓库
BUILD_PLATFORM="linux/amd64"          # 构建平台
```

## 🔍 验证和查看

### 查看本地镜像
```bash
docker images | grep model
# 输出: maptr-model    latest    abc123    2 hours ago    2.1GB
```

### 查看推送的镜像
```bash
# Docker Hub链接
https://hub.docker.com/r/iankaramazov/ai-models/tags

# 拉取测试
docker pull docker.io/iankaramazov/ai-models:maptr-latest
```

## 📝 注意事项

1. **模型名称统一**: 确保模型名称在所有脚本中保持一致
2. **标签规范**: 使用语义化版本号，避免随意命名
3. **推送前构建**: 确保本地镜像构建成功后再推送
4. **权限管理**: 确保有Docker Hub推送权限

---

**维护**: 此文档随Docker命名规则变化而更新  
**最后更新**: 2025-01-07  
**相关脚本**: `scripts/build/build_model_image.sh`, `scripts/build/docker_hub_workflow.sh`