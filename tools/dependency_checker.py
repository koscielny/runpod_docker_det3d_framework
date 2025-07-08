#!/usr/bin/env python3
"""
Docker容器依赖检查工具
用于首次运行时验证所有依赖是否健全，确保模型可以正常运行
"""

import os
import sys
import json
import time
import subprocess
import importlib
from pathlib import Path
from typing import Dict, List, Tuple, Optional, Any
import warnings
import mmdet
import mmdet3d
import mmcv
# 抑制警告信息，避免影响检查结果显示
warnings.filterwarnings("ignore")

class DependencyChecker:
    """依赖检查器"""
    
    def __init__(self, model_name: str = "Unknown"):
        # 保持正确的模型名称格式
        self.model_name = model_name
        self.display_name = model_name.upper()
        self.checks_passed = 0
        self.checks_total = 0
        self.errors = []
        self.warnings = []
        self.start_time = time.time()
    
    def log_result(self, check_name: str, status: bool, details: str = "", is_critical: bool = True):
        """记录检查结果"""
        self.checks_total += 1
        if status:
            self.checks_passed += 1
            print(f"✅ {check_name}: {details}")
        else:
            emoji = "❌" if is_critical else "⚠️"
            print(f"{emoji} {check_name}: {details}")
            if is_critical:
                self.errors.append(f"{check_name}: {details}")
            else:
                self.warnings.append(f"{check_name}: {details}")
    
    def check_python_environment(self) -> bool:
        """检查Python环境"""
        print("\n🐍 检查Python环境...")
        
        # Python版本
        python_version = sys.version_info
        required_major, required_minor = 3, 7
        version_ok = python_version.major >= required_major and python_version.minor >= required_minor
        self.log_result(
            "Python版本", 
            version_ok,
            f"{python_version.major}.{python_version.minor}.{python_version.micro} (需要 >= {required_major}.{required_minor})"
        )
        
        # Python路径
        python_path = sys.executable
        self.log_result(
            "Python路径", 
            os.path.exists(python_path),
            python_path
        )
        
        # 检查pip
        try:
            import pip
            pip_version = pip.__version__
            self.log_result("pip", True, f"版本 {pip_version}")
        except ImportError:
            self.log_result("pip", False, "pip未安装")
        
        return version_ok
    
    def check_core_dependencies(self) -> bool:
        """检查核心Python依赖"""
        print("\n📦 检查核心依赖...")
        
        # 核心依赖列表
        core_deps = {
            'torch': 'PyTorch深度学习框架',
            'torchvision': 'PyTorch视觉库',
            'numpy': '数值计算库',
            'opencv-python': '计算机视觉库',  # 实际模块名是cv2
            'pillow': '图像处理库',  # 实际模块名是PIL
            'matplotlib': '绘图库',
            'psutil': '系统监控库',
        }
        
        # 特殊模块名映射
        module_mapping = {
            'opencv-python': 'cv2',
            'pillow': 'PIL'
        }
        
        all_ok = True
        for pkg_name, description in core_deps.items():
            module_name = module_mapping.get(pkg_name, pkg_name)
            try:
                module = importlib.import_module(module_name)
                version = getattr(module, '__version__', 'Unknown')
                self.log_result(f"{pkg_name}", True, f"{description} - 版本 {version}")
            except ImportError as e:
                self.log_result(f"{pkg_name}", False, f"{description} - 未安装: {e}")
                all_ok = False
        
        return all_ok
    def check_ai_frameworks(self) -> bool:
        """检查AI框架和库 - 简化版本"""
        print("\n🤖 检查AI框架...")
        
        ai_deps = {
            'mmcv': 'OpenMMLab计算机视觉库',
            'mmdet': 'MMDetection目标检测库',
            'mmdet3d': 'MMDetection3D 3D检测库',
            'scipy': '科学计算库',
            'scikit-image': '图像处理库',
            'shapely': '几何计算库',
            'timm': 'PyTorch图像模型库',
        }
        
        # Module name mapping for special cases
        module_mapping = {
            'scikit-image': 'skimage',
            'scikit-learn': 'sklearn'
        }
        
        essential_count = 0
        available_count = 0
        
        for pkg_name, description in ai_deps.items():
            module_name = module_mapping.get(pkg_name, pkg_name)
            
            # Use simplified import strategy for MM modules and others
            if pkg_name in ['mmcv', 'mmdet', 'mmdet3d']:
                success, version = self._simple_import_mm_module(module_name)
            else:
                success, version = self._simple_import_module(module_name)
            
            if success:
                status_msg = f"{description} - 版本 {version}"
                self.log_result(f"{pkg_name}", True, status_msg, is_critical=False)
                available_count += 1
                if pkg_name in ['mmcv', 'scipy']:  # Core frameworks
                    essential_count += 1
            else:
                is_critical = pkg_name in ['mmcv', 'scipy']
                self.log_result(f"{pkg_name}", False, f"{description} - 未安装", is_critical=is_critical)
        
        return essential_count >= 1  # At least one core framework available

    def check_gpu_support(self) -> bool:
        """检查GPU支持"""
        print("\n🎮 检查GPU支持...")
        
        # 检查CUDA可用性
        try:
            import torch
            cuda_available = torch.cuda.is_available()
            if cuda_available:
                gpu_count = torch.cuda.device_count()
                gpu_name = torch.cuda.get_device_name(0) if gpu_count > 0 else "Unknown"
                cuda_version = torch.version.cuda
                self.log_result(
                    "CUDA可用性", True, 
                    f"✓ {gpu_count}个GPU - {gpu_name} (CUDA {cuda_version})"
                )
                
                # 检查GPU内存
                if gpu_count > 0:
                    gpu_memory = torch.cuda.get_device_properties(0).total_memory / (1024**3)
                    self.log_result(
                        "GPU内存", True,
                        f"{gpu_memory:.1f}GB"
                    )
            else:
                self.log_result("CUDA可用性", False, "CUDA不可用，将使用CPU", is_critical=False)
                
        except ImportError:
            self.log_result("PyTorch", False, "PyTorch未安装，无法检查GPU")
            return False
        
        # 检查nvidia-smi
        try:
            result = subprocess.run(['nvidia-smi'], capture_output=True, text=True, timeout=10)
            if result.returncode == 0:
                # 解析GPU信息
                lines = result.stdout.split('\n')
                driver_line = [line for line in lines if 'Driver Version' in line]
                if driver_line:
                    driver_info = driver_line[0].split()
                    driver_version = next((item for item in driver_info if '.' in item and item.replace('.', '').isdigit()), "Unknown")
                    self.log_result("NVIDIA驱动", True, f"版本 {driver_version}")
                else:
                    self.log_result("NVIDIA驱动", True, "已安装")
            else:
                self.log_result("NVIDIA驱动", False, "nvidia-smi命令失败", is_critical=False)
        except (subprocess.TimeoutExpired, FileNotFoundError):
            self.log_result("NVIDIA驱动", False, "nvidia-smi不可用", is_critical=False)
        
        return cuda_available if 'torch' in locals() else False
    
    def check_model_files(self) -> bool:
        """检查模型文件和配置"""
        print("\n📁 检查模型文件...")
        
        # 检查关键目录
        important_paths = {
            '/app': '应用根目录',
            f'/app/{self.model_name}': f'{self.display_name}模型目录',
            '/app/tools': '工具目录',
            '/app/tools/health_check.py': '健康检查脚本',
            '/app/tools/model_output_standard.py': '标准输出脚本',
        }
        
        all_ok = True
        for path, description in important_paths.items():
            exists = os.path.exists(path)
            if not exists and '/app/tools' in path:
                # tools目录不是必需的
                self.log_result(f"{description}", exists, path, is_critical=False)
            else:
                self.log_result(f"{description}", exists, path)
                if not exists and path != f'/app/{self.model_name}':  # 模型目录可能不存在
                    all_ok = False
        
        # 检查模型特定文件
        model_dir = f'/app/{self.model_name}'
        if os.path.exists(model_dir):
            model_files = {
                f'{model_dir}/inference.py': '推理脚本',
                f'{model_dir}/requirements.txt': '依赖文件',
            }
            
            for file_path, description in model_files.items():
                exists = os.path.exists(file_path)
                self.log_result(f"{description}", exists, file_path, is_critical=(description == '推理脚本'))
        
        return all_ok
    
    def check_system_resources(self) -> bool:
        """检查系统资源"""
        print("\n💾 检查系统资源...")
        
        try:
            import psutil
            
            # 内存检查
            memory = psutil.virtual_memory()
            memory_gb = memory.total / (1024**3)
            memory_available_gb = memory.available / (1024**3)
            memory_ok = memory_gb >= 0.5  # 至少500MB
            
            self.log_result(
                "系统内存", memory_ok,
                f"{memory_gb:.1f}GB 总量, {memory_available_gb:.1f}GB 可用 ({memory.percent:.1f}% 使用)"
            )
            
            # 磁盘空间检查
            disk = psutil.disk_usage('/')
            disk_free_gb = disk.free / (1024**3)
            disk_ok = disk_free_gb >= 1.0  # 至少1GB空闲
            
            self.log_result(
                "磁盘空间", disk_ok,
                f"{disk_free_gb:.1f}GB 可用空间"
            )
            
            # CPU检查
            cpu_count = psutil.cpu_count()
            self.log_result(
                "CPU核心", True,
                f"{cpu_count}个CPU核心"
            )
            
            return memory_ok and disk_ok
            
        except ImportError:
            self.log_result("psutil", False, "系统监控库未安装")
            return False
    
    def check_network_connectivity(self) -> bool:
        """检查网络连接"""
        print("\n🌐 检查网络连接...")
        
        # 测试常用的机器学习资源
        test_urls = [
            ('huggingface.co', 'Hugging Face'),
            ('download.pytorch.org', 'PyTorch下载'),
            ('pypi.org', 'Python包索引'),
        ]
        
        success_count = 0
        for host, description in test_urls:
            try:
                result = subprocess.run(
                    ['ping', '-c', '1', '-W', '3', host], 
                    capture_output=True, 
                    timeout=5
                )
                success = result.returncode == 0
                if success:
                    success_count += 1
                self.log_result(
                    f"网络连接-{description}", success, 
                    host, is_critical=False
                )
            except (subprocess.TimeoutExpired, FileNotFoundError):
                self.log_result(
                    f"网络连接-{description}", False,
                    f"无法ping {host}", is_critical=False
                )
        
        return success_count > 0  # 至少一个连接成功
    
    def run_simple_model_test(self) -> bool:
        """运行简单的模型测试"""
        print("\n🧪 运行基础功能测试...")
        
        try:
            # 测试PyTorch基础功能
            import torch
            
            # 创建简单张量测试
            x = torch.randn(2, 3)
            y = torch.randn(3, 2)
            result = torch.mm(x, y)
            
            tensor_test = result.shape == (2, 2)
            self.log_result("PyTorch张量运算", tensor_test, "基础张量运算正常")
            
            # 测试GPU功能（如果可用）
            if torch.cuda.is_available():
                try:
                    x_gpu = x.cuda()
                    gpu_test = x_gpu.device.type == 'cuda'
                    self.log_result("GPU张量运算", gpu_test, "GPU张量创建正常")
                except Exception as e:
                    self.log_result("GPU张量运算", False, f"GPU测试失败: {e}")
                    gpu_test = False
            else:
                gpu_test = True  # 如果没有GPU，跳过测试
                self.log_result("GPU张量运算", True, "跳过 (无GPU)", is_critical=False)
            
            # 测试内存清理
            del x, y, result
            if 'x_gpu' in locals():
                del x_gpu
            
            import gc
            collected = gc.collect()
            self.log_result("内存清理", True, f"回收了 {collected} 个对象")
            
            return tensor_test
            
        except ImportError:
            self.log_result("PyTorch测试", False, "PyTorch不可用")
            return False
        except Exception as e:
            self.log_result("PyTorch测试", False, f"测试失败: {e}")
            return False
    
    def generate_report(self) -> Dict[str, Any]:
        """生成详细报告"""
        elapsed_time = time.time() - self.start_time
        
        report = {
            'model_name': self.model_name,
            'timestamp': time.strftime('%Y-%m-%d %H:%M:%S'),
            'elapsed_time': f"{elapsed_time:.2f}秒",
            'checks_passed': self.checks_passed,
            'checks_total': self.checks_total,
            'success_rate': f"{(self.checks_passed/self.checks_total*100):.1f}%" if self.checks_total > 0 else "0%",
            'errors': self.errors,
            'warnings': self.warnings,
            'status': 'READY' if len(self.errors) == 0 else 'ISSUES_FOUND'
        }
        
        return report
    
    def run_full_check(self) -> bool:
        """运行完整的依赖检查"""
        print("=" * 70)
        print(f"🔍 Docker容器依赖检查 - {self.display_name}模型")
        print("=" * 70)
        
        # 执行所有检查
        checks = [
            self.check_python_environment,
            self.check_core_dependencies,
            self.check_ai_frameworks,
            self.check_gpu_support,
            self.check_model_files,
            self.check_system_resources,
            self.check_network_connectivity,
            self.run_simple_model_test,
        ]
        
        for check in checks:
            try:
                check()
            except Exception as e:
                print(f"❌ 检查过程出错: {e}")
                self.errors.append(f"检查过程错误: {e}")
        
        # 生成报告
        report = self.generate_report()
        
        # 显示结果
        print("\n" + "=" * 70)
        print("📊 检查结果汇总")
        print("=" * 70)
        
        print(f"🏷️  模型: {report['model_name']}")
        print(f"⏱️  用时: {report['elapsed_time']}")
        print(f"✅ 通过: {report['checks_passed']}/{report['checks_total']} ({report['success_rate']})")
        
        if report['errors']:
            print(f"\n❌ 严重问题 ({len(report['errors'])}个):")
            for error in report['errors']:
                print(f"   • {error}")
        
        if report['warnings']:
            print(f"\n⚠️  警告 ({len(report['warnings'])}个):")
            for warning in report['warnings']:
                print(f"   • {warning}")
        
        # 最终状态
        if report['status'] == 'READY':
            print(f"\n🎉 状态: 容器依赖健全，{self.display_name}模型可以运行！")
            print(f"📝 建议: 可以开始使用模型进行推理")
        else:
            print(f"\n⚠️  状态: 发现问题，需要修复后才能运行模型")
            print(f"📝 建议: 请解决上述错误后重新检查")
        
        # 快速解决方案
        if report['errors'] or report['warnings']:
            print(f"\n🛠️  快速解决方案:")
            if any('未安装' in error for error in report['errors']):
                print(f"   • 安装缺失依赖: pip install torch torchvision numpy opencv-python")
            if any('内存' in error for error in report['errors']):
                print(f"   • 内存优化: python /app/tools/memory_optimizer.py --cleanup")
            if any('GPU' in error for error in report['errors']):
                print(f"   • 检查GPU: nvidia-smi")
        
        print("=" * 70)
        
        return report['status'] == 'READY'

    # ...existing code...

    def _simple_import_mm_module(self, module_name: str) -> Tuple[bool, str]:
        """
        Simple import method for MM modules (mmcv, mmdet, mmdet3d)
        Using the verified approach that works for these modules
        
        Args:
            module_name: Name of the module to import
            
        Returns:
            Tuple of (success, version)
        """
        try:
            module = importlib.import_module(module_name)
            version = getattr(module, '__version__', 'Unknown')
            return True, version
        except ImportError:
            return False, 'Unknown'
        except Exception:
            return False, 'Unknown'

    def _simple_import_module(self, module_name: str) -> Tuple[bool, str]:
        """
        Simple import method for other modules
        
        Args:
            module_name: Name of the module to import
            
        Returns:
            Tuple of (success, version)
        """
        try:
            module = importlib.import_module(module_name)
            # Try common version attributes
            version_attrs = ['__version__', 'VERSION', 'version']
            for attr in version_attrs:
                if hasattr(module, attr):
                    version = getattr(module, attr)
                    if version:
                        return True, str(version)
            return True, 'Unknown'
        except ImportError:
            return False, 'Unknown'
        except Exception:
            return False, 'Unknown'

def detect_model_name() -> str:
    """自动检测当前模型名称"""
    cwd = os.getcwd()
    
    # 从当前目录推断模型名称
    model_names = ['MapTR', 'PETR', 'StreamPETR', 'TopoMLP', 'VAD']
    for model in model_names:
        if model.lower() in cwd.lower() or os.path.exists(f'/app/{model}'):
            return model
    
    # 检查环境变量
    model_env = os.environ.get('MODEL_NAME', '').upper()
    if model_env in model_names:
        return model_env
    
    return "Unknown"

def main():
    """主函数"""
    import argparse
    
    parser = argparse.ArgumentParser(description='Docker容器依赖检查工具')
    parser.add_argument('--model', type=str, help='指定模型名称 (MapTR/PETR/StreamPETR/TopoMLP/VAD)')
    parser.add_argument('--quick', action='store_true', help='快速检查模式（跳过网络测试）')
    parser.add_argument('--json', action='store_true', help='以JSON格式输出结果')
    
    args = parser.parse_args()
    
    # 确定模型名称
    model_name = args.model if args.model else detect_model_name()
    
    # 创建检查器
    checker = DependencyChecker(model_name)
    
    # 执行检查
    if args.quick:
        # 快速模式，跳过网络检查
        original_method = checker.check_network_connectivity
        checker.check_network_connectivity = lambda: True
        
    success = checker.run_full_check()
    
    # 输出结果
    if args.json:
        report = checker.generate_report()
        print(json.dumps(report, ensure_ascii=False, indent=2))
    
    # 返回适当的退出码
    sys.exit(0 if success else 1)

if __name__ == "__main__":
    main()