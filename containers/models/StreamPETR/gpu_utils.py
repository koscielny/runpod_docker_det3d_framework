#!/usr/bin/env python3
"""
GPU Memory Monitoring and Cleanup Utilities for RunPod Deployment
Provides functions to monitor GPU memory usage and clean up resources
"""

import gc
import sys
import psutil
import subprocess
from typing import Dict, Optional

try:
    import torch
    HAS_TORCH = True
except ImportError:
    HAS_TORCH = False

def get_gpu_memory_info() -> Dict[str, float]:
    """
    Get current GPU memory usage information
    
    Returns:
        Dict containing GPU memory stats in MB
    """
    gpu_info = {
        'total_mb': 0.0,
        'used_mb': 0.0, 
        'free_mb': 0.0,
        'utilization_pct': 0.0
    }
    
    if HAS_TORCH and torch.cuda.is_available():
        try:
            # Get GPU memory info from PyTorch
            total_memory = torch.cuda.get_device_properties(0).total_memory
            allocated_memory = torch.cuda.memory_allocated(0)
            cached_memory = torch.cuda.memory_reserved(0)
            
            gpu_info['total_mb'] = total_memory / (1024 * 1024)
            gpu_info['used_mb'] = allocated_memory / (1024 * 1024)
            gpu_info['cached_mb'] = cached_memory / (1024 * 1024)
            gpu_info['free_mb'] = (total_memory - cached_memory) / (1024 * 1024)
            gpu_info['utilization_pct'] = (cached_memory / total_memory) * 100
            
        except Exception as e:
            print(f"Warning: Could not get GPU memory info via PyTorch: {e}")
    
    # Try nvidia-smi as fallback
    try:
        result = subprocess.run([
            'nvidia-smi', '--query-gpu=memory.total,memory.used,memory.free',
            '--format=csv,nounits,noheader'
        ], capture_output=True, text=True, timeout=10)
        
        if result.returncode == 0:
            memory_info = result.stdout.strip().split(',')
            if len(memory_info) >= 3:
                total_mb = float(memory_info[0])
                used_mb = float(memory_info[1])
                free_mb = float(memory_info[2])
                
                # Only update if we don't have PyTorch info
                if gpu_info['total_mb'] == 0:
                    gpu_info.update({
                        'total_mb': total_mb,
                        'used_mb': used_mb,
                        'free_mb': free_mb,
                        'utilization_pct': (used_mb / total_mb) * 100 if total_mb > 0 else 0
                    })
                    
    except Exception as e:
        print(f"Warning: Could not get GPU memory info via nvidia-smi: {e}")
    
    return gpu_info

def cleanup_gpu_memory() -> None:
    """
    Clean up GPU memory by clearing PyTorch cache and running garbage collection
    """
    if HAS_TORCH and torch.cuda.is_available():
        try:
            # Clear PyTorch GPU cache
            torch.cuda.empty_cache()
            torch.cuda.synchronize()
            print("GPU cache cleared")
        except Exception as e:
            print(f"Warning: Could not clear GPU cache: {e}")
    
    # Run Python garbage collection
    gc.collect()

def monitor_memory_usage(stage: str) -> None:
    """
    Monitor and log memory usage at different stages
    
    Args:
        stage: Description of current stage (e.g., "before_inference", "after_inference")
    """
    gpu_info = get_gpu_memory_info()
    
    # Get system memory info
    system_memory = psutil.virtual_memory()
    
    print(f"=== Memory Usage - {stage} ===")
    print(f"GPU Memory: {gpu_info['used_mb']:.1f}MB / {gpu_info['total_mb']:.1f}MB "
          f"({gpu_info['utilization_pct']:.1f}% used)")
    if 'cached_mb' in gpu_info:
        print(f"GPU Cached: {gpu_info['cached_mb']:.1f}MB")
    print(f"System RAM: {system_memory.used / (1024**3):.1f}GB / "
          f"{system_memory.total / (1024**3):.1f}GB ({system_memory.percent:.1f}% used)")
    print("=" * 40)

def check_gpu_availability() -> bool:
    """
    Check if GPU is available and accessible
    
    Returns:
        True if GPU is available, False otherwise
    """
    if not HAS_TORCH:
        print("Warning: PyTorch not available")
        return False
        
    if not torch.cuda.is_available():
        print("Warning: CUDA not available")
        return False
        
    gpu_count = torch.cuda.device_count()
    if gpu_count == 0:
        print("Warning: No GPU devices found")
        return False
        
    print(f"GPU available: {torch.cuda.get_device_name(0)} (Count: {gpu_count})")
    return True

def setup_gpu_monitoring() -> None:
    """
    Setup GPU monitoring for inference
    """
    print("=== GPU Monitoring Setup ===")
    
    if check_gpu_availability():
        monitor_memory_usage("startup")
    else:
        print("GPU monitoring disabled - no GPU available")

def cleanup_and_monitor() -> None:
    """
    Cleanup GPU memory and monitor final state
    """
    print("=== Cleaning up GPU resources ===")
    cleanup_gpu_memory()
    
    if HAS_TORCH and torch.cuda.is_available():
        monitor_memory_usage("after_cleanup")

if __name__ == "__main__":
    # Test the GPU monitoring functions
    setup_gpu_monitoring()
    cleanup_and_monitor()