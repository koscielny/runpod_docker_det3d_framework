# 跨机器部署指南

## 🎯 设计理念

所有路径都使用相对路径，支持在不同机器上灵活部署。

## 📁 目录结构

```
your_project/                    # 可以在任意位置
├── runpod_docker/              # 部署脚本目录
│   ├── config.sh               # 🔧 统一配置文件
│   ├── simple_setup.sh         # 🚀 主安装脚本
│   ├── install_single_model.sh # 🎯 单模型安装
│   ├── host_deploy_tools/      # 🔧 主机部署工具集
│   └── docs/                   # 📚 文档集合
├── MapTR/                      # 模型目录（自动克隆）
├── PETR/
├── StreamPETR/
├── TopoMLP/
└── VAD/
```

## 🚀 部署方式

### 方式1：自动检测环境（推荐）

脚本会自动检测并适配不同环境：

```bash
# 克隆项目到任意位置
git clone your-repo /path/to/your/project
cd /path/to/your/project/runpod_docker

# 直接运行，脚本会自动检测环境
./simple_setup.sh
```

**自动检测逻辑：**
1. **RunPod环境**: 如果检测到`/workspace`目录，使用`/workspace/models`
2. **本地环境**: 使用相对路径`../`（脚本父目录）
3. **自定义**: 通过环境变量`MODELS_DIR`指定

### 方式2：环境变量自定义

```bash
# 指定模型安装目录
export MODELS_DIR="/custom/path/to/models"
./simple_setup.sh
```

### 方式3：不同环境示例

#### 在本地机器上
```bash
# 项目在任意位置都可以
cd /home/user/my_projects/online_mapping/runpod_docker
./simple_setup.sh
# 模型会安装到: /home/user/my_projects/online_mapping/
```

#### 在RunPod云环境
```bash
cd /workspace/online_mapping/runpod_docker  
./simple_setup.sh
# 模型会安装到: /workspace/models/
```

#### 在服务器上
```bash
export MODELS_DIR="/data/models"
cd /opt/online_mapping/runpod_docker
./simple_setup.sh
# 模型会安装到: /data/models/
```

## 🔧 配置文件详解

### config.sh 核心配置

```bash
# 路径自动检测优先级：
# 1. 环境变量 MODELS_DIR（最高优先级）
# 2. RunPod环境检测 /workspace/models  
# 3. 相对路径 ../（默认）

# 用户自定义配置示例：
export MODELS_DIR="/your/custom/path"     # 自定义模型目录
export CONDA_ENV_NAME="my_models"        # 自定义conda环境名
```

### 支持的环境变量

| 变量名 | 描述 | 默认值 | 示例 |
|--------|------|--------|------|
| `MODELS_DIR` | 模型安装目录 | 自动检测 | `/data/models` |
| `CONDA_ENV_NAME` | Conda环境名称 | `mapping_models` | `my_env` |

## 📋 部署检查清单

### 1. 环境准备
```bash
# 检查conda是否可用
conda --version

# 检查git是否可用  
git --version

# 检查python环境
python --version
```

### 2. 权限检查
```bash
# 确保脚本有执行权限
chmod +x *.sh

# 确保目标目录有写权限
ls -la $MODELS_DIR
```

### 3. 配置验证
```bash
# 查看当前配置
./simple_setup.sh --help
# 或运行单模型脚本查看配置
./install_single_model.sh
```

## 🛠️ 故障排除

### 问题1：路径不正确
```bash
# 检查配置
source config.sh && print_config

# 手动指定路径
export MODELS_DIR="/correct/path"
./simple_setup.sh
```

### 问题2：conda环境问题
```bash
# 检查conda安装
which conda
conda info

# 手动创建环境
conda create -n mapping_models python=3.9 -y
```

### 问题3：权限问题
```bash
# 检查目录权限
ls -la $(dirname $MODELS_DIR)

# 创建目录
mkdir -p $MODELS_DIR
```

## 🎯 最佳实践

### 1. 生产环境部署
```bash
# 使用专门的模型目录
export MODELS_DIR="/opt/ai_models"
export CONDA_ENV_NAME="production_models"
./simple_setup.sh
```

### 2. 开发环境部署  
```bash
# 使用相对路径，便于版本控制
cd project/runpod_docker
./simple_setup.sh
# 模型在 project/ 目录下
```

### 3. 多环境管理
```bash
# 不同环境使用不同配置
# dev环境
export MODELS_DIR="./dev_models" && ./simple_setup.sh

# test环境  
export MODELS_DIR="./test_models" && ./simple_setup.sh

# prod环境
export MODELS_DIR="/opt/prod_models" && ./simple_setup.sh
```

## 📝 迁移现有部署

如果你已经有现有的部署，可以轻松迁移：

```bash
# 1. 备份现有模型（如果需要）
cp -r /old/models/path /backup/location

# 2. 更新脚本
git pull  # 获取最新的相对路径版本

# 3. 指定现有模型目录
export MODELS_DIR="/old/models/path"
./simple_setup.sh

# 4. 或者让脚本自动检测新位置
./simple_setup.sh
```

现在你可以在任意机器上部署，只需要简单的 `git clone` + `./simple_setup.sh`！