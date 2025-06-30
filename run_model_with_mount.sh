#!/bin/bash

# 此脚本用于在本地 Docker 环境中对单个数据样本运行模型推理。
# 它会将模型权重、输入数据目录和输出目录挂载到容器中，
# 然后调用容器内的推理包装脚本。

# 检查参数数量
if [ "$#" -lt 5 ] || [ "$#" -gt 6 ]; then
    echo "用法: $0 <ModelName> <PathToPthFile> <PathToInputDataDir> <PathToOutputResultsDir> <SampleToken> [ConfigFile]"
    echo "支持的模型: MapTR, PETR, StreamPETR, TopoMLP, VAD"
    echo "例如: $0 PETR /path/to/petr.pth /path/to/input_dir /path/to/output_dir sample_token_xxx"
    echo "     $0 MapTR /path/to/maptr.pth /path/to/input_dir /path/to/output_dir sample_token_xxx"
    echo "     $0 PETR /path/to/petr.pth /path/to/input_dir /path/to/output_dir sample_token_xxx /custom/config.py"
    exit 1
fi

MODEL_NAME=$1
HOST_PTH_FILE_PATH=$2
HOST_INPUT_DIR=$3
HOST_OUTPUT_DIR=$4
SAMPLE_TOKEN=$5
CUSTOM_CONFIG_FILE=$6  # 可选的自定义配置文件

IMAGE_NAME="${MODEL_NAME,,}-model:latest"
PTH_FILENAME=$(basename "${HOST_PTH_FILE_PATH}")
CONTAINER_MODEL_PATH="/app/checkpoints/${PTH_FILENAME}"
CONTAINER_INPUT_FILE="/app/input_data/sample.txt"
CONTAINER_OUTPUT_FILE="/app/output_results/results.json"

echo "--------------------------------------------------"
echo "准备运行模型: ${MODEL_NAME}"
echo "使用镜像: ${IMAGE_NAME}"
echo "挂载模型: ${HOST_PTH_FILE_PATH} -> ${CONTAINER_MODEL_PATH}"
echo "挂载输入目录: ${HOST_INPUT_DIR} -> /app/input_data"
echo "挂载输出目录: ${HOST_OUTPUT_DIR} -> /app/output_results"
echo "处理样本 Token: ${SAMPLE_TOKEN}"
echo "--------------------------------------------------"

# --- 准备工作 ---
# 1. 检查 .pth 文件是否存在
if [ ! -f "${HOST_PTH_FILE_PATH}" ]; then
    echo "错误: 模型权重文件未找到: ${HOST_PTH_FILE_PATH}"
    exit 1
fi

# 2. 创建临时的输入和输出目录（如果它们不存在）
mkdir -p "${HOST_INPUT_DIR}"
mkdir -p "${HOST_OUTPUT_DIR}"

# 3. 将 sample token 写入输入文件
echo "${SAMPLE_TOKEN}" > "${HOST_INPUT_DIR}/sample.txt"
echo "已将 Sample Token 写入 ${HOST_INPUT_DIR}/sample.txt"

# --- 配置文件选择 ---
# 如果提供了自定义配置文件，使用它；否则使用默认配置
if [ -n "${CUSTOM_CONFIG_FILE}" ]; then
    # 用户提供了自定义配置文件
    if [ ! -f "${CUSTOM_CONFIG_FILE}" ]; then
        echo "错误: 自定义配置文件未找到: ${CUSTOM_CONFIG_FILE}"
        exit 1
    fi
    
    # 将自定义配置文件挂载到容器中
    CONTAINER_CONFIG_FILE="/app/custom_config.py"
    CUSTOM_CONFIG_MOUNT="-v ${CUSTOM_CONFIG_FILE}:${CONTAINER_CONFIG_FILE}:ro"
    echo "使用自定义配置文件: ${CUSTOM_CONFIG_FILE}"
else
    # 根据模型名称动态选择默认配置文件
    case "${MODEL_NAME}" in
        "MapTR")
            CONTAINER_CONFIG_FILE="/app/MapTR/projects/configs/maptr/maptr_tiny_r50_24e.py"
            ;;
        "PETR")
            CONTAINER_CONFIG_FILE="/app/PETR/projects/configs/petr/petr_r50dcn_gridmask_p4.py"
            ;;
        "StreamPETR")
            CONTAINER_CONFIG_FILE="/app/StreamPETR/projects/configs/streampetr/streampetr_r50_flash_704_bs2_seq_24e.py"
            ;;
        "TopoMLP")
            CONTAINER_CONFIG_FILE="/app/TopoMLP/configs/topomlp/topomlp_r50_8x1_24e_bs2_4key_256_lss.py"
            ;;
        "VAD")
            CONTAINER_CONFIG_FILE="/app/VAD/projects/configs/VAD/VAD_base.py"
            ;;
        *)
            echo "错误: 不支持的模型名称: ${MODEL_NAME}"
            echo "支持的模型: MapTR, PETR, StreamPETR, TopoMLP, VAD"
            exit 1
            ;;
    esac
    
    CUSTOM_CONFIG_MOUNT=""
    echo "使用默认配置文件: ${CONTAINER_CONFIG_FILE}"
fi

# --- 运行 Docker 容器 ---

docker run --rm --gpus all \
    -v "${HOST_PTH_FILE_PATH}:${CONTAINER_MODEL_PATH}:ro" \
    -v "${HOST_INPUT_DIR}:/app/input_data:ro" \
    -v "${HOST_OUTPUT_DIR}:/app/output_results:rw" \
    ${CUSTOM_CONFIG_MOUNT} \
    "${IMAGE_NAME}" \
    python3 "/app/${MODEL_NAME}/inference.py" \
    --config "${CONTAINER_CONFIG_FILE}" \
    --model-path "${CONTAINER_MODEL_PATH}" \
    --input "${CONTAINER_INPUT_FILE}" \
    --output "${CONTAINER_OUTPUT_FILE}"

if [ $? -ne 0 ]; then
    echo "错误: Docker 容器运行时出现问题。"
    # 清理临时输入文件
    rm "${HOST_INPUT_DIR}/sample.txt"
    exit 1
fi

# --- 清理和总结 ---
rm "${HOST_INPUT_DIR}/sample.txt"
echo "--------------------------------------------------"
echo "模型 ${MODEL_NAME} 在 Docker 中运行完毕。"
echo "推理结��已保存在: ${HOST_OUTPUT_DIR}/results.json"
echo "--------------------------------------------------"
