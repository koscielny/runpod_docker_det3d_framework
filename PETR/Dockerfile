# VS Code Ready PETR Dockerfile  
# 基于VS Code兼容的基础镜像
FROM iankaramazov/ai-models:vscode-base

WORKDIR /app

# 克隆PETR仓库
RUN git clone https://github.com/koscielny/PETR_docker.git /app/PETR

# 复制必要文件
COPY PETR/requirements.txt /app/requirements.txt
COPY PETR/inference.py /app/PETR/inference.py
COPY gpu_utils.py /app/gpu_utils.py
COPY entrypoint_optimized.sh /app/entrypoint.sh

# 设置执行权限
RUN chmod +x /app/entrypoint.sh

# 工作目录设置为模型目录
WORKDIR /app/PETR

# 暴露SSH端口
EXPOSE 22

# 设置入口点
ENTRYPOINT ["/app/entrypoint.sh"]

# 默认保持容器运行 (无CMD，让entrypoint处理)
# CMD []