#!/bin/bash

# 这是一个用于为指定模型构建 Docker 镜像的辅助脚本。
# 它会根据模型名称，在对应的子目录中执行 docker build 命令。

# 检查是否提供了模型名称
if [ "$#" -ne 1 ]; then
    echo "用法: $0 <ModelName>"
    echo "例如: $0 MapTR"
    exit 1
fi

MODEL_NAME=$1
MODEL_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)/${MODEL_NAME}
IMAGE_NAME="${MODEL_NAME,,}-model:latest" # 将模型名称转为小写并添加-model:latest后缀

# 检查模型目录是否存在
if [ ! -d "${MODEL_DIR}" ]; then
    echo "错误: 模型目录不存在: ${MODEL_DIR}"
    exit 1
fi

# 检查模型目录中是否存在 Dockerfile
if [ ! -f "${MODEL_DIR}/Dockerfile" ]; then
    echo "错误: 在 ${MODEL_DIR} 中未找到 Dockerfile"
    exit 1
fi

echo "--------------------------------------------------"
echo "正在为模型 '${MODEL_NAME}' 构建镜像..."
echo "镜像名称: ${IMAGE_NAME}"
echo "Dockerfile路径: ${MODEL_DIR}/Dockerfile"
echo "构建上下文: ${MODEL_DIR}"
echo "--------------------------------------------------"

# 执行 Docker build 命令
docker build -t "${IMAGE_NAME}" -f "${MODEL_DIR}/Dockerfile" "${MODEL_DIR}"

# 检查构建是否成功
if [ $? -ne 0 ]; then
    echo "错误: Docker 镜像构建失败: ${MODEL_NAME}"
    exit 1
fi

echo "--------------------------------------------------"
echo "镜像 '${IMAGE_NAME}' 构建成功！"
echo "--------------------------------------------------"
echo "现在您可以将此镜像推送到容器注册中心，例如："
echo "docker push ${IMAGE_NAME}"
echo "或者使用 run_model_with_mount.sh 脚本在本地进行测试。"
