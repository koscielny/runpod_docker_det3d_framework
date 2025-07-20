# EntryPoint 脚本架构设计

## 🗂️ 优化后的目录结构

```
containers/
├── base/
│   ├── entrypoints/                    # 基础层脚本
│   │   ├── ssh.sh                      # SSH服务专用脚本
│   │   ├── jupyter.sh                  # Jupyter Lab专用脚本
│   │   └── main.sh                     # 基础层主入口（组合器）
│   ├── Dockerfile.vscode
│   └── Dockerfile.jupyterlab
├── shared/
│   ├── entrypoints/                    # 共享层脚本
│   │   ├── utils.sh                    # 通用工具函数库
│   │   └── model.sh                    # 模型应用通用入口
│   └── entrypoint_optimized.sh         # 保留向后兼容
└── models/
    └── VAD/
        ├── Dockerfile                   # 直接继承，无需复制entrypoint
        └── entrypoints/                 # 可选：模型特定脚本
            └── vad_init.sh             # VAD特定初始化（如需要）
```

## 🎯 设计原则

### **1. 按层级分离职责**
- **base/entrypoints/**: 基础服务（SSH、Jupyter）
- **shared/entrypoints/**: 通用工具和模型应用逻辑
- **models/*/entrypoints/**: 模型特定的初始化（可选）

### **2. 功能模块化**
- 每个服务一个独立脚本
- 标准化的函数接口
- 可组合的服务启动

### **3. 智能继承**
- 下游镜像自动继承上游脚本
- 无需重复复制entrypoint文件
- 通过标志文件避免重复初始化

## 📋 脚本功能详解

### **base/entrypoints/ssh.sh**
```bash
职责: SSH基础服务
功能:
  - SSH密钥生成
  - 公钥配置 
  - SSH服务启动
  - 健康检查函数
导出: start_ssh_service, check_ssh_service
```

### **base/entrypoints/jupyter.sh**
```bash
职责: Jupyter Lab服务
功能:
  - 自动检测jupyter安装
  - 无密码配置启动
  - 日志管理
  - 健康检查函数
导出: start_jupyter_service, check_jupyter_service
```

### **base/entrypoints/main.sh**
```bash
职责: 基础层主入口
功能:
  - 组合调用SSH和Jupyter服务
  - 系统信息显示
  - 基础依赖检查
  - 健康检查守护进程
用途: 作为基础镜像的ENTRYPOINT
```

### **shared/entrypoints/utils.sh**
```bash
职责: 通用工具函数库
功能:
  - 颜色输出函数
  - 系统信息显示
  - 内存状态检查
  - 端口检查
  - 便捷别名创建
导出: 20+个通用函数
```

### **shared/entrypoints/model.sh**
```bash
职责: 模型应用通用入口
功能:
  - 继承基础服务
  - 模型目录自动检测
  - 深度学习库检查
  - GPU状态监控
  - 增强健康检查
用途: 作为模型镜像的ENTRYPOINT
```

## 🔧 使用指南

### **基础镜像配置**
```dockerfile
# Dockerfile.jupyterlab
COPY containers/base/entrypoints/ /app/entrypoints/
COPY containers/shared/entrypoints/ /app/shared/entrypoints/
ENTRYPOINT ["/app/entrypoints/main.sh"]
```

### **模型镜像配置**
```dockerfile
# VAD/Dockerfile - 推荐方式
# 直接继承，无需额外配置
ENTRYPOINT ["/app/shared/entrypoints/model.sh"]

# 或者继续使用基础入口
ENTRYPOINT ["/app/entrypoints/main.sh"]
```

### **自定义模型初始化**
```dockerfile
# 如果需要模型特定初始化
COPY containers/models/VAD/entrypoints/ /app/model_entrypoints/
# 在model.sh中自动检测并调用
```

## 🚀 启动流程对比

### **基础镜像启动流程**
```
Jupyter Lab容器启动
    ↓
main.sh (基础层主入口)
    ↓
加载utils.sh (工具函数)
    ↓
加载ssh.sh (SSH服务)
    ↓
加载jupyter.sh (Jupyter服务)
    ↓
start_ssh_service() → SSH启动
    ↓
start_jupyter_service() → Jupyter启动
    ↓
显示系统信息 → 访问提示
    ↓
健康检查守护进程
```

### **模型镜像启动流程**
```
VAD容器启动
    ↓
model.sh (模型应用入口)
    ↓
调用main.sh → 基础服务启动
    ↓
模型特定初始化:
  - 检测模型目录 (VAD/MapTR/PETR等)
  - 深度学习库检查
  - GPU状态检查
  - MM系列库验证
    ↓
显示模型应用信息
    ↓
增强健康检查守护进程
```

## ✅ 优势总结

1. **清晰的层级结构**: 按功能和层级组织，易于理解和维护
2. **避免重复代码**: 通过继承机制，下游镜像无需重复复制
3. **模块化设计**: 每个服务独立脚本，职责清晰
4. **智能检测**: 自动检测可用服务和模型类型
5. **功能丰富**: 提供完整的工具函数库和便捷别名
6. **向下兼容**: 保留旧版本entrypoint
7. **健康监控**: 多层次的服务健康检查

## 🔄 迁移路径

### **从旧架构迁移**
1. **基础镜像**: 更新Dockerfile使用新的entrypoints目录结构
2. **模型镜像**: 移除entrypoint复制，选择适合的入口脚本
3. **验证测试**: 确保所有服务正常启动，无重复初始化

### **版本兼容**
- 保留`containers/shared/entrypoint_optimized.sh`
- 新项目使用新架构
- 现有项目可逐步迁移

这种新架构更加清晰、模块化，并且完全解决了重复调用的问题！