# 模型部署指南

这个统一的模板适用于所有支持的模型：MapTR, PETR, StreamPETR, TopoMLP, VAD

## 🎯 支持的模型

| 模型 | 功能 | 输出类型 |
|------|------|----------|
| MapTR | 在线矢量化高精地图构建 | 矢量化地图元素 |
| PETR | 多视角3D目标检测 | 3D边界框 |
| StreamPETR | 时序建模的高效3D检测 | 3D边界框 |
| TopoMLP | 自动驾驶拓扑推理 | 拓扑关系 |
| VAD | 矢量化场景表示 | 矢量化元素 |

## 🏗️ 架构

本部署方案遵循关注点分离的原则：

- **模型推理**: 核心的推理逻辑由各模型项目自身的 `tools/demo.py` 脚本负责
- **环境与执行**: 每个模型目录下的 `Dockerfile` 用于构建包含所有依赖的可移植运行环境
- **接口标准化**: `inference.py` 脚本充当包装器，调用各模型的推理脚本

这种设计使得模型代码库保持独立和标准，同时简化了部署流程。

## 📁 文件说明

每个模型目录包含：
- `Dockerfile`: 定义构建模型运行环境的指令
- `requirements.txt`: 列出模型运行所需的Python依赖
- `inference.py`: 包装器脚本，负责调用模型的推理脚本
- `gpu_utils.py`: GPU监控和内存管理工具

## 🚀 使用流程

### 1. 构建镜像

使用项目根目录下的 `build_model_image.sh` 脚本：

```bash
# 切换到 runpod_docker 目录
cd /home/ian/dev/src/online_mapping/runpod_docker

# 构建指定模型的 Docker 镜像
bash build_model_image.sh <MODEL_NAME>
```

支持的模型名称: `MapTR`, `PETR`, `StreamPETR`, `TopoMLP`, `VAD`

### 2. 运行推理

推荐使用 `runpod_docker` 目录下的高级脚本：

#### 单模型测试
```bash
bash run_model_with_mount.sh <MODEL_NAME> /path/to/model.pth /path/to/input_dir /path/to/output_dir <sample_token>
```

#### 批量模型比较
```bash
python3 run_comparison.py --data_dir <...> --output_dir <...> --model_weights_dir <...> --dataroot <...>
```

#### 健康检查
```bash
./run_model_evaluation.sh --health-check
```

## 🔧 配置说明

### 模型特定配置

每个模型都有自己的配置文件，位于 `models_config.json` 中。包含：
- 模型特定的输出解析逻辑
- Docker镜像标签
- 依赖版本要求
- 推理参数

### 环境变量

```bash
# 模型配置
export MODEL_NAME="<MODEL_NAME>"
export CUSTOM_CONFIG_FILE="/path/to/config.py"
export CHECKPOINT_FILE="/path/to/model.pth"

# 系统配置
export GPU_MEMORY_LIMIT="20GB"
export INFERENCE_TIMEOUT="600"
export LOG_LEVEL="INFO"
```

## 🛠️ 输出格式解析

不同模型有不同的输出格式，需要相应的解析逻辑：

### MapTR (矢量化地图元素)
```python
# 解析矢量化地图元素
output_item = {
    'points': vector['pts'].tolist(),
    'point_count': vector['pts_num'],
    'class_name': vector['cls_name'],
    'score': float(vector['score']),
}
```

### PETR/StreamPETR (3D边界框)
```python
# 解析3D目标检测结果
output_item = {
    'box3d': {
        'center': [float(c) for c in box[:3]],
        'size': [float(s) for s in box[3:6]],
        'yaw': float(box[6]),
    },
    'velocity': [float(v) for v in box[7:9]] if box.shape[0] > 7 else [0.0, 0.0],
    'score': float(scores_3d[i]),
    'label': dataset.CLASSES[labels_3d[i]]
}
```

### TopoMLP/VAD (拓扑/矢量化元素)
```python
# 解析拓扑或矢量化结果
output_item = {
    'elements': processed_elements,
    'topology': topology_relations,
    'confidence': float(confidence_score)
}
```

## 📚 更多信息

详细的使用指南和故障排除请参考：
- `docs/evaluation_guide.md`: 完整评测流程
- `docs/dataset_guide.md`: 数据集准备和使用
- `RUNPOD_SETUP_GUIDE.md`: RunPod部署指南

## 🔍 故障排除

常见问题和解决方案：

1. **构建失败**: 检查Docker环境和依赖版本
2. **推理错误**: 验证模型权重文件和配置
3. **内存不足**: 调整GPU内存限制或批处理大小
4. **输出格式**: 检查模型特定的输出解析逻辑

更多故障排除信息请运行：
```bash
./run_model_evaluation.sh --health-check
```

---

**注意**: 这个模板替代了原来5个重复的模型README文件，提供了统一的使用说明和配置指南。