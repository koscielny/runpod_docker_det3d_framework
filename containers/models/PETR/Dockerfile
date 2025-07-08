# VS Code Ready PETR Dockerfile  
# 基于VS Code兼容的基础镜像
FROM iankaramazov/ai-models:vscode-base

# 确保Python环境正确
ENV PATH=/opt/conda/bin:/usr/local/bin:/usr/bin:/bin:$PATH
ENV PYTHONPATH=/opt/conda/bin:/usr/local/bin:/usr/bin:/bin

WORKDIR /app

# 验证Python可用性
RUN python --version && python3 --version && which python && which python3

# 安装PETR兼容的最低PyTorch版本 (Python 3.10最低支持1.11.0)
RUN pip install torch==1.11.0 torchvision==0.12.0 torchaudio==0.11.0

# 克隆PETR仓库
RUN git clone https://github.com/koscielny/PETR_docker.git /app/PETR

# 复制并安装模型特定依赖
COPY containers/models/PETR/requirements.txt /tmp/requirements.txt
RUN pip install -r /tmp/requirements.txt

# 复制核心配置文件
COPY config/ /app/config/

# 复制完整的scripts目录
COPY scripts/ /app/scripts/

# 复制工具目录
COPY tools/ /app/tools/

# 复制统一主入口
COPY runpod_platform.sh /app/runpod_platform.sh

# 复制数据集管理脚本
COPY datasets/ /app/datasets/

# 复制测试数据
COPY tests/test_results/test_data/ /app/test_data/

# 复制文档目录
COPY docs/ /app/docs/

# 复制模型特定文件
COPY containers/models/PETR/requirements.txt /app/requirements.txt
COPY containers/models/PETR/inference.py /app/PETR/inference.py
COPY containers/models/PETR/gpu_utils.py /app/gpu_utils.py
COPY containers/shared/entrypoint_optimized.sh /app/entrypoint.sh

# 设置PATH和权限
ENV PATH="/app/scripts/utils:/app/scripts/evaluation:/app/tools:$PATH"
RUN find /app/scripts -name "*.sh" -type f -exec chmod +x {} \;
RUN chmod +x /app/datasets/*.sh /app/runpod_platform.sh /app/entrypoint.sh

# 创建便捷别名
RUN echo 'alias platform="/app/runpod_platform.sh"' >> /root/.bashrc && \
    echo 'alias quick-test="/app/scripts/utils/quick_test.sh"' >> /root/.bashrc && \
    echo 'alias health-check="python /app/tools/health_check.py"' >> /root/.bashrc && \
    echo 'alias model-compare="python /app/tools/model_comparison.py"' >> /root/.bashrc

# 工作目录设置为模型目录
WORKDIR /app/PETR

# 暴露SSH端口
EXPOSE 22

# 设置入口点
ENTRYPOINT ["/app/entrypoint.sh"]

# 默认保持容器运行 (无CMD，让entrypoint处理)
# CMD []