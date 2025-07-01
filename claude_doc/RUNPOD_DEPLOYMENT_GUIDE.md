# RunPod 部署完整指南

## 🎯 概述

本指南提供从购买RunPod实例到成功部署多模型评测框架的完整步骤清单。适用于在RunPod云平台上部署MapTR、PETR、StreamPETR、TopoMLP、VAD等3D检测和地图构建模型。

## 🛒 第一步：购买和设置 RunPod

### 1.1 注册账户
```bash
# 访问 https://runpod.io
# 注册账户并完成邮箱验证
# 添加付款方式（信用卡或充值余额）
```

### 1.2 选择Pod Template（推荐配置）

**🔥 强烈推荐模板：**

1. **PyTorch 2.1** (最兼容)
   - 基础镜像：`runpod/pytorch:2.1.0-py3.10-cuda11.8.0-devel-ubuntu22.04`
   - 预装：PyTorch 2.1, CUDA 11.8, Python 3.10
   - 优点：版本较新，兼容性好，性能优秀
   - ⚠️ 需要：需要调整我们的Dockerfile基础镜像

2. **PyTorch 1.13** (完美匹配) ⭐
   - 基础镜像：`runpod/pytorch:1.13.0-py3.10-cuda11.7.1-devel`
   - 预装：PyTorch 1.13, CUDA 11.7, Python 3.10
   - 优点：与我们的CUDA 11.1接近，兼容性好
   - 推荐理由：版本最接近我们的需求

3. **Universal Template** (灵活选择)
   - 基础镜像：`runpod/base:0.4.0-cuda11.8.0`
   - 预装：基础CUDA环境
   - 优点：最大灵活性，可以完全按需配置
   - 适合：需要完全控制环境的高级用户

**💰 GPU实例推荐：**

| GPU型号 | 显存 | 价格/小时 | 推荐用途 | 性价比 |
|---------|------|----------|----------|--------|
| **RTX A5000** | 24GB | ~$0.50 | 🔥推荐-完整评测 | ⭐⭐⭐⭐⭐ |
| RTX 4090 | 24GB | ~$0.70 | 高性能评测 | ⭐⭐⭐⭐ |
| RTX 3090 | 24GB | ~$0.45 | 预算友好 | ⭐⭐⭐⭐⭐ |
| RTX A6000 | 48GB | ~$0.80 | 大规模评测 | ⭐⭐⭐ |
| RTX 4080 | 16GB | ~$0.40 | 单模型测试 | ⭐⭐⭐ |

### 1.3 启动实例配置
```bash
# 在RunPod控制台设置：
# 1. 选择 "GPU Pods"
# 2. 选择推荐的Pod Template
# 3. 配置存储空间 (推荐 150GB+)
# 4. 设置容器磁盘空间 (50GB+)
# 5. 设置端口映射 (SSH: 22, HTTP: 8080)
# 6. 点击 "Deploy" 启动实例
```

**存储配置建议：**
- **容器磁盘**: 50GB (Docker镜像和模型)
- **卷存储**: 100GB (数据集和结果)
- **网络存储**: 可选，用于持久化

## 🔧 第二步：连接和初始化

### 2.1 SSH连接设置
```bash
# 方法1：使用RunPod提供的SSH命令
ssh root@<pod-id>-<port>.proxy.runpod.net -p <port>

# 方法2：使用Web Terminal (在浏览器中)
# 点击实例的 "Connect" -> "Start Web Terminal"

# 方法3：使用Jupyter Lab
# 点击实例的 "Connect" -> "Connect to Jupyter Lab"
```

### 2.2 系统初始化
```bash
# 更新系统包
apt update && apt upgrade -y

# 安装必要工具
apt install -y git wget curl htop tree unzip

# 安装GPU监控工具
apt install -y nvtop

# 验证GPU和CUDA
nvidia-smi
nvcc --version
```

### 2.3 验证环境
```bash
# 检查Python和PyTorch
python3 --version
python3 -c "import torch; print(f'PyTorch: {torch.__version__}'); print(f'CUDA Available: {torch.cuda.is_available()}')"

# 检查Docker
docker --version
docker ps
```

## 📦 第三步：部署评测框架

### 3.1 克隆项目
```bash
# 切换到工作目录
cd /workspace  # RunPod默认工作目录

# 克隆评测框架
git clone https://github.com/yilan-slam/runpod_docker_det3d_framework.git
cd runpod_docker_det3d_framework

# 验证文件结构
tree -L 2
```

### 3.2 系统验证
```bash
# 设置执行权限
chmod +x *.sh
chmod +x claude_doc/*.sh

# 运行快速测试
./quick_test.sh

# 期望输出：
# ✅ 脚本语法检查通过
# ✅ Python模块导入成功  
# ✅ 输出标准化测试通过
# ✅ 健康检查测试通过
```

### 3.3 环境配置（如果需要）
```bash
# 如果使用PyTorch 2.1模板，需要调整Dockerfile
# 编辑所有模型的Dockerfile，将基础镜像改为：
# FROM pytorch/pytorch:2.1.0-cuda11.8-cudnn8-devel

# 更新requirements.txt中的PyTorch版本：
# torch==2.1.0
# torchvision==0.16.0

# 如果使用Universal模板，需要安装Python和基础包
pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu118
```

## 🐳 第四步：构建Docker镜像

### 4.1 构建所有模型镜像
```bash
# 构建所有模型的Docker镜像
./build_model_image.sh

# 构建过程约30-60分钟，依次构建：
# 1. MapTR (HD地图构建)
# 2. PETR (多视角3D检测)
# 3. StreamPETR (时序3D检测)  
# 4. TopoMLP (拓扑推理)
# 5. VAD (矢量化自动驾驶)
```

### 4.2 验证镜像构建
```bash
# 检查构建的镜像
docker images | grep -E "(maptr|petr|streampetr|topomlp|vad)"

# 期望输出：每个镜像约5-8GB
# maptr-runpod    latest    abc123    5.2GB
# petr-runpod     latest    def456    4.8GB
# streampetr-runpod latest  ghi789    5.1GB
# topomlp-runpod  latest    jkl012    4.5GB
# vad-runpod      latest    mno345    5.5GB
```

### 4.3 磁盘空间检查
```bash
# 检查磁盘使用情况
df -h

# 如果空间不足，清理Docker缓存
docker system prune -a -f

# 检查Docker镜像大小
docker images --format "{{.Repository}}:{{.Tag}} {{.Size}}"
```

## 🏥 第五步：健康检查

### 5.1 系统健康验证
```bash
# 运行完整健康检查
./run_model_evaluation.sh --health-check

# 期望输出：
# 🏥 系统健康检查
# ✅ MapTR: 健康
# ✅ PETR: 健康  
# ✅ StreamPETR: 健康
# ✅ TopoMLP: 健康
# ✅ VAD: 健康
```

### 5.2 单独检查每个模型
```bash
# 检查各个模型的健康状态
python claude_doc/health_check.py --model MapTR --mode check
python claude_doc/health_check.py --model PETR --mode check
python claude_doc/health_check.py --model StreamPETR --mode check
python claude_doc/health_check.py --model TopoMLP --mode check
python claude_doc/health_check.py --model VAD --mode check
```

### 5.3 配置验证
```bash
# 列出所有可用配置
./list_model_configs.sh

# 验证配置文件完整性
python validate_config.py --help

# 测试配置验证
python validate_config.py --config /app/MapTR/projects/configs/maptr/maptr_tiny_r50_24e.py --model MapTR
```

## 📊 第六步：运行测试评估

### 6.1 准备测试数据
```bash
# 创建测试数据目录
mkdir -p /workspace/test_data

# 创建模拟测试数据
echo "sample_test_token_001" > /workspace/test_data/sample.txt
echo "sample_test_token_002" > /workspace/test_data/sample2.txt

# 创建测试配置
export DATA_PATH="/workspace/test_data/sample.txt"
```

### 6.2 单模型测试
```bash
# 测试MapTR (HD地图构建)
./run_model_evaluation.sh --single-model MapTR --data-path $DATA_PATH

# 测试PETR (3D检测)
./run_model_evaluation.sh --single-model PETR --data-path $DATA_PATH

# 测试StreamPETR (时序检测)
./run_model_evaluation.sh --single-model StreamPETR --data-path $DATA_PATH

# 测试TopoMLP (拓扑推理)
./run_model_evaluation.sh --single-model TopoMLP --data-path $DATA_PATH

# 测试VAD (矢量化驾驶)
./run_model_evaluation.sh --single-model VAD --data-path $DATA_PATH
```

### 6.3 多模型比较评测
```bash
# 运行完整评测 (推荐)
./run_model_evaluation.sh --full-evaluation

# 比较特定模型组合
./run_model_evaluation.sh --compare-models --models MapTR,PETR,VAD

# 快速比较 (仅检测模型)
./run_model_evaluation.sh --compare-models --models PETR,StreamPETR,TopoMLP
```

### 6.4 性能基准测试
```bash
# 运行性能基准测试
./run_model_evaluation.sh --benchmark --iterations 10

# 压力测试
./run_model_evaluation.sh --stress-test --duration 30m
```

## 📈 第七步：查看和分析结果

### 7.1 检查评测结果
```bash
# 查看生成的结果目录
ls -la evaluation_results/

# 典型结果结构：
# evaluation_results/
# ├── comparison_report.json       # 模型比较报告
# ├── individual_results/          # 单模型结果
# ├── visualizations/              # 可视化图表
# ├── performance_metrics.json     # 性能指标
# └── system_info.json            # 系统信息
```

### 7.2 查看比较报告
```bash
# 查看JSON格式报告
cat evaluation_results/comparison_report.json | python -m json.tool

# 查看性能指标
cat evaluation_results/performance_metrics.json | python -m json.tool

# 查看可视化文件
ls evaluation_results/visualizations/
# 应该包含：
# - radar_chart.png (雷达图)
# - performance_bar_chart.png (柱状图)
# - memory_usage_chart.png (内存使用图)
```

### 7.3 分析结果示例
```bash
# 提取关键性能指标
python3 -c "
import json
with open('evaluation_results/comparison_report.json') as f:
    data = json.load(f)
    
print('=== 模型性能排名 ===')
ranking = data['performance_ranking']
for metric, models in ranking.items():
    print(f'{metric}: {models[0]}')
"
```

## 🔧 第八步：高级功能验证

### 8.1 SSH开发环境测试
```bash
# 启动SSH服务器
./start_ssh_server.sh

# 验证SSH连接（在本地机器上）
# ssh runpod@<runpod-ip> -p 22
```

### 8.2 数据集管理测试
```bash
# 进入数据集管理目录
cd claude_doc

# 查看数据集下载指南
cat DATASET_DOWNLOAD_GUIDE.md

# 测试数据集脚本（不实际下载）
./download_datasets.sh --help
```

### 8.3 健康监控HTTP端点
```bash
# 启动健康检查HTTP服务器
python claude_doc/health_check.py --mode server --port 8080 &

# 测试HTTP端点
curl http://localhost:8080/health

# 在RunPod外部访问（使用公开端口）
# curl http://<runpod-public-ip>:8080/health
```

## 🔍 故障排除指南

### 常见问题1：Docker构建失败
```bash
# 检查磁盘空间
df -h

# 如果空间不足
docker system prune -a -f
apt autoremove -y

# 检查网络连接
ping github.com

# 重新构建特定模型
docker build -t maptr-runpod ./MapTR/
```

### 常见问题2：GPU内存不足
```bash
# 检查GPU使用情况
nvidia-smi

# 清理GPU内存
python3 -c "import torch; torch.cuda.empty_cache()"

# 重启Docker服务
sudo systemctl restart docker

# 降低批处理大小
export BATCH_SIZE=1
```

### 常见问题3：模型推理失败
```bash
# 检查模型文件权限
ls -la /workspace/models/

# 检查Docker容器日志
docker logs <container_name>

# 重新运行健康检查
./run_model_evaluation.sh --health-check

# 查看详细错误信息
./run_model_evaluation.sh --single-model MapTR --data-path $DATA_PATH --verbose
```

### 常见问题4：网络和连接问题
```bash
# 检查RunPod端口配置
# 确保在RunPod控制台中开放了必要端口：22 (SSH), 8080 (HTTP)

# 检查防火墙
ufw status

# 重启网络服务
systemctl restart networking
```

## 💡 性能优化建议

### GPU优化
```bash
# 设置CUDA环境变量
export CUDA_VISIBLE_DEVICES=0
export TORCH_CUDA_ARCH_LIST="8.6"  # RTX A5000
export CUDA_LAUNCH_BLOCKING=0  # 异步执行

# GPU内存管理
export PYTORCH_CUDA_ALLOC_CONF=max_split_size_mb:512
```

### 并行化设置
```bash
# 多进程推理
export OMP_NUM_THREADS=8
export MKL_NUM_THREADS=8

# 并行模型比较
./run_model_evaluation.sh --parallel --workers 2
```

### 缓存优化
```bash
# 启用Docker层缓存
export DOCKER_BUILDKIT=1

# 设置PyTorch缓存
export TORCH_HOME=/workspace/.torch
mkdir -p $TORCH_HOME
```

## 📋 部署成功检查清单

### ✅ 部署前检查
- [ ] RunPod实例正常启动 (GPU: RTX A5000/4090/3090)
- [ ] SSH连接成功建立
- [ ] GPU驱动和CUDA正常工作 (`nvidia-smi`)
- [ ] Docker服务运行正常 (`docker ps`)
- [ ] 网络连接稳定 (`ping github.com`)
- [ ] 磁盘空间充足 (>100GB可用)

### ✅ 构建验证
- [ ] 项目代码成功克隆
- [ ] `./quick_test.sh` 全部通过
- [ ] 所有5个Docker镜像构建成功
- [ ] 镜像大小合理 (每个4-8GB)
- [ ] 无构建错误或警告

### ✅ 功能验证  
- [ ] 健康检查全部通过 (`--health-check`)
- [ ] 至少3个模型能成功推理
- [ ] 多模型比较能正常运行
- [ ] 生成可视化结果文件
- [ ] HTTP健康端点响应正常

### ✅ 性能验证
- [ ] 单模型推理时间 <1秒
- [ ] GPU内存使用合理 (<20GB)
- [ ] 系统资源使用正常
- [ ] 没有内存泄漏问题

## 💰 费用控制和预算

### 预算估算
```bash
# 开发测试阶段 (RTX A5000 @ $0.50/hour)
# - 初始部署和测试: 2-4小时 = $1-2
# - 功能验证: 2-3小时 = $1-1.5  
# - 性能调优: 3-5小时 = $1.5-2.5
# 总计: $3.5-6

# 完整评测阶段
# - 全模型评测: 4-6小时 = $2-3
# - 数据集测试: 6-10小时 = $3-5
# - 报告生成: 1-2小时 = $0.5-1
# 总计: $5.5-9

# 建议预算: $15-20 (包含调试和重试时间)
```

### 节省费用技巧
```bash
# 1. 及时暂停实例
# 完成测试后在RunPod控制台点击 "Stop"
# 数据会保留在卷存储中，只停止GPU计费

# 2. 批量处理任务
./run_model_evaluation.sh --full-evaluation --batch-mode

# 3. 使用spot实例
# 在RunPod中选择 "Spot" 实例，价格可低30-50%

# 4. 选择合适的GPU
# RTX 3090 (24GB): 最便宜，性能足够
# RTX A5000 (24GB): 性价比最好
# RTX 4090 (24GB): 性能最强，价格较高
```

## 🎯 部署成功标志

当你看到以下完整输出时，说明部署完全成功：

```bash
🎉 RunPod多模型评测系统部署成功！

📊 系统状态:
  ✅ GPU: RTX A5000 (24GB) - 正常工作
  ✅ CUDA: 11.8 - 兼容
  ✅ Docker: 5个模型镜像构建成功
  ✅ 健康检查: 全部通过

📋 可用功能:
  ✅ 标准化输出格式 - 统一所有模型输出
  ✅ 健康检查端点 - 验证模型和系统状态  
  ✅ 模型比较分析 - 多维度性能对比
  ✅ 配置动态管理 - 灵活的配置文件支持
  ✅ SSH开发环境 - VS Code远程开发
  ✅ 数据集管理 - 自动化下载和验证

🚀 快速开始命令:
  ./run_model_evaluation.sh --health-check
  ./run_model_evaluation.sh --full-evaluation
  ./run_model_evaluation.sh --compare-models --models MapTR,PETR,VAD

📈 预期性能 (RTX A5000):
  MapTR: ~0.20s, 2.0GB VRAM
  PETR: ~0.15s, 1.7GB VRAM  
  StreamPETR: ~0.18s, 1.9GB VRAM
  TopoMLP: ~0.12s, 1.4GB VRAM
  VAD: ~0.25s, 2.2GB VRAM

🎯 系统已完全就绪，开始你的多模型评测之旅！
```

## 📞 技术支持

### 故障诊断
1. 首先运行 `./quick_test.sh` 进行系统自检
2. 查看 `claude_doc/TODO.md` 了解已知问题
3. 运行 `./run_model_evaluation.sh --health-check` 获取详细状态

### 文档资源
- `claude_doc/EVALUATION_GUIDE.md`: 完整评测工作流程
- `claude_doc/DATASET_DOWNLOAD_GUIDE.md`: 数据集设置说明  
- `claude_doc/IMPLEMENTATION_DETAILS.md`: 技术实现详情
- `SYSTEM_SUMMARY.md`: 项目完成总结

### 社区支持
- GitHub Issues: 报告问题和获取帮助
- RunPod Discord: RunPod平台相关问题
- 项目文档: 完整的使用和开发指南

---

通过遵循这个详细的部署指南，你应该能够在RunPod上成功部署并运行完整的多模型3D检测和地图构建评测系统！