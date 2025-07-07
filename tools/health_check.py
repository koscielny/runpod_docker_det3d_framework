#!/usr/bin/env python3
"""
模型健康检查和状态监控
用于快速验证模型容器是否正常工作
"""

import os
import sys
import time
import json
import psutil
import subprocess
from typing import Dict, Any, Optional
from pathlib import Path
import argparse

class ModelHealthChecker:
    """模型健康检查器"""
    
    def __init__(self, model_name: str, model_path: str = "/app"):
        self.model_name = model_name.upper()
        self.model_path = Path(model_path)
        self.start_time = time.time()
    
    def check_system_health(self) -> Dict[str, Any]:
        """检查系统基础健康状态"""
        health = {
            "timestamp": time.time(),
            "uptime": time.time() - self.start_time,
            "system": {},
            "gpu": {},
            "disk": {},
            "status": "unknown"
        }
        
        try:
            # CPU和内存信息
            health["system"] = {
                "cpu_percent": psutil.cpu_percent(interval=1),
                "memory_percent": psutil.virtual_memory().percent,
                "memory_available_gb": psutil.virtual_memory().available / (1024**3),
                "memory_total_gb": psutil.virtual_memory().total / (1024**3),
                "disk_usage_percent": psutil.disk_usage('/').percent,
                "load_average": os.getloadavg() if hasattr(os, 'getloadavg') else [0, 0, 0]
            }
            
            # GPU信息
            health["gpu"] = self._check_gpu_health()
            
            # 磁盘空间
            health["disk"] = self._check_disk_health()
            
            # 综合状态评估
            health["status"] = self._evaluate_overall_health(health)
            
        except Exception as e:
            health["error"] = str(e)
            health["status"] = "error"
        
        return health
    
    def _check_gpu_health(self) -> Dict[str, Any]:
        """检查GPU健康状态"""
        gpu_info = {
            "available": False,
            "count": 0,
            "memory_used_mb": 0,
            "memory_total_mb": 0,
            "utilization_percent": 0
        }
        
        try:
            # 尝试使用nvidia-smi
            result = subprocess.run([
                'nvidia-smi', 
                '--query-gpu=memory.total,memory.used,utilization.gpu',
                '--format=csv,nounits,noheader'
            ], capture_output=True, text=True, timeout=10)
            
            if result.returncode == 0:
                lines = result.stdout.strip().split('\n')
                gpu_info["available"] = True
                gpu_info["count"] = len(lines)
                
                if lines:
                    # 使用第一个GPU的信息
                    memory_total, memory_used, utilization = lines[0].split(',')
                    gpu_info["memory_total_mb"] = float(memory_total.strip())
                    gpu_info["memory_used_mb"] = float(memory_used.strip())
                    gpu_info["utilization_percent"] = float(utilization.strip())
            
            # 尝试使用PyTorch
            try:
                import torch
                if torch.cuda.is_available():
                    gpu_info["torch_available"] = True
                    gpu_info["torch_device_count"] = torch.cuda.device_count()
                    if torch.cuda.device_count() > 0:
                        gpu_info["torch_memory_allocated_mb"] = torch.cuda.memory_allocated(0) / (1024**2)
                        gpu_info["torch_memory_reserved_mb"] = torch.cuda.memory_reserved(0) / (1024**2)
                else:
                    gpu_info["torch_available"] = False
            except ImportError:
                gpu_info["torch_error"] = "PyTorch not available"
                
        except Exception as e:
            gpu_info["error"] = str(e)
        
        return gpu_info
    
    def _check_disk_health(self) -> Dict[str, Any]:
        """检查磁盘健康状态"""
        disk_info = {}
        
        try:
            # 检查主要路径的磁盘使用情况
            paths_to_check = ["/", "/app", "/tmp", "/data"]
            
            for path in paths_to_check:
                if os.path.exists(path):
                    usage = psutil.disk_usage(path)
                    disk_info[path] = {
                        "total_gb": usage.total / (1024**3),
                        "used_gb": usage.used / (1024**3),
                        "free_gb": usage.free / (1024**3),
                        "usage_percent": (usage.used / usage.total) * 100
                    }
        except Exception as e:
            disk_info["error"] = str(e)
        
        return disk_info
    
    def _evaluate_overall_health(self, health: Dict[str, Any]) -> str:
        """评估综合健康状态"""
        issues = []
        
        # 检查CPU使用率
        cpu_percent = health["system"].get("cpu_percent", 0)
        if cpu_percent > 90:
            issues.append("high_cpu")
        
        # 检查内存使用率
        memory_percent = health["system"].get("memory_percent", 0)
        if memory_percent > 90:
            issues.append("high_memory")
        
        # 检查磁盘使用率
        disk_percent = health["system"].get("disk_usage_percent", 0)
        if disk_percent > 90:
            issues.append("low_disk")
        
        # 检查GPU可用性
        if not health["gpu"].get("available", False):
            issues.append("no_gpu")
        
        # 评估状态
        if not issues:
            return "healthy"
        elif len(issues) <= 2 and "no_gpu" not in issues:
            return "warning"
        else:
            return "unhealthy"
    
    def check_model_health(self) -> Dict[str, Any]:
        """检查模型特定的健康状态"""
        model_health = {
            "model_name": self.model_name,
            "model_path": str(self.model_path),
            "files": {},
            "dependencies": {},
            "status": "unknown"
        }
        
        try:
            # 检查模型文件
            model_health["files"] = self._check_model_files()
            
            # 检查依赖项
            model_health["dependencies"] = self._check_dependencies()
            
            # 评估模型健康状态
            model_health["status"] = self._evaluate_model_health(model_health)
            
        except Exception as e:
            model_health["error"] = str(e)
            model_health["status"] = "error"
        
        return model_health
    
    def _check_model_files(self) -> Dict[str, Any]:
        """检查模型相关文件"""
        files_status = {}
        
        # 根据模型类型检查不同的文件
        expected_files = {
            "MAPTR": [
                "projects/configs/maptr/maptr_tiny_r50_24e.py",
                "tools/demo.py"
            ],
            "PETR": [
                "projects/configs/petr/petr_r50dcn_gridmask_p4.py",
                "tools/demo.py"
            ],
            "STREAMPETR": [
                "projects/configs/streampetr/streampetr_r50_flash_704_bs2_seq_24e.py",
                "tools/demo.py"
            ],
            "TOPOMLP": [
                "configs/topomlp/topomlp_r50_8x1_24e_bs2_4key_256_lss.py",
                "tools/demo.py"
            ],
            "VAD": [
                "projects/configs/VAD/VAD_base.py",
                "tools/demo.py"
            ]
        }
        
        model_files = expected_files.get(self.model_name, [])
        
        for file_path in model_files:
            full_path = self.model_path / self.model_name / file_path
            files_status[file_path] = {
                "exists": full_path.exists(),
                "size_bytes": full_path.stat().st_size if full_path.exists() else 0,
                "readable": os.access(full_path, os.R_OK) if full_path.exists() else False
            }
        
        # 检查推理脚本
        inference_script = self.model_path / self.model_name / "inference.py"
        files_status["inference.py"] = {
            "exists": inference_script.exists(),
            "size_bytes": inference_script.stat().st_size if inference_script.exists() else 0,
            "executable": os.access(inference_script, os.X_OK) if inference_script.exists() else False
        }
        
        return files_status
    
    def _check_dependencies(self) -> Dict[str, Any]:
        """检查Python依赖项"""
        deps_status = {}
        
        # 检查关键依赖项
        critical_deps = [
            "torch", "torchvision", "numpy", "opencv-python", 
            "mmcv", "mmdet", "mmsegmentation"
        ]
        
        for dep in critical_deps:
            try:
                __import__(dep.replace("-", "_"))
                deps_status[dep] = {"available": True, "error": None}
            except ImportError as e:
                deps_status[dep] = {"available": False, "error": str(e)}
        
        # 检查特定版本要求
        try:
            import torch
            deps_status["torch"]["version"] = torch.__version__
            deps_status["torch"]["cuda_available"] = torch.cuda.is_available()
        except:
            pass
        
        try:
            import mmcv
            deps_status["mmcv"]["version"] = mmcv.__version__
        except:
            pass
        
        return deps_status
    
    def _evaluate_model_health(self, model_health: Dict[str, Any]) -> str:
        """评估模型健康状态"""
        issues = []
        
        # 检查关键文件
        files = model_health.get("files", {})
        critical_files = ["inference.py"]
        
        for file_name in critical_files:
            if file_name in files and not files[file_name].get("exists", False):
                issues.append(f"missing_{file_name}")
        
        # 检查依赖项
        deps = model_health.get("dependencies", {})
        critical_deps = ["torch", "mmcv"]
        
        for dep in critical_deps:
            if dep in deps and not deps[dep].get("available", False):
                issues.append(f"missing_{dep}")
        
        # 评估状态
        if not issues:
            return "ready"
        elif len(issues) <= 2:
            return "partial"
        else:
            return "broken"
    
    def run_quick_test(self) -> Dict[str, Any]:
        """运行快速功能测试"""
        test_result = {
            "test_name": "quick_functionality_test",
            "timestamp": time.time(),
            "status": "unknown",
            "details": {}
        }
        
        try:
            # 尝试导入模型相关模块
            test_result["details"]["import_torch"] = self._test_torch_import()
            test_result["details"]["import_mmcv"] = self._test_mmcv_import()
            
            # 尝试创建简单的tensor操作
            test_result["details"]["tensor_ops"] = self._test_tensor_operations()
            
            # 检查GPU tensor操作
            test_result["details"]["gpu_ops"] = self._test_gpu_operations()
            
            # 评估测试结果
            passed_tests = sum(1 for test in test_result["details"].values() 
                             if isinstance(test, dict) and test.get("passed", False))
            total_tests = len(test_result["details"])
            
            if passed_tests == total_tests:
                test_result["status"] = "passed"
            elif passed_tests >= total_tests * 0.7:
                test_result["status"] = "mostly_passed"
            else:
                test_result["status"] = "failed"
                
        except Exception as e:
            test_result["error"] = str(e)
            test_result["status"] = "error"
        
        return test_result
    
    def _test_torch_import(self) -> Dict[str, Any]:
        """测试PyTorch导入"""
        try:
            import torch
            return {
                "passed": True,
                "version": torch.__version__,
                "cuda_available": torch.cuda.is_available()
            }
        except Exception as e:
            return {"passed": False, "error": str(e)}
    
    def _test_mmcv_import(self) -> Dict[str, Any]:
        """测试MMCV导入"""
        try:
            import mmcv
            return {
                "passed": True,
                "version": mmcv.__version__
            }
        except Exception as e:
            return {"passed": False, "error": str(e)}
    
    def _test_tensor_operations(self) -> Dict[str, Any]:
        """测试基础tensor操作"""
        try:
            import torch
            x = torch.randn(2, 3)
            y = torch.randn(3, 2)
            z = torch.mm(x, y)
            return {
                "passed": True,
                "operation": "matrix_multiplication",
                "result_shape": list(z.shape)
            }
        except Exception as e:
            return {"passed": False, "error": str(e)}
    
    def _test_gpu_operations(self) -> Dict[str, Any]:
        """测试GPU操作"""
        try:
            import torch
            if not torch.cuda.is_available():
                return {"passed": False, "error": "CUDA not available"}
            
            x = torch.randn(2, 3).cuda()
            y = torch.randn(3, 2).cuda()
            z = torch.mm(x, y)
            result = z.cpu()
            
            return {
                "passed": True,
                "operation": "cuda_matrix_multiplication",
                "result_shape": list(result.shape),
                "device": str(x.device)
            }
        except Exception as e:
            return {"passed": False, "error": str(e)}
    
    def get_comprehensive_status(self) -> Dict[str, Any]:
        """获取综合健康状态报告"""
        return {
            "health_check_version": "1.0",
            "timestamp": time.time(),
            "model_name": self.model_name,
            "system_health": self.check_system_health(),
            "model_health": self.check_model_health(),
            "functionality_test": self.run_quick_test()
        }

def create_health_endpoint():
    """创建简单的HTTP健康检查端点"""
    try:
        from http.server import HTTPServer, BaseHTTPRequestHandler
        import urllib.parse
        
        class HealthHandler(BaseHTTPRequestHandler):
            def do_GET(self):
                # 解析请求路径
                parsed_path = urllib.parse.urlparse(self.path)
                
                if parsed_path.path == "/health":
                    # 基础健康检查
                    model_name = urllib.parse.parse_qs(parsed_path.query).get('model', ['UNKNOWN'])[0]
                    checker = ModelHealthChecker(model_name)
                    status = checker.check_system_health()
                    
                    self.send_response(200)
                    self.send_header('Content-type', 'application/json')
                    self.end_headers()
                    self.wfile.write(json.dumps(status, indent=2).encode())
                    
                elif parsed_path.path == "/health/detailed":
                    # 详细健康检查
                    model_name = urllib.parse.parse_qs(parsed_path.query).get('model', ['UNKNOWN'])[0]
                    checker = ModelHealthChecker(model_name)
                    status = checker.get_comprehensive_status()
                    
                    self.send_response(200)
                    self.send_header('Content-type', 'application/json')
                    self.end_headers()
                    self.wfile.write(json.dumps(status, indent=2).encode())
                    
                else:
                    self.send_response(404)
                    self.end_headers()
                    self.wfile.write(b'Not Found')
            
            def log_message(self, format, *args):
                # 简化日志输出
                pass
        
        return HTTPServer, HealthHandler
    except ImportError:
        return None, None

def main():
    parser = argparse.ArgumentParser(description='模型健康检查工具')
    parser.add_argument('--model', type=str, required=True,
                       choices=['MapTR', 'PETR', 'StreamPETR', 'TopoMLP', 'VAD'],
                       help='模型名称')
    parser.add_argument('--mode', type=str, default='check',
                       choices=['check', 'test', 'comprehensive', 'server'],
                       help='运行模式')
    parser.add_argument('--port', type=int, default=8080,
                       help='HTTP服务器端口 (仅server模式)')
    
    args = parser.parse_args()
    
    checker = ModelHealthChecker(args.model)
    
    if args.mode == 'check':
        # 基础健康检查
        status = checker.check_system_health()
        print(json.dumps(status, indent=2))
        
    elif args.mode == 'test':
        # 功能测试
        test_result = checker.run_quick_test()
        print(json.dumps(test_result, indent=2))
        
    elif args.mode == 'comprehensive':
        # 综合检查
        status = checker.get_comprehensive_status()
        print(json.dumps(status, indent=2))
        
    elif args.mode == 'server':
        # HTTP服务器模式
        HTTPServer, HealthHandler = create_health_endpoint()
        if HTTPServer and HealthHandler:
            server = HTTPServer(('0.0.0.0', args.port), HealthHandler)
            print(f"健康检查服务器运行在端口 {args.port}")
            print(f"访问 http://localhost:{args.port}/health?model={args.model}")
            print(f"访问 http://localhost:{args.port}/health/detailed?model={args.model}")
            try:
                server.serve_forever()
            except KeyboardInterrupt:
                server.shutdown()
                print("\n服务器已停止")
        else:
            print("HTTP服务器不可用，请检查Python环境")

if __name__ == "__main__":
    main()