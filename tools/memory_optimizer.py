#!/usr/bin/env python3
"""
内存优化和监控工具
用于优化Docker容器内存使用和监控内存状况
"""

import os
import gc
import sys
import psutil
import subprocess
from typing import Dict, List, Tuple
import time

class MemoryOptimizer:
    """内存优化器"""
    
    def __init__(self):
        self.process = psutil.Process()
        
    def get_memory_info(self) -> Dict[str, float]:
        """获取详细内存信息"""
        # 系统内存
        vm = psutil.virtual_memory()
        
        # 进程内存
        process_memory = self.process.memory_info()
        
        info = {
            # 系统内存 (MB)
            'system_total_mb': vm.total / (1024**2),
            'system_used_mb': vm.used / (1024**2),
            'system_available_mb': vm.available / (1024**2),
            'system_percent': vm.percent,
            
            # 进程内存 (MB)
            'process_rss_mb': process_memory.rss / (1024**2),
            'process_vms_mb': process_memory.vms / (1024**2),
            
            # 计算值
            'recommended_total_mb': max(1024, vm.used / (1024**2) * 1.5),  # 推荐总内存
            'memory_pressure': vm.percent > 80,  # 内存压力指标
        }
        
        return info
    
    def analyze_memory_usage(self) -> Tuple[str, List[str]]:
        """分析内存使用情况并提供建议"""
        info = self.get_memory_info()
        
        status = "正常"
        suggestions = []
        
        # 分析系统内存
        if info['system_percent'] > 90:
            status = "严重"
            suggestions.extend([
                "🚨 内存使用率过高 (>90%)，可能影响系统稳定性",
                "建议立即释放内存或增加容器内存配置",
                f"推荐内存配置: {info['recommended_total_mb']:.0f}MB"
            ])
        elif info['system_percent'] > 80:
            status = "警告"
            suggestions.extend([
                "⚠️ 内存使用率较高 (>80%)，建议优化",
                "建议运行内存清理或增加内存配置",
                f"推荐内存配置: {info['recommended_total_mb']:.0f}MB"
            ])
        elif info['system_percent'] > 70:
            status = "注意"
            suggestions.extend([
                "💡 内存使用率偏高 (>70%)，可考虑优化",
                f"当前可用内存: {info['system_available_mb']:.0f}MB"
            ])
        
        # 检查总内存大小
        if info['system_total_mb'] < 1024:
            suggestions.append(
                f"📈 当前内存配置较小 ({info['system_total_mb']:.0f}MB)，"
                f"AI模型推荐至少1GB内存"
            )
        
        return status, suggestions
    
    def cleanup_memory(self) -> Dict[str, float]:
        """执行内存清理"""
        print("🧹 开始内存清理...")
        
        before = self.get_memory_info()
        
        # Python垃圾回收
        collected = gc.collect()
        print(f"   Python GC: 回收了 {collected} 个对象")
        
        # 清理PyTorch缓存（如果可用）
        try:
            import torch
            if torch.cuda.is_available():
                torch.cuda.empty_cache()
                torch.cuda.synchronize()
                print("   GPU缓存已清理")
        except ImportError:
            pass
        
        # 强制内存整理
        if hasattr(gc, 'set_threshold'):
            gc.set_threshold(700, 10, 10)  # 更激进的GC
        
        time.sleep(0.5)  # 等待清理完成
        after = self.get_memory_info()
        
        freed_mb = before['system_used_mb'] - after['system_used_mb']
        print(f"✅ 内存清理完成，释放了 {freed_mb:.1f}MB")
        
        return {
            'freed_mb': freed_mb,
            'before_percent': before['system_percent'],
            'after_percent': after['system_percent']
        }
    
    def monitor_memory(self, duration: int = 60, interval: int = 5):
        """持续监控内存使用"""
        print(f"📊 开始监控内存使用 ({duration}秒, 每{interval}秒检查)")
        print("时间\t\t使用率\t已用内存\t可用内存")
        print("-" * 50)
        
        start_time = time.time()
        while time.time() - start_time < duration:
            info = self.get_memory_info()
            timestamp = time.strftime("%H:%M:%S")
            
            print(f"{timestamp}\t{info['system_percent']:.1f}%\t\t"
                  f"{info['system_used_mb']:.0f}MB\t\t{info['system_available_mb']:.0f}MB")
            
            if info['memory_pressure']:
                print("⚠️ 检测到内存压力!")
                
            time.sleep(interval)
    
    def get_top_memory_processes(self, limit: int = 5) -> List[Dict]:
        """获取内存使用最高的进程"""
        processes = []
        for proc in psutil.process_iter(['pid', 'name', 'memory_percent', 'memory_info']):
            try:
                processes.append(proc.info)
            except (psutil.NoSuchProcess, psutil.AccessDenied):
                pass
        
        # 按内存使用排序
        processes.sort(key=lambda x: x['memory_percent'], reverse=True)
        return processes[:limit]

def print_memory_report():
    """打印详细内存报告"""
    optimizer = MemoryOptimizer()
    info = optimizer.get_memory_info()
    status, suggestions = optimizer.analyze_memory_usage()
    
    print("=" * 60)
    print("📋 内存状态报告")
    print("=" * 60)
    
    # 基本信息
    print(f"💾 系统内存: {info['system_used_mb']:.1f}MB / {info['system_total_mb']:.1f}MB "
          f"({info['system_percent']:.1f}%)")
    print(f"🆓 可用内存: {info['system_available_mb']:.1f}MB")
    print(f"🔄 进程内存: RSS={info['process_rss_mb']:.1f}MB, VMS={info['process_vms_mb']:.1f}MB")
    
    # 状态评估
    status_emoji = {
        "正常": "✅",
        "注意": "💡", 
        "警告": "⚠️",
        "严重": "🚨"
    }
    print(f"\n📊 状态评估: {status_emoji.get(status, '❓')} {status}")
    
    # 建议
    if suggestions:
        print(f"\n💡 优化建议:")
        for suggestion in suggestions:
            print(f"   {suggestion}")
    
    # 热门进程
    print(f"\n🔝 内存使用最高的进程:")
    top_processes = optimizer.get_top_memory_processes()
    for proc in top_processes:
        memory_mb = proc['memory_info'].rss / (1024**2) if proc['memory_info'] else 0
        print(f"   {proc['name']} (PID: {proc['pid']}): "
              f"{memory_mb:.1f}MB ({proc['memory_percent']:.1f}%)")
    
    print("=" * 60)
    
    return optimizer, status

def main():
    """主函数"""
    import argparse
    
    parser = argparse.ArgumentParser(description='内存优化和监控工具')
    parser.add_argument('--cleanup', action='store_true', help='执行内存清理')
    parser.add_argument('--monitor', type=int, metavar='SECONDS', help='监控指定秒数')
    parser.add_argument('--report', action='store_true', help='显示内存报告')
    
    args = parser.parse_args()
    
    # 默认显示报告
    if not any([args.cleanup, args.monitor]):
        args.report = True
    
    optimizer, status = print_memory_report()
    
    if args.cleanup:
        print()
        result = optimizer.cleanup_memory()
        print(f"\n📈 清理效果: {result['before_percent']:.1f}% → {result['after_percent']:.1f}%")
    
    if args.monitor:
        print()
        optimizer.monitor_memory(duration=args.monitor)
    
    # 根据状态提供操作建议
    if status in ["警告", "严重"]:
        print(f"\n🎯 快速解决方案:")
        print(f"   python {__file__} --cleanup  # 执行内存清理")
        print(f"   python {__file__} --monitor 30  # 监控30秒")

if __name__ == "__main__":
    main()