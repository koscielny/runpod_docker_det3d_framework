# 🚨 TopoMLP安装错误快速修复

## 问题症状
```
ERROR: Could not find a version that satisfies the requirement ortools==9.2.9972
Requires-Python >=3.9.0
CondaEnvException: Pip failed
```

## 🎯 一键修复 (推荐)

```bash
# 运行强制重建脚本
./force_recreate_topomlp_env.sh
```

**这个脚本会:**
- ✅ 验证修复已应用
- ✅ 删除旧的mapping_models环境
- ✅ 使用修复后的topomlp.yaml重新创建环境
- ✅ 自动验证安装

## 🔧 手动修复 (如果一键修复失败)

### 1. 检查修复状态
```bash
./test_topomlp_fix.sh
```

### 2. 如果显示❌，手动编辑文件
```bash
nano /home/ian/dev/src/online_mapping/TopoMLP/topomlp.yaml
```

**必须修改的行:**
- 第6行: `python=3.8.16` → `python=3.9`
- 第128行: `ortools==9.2.9972` → `ortools>=9.0,<10.0`

### 3. 删除现有环境并重新创建
```bash
# 删除旧环境
source /workspace/miniconda/bin/activate base
conda remove -n mapping_models --all -y

# 重新创建
conda env create -n mapping_models -f /home/ian/dev/src/online_mapping/TopoMLP/topomlp.yaml
```

## 📋 验证修复成功

运行验证脚本应该显示：
```bash
./test_topomlp_fix.sh

# 预期输出:
✅ Python version upgraded to 3.9
✅ OR-Tools version fixed to use compatible range
✅ System packages removed successfully
✅ All key packages present
✅ YAML basic structure looks correct
```

环境创建成功后验证：
```bash
source /workspace/miniconda/bin/activate mapping_models
python --version  # 应该显示 Python 3.9.x

python -c "import ortools; print('OR-Tools works!')"
python -c "import torch; print('PyTorch works!')"
```

## 🚀 重新运行安装

修复完成后，重新运行主安装脚本：
```bash
./setup_runpod_environment.sh
```

现在TopoMLP应该能够成功安装！

## 🔍 故障排除

如果仍然有问题：

1. **检查conda可用性:**
   ```bash
   /workspace/miniconda/bin/conda --version
   ```

2. **检查网络连接:**
   ```bash
   ping conda-forge.org
   ```

3. **手动安装关键包:**
   ```bash
   source /workspace/miniconda/bin/activate mapping_models
   pip install "ortools>=9.0,<10.0" torch mmcv-full shapely
   ```

4. **查看详细错误日志:**
   ```bash
   conda env create -n mapping_models -f /home/ian/dev/src/online_mapping/TopoMLP/topomlp.yaml -v
   ```

修复核心是确保Python 3.9和OR-Tools使用兼容版本范围！