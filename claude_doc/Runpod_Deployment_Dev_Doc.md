# Online Mapping 模型在 Runpod 上的部署开发文档 (最终版)

## 1. 项目目标与最终架构

本项目旨在为一系列基于 `mmdetection3d` 的在线建图模型（PETR, MapTR, VAD, StreamPETR, TopoMLP）创建一套健壮、灵活且易于维护的 Docker化推理环境，以便在 Runpod 等云平台上进行部署、测试和横向性能比较。

### 最终架构

经过讨论和迭代，我们确定了以下核心设计原则，以实现关注点分离和最大的灵活性：

1.  **每个模型一个独立的 Docker 环境**: 由于各模型间存在严重的依赖库版本冲突，我们为每个模型（PETR, MapTR 等）构建一个独立的、专门配置的 Docker 镜像。这是解决依赖问题的最可靠方法。

2.  **模型代码库负责核心推理**: 每个模型的代码库（例如 `PETR/`）内部都包含一个标准的、可独立执行的推理脚本 `tools/demo.py`。该脚本负责加载模型、处理单个数据样本并输出结果，是所有推理逻辑的核心。

3.  **Docker 脚本负责环境与执行**: `runpod_docker/` 目录下的脚本充当“启动器”和“编排器”。它们的职责是：
    *   构建 Docker 镜像 (`build_model_image.sh`)。
    *   启动正确的容器，并将外部的数据、权重和输出目录挂载到容器内部的预定位置。
    *   调用模型代码库内的 `tools/demo.py` 脚本，并向其传递正确的参数。

这种架构将模型的核心逻辑与其运行环境完全解耦，使得代码库更加规范，部署流程也更加清晰。

## 2. 关键脚本及其作用

| 文件路径                                       | 作用                                                                                                                              |
| ---------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------- |
| `build_model_image.sh`                         | **构建脚本**：为指定模型构建其专用的 Docker 镜像。用法: `bash build_model_image.sh <ModelName>`                                       |
| `run_model_with_mount.sh`                      | **单样本测试脚本**：用于在本地快速测试单个模型对单个数据样本的推理，会自动处理所有目录挂载和参数传递。非常适合调试。            |
| `run_comparison.py`                            | **批量比较脚本**：整个框架的入口。它读取配置文件，遍历所有模型和所有输入样本，自动调用 Docker 容器执行推理，并收集结果。        |
| `models_config.json`                           | **中央配置文件**：定义了所有待测试模型的信息，包括镜像名称、模型配置文件路径、权重文件名等。`run_comparison.py` 依赖此文件。 |
| `<ModelName>/tools/demo.py`                    | **核心推理脚本**：位于每个模型项目内部。这是一个标准的 `mmdetection3d` 推理脚本，负责加载模型和处理单个样本。                  |
| `runpod_docker/<ModelName>/inference.py`       | **Docker 包装器**：一个轻量级脚本，在 Docker 容器内部被调用，其唯一作用是解析参数并再次调用项目内的 `tools/demo.py`。        |
| `runpod_docker/<ModelName>/Dockerfile`         | **环境定义文件**：为每个模型定义了其独立的、包含正确 CUDA 版本和所有 Python 依赖的 Docker 环境。                               |

## 3. 端到端使用流程

### 步骤 1: 准备先决条件

1.  **Docker**: 确保您的系统中已安装并运行 Docker.
2.  **nuScenes 数据集**: 准备好完整的 nuScenes 数据集，并记下其根目录路径.
3.  **模型权重**: 将所有需要测试的模型的 `.pth` 权重文件下载并存放在一个目录下（例如 `~/my_test_data/model_weights`）.
4.  **配置文件检查**: 打开 `runpod_docker/models_config.json`，确保每个模型的 `config_path` 和 `weight_file` 字段正确无误.

### 步骤 2: 构建所有 Docker 镜像

在 `runpod_docker` 目录下，为所有需要测试的模型构建镜像：

```bash
cd /home/ian/dev/src/online_mapping/runpod_docker

bash build_model_image.sh PETR
bash build_model_image.sh MapTR
bash build_model_image.sh VAD
bash build_model_image.sh StreamPETR
bash build_model_image.sh TopoMLP
```

### 步骤 3: (可选) 推送镜像到注册中心

如果您计划在 Runpod 或其他云平台上运行，建议将构建好的镜像推送到 Docker Hub 或其他容器注册中心。

```bash
# 登录
docker login

# 为镜像打标签并推送
docker tag petr-model:latest your-username/petr-model:latest
docker push your-username/petr-model:latest
# (为其他所有镜像重复此操作)
```

### 步骤 4: 准备输入数据

1.  创建一个目录用于存放输入文件，例如 `~/my_test_data/inputs`.
2.  对于每一个您想测试的 nuScenes 样本，在该目录中创建一个文本文件。文件名可以任意（如 `sample1.txt`），但文件内容**必须**是该样本的 `sample_token`.

### 步骤 5: 运行批量比较

现在，您可以运行主比较脚本。请将路径替换为您的实际路径。

```bash
cd /home/ian/dev/src/online_mapping/runpod_docker

python3 run_comparison.py \
    --data_dir ~/my_test_data/inputs \
    --output_dir ~/my_test_data/outputs \
    --model_weights_dir ~/my_test_data/model_weights \
    --dataroot /path/to/your/full/nuscenes/dataset
```

脚本将开始依次为每个模型和每个输入样本运行推理。完成后，所有的输出（JSON 文件）和一份总结报告 `comparison_summary.json` 将会保存在 `~/my_test_data/outputs` 目录中。

### 步骤 6: (可选) 运行单个样本测试

如果您想快速调试或测试单个样本，可以使用 `run_model_with_mount.sh` 脚本。

```bash
cd /home/ian/dev/src/online_mapping/runpod_docker

bash run_model_with_mount.sh \
    PETR \
    ~/my_test_data/model_weights/petr_r50dcn_gridmask_p4.pth \
    ~/my_test_data/inputs_single \
    ~/my_test_data/outputs_single \
    "c0be823ae8f040e2b3306002c571ae57" 
```
*(请注意，您需要为 `inputs_single` 和 `outputs_single` 准备好对应的目录)*

## 4. 待办事项与注意事项

- **核心推理逻辑**: `tools/demo.py` 脚本中的核心推理逻辑是基于 `mmdetection3d` 的标准流程实现的。对于某些输出格式特殊的模型（如 MapTR），您可能需要微调 `demo.py` 中处理和保存结果的部分，以确保其正确性.
- **指标计算**: `run_comparison.py` 中的 `calculate_metrics` 函数目前是一个占位符。您需要根据您的具体需求（例如，比较不同模型输出的边界框的 mAP、NDS 等），实现有意义的性能指标计算逻辑.
