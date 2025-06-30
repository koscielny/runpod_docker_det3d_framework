# 多模型评测和比较指南

这是一个为个人使用设计的多模型Docker评测和比较项目，帮助你理解各个模型的特性和优劣。

## 🎯 **项目目标**

- 🔍 **模型理解**: 通过标准化输出比较不同模型的能力
- ⚡ **性能评测**: 评估推理速度、内存使用等性能指标
- 📊 **可视化比较**: 生成直观的图表和报告
- 🛠️ **易于使用**: 简化的命令行界面，复杂度较低

## 📋 **功能特性**

### ✅ **已实现的中优先级功能**

1. **标准化输出格式** - 统一所有模型的输出结构，便于比较
2. **健康检查端点** - 快速验证模型是否正常工作
3. **模型比较分析** - 自动生成性能比较报告和可视化图表

### 🎨 **输出标准化**
- 统一的3D检测、地图元素、轨迹预测格式
- 自动转换各模型的原始输出为标准格式
- 保留原始输出用于调试

### 🏥 **健康检查**
- 系统资源监控 (CPU、内存、GPU)
- 模型文件完整性检查
- 依赖项验证
- 功能测试 (PyTorch、CUDA操作)

### 📊 **性能比较**
- 推理时间对比
- GPU内存使用分析
- 检测能力评估
- 置信度统计
- 雷达图和柱状图可视化

## 🚀 **快速开始**

### **1. 健康检查**
```bash
# 检查所有模型的健康状态
./run_model_evaluation.sh --health-check

# 检查特定模型
./run_model_evaluation.sh --health-check --models MapTR,PETR
```

### **2. 单模型评测**
```bash
# 评测MapTR模型
./run_model_evaluation.sh --single-model MapTR --data-path /data/test_sample.txt

# 使用自定义checkpoint
./run_model_evaluation.sh --single-model PETR --data-path /data/test.txt --checkpoint /path/to/model.pth
```

### **3. 多模型比较**
```bash
# 完整评测流程 (推荐)
./run_model_evaluation.sh --full-evaluation --models MapTR,PETR,VAD

# 只比较已有结果
./run_model_evaluation.sh --compare-models
```

### **4. 高级选项**
```bash
# 自定义输出目录
./run_model_evaluation.sh --full-evaluation --output-dir /my/results

# 跳过健康检查
./run_model_evaluation.sh --full-evaluation --skip-health

# 保持容器运行以便调试
./run_model_evaluation.sh --single-model MapTR --keep-containers
```

## 📁 **输出结构**

```
evaluation_results/
├── health_reports/              # 健康检查报告
│   ├── MapTR_health.json
│   ├── PETR_health.json
│   └── health_summary.json
├── model_outputs/               # 单模型输出
│   ├── MapTR/
│   │   ├── input/
│   │   ├── output/
│   │   └── standardized_output.json
│   └── PETR/
├── comparison/                  # 模型比较结果
│   ├── comparison_report.json
│   ├── performance_comparison.csv
│   ├── model_comparison_charts.png
│   └── model_radar_comparison.png
├── evaluation_summary.json     # 总体评测摘要
└── logs/                       # 日志文件
```

## 🔧 **配置和自定义**

### **模型配置**
每个模型使用标准化的配置管理：
```bash
# 查看可用配置
./list_model_configs.sh

# 验证配置文件
./validate_config.py MapTR /path/to/config.py

# 使用自定义配置运行
./run_model_with_mount.sh MapTR /path/to/model.pth /input /output sample_token /custom/config.py
```

### **输出格式自定义**
标准化输出格式包含：
- **检测结果**: 3D边界框、类别、置信度
- **地图元素**: 向量化道路元素
- **轨迹预测**: 未来轨迹预测
- **规划轨迹**: 路径规划结果
- **元数据**: 推理时间、GPU使用等

### **比较指标自定义**
可以在 `model_comparison.py` 中自定义比较指标：
- 推理速度权重
- 内存使用阈值
- 置信度过滤条件
- 可视化样式

## 📊 **理解比较结果**

### **性能排名指标**
- **fastest_inference**: 推理速度最快的模型
- **lowest_memory**: GPU内存使用最少的模型
- **most_detections**: 检测目标数量最多的模型
- **highest_confidence**: 平均置信度最高的模型

### **雷达图解读**
雷达图显示模型在四个维度的综合表现：
- **推理速度**: 值越高表示速度越快
- **GPU效率**: 值越高表示内存使用越少
- **检测能力**: 值越高表示检测目标越多
- **置信度**: 值越高表示模型越自信

### **分析洞察示例**
```json
{
  "insights": [
    "推理速度：PETR 比 MapTR 快 1.4x",
    "内存效率：TopoMLP 比 VAD 节省 512MB GPU内存",
    "检测能力：MapTR 检测到最多目标，平均检测数量 15.2",
    "置信度：PETR 具有最高平均置信度，整体平均 0.847"
  ]
}
```

## 🛠️ **故障排除**

### **常见问题**

1. **Docker镜像不存在**
```bash
# 构建所需的Docker镜像
docker build -t maptr-model:latest ./MapTR/
docker build -t petr-model:latest ./PETR/
```

2. **GPU不可用**
```bash
# 检查NVIDIA驱动和Docker GPU支持
nvidia-smi
docker run --rm --gpus all nvidia/cuda:11.1-base nvidia-smi
```

3. **Python依赖缺失**
```bash
# 安装必要的Python包
pip install pandas matplotlib seaborn numpy
```

4. **权限问题**
```bash
# 确保脚本有执行权限
chmod +x run_model_evaluation.sh
chmod +x list_model_configs.sh
```

### **调试技巧**

1. **保持容器运行**
```bash
./run_model_evaluation.sh --single-model MapTR --keep-containers
# 然后可以进入容器调试
docker exec -it container_name bash
```

2. **查看详细日志**
```bash
# 检查健康状态
python3 claude_doc/health_check.py --model MapTR --mode comprehensive

# 手动运行推理
./run_model_with_mount.sh MapTR /path/to/model.pth /input /output sample_token
```

3. **验证输出格式**
```bash
# 检查标准化输出
python3 -c "
from claude_doc.model_output_standard import create_standardizer
standardizer = create_standardizer('MapTR')
# ... 测试代码
"
```

## 🎯 **使用建议**

### **评测流程建议**
1. **先运行健康检查**: 确保所有模型容器正常
2. **单模型验证**: 逐个测试每个模型
3. **完整比较**: 运行完整的多模型比较
4. **结果分析**: 查看可视化图表和分析报告

### **模型选择建议**
根据你的需求选择合适的模型：
- **速度优先**: 选择推理时间最短的模型
- **精度优先**: 选择置信度最高、检测最全面的模型
- **资源受限**: 选择GPU内存使用最少的模型
- **功能需求**: 根据需要3D检测、地图构建、轨迹预测等功能选择

### **扩展建议**
- 添加更多评测指标 (准确率、召回率等)
- 支持批量数据评测
- 集成更多可视化工具
- 添加模型训练性能对比

## 📚 **相关文档**

- [Docker配置指南](./IMPLEMENTATION_DETAILS.md)
- [数据集下载指南](./DATASET_DOWNLOAD_GUIDE.md)
- [配置文件管理](./list_model_configs.sh)
- [健康检查详情](./health_check.py)

---

这个评测项目帮助你轻松比较不同的自动驾驶感知模型，理解它们的特性和适用场景。通过标准化的接口和直观的可视化，你可以快速获得有价值的模型对比信息。