# PETR 模型在 Runpod 上的部署

此目录包含在 Runpod 上部署 PETR 模型所需的 Dockerfile 和一个简单的启动脚本。

## 架构

本部署方案遵循关注点分离的原则：

-   **模型推理**: 核心的推理逻辑由 PETR 项目自身的 `tools/demo.py` 脚本负责。
-   **环境与执行**: 此目录下的 `Dockerfile` 用于构建一个包含所有依赖的、可移植的运行环境。`inference.py` 脚本则充当一个简单的包装器，负责在 Docker 容器内调用 `tools/demo.py`。

这种设计使得模型代码库保持独立和标准，同时简化了部署流程。

## 文件说明

-   `Dockerfile`: 定义了构建 PETR 模型运行环境所需的指令，包括基础镜像（PyTorch + CUDA）、系统依赖和 Python 包。
-   `requirements.txt`: 列出了 PETR 运行所需的 Python 依赖。
-   `inference.py`: (包装器脚本) 在 Docker 容器内部运行，负责接收参数并调用位于 `/app/PETR/tools/demo.py` 的主推理脚本。

## 使用流程

### 1. 构建镜像

使用项目根目录下的 `build_model_image.sh` 脚本来构建此模型的 Docker 镜像。

```bash
# 切换到 runpod_docker 目录
cd /home/ian/dev/src/online_mapping/runpod_docker

# 执行构建命令
bash build_model_image.sh PETR
```

这将构建一个名为 `petr-model:latest` 的 Docker 镜像。

### 2. 运行推理

推荐使用 `runpod_docker` 目录下的高级脚本来运行推理：

-   **测试单个样本**: 使用 `run_model_with_mount.sh` 脚本。
    ```bash
    bash run_model_with_mount.sh PETR /path/to/your/petr.pth /path/to/input_dir /path/to/output_dir <sample_token>
    ```
-   **批量比较模型**: 使用 `run_comparison.py` 脚本，它会自动处理所有模型的推理流程。
    ```bash
    python3 run_comparison.py --data_dir <...> --output_dir <...> --model_weights_dir <...> --dataroot <...>
    ```

详细用法请参考根目录下的 `Runpod_Deployment_Dev_Doc.md` 文档。

## 如何完成 `tools/demo.py`

`tools/demo.py` 脚本已经为您搭建好了框架，但您需要完成最关键的一步：**解析模型输出并将其格式化为 JSON**。

请打开 `/home/ian/dev/src/online_mapping/PETR/tools/demo.py` 文件，并找到 `main` 函数中的 **"步骤 4. 处理并保存输出"** 部分。

您需要修改以下代码块：

```python
    # --- 4. 处理并保存��出 ---
    # result 是一个列表，每个元素对应一个批次中的样本
    # 在我们的例子中，批次大小为1，所以我们只关心 result[0]
    pred_dict = result[0]['pts_bbox']
    boxes_3d = pred_dict['boxes_3d'].tensor.cpu().numpy()
    scores_3d = pred_dict['scores_3d'].cpu().numpy()
    labels_3d = pred_dict['labels_3d'].cpu().numpy()

    output_data = []
    for i in range(len(boxes_3d)):
        box = boxes_3d[i]
        # PETR 的 box 格式通常是 [x, y, z, l, w, h, yaw, vx, vy]
        # 您需要确认此处的索引是否正确
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
        output_data.append(output_item)

    # 将结果写入 JSON 文件
    os.makedirs(os.path.dirname(args.out_file), exist_ok=True)
    with open(args.out_file, "w") as f:
        json.dump(output_data, f, indent=4)
    print(f"Inference results saved to: {args.out_file}")
```

**修改指南:**

1.  **确认输出结构**: `result[0]['pts_bbox']` 是 `mmdetection3d` 的标准输出结构。请通过调试或打印 `result[0]` 来确认 PETR 的输出是否遵循此结构。如果不遵循，请相应地修改键名（例如，可能是 `result[0]['boxes_3d']`）。
2.  **确认 Box 格式**: PETR 输出的 `boxes_3d` 张量中，每一行的维度顺序是什么？默认的实现是 `[x, y, z, l, w, h, yaw, vx, vy]`。如果您的模型输出顺序不同（例如，`w` 和 `l` 交换了位置），请务必在 `output_item` 的构建过程中正确地索引它们。
3.  **自定义输出**: 您可以根据需要向 `output_item` 字典中添加或删除任何字段。

完成这一步后，您的 PETR 推理流程就完全打通了。

