# Docker EntryPoint 分层设计文档

## 🏗️ 设计理念

采用**分层entrypoint + 组合模式**，避免重复初始化，提高容器启动效率和维护性。

## 📁 文件结构

```
containers/shared/
├── entrypoint_base.sh      # 基础服务（SSH等）
├── entrypoint_jupyter.sh   # Jupyter Lab服务
├── entrypoint_model.sh     # 组合入口点（推荐）
└── entrypoint_optimized.sh # 旧版本（保留兼容）
```

## 🎯 各层级职责

### **基础层 (entrypoint_base.sh)**
- SSH服务配置和启动
- 内存优化设置
- 基础环境配置
- 不能单独使用，只供其他脚本调用

### **Jupyter层 (entrypoint_jupyter.sh)**  
- Jupyter Lab服务启动
- 无密码配置
- 端口8888绑定
- 可选服务，自动检测是否需要

### **模型层 (entrypoint_model.sh)**
- 组合调用基础和专用服务
- 智能检测可用服务
- 健康检查和自动重启
- **推荐作为最终ENTRYPOINT**

## 🔧 使用方式

### **方式1: 基础镜像（推荐）**
```dockerfile
# Dockerfile.jupyterlab
COPY containers/shared/entrypoint_base.sh /app/shared/entrypoint_base.sh
COPY containers/shared/entrypoint_jupyter.sh /app/shared/entrypoint_jupyter.sh  
COPY containers/shared/entrypoint_model.sh /entrypoint.sh
ENTRYPOINT ["/entrypoint.sh"]
```

### **方式2: 模型镜像（推荐）**
```dockerfile
# VAD/Dockerfile  
# 不需要复制，从基础镜像继承
ENTRYPOINT ["/entrypoint.sh"]
```

### **方式3: 自定义模型镜像**
```dockerfile
# 如果需要特殊初始化
COPY containers/shared/entrypoint_model.sh /app/entrypoint_custom.sh
# 在entrypoint_custom.sh中调用基础服务
ENTRYPOINT ["/app/entrypoint_custom.sh"]
```

## ✅ 优势

1. **避免重复初始化**：通过标志文件防止重复启动服务
2. **模块化设计**：各层职责清晰，易于维护
3. **智能检测**：自动检测需要的服务（如Jupyter）
4. **向下兼容**：保留旧版本entrypoint
5. **健康检查**：自动监控和重启异常服务
6. **灵活组合**：可以选择性启用服务

## 🚀 启动流程

```
模型容器启动
    ↓
加载基础服务模块
    ↓  
检测可选服务（Jupyter等）
    ↓
启动基础服务（SSH）
    ↓
启动可选服务（Jupyter）
    ↓
显示访问信息
    ↓
启动健康检查守护进程
```

## 🔍 服务检测逻辑

```bash
# 自动检测Jupyter
if command -v jupyter >/dev/null 2>&1; then
    echo "检测到Jupyter Lab，启动服务"
    start_jupyter_services
fi

# 防重复启动
if [ -f "/tmp/.jupyter_services_started" ]; then
    echo "Jupyter服务已启动，跳过"
fi
```

## 📋 迁移指南

### **从旧版本迁移**

1. **基础镜像**：更新Dockerfile使用新的分层脚本
2. **模型镜像**：移除entrypoint复制，直接继承
3. **测试验证**：确保所有服务正常启动

### **兼容性**
- 保留`entrypoint_optimized.sh`用于向后兼容
- 新镜像优先使用`entrypoint_model.sh`
- 旧镜像可以继续使用旧版本

## 🛠️ 自定义服务

如果需要添加新的服务模块：

```bash
# 创建新服务脚本
# containers/shared/entrypoint_myservice.sh

start_myservice() {
    if [ -f "/tmp/.myservice_started" ]; then
        return 0
    fi
    
    echo "启动我的服务..."
    # 服务启动逻辑
    
    touch "/tmp/.myservice_started"
}

export -f start_myservice
```

然后在`entrypoint_model.sh`中加载：
```bash
if [ -f "$SCRIPT_DIR/entrypoint_myservice.sh" ]; then
    source "$SCRIPT_DIR/entrypoint_myservice.sh"
    start_myservice
fi
```

## 🎯 最佳实践

1. **基础镜像**：复制所有必要的entrypoint脚本
2. **中间镜像**：通常不需要修改entrypoint
3. **最终镜像**：使用继承的entrypoint，除非有特殊需求
4. **服务模块**：保持单一职责，使用标志文件防重复
5. **健康检查**：定期检查服务状态，自动重启异常服务

这种设计确保了容器启动的效率和维护的便利性！