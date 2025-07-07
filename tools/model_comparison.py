#!/usr/bin/env python3
"""
多模型比较和分析工具
用于比较不同模型在相同数据上的表现
"""

import json
import pandas as pd
import numpy as np
from typing import List, Dict, Any, Optional
from dataclasses import dataclass
from pathlib import Path
import matplotlib.pyplot as plt
import seaborn as sns
from model_output_standard import StandardOutput

@dataclass
class ModelPerformance:
    """模型性能指标"""
    model_name: str
    inference_time: float      # 推理时间 (秒)
    gpu_memory_used: float     # GPU内存使用 (MB)
    detection_count: int       # 检测目标数量
    map_element_count: int     # 地图元素数量
    avg_confidence: float      # 平均置信度
    high_conf_ratio: float     # 高置信度比例 (>0.7)
    error_status: Optional[str] # 错误状态

class ModelComparator:
    """多模型比较器"""
    
    def __init__(self, output_dir: str = "./comparison_results"):
        self.output_dir = Path(output_dir)
        self.output_dir.mkdir(exist_ok=True)
        self.results: List[StandardOutput] = []
        self.performances: List[ModelPerformance] = []
    
    def add_result(self, result: StandardOutput):
        """添加模型结果"""
        self.results.append(result)
        self._calculate_performance(result)
    
    def _calculate_performance(self, result: StandardOutput) -> ModelPerformance:
        """计算模型性能指标"""
        # 基础指标
        inference_time = result.metadata.inference_time
        gpu_memory = result.metadata.gpu_memory_used
        
        # 检测统计
        detection_count = len(result.detections_3d) if result.detections_3d else 0
        map_element_count = len(result.map_elements) if result.map_elements else 0
        
        # 置信度统计
        confidences = []
        if result.detections_3d:
            confidences.extend([det.confidence for det in result.detections_3d])
        if result.map_elements:
            confidences.extend([elem.confidence for elem in result.map_elements])
        
        avg_confidence = np.mean(confidences) if confidences else 0.0
        high_conf_ratio = sum(1 for c in confidences if c > 0.7) / len(confidences) if confidences else 0.0
        
        performance = ModelPerformance(
            model_name=result.metadata.model_name,
            inference_time=inference_time,
            gpu_memory_used=gpu_memory,
            detection_count=detection_count,
            map_element_count=map_element_count,
            avg_confidence=avg_confidence,
            high_conf_ratio=high_conf_ratio,
            error_status=result.error
        )
        
        self.performances.append(performance)
        return performance
    
    def generate_comparison_report(self) -> Dict[str, Any]:
        """生成比较报告"""
        if not self.performances:
            return {"error": "No results to compare"}
        
        # 创建性能数据框
        df = pd.DataFrame([
            {
                'Model': p.model_name,
                'Inference_Time_s': p.inference_time,
                'GPU_Memory_MB': p.gpu_memory_used,
                'Detection_Count': p.detection_count,
                'Map_Element_Count': p.map_element_count,
                'Avg_Confidence': p.avg_confidence,
                'High_Conf_Ratio': p.high_conf_ratio,
                'Has_Error': p.error_status is not None
            }
            for p in self.performances
        ])
        
        # 统计分析
        report = {
            "summary": {
                "total_models": len(self.performances),
                "successful_models": sum(1 for p in self.performances if p.error_status is None),
                "failed_models": sum(1 for p in self.performances if p.error_status is not None)
            },
            "performance_ranking": {},
            "detailed_comparison": df.to_dict('records'),
            "insights": []
        }
        
        # 性能排名
        if len(df) > 1:
            report["performance_ranking"] = {
                "fastest_inference": df.loc[df['Inference_Time_s'].idxmin(), 'Model'],
                "lowest_memory": df.loc[df['GPU_Memory_MB'].idxmin(), 'Model'],
                "most_detections": df.loc[df['Detection_Count'].idxmax(), 'Model'],
                "highest_confidence": df.loc[df['Avg_Confidence'].idxmax(), 'Model']
            }
            
            # 生成洞察
            report["insights"] = self._generate_insights(df)
        
        return report
    
    def _generate_insights(self, df: pd.DataFrame) -> List[str]:
        """生成分析洞察"""
        insights = []
        
        # 推理时间分析
        time_range = df['Inference_Time_s'].max() - df['Inference_Time_s'].min()
        if time_range > 0.1:  # 超过100ms差异
            fastest = df.loc[df['Inference_Time_s'].idxmin(), 'Model']
            slowest = df.loc[df['Inference_Time_s'].idxmax(), 'Model']
            speedup = df['Inference_Time_s'].max() / df['Inference_Time_s'].min()
            insights.append(f"推理速度：{fastest} 比 {slowest} 快 {speedup:.1f}x")
        
        # 内存使用分析
        memory_range = df['GPU_Memory_MB'].max() - df['GPU_Memory_MB'].min()
        if memory_range > 500:  # 超过500MB差异
            efficient = df.loc[df['GPU_Memory_MB'].idxmin(), 'Model']
            hungry = df.loc[df['GPU_Memory_MB'].idxmax(), 'Model']
            insights.append(f"内存效率：{efficient} 比 {hungry} 节省 {memory_range:.0f}MB GPU内存")
        
        # 检测能力分析
        if df['Detection_Count'].sum() > 0:
            best_detector = df.loc[df['Detection_Count'].idxmax(), 'Model']
            avg_detections = df['Detection_Count'].mean()
            insights.append(f"检测能力：{best_detector} 检测到最多目标，平均检测数量 {avg_detections:.1f}")
        
        # 置信度分析
        if df['Avg_Confidence'].max() > 0:
            most_confident = df.loc[df['Avg_Confidence'].idxmax(), 'Model']
            avg_conf = df['Avg_Confidence'].mean()
            insights.append(f"置信度：{most_confident} 具有最高平均置信度，整体平均 {avg_conf:.3f}")
        
        return insights
    
    def create_visualizations(self):
        """创建可视化图表"""
        if len(self.performances) < 2:
            print("需要至少2个模型结果才能创建比较图表")
            return
        
        # 设置图表样式
        plt.style.use('seaborn-v0_8')
        fig, axes = plt.subplots(2, 2, figsize=(15, 12))
        fig.suptitle('多模型性能比较', fontsize=16, fontweight='bold')
        
        # 准备数据
        models = [p.model_name for p in self.performances]
        inference_times = [p.inference_time for p in self.performances]
        memory_usage = [p.gpu_memory_used for p in self.performances]
        detection_counts = [p.detection_count for p in self.performances]
        avg_confidences = [p.avg_confidence for p in self.performances]
        
        # 1. 推理时间比较
        axes[0, 0].bar(models, inference_times, color='skyblue', alpha=0.7)
        axes[0, 0].set_title('推理时间比较')
        axes[0, 0].set_ylabel('时间 (秒)')
        axes[0, 0].tick_params(axis='x', rotation=45)
        
        # 2. GPU内存使用比较
        axes[0, 1].bar(models, memory_usage, color='lightcoral', alpha=0.7)
        axes[0, 1].set_title('GPU内存使用比较')
        axes[0, 1].set_ylabel('内存 (MB)')
        axes[0, 1].tick_params(axis='x', rotation=45)
        
        # 3. 检测数量比较
        axes[1, 0].bar(models, detection_counts, color='lightgreen', alpha=0.7)
        axes[1, 0].set_title('检测目标数量比较')
        axes[1, 0].set_ylabel('检测数量')
        axes[1, 0].tick_params(axis='x', rotation=45)
        
        # 4. 平均置信度比较
        axes[1, 1].bar(models, avg_confidences, color='gold', alpha=0.7)
        axes[1, 1].set_title('平均置信度比较')
        axes[1, 1].set_ylabel('置信度')
        axes[1, 1].set_ylim(0, 1)
        axes[1, 1].tick_params(axis='x', rotation=45)
        
        plt.tight_layout()
        
        # 保存图表
        chart_path = self.output_dir / "model_comparison_charts.png"
        plt.savefig(chart_path, dpi=300, bbox_inches='tight')
        plt.close()
        
        print(f"📊 比较图表已保存至: {chart_path}")
        
        # 创建雷达图 (如果有多个指标)
        self._create_radar_chart(models, inference_times, memory_usage, detection_counts, avg_confidences)
    
    def _create_radar_chart(self, models, inference_times, memory_usage, detection_counts, avg_confidences):
        """创建雷达图比较"""
        try:
            from math import pi
            
            # 标准化数据 (0-1 范围，值越高越好)
            def normalize_metric(values, higher_better=True):
                if not values or max(values) == min(values):
                    return [0.5] * len(values)
                if higher_better:
                    return [(v - min(values)) / (max(values) - min(values)) for v in values]
                else:
                    return [(max(values) - v) / (max(values) - min(values)) for v in values]
            
            # 标准化指标 (推理时间和内存使用越低越好，其他越高越好)
            norm_time = normalize_metric(inference_times, higher_better=False)
            norm_memory = normalize_metric(memory_usage, higher_better=False)
            norm_detections = normalize_metric(detection_counts, higher_better=True)
            norm_confidence = normalize_metric(avg_confidences, higher_better=True)
            
            # 指标名称
            metrics = ['推理速度', 'GPU效率', '检测能力', '置信度']
            
            # 创建雷达图
            fig, ax = plt.subplots(figsize=(10, 10), subplot_kw=dict(projection='polar'))
            
            # 角度
            angles = [n / float(len(metrics)) * 2 * pi for n in range(len(metrics))]
            angles += angles[:1]  # 完成圆圈
            
            # 为每个模型绘制
            colors = ['red', 'blue', 'green', 'orange', 'purple']
            for i, model in enumerate(models):
                values = [norm_time[i], norm_memory[i], norm_detections[i], norm_confidence[i]]
                values += values[:1]  # 完成圆圈
                
                ax.plot(angles, values, 'o-', linewidth=2, 
                       label=model, color=colors[i % len(colors)])
                ax.fill(angles, values, alpha=0.25, color=colors[i % len(colors)])
            
            # 添加标签
            ax.set_xticks(angles[:-1])
            ax.set_xticklabels(metrics)
            ax.set_ylim(0, 1)
            ax.set_yticks([0.2, 0.4, 0.6, 0.8, 1.0])
            ax.set_yticklabels(['20%', '40%', '60%', '80%', '100%'])
            ax.grid(True)
            
            plt.legend(loc='upper right', bbox_to_anchor=(1.2, 1.0))
            plt.title('模型综合性能雷达图', size=16, fontweight='bold', pad=20)
            
            # 保存雷达图
            radar_path = self.output_dir / "model_radar_comparison.png"
            plt.savefig(radar_path, dpi=300, bbox_inches='tight')
            plt.close()
            
            print(f"📈 雷达图已保存至: {radar_path}")
            
        except Exception as e:
            print(f"创建雷达图时出错: {e}")
    
    def save_results(self):
        """保存比较结果"""
        # 保存详细的JSON结果
        detailed_results = {
            "models": [result.to_dict() for result in self.results],
            "performances": [
                {
                    "model_name": p.model_name,
                    "inference_time": p.inference_time,
                    "gpu_memory_used": p.gpu_memory_used,
                    "detection_count": p.detection_count,
                    "map_element_count": p.map_element_count,
                    "avg_confidence": p.avg_confidence,
                    "high_conf_ratio": p.high_conf_ratio,
                    "error_status": p.error_status
                }
                for p in self.performances
            ]
        }
        
        results_path = self.output_dir / "detailed_results.json"
        with open(results_path, 'w', encoding='utf-8') as f:
            json.dump(detailed_results, f, indent=2, ensure_ascii=False)
        
        # 保存比较报告
        report = self.generate_comparison_report()
        report_path = self.output_dir / "comparison_report.json"
        with open(report_path, 'w', encoding='utf-8') as f:
            json.dump(report, f, indent=2, ensure_ascii=False)
        
        # 保存CSV格式的性能数据
        if self.performances:
            df = pd.DataFrame([
                {
                    'Model': p.model_name,
                    'Inference_Time_s': p.inference_time,
                    'GPU_Memory_MB': p.gpu_memory_used,
                    'Detection_Count': p.detection_count,
                    'Map_Element_Count': p.map_element_count,
                    'Avg_Confidence': p.avg_confidence,
                    'High_Conf_Ratio': p.high_conf_ratio,
                    'Has_Error': p.error_status is not None
                }
                for p in self.performances
            ])
            
            csv_path = self.output_dir / "performance_comparison.csv"
            df.to_csv(csv_path, index=False)
        
        print(f"📁 结果已保存至目录: {self.output_dir}")
        print(f"  - 详细结果: {results_path}")
        print(f"  - 比较报告: {report_path}")
        print(f"  - 性能CSV: {csv_path}")

# 使用示例
if __name__ == "__main__":
    from model_output_standard import create_standardizer, ModelMetadata
    
    # 创建比较器
    comparator = ModelComparator("./model_comparison_demo")
    
    # 模拟一些测试结果
    test_results = [
        {
            "model": "MapTR",
            "raw_output": [
                {"id": 0, "class_name": "divider", "confidence": 0.85, "pts": [[1, 2], [3, 4]]},
                {"id": 1, "class_name": "car", "confidence": 0.92, "bbox": [10, 10, 20, 20]}
            ],
            "metadata": {"inference_time": 0.25, "gpu_memory_used": 2048}
        },
        {
            "model": "PETR", 
            "raw_output": {
                "pts_bbox": {
                    "boxes_3d": [[0, 0, 0, 2, 3, 1, 0.1]],
                    "scores_3d": [0.88],
                    "labels_3d": [0]
                }
            },
            "metadata": {"inference_time": 0.18, "gpu_memory_used": 1800}
        }
    ]
    
    # 处理结果
    for test in test_results:
        standardizer = create_standardizer(test["model"])
        result = standardizer.standardize(test["raw_output"], test["metadata"])
        comparator.add_result(result)
    
    # 生成比较报告和可视化
    report = comparator.generate_comparison_report()
    print("\n📊 比较报告:")
    print(json.dumps(report, indent=2, ensure_ascii=False))
    
    comparator.create_visualizations()
    comparator.save_results()