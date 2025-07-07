# VS Code Ready VAD Dockerfile (Simple Version)
# 基于VS Code兼容的基础镜像
FROM iankaramazov/ai-models:vscode-base

WORKDIR /app

# 安装MMCV兼容当前PyTorch版本 (2.0.1)
RUN pip install mmcv-full==1.7.0 -f https://download.openmmlab.com/mmcv/dist/cu117/torch2.0.0/index.html

# 克隆VAD仓库（跳过mmdetection3d依赖）
RUN git clone https://github.com/koscielny/VAD_docker.git /app/VAD && \
    cd /app/VAD && \
    git checkout runpod/init

# 安装核心依赖（跳过有问题的包）
RUN pip install --no-cache-dir \
    numpy \
    opencv-python \
    plotly \
    scikit-image \
    scikit-learn \
    scipy \
    shapely \
    timm \
    psutil

# 复制必要文件
COPY inference.py /app/VAD/inference.py
COPY ../shared/entrypoint_optimized.sh /app/entrypoint.sh

# 复制评测工具
COPY ../../tools/health_check.py /app/health_check.py
COPY ../../tools/model_output_standard.py /app/model_output_standard.py

# 设置执行权限
RUN chmod +x /app/entrypoint.sh

# 工作目录设置为模型目录
WORKDIR /app/VAD

# 暴露SSH端口
EXPOSE 22

# 设置入口点
ENTRYPOINT ["/app/entrypoint.sh"]

# 默认保持容器运行 (无CMD，让entrypoint处理)
# CMD []