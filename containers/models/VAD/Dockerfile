# VAD Application Image
# 基于vad-mmlibs添加VAD应用和配置
FROM iankaramazov/ai-models:vad-mmlibs

# 克隆VAD仓库
RUN git clone https://github.com/koscielny/VAD_docker.git /app/VAD && \
    cd /app/VAD && \
    git checkout runpod/init

# 复制VAD requirements并安装
COPY containers/models/VAD/requirements_official.txt /tmp/vad_requirements.txt
RUN pip install --no-cache-dir -r /tmp/vad_requirements.txt

# 复制模型特定文件
COPY containers/models/VAD/inference.py /app/VAD/inference.py

# 复制共享脚本
COPY containers/shared/entrypoint_optimized.sh /app/entrypoint.sh

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

# 设置权限
RUN chmod +x /app/entrypoint.sh

# 创建便捷别名
RUN echo 'alias vad="cd /app/VAD && python inference.py"' >> /root/.bashrc

# 工作目录设置为模型目录
WORKDIR /app/VAD

# 暴露SSH端口
EXPOSE 22

# 设置入口点
ENTRYPOINT ["/app/entrypoint.sh"]