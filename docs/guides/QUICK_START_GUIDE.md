# 快速开始指南

## 🚀 一分钟上手RunPod多模型AI评测平台

使用新的统一主入口脚本，您只需要一个命令就能完成所有操作！

## 📋 第一次使用

### 1. 环境检查
```bash
./runpod_platform.sh setup --check-only
```
检查Docker、GPU和项目文件是否准备就绪。

### 2. 查看系统状态
```bash
./runpod_platform.sh status
```
了解当前系统配置和资源使用情况。

## 🏗️ 构建和部署

### 构建单个模型
```bash
# 构建MapTR模型
./runpod_platform.sh build MapTR

# 构建并推送到Docker Hub
./runpod_platform.sh build PETR --push
```

### 构建所有模型
```bash
# 构建所有模型（使用缓存）
./runpod_platform.sh build all

# 无缓存构建所有模型
./runpod_platform.sh build all --no-cache
```

## 🏥 健康检查

### 检查所有模型
```bash
./runpod_platform.sh health
```

### 检查特定模型
```bash
./runpod_platform.sh health MapTR --detailed
```

## 🧪 模型测试

### 快速测试
```bash
# 使用默认测试数据
./runpod_platform.sh test MapTR --quick
```

### 完整测试
```bash
# 使用自定义数据
./runpod_platform.sh test PETR --data /path/to/data --output /path/to/results
```

## 📊 模型比较

### 比较所有模型
```bash
./runpod_platform.sh compare
```

### 比较特定模型
```bash
./runpod_platform.sh compare --models "MapTR,PETR,VAD"
```

## 🧹 清理资源

### 清理所有资源
```bash
./runpod_platform.sh clean --all
```

### 只清理Docker镜像
```bash
./runpod_platform.sh clean --images
```

## 💡 获取帮助

### 查看所有命令
```bash
./runpod_platform.sh help
```

### 查看特定命令帮助
```bash
./runpod_platform.sh help build
./runpod_platform.sh help test
./runpod_platform.sh help compare
```

## 🎯 典型工作流

### 新用户完整流程
```bash
# 1. 检查环境
./runpod_platform.sh setup

# 2. 构建模型镜像
./runpod_platform.sh build all

# 3. 健康检查
./runpod_platform.sh health

# 4. 快速测试
./runpod_platform.sh test MapTR --quick

# 5. 模型比较
./runpod_platform.sh compare
```

### 日常开发流程
```bash
# 1. 查看状态
./runpod_platform.sh status

# 2. 构建更新的模型
./runpod_platform.sh build PETR

# 3. 测试特定功能
./runpod_platform.sh test PETR --data /custom/data

# 4. 清理资源
./runpod_platform.sh clean --cache
```

## 🔧 常见问题

### Q: 构建失败怎么办？
```bash
# 检查环境
./runpod_platform.sh setup --check-only

# 清理缓存重新构建
./runpod_platform.sh clean --cache
./runpod_platform.sh build ModelName --no-cache
```

### Q: 如何查看详细错误信息？
```bash
# 所有命令都支持详细输出
./runpod_platform.sh health --detailed
./runpod_platform.sh test ModelName --output /custom/path
```

### Q: 如何自定义配置？
```bash
# 查看配置文件位置
ls config/models_config.json

# 使用自定义配置测试
./runpod_platform.sh test ModelName --config /path/to/config.py
```

## 📚 进阶使用

### 批量操作
```bash
# 批量构建并推送
./runpod_platform.sh build all --push --tag v1.1

# 批量健康检查
for model in MapTR PETR VAD; do
    ./runpod_platform.sh health $model
done
```

### 自动化脚本示例
```bash
#!/bin/bash
# 每日自动化测试脚本

./runpod_platform.sh health || exit 1
./runpod_platform.sh test MapTR --quick
./runpod_platform.sh compare --output daily_report_$(date +%Y%m%d)
./runpod_platform.sh clean --logs
```

## 🎯 下一步

- 查看 [评测使用指南](evaluation_guide.md) 了解详细评测功能
- 查看 [Docker镜像命名规范](../technical/DOCKER_NAMING_CONVENTIONS.md) 了解镜像管理
- 查看 [RunPod部署指南](RUNPOD_SETUP_GUIDE.md) 了解云端部署

---

**提示**: 运行 `./runpod_platform.sh help [command]` 随时获取命令帮助！