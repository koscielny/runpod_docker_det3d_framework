# 自动驾驶数据集下载和整理指南

本文档提供了 nuScenes、Waymo Open Dataset 和 Argoverse 数据集的下载和整理方法，特别关注小型验证子集的获取，适用于模型验证和调试评估流水线。

## 目录
- [nuScenes 数据集](#nuscenes-数据集)
- [Waymo Open Dataset](#waymo-open-dataset)
- [Argoverse 数据集](#argoverse-数据集)
- [统一数据管理脚本](#统一数据管理脚本)
- [存储空间规划](#存储空间规划)

---

## nuScenes 数据集

### 📋 **数据集概述**
- **发布方**: nuTonomy (现为 Motional)
- **数据类型**: 3D 检测、跟踪、预测、地图重建
- **传感器**: 6个摄像头、1个激光雷达、5个毫米波雷达、IMU/GPS
- **场景**: 1000个场景，23小时数据

### 📊 **数据集规模**
| 版本 | 场景数量 | 数据大小 | 用途 |
|------|----------|----------|------|
| v1.0-mini | 10 | ~4GB | 🎯 **推荐验证集** |
| v1.0-trainval | 850 | ~365GB | 训练和验证 |
| v1.0-test | 150 | ~75GB | 测试 |

### 🚀 **快速开始 (推荐)**

#### 1. 下载 Mini 数据集
```bash
# 创建数据目录
mkdir -p /data/datasets/nuscenes

# 下载 mini 数据集 (约4GB)
cd /data/datasets/nuscenes
wget https://www.nuscenes.org/data/v1.0-mini.tgz
tar -xzf v1.0-mini.tgz

# 目录结构验证
tree -L 2 /data/datasets/nuscenes/
```

#### 2. 安装开发工具包
```bash
pip install nuscenes-devkit
```

#### 3. 验证安装
```python
from nuscenes.nuscenes import NuScenes
nusc = NuScenes(version='v1.0-mini', dataroot='/data/datasets/nuscenes', verbose=True)
print(f"场景数量: {len(nusc.scene)}")
print(f"样本数量: {len(nusc.sample)}")
```

### 📁 **完整数据集下载**
1. **注册账户**: 访问 [nuScenes 官网](https://www.nuscenes.org/)
2. **同意条款**: 阅读并同意 nuScenes Terms of Use
3. **下载文件**: 从下载页面获取所有档案文件

**完整数据集结构**:
```
/data/datasets/nuscenes/
├── maps/                 # 高精度地图
├── samples/              # 关键帧传感器数据
├── sweeps/               # 中间帧传感器数据
├── v1.0-trainval/        # 训练验证元数据
├── v1.0-test/            # 测试元数据
└── v1.0-mini/            # Mini 数据集元数据
```

---

## Waymo Open Dataset

### 📋 **数据集概述**
- **发布方**: Waymo LLC
- **数据类型**: 3D 检测、分割、运动预测
- **传感器**: 5个激光雷达、5个高分辨率摄像头
- **场景**: 1,950个场景，200,000个样本

### 📊 **数据集规模**
| 版本 | 场景数量 | 数据大小 | 用途 |
|------|----------|----------|------|
| 验证集 | 202 | ~150GB | 🎯 **推荐验证集** |
| 训练集 | 798 | ~600GB | 训练 |
| 测试集 | 150 | ~120GB | 测试 |

### 🚀 **快速开始**

#### 1. 注册和授权
```bash
# 1. 访问 https://waymo.com/open/licensing/
# 2. 注册账户并同意许可协议
# 3. 获取 Google Cloud 访问权限
```

#### 2. 安装 API
```bash
pip install waymo-open-dataset-tf-2-11-0
# 或者从源码安装
git clone https://github.com/waymo-research/waymo-open-dataset.git
cd waymo-open-dataset
pip install -e .
```

#### 3. 下载验证子集 (推荐开始)
```bash
# 使用 gsutil 下载验证集的前10个文件 (约15GB)
mkdir -p /data/datasets/waymo
cd /data/datasets/waymo

# 下载小型验证子集
gsutil -m cp gs://waymo_open_dataset_v_1_4_2/individual_files/validation/validation_0000.tfrecord .
gsutil -m cp gs://waymo_open_dataset_v_1_4_2/individual_files/validation/validation_0001.tfrecord .
# ... 继续下载更多文件按需
```

#### 4. 使用 TensorFlow Datasets
```python
import tensorflow_datasets as tfds

# 加载小型验证集
dataset = tfds.load(
    'waymo_open_dataset/v1.4.2',
    split='validation[:10]',  # 只加载前10个样本
    data_dir='/data/datasets/waymo'
)
```

### 📁 **数据集结构**
```
/data/datasets/waymo/
├── training/             # 训练 TFRecord 文件
├── validation/           # 验证 TFRecord 文件
├── testing/              # 测试 TFRecord 文件
└── domain_adaptation/    # 域适应数据
```

---

## Argoverse 数据集

### 📋 **数据集概述**
- **发布方**: Argo AI (现为 Ford)
- **版本**: Argoverse 1 和 Argoverse 2
- **数据类型**: 3D 跟踪、运动预测、地图重建
- **传感器**: 激光雷达、摄像头、高精度地图

### 📊 **Argoverse 2 数据集规模** (推荐)
| 数据集 | 场景数量 | 数据大小 | 用途 |
|--------|----------|----------|------|
| Sensor Dataset | 1,000 | ~1TB | 3D 检测和跟踪 |
| Lidar Dataset | 20,000 | ~2TB | 激光雷达处理 |
| Motion Forecasting | 250,000 | ~100GB | 🎯 **推荐验证集** |
| Map Change | 1,000 | ~50GB | 地图变化检测 |

### 🚀 **快速开始**

#### 1. 安装 API
```bash
# Argoverse 2 (推荐)
pip install av2

# Argoverse 1 (如果需要)
pip install argoverse
```

#### 2. 下载验证子集
```bash
# 创建数据目录
mkdir -p /data/datasets/argoverse2

# 下载 Motion Forecasting 验证集 (最小，适合开始)
# 注意：需要先在官网注册并获取下载链接
cd /data/datasets/argoverse2

# 使用官方下载脚本
python -m av2.datasets.motion_forecasting.download \
    --split val \
    --target-dir /data/datasets/argoverse2 \
    --max-scenarios 100  # 限制下载数量
```

#### 3. 验证安装
```python
from av2.datasets.motion_forecasting import scenario_serialization

# 加载场景
scenario_dir = "/data/datasets/argoverse2/val"
scenario_files = list(scenario_dir.glob("*.parquet"))
print(f"找到 {len(scenario_files)} 个场景文件")

# 加载第一个场景
if scenario_files:
    scenario = scenario_serialization.load_argoverse_scenario_parquet(scenario_files[0])
    print(f"场景ID: {scenario.scenario_id}")
    print(f"轨迹数量: {len(scenario.tracks)}")
```

### 📁 **Argoverse 2 数据结构**
```
/data/datasets/argoverse2/
├── sensor/               # 传感器数据
│   ├── train/
│   ├── val/
│   └── test/
├── lidar/                # 激光雷达数据
├── motion_forecasting/   # 运动预测数据
└── map_change/           # 地图变化数据
```

---

## 统一数据管理脚本

### 🛠️ **完整下载脚本** (`download_datasets.sh`)

```bash
#!/bin/bash
# 详见 claude_doc/download_datasets.sh 脚本
```

### 📊 **数据集验证脚本** (`validate_datasets.py`)

```python
#!/usr/bin/env python3
# 详见 claude_doc/validate_datasets.py 脚本
```

---

## 存储空间规划

### 💾 **推荐的最小验证配置** (总计约25GB)

| 数据集 | 子集 | 大小 | 用途 |
|--------|------|------|------|
| nuScenes | v1.0-mini | 4GB | 所有模型验证 |
| Waymo | 验证集前10个文件 | 15GB | 大规模验证 |
| Argoverse 2 | Motion Forecasting 100场景 | 6GB | 预测模型验证 |

### 🗂️ **目录结构建议**

```
/data/datasets/
├── nuscenes/
│   ├── v1.0-mini/           # 4GB - 快速验证
│   └── maps/
├── waymo/
│   ├── validation/          # 15GB - 子集验证
│   └── training/            # 按需扩展
└── argoverse2/
    ├── motion_forecasting/  # 6GB - 预测验证
    └── sensor/              # 按需扩展
```

### ⚡ **性能优化建议**

1. **SSD 存储**: 数据集IO密集，建议使用SSD
2. **并行下载**: 使用 `gsutil -m` 或 `wget -P` 并行下载
3. **分批验证**: 先用小数据集验证模型，再扩展到完整数据集
4. **数据缓存**: 在容器中挂载数据目录，避免重复下载

---

## 故障排除

### 🔧 **常见问题**

1. **权限问题**
```bash
# Waymo 数据集需要 Google Cloud 认证
gcloud auth login
gcloud config set project YOUR_PROJECT_ID
```

2. **网络超时**
```bash
# 设置更长的超时时间
gsutil -o GSUtil:socket_timeout=300 cp gs://bucket/file .
```

3. **存储空间不足**
```bash
# 检查可用空间
df -h /data/datasets/
# 清理下载缓存
rm -rf ~/.cache/pip
```

4. **API 版本兼容性**
```bash
# 检查已安装版本
pip list | grep -E "(nuscenes|waymo|av2)"
# 更新到最新版本
pip install --upgrade nuscenes-devkit av2
```

---

## 下一步

1. **运行下载脚本**: 使用提供的脚本下载验证子集
2. **验证数据完整性**: 运行验证脚本确保数据正确
3. **集成到模型**: 修改模型配置文件指向新的数据路径
4. **运行评估**: 使用小数据集测试完整的评估流水线

完整的自动化脚本请参考 `download_datasets.sh` 和 `validate_datasets.py`。