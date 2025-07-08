# PETR Application Image
# 基于petr-mmlibs添加PETR应用和配置
FROM iankaramazov/ai-models:petr-mmlibs

# 克隆PETR仓库
RUN git clone https://github.com/koscielny/PETR_docker.git /app/PETR

# 复制PETR requirements并安装
COPY containers/models/PETR/requirements.txt /tmp/petr_requirements.txt
RUN pip install --no-cache-dir -r /tmp/petr_requirements.txt

# 复制模型特定文件
COPY containers/models/PETR/inference.py /app/PETR/inference.py

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
RUN echo 'alias petr="cd /app/PETR && python inference.py"' >> /root/.bashrc

# 工作目录设置为模型目录
WORKDIR /app/PETR

# 暴露SSH端口
EXPOSE 22

# 设置入口点
ENTRYPOINT ["/app/entrypoint.sh"]