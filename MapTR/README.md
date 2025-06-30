# MapTR 模型在 Runpod 上的部署

此目录包含在 Runpod 上部署 MapTR 模型所需的 Dockerfile 和一个简单的启动脚本。

## 架构

本部署方案遵循关注点分离的原则：

-   **模型推理**: 核心的推理逻辑由 MapTR 项目自身的 `tools/demo.py` 脚本负责。
-   **环境与执行**: 此目录下的 `Dockerfile` 用于构建一个包含所有依赖的、可移植的运行环境。`inference.py` 脚本则充当一个简单的包装器，负责在 Docker 容器内调用 `tools/demo.py`。

这种设计使得模型代码库保持独立和标准，同时简化了部署流程。

## 文件说明

-   `Dockerfile`: 定义了构建 MapTR 模型运行环境所需的指令，包括基础镜像（PyTorch + CUDA）、系统依赖和 Python 包。
-   `requirements.txt`: 列出了 MapTR 运行所需的 Python 依赖。
-   `inference.py`: (包装器脚本) 在 Docker 容器内部运行，负责接收参数并调用位于 `/app/MapTR/tools/demo.py` 的主推理脚本。

## 使用流程

### 1. 构建镜像

使用项目根目录下的 `build_model_image.sh` 脚本来构建此模型的 Docker 镜像。

```bash
# 切换到 runpod_docker 目录
cd /home/ian/dev/src/online_mapping/runpod_docker

# 执行构建命令
bash build_model_image.sh MapTR
```

这将构建一个名为 `maptr-model:latest` 的 Docker 镜像。

### 2. 运行推理

推荐使用 `runpod_docker` 目录下的高级脚本来运行推理：

-   **测试单个样本**: 使用 `run_model_with_mount.sh` 脚本。
    ```bash
    bash run_model_with_mount.sh MapTR /path/to/your/maptr.pth /path/to/input_dir /path/to/output_dir <sample_token>
    ```
-   **批量比较模型**: 使用 `run_comparison.py` 脚本，它会自动处理所有模型的推理流程。
    ```bash
    python3 run_comparison.py --data_dir <...> --output_dir <...> --model_weights_dir <...> --dataroot <...>
    ```

详细用法请参考根目录下的 `Runpod_Deployment_Dev_Doc.md` 文档。

## 如何完成 `tools/demo.py`

`tools/demo.py` 脚本已经为您搭建好了框架，但您需要完成最关键的一步：**解析 MapTR 模型的独特输出并将其格式化为 JSON**。

与标准的3D目标检测器不同，MapTR 输出的是矢量化的地图元素（如车道线中心线、路沿等）。您需要根据 MapTR 的具体实现来解析这些输出。

请打开 `/home/ian/dev/src/online_mapping/MapTR/tools/demo.py` 文件，并找到 `main` 函数中的 **"步骤 4. 处理并保存输出"** 部分。

您需要修改以下代码块：

```python
    # --- 4. 处理并保存输出 ---
    # MapTR 的输出格式可能与其他模型不同，这里需要根据实际情况调整
    # 假设 result[0] 包含 'vectors' 键，这是一个常见的地图元素输出格式
    if 'vectors' in result[0]:
        vectors = result[0]['vectors']
        output_data = []
        for vector in vectors:
            # 这是一个示例，您需要根据 MapTR 的实际输出来解析
            # 'pts' 可能是一系列点的坐标 (x, y, z)
            # 'cls_name' 可能是 'lane_centerline', 'road_curb' 等
            output_item = {
                'points': vector['pts'].tolist(),
                'point_count': vector['pts_num'],
                'class_name': vector['cls_name'],
                'score': float(vector['score']),
            }
            output_data.append(output_item)
    else:
        print("Warning: 'vectors' key not found in model output. Saving raw result.")
        # 如果格式未知，可以先打印 result[0] 的所有键，以确定正确的输出键
        print(f"Available keys in result: {result[0].keys()}")
        output_data = {"raw_result": "Unsupported format for direct JSON conversion"}

    # 将结果写入 JSON 文件
    os.makedirs(os.path.dirname(args.out_file), exist_ok=True)
    with open(args.out_file, "w") as f:
        json.dump(output_data, f, indent=4)
    print(f"Inference results saved to: {args.out_file}")
```

**修改指南:**

1.  **确认输出结构**: 通过调试或打印 `result[0].keys()` 来确定 MapTR 模型输出的主要键是什么。它很可能不是 `'pts_bbox'`，而可能是 `'vectors'`, `'map_elements'` 或其他自定义键。
2.  **解析矢量数据**: 遍历模型输出的每个矢量元素。每个元素可能包含：
    *   一系列点的坐标 (`vector['pts']`)。
    *   点的数量 (`vector['pts_num']`)。
    *   元素的类别 (`vector['cls_name']` 或 `vector['label']`)。
    *   置信度分数 (`vector['score']`)。
3.  **格式化输出**: 将解析出的数据组织成一个清晰的 JSON 结构，如示例中的 `output_item`。

完成这一步后，您的 MapTR 推理流程就完全打通了。

