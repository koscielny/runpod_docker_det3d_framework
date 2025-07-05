# 工具集合目录

此目录包含所有host machine安装相关的工具和脚本。

## 🔧 核心工具

### 依赖转换工具
- **`convert_conda_to_pip.py`** - 将conda export文件转换为pip requirements格式
- **`install_from_conda_export.sh`** - 智能安装conda export文件中的包

### 环境管理工具  
- **`force_recreate_topomlp_env.sh`** - 强制重新创建TopoMLP环境
- **`create_minimal_topomlp_env.sh`** - 创建最小化TopoMLP环境

### 版本修复工具
- **`fix_pytorch_versions.sh`** - 修复PyTorch CUDA版本问题

### 测试验证工具
- **`test_topomlp_fix.sh`** - 验证TopoMLP修复状态  
- **`test_install_strategy.sh`** - 测试混合安装策略

## 📋 使用场景

### 正常安装（推荐）
大多数情况下，直接使用简化的安装脚本：
```bash
# 安装所有模型
./simple_setup.sh

# 安装单个模型  
./install_single_model.sh TopoMLP
```

### 问题修复
当遇到特定问题时使用相应工具：
```bash
# TopoMLP环境问题
./tools/force_recreate_topomlp_env.sh

# PyTorch版本问题
./tools/fix_pytorch_versions.sh

# 验证修复结果
./tools/test_topomlp_fix.sh
```

### 高级用法
需要深度定制时使用核心工具：
```bash
# 转换conda文件
python tools/convert_conda_to_pip.py input.txt output.txt

# 智能安装conda export
./tools/install_from_conda_export.sh requirements.txt env_name
```

## 🎯 设计原则

1. **简单优先** - 大部分情况用简单脚本
2. **工具分离** - 复杂工具放在tools目录
3. **按需使用** - 只有遇到问题才使用复杂工具
4. **集中管理** - 所有host machine工具统一存放