# VS Code Ready StreamPETR Dockerfile  
# 基于VS Code兼容的基础镜像
FROM iankaramazov/ai-models:vscode-base

WORKDIR /app

# 克隆StreamPETR仓库  
RUN git clone https://github.com/koscielny/StreamPETR-docker.git /app/StreamPETR

# 复制必要文件
COPY requirements.txt /app/requirements.txt
COPY inference.py /app/StreamPETR/inference.py
COPY gpu_utils.py /app/gpu_utils.py
COPY ../shared/entrypoint_optimized.sh /app/entrypoint.sh

# 复制评测工具
COPY ../../tools/health_check.py /app/health_check.py
COPY ../../tools/model_output_standard.py /app/model_output_standard.py

# 设置执行权限
RUN chmod +x /app/entrypoint.sh

# 工作目录设置为模型目录
WORKDIR /app/StreamPETR

# 暴露SSH端口
EXPOSE 22

# 设置入口点
ENTRYPOINT ["/app/entrypoint.sh"]

# 默认保持容器运行 (无CMD，让entrypoint处理)
# CMD []