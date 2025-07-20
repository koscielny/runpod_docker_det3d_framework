# EntryPoint 脚本清理计划

## 🔄 演进历史

### **第一代 (原始)**
```
entrypoint_optimized.sh          # 一体化脚本，包含所有功能
```
- ✅ 保留：向后兼容

### **第二代 (分层尝试) - 需要清理**
```
entrypoint_base.sh              # 🗑️ 删除：被base/entrypoints/ssh.sh替代
entrypoint_jupyter.sh            # 🗑️ 删除：被base/entrypoints/jupyter.sh替代  
entrypoint_model.sh              # 🗑️ 删除：被shared/entrypoints/model.sh替代
```
- ❌ 清理：功能已迁移到新架构

### **第三代 (最终架构) - 推荐使用**
```
base/entrypoints/
├── ssh.sh                       # ✅ SSH专用服务
├── jupyter.sh                   # ✅ Jupyter专用服务
└── main.sh                      # ✅ 基础层主入口

shared/entrypoints/
├── utils.sh                     # ✅ 通用工具函数
└── model.sh                     # ✅ 模型应用入口
```
- ✅ 保留：最终推荐架构

## 🎯 清理后的最终架构

### **文件映射关系**

| 旧文件 | 新文件 | 状态 |
|--------|--------|------|
| `entrypoint_optimized.sh` | 保持不变 | ✅ 保留 (向后兼容) |
| `entrypoint_base.sh` | `base/entrypoints/ssh.sh` | 🗑️ 删除 |
| `entrypoint_jupyter.sh` | `base/entrypoints/jupyter.sh` | 🗑️ 删除 |
| `entrypoint_model.sh` | `shared/entrypoints/model.sh` | 🗑️ 删除 |

### **功能对比**

| 功能 | 第一代 | 第二代 | 第三代 ⭐ |
|------|--------|--------|----------|
| SSH服务 | ✅ 内置 | `entrypoint_base.sh` | `base/entrypoints/ssh.sh` |
| Jupyter服务 | ✅ 内置 | `entrypoint_jupyter.sh` | `base/entrypoints/jupyter.sh` |
| 模型应用 | ✅ 内置 | `entrypoint_model.sh` | `shared/entrypoints/model.sh` |
| 工具函数 | ❌ 缺少 | ❌ 分散 | `shared/entrypoints/utils.sh` |
| 组合入口 | ❌ 单一 | `entrypoint_model.sh` | `base/entrypoints/main.sh` |

## 🚀 推荐使用方式

### **基础镜像 (vscode, jupyterlab)**
```dockerfile
# 使用第三代架构
ENTRYPOINT ["/app/entrypoints/main.sh"]
```

### **模型镜像 (VAD, MapTR等)**
```dockerfile
# 选择之一：
ENTRYPOINT ["/app/entrypoints/main.sh"]           # 基础服务入口
# 或：
ENTRYPOINT ["/app/shared/entrypoints/model.sh"]   # 模型应用入口 (推荐)
```

### **向后兼容 (现有部署)**
```dockerfile
# 继续使用第一代
ENTRYPOINT ["/entrypoint.sh"]  # 即 entrypoint_optimized.sh
```

## 🗑️ 清理建议

1. **删除第二代文件**：
   - `entrypoint_base.sh`
   - `entrypoint_jupyter.sh` 
   - `entrypoint_model.sh`

2. **保留文件**：
   - `entrypoint_optimized.sh` (向后兼容)
   - `base/entrypoints/*` (新架构)
   - `shared/entrypoints/*` (新架构)

3. **迁移路径**：
   - 新项目：使用第三代架构
   - 现有项目：可继续使用第一代，或逐步迁移到第三代

这样架构就清晰了：
- **第一代**：向后兼容
- **第三代**：推荐使用
- **删除第二代**：避免混乱