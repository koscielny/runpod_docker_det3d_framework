#!/usr/bin/env python3
"""
nuScenes 数据集分析工具
提供数据集的统计分析和可视化
"""

import argparse
import json
import os
import numpy as np
import matplotlib.pyplot as plt
import seaborn as sns
from collections import defaultdict, Counter
from nuscenes.nuscenes import NuScenes
from nuscenes.utils.geometry_utils import view_points, transform_matrix
import pandas as pd


def analyze_dataset(dataroot, version='v1.0-trainval', output_dir='outputs/analysis'):
    """
    分析nuScenes数据集
    
    Args:
        dataroot: nuScenes数据集根目录
        version: 数据集版本
        output_dir: 输出目录
    """
    try:
        print(f"正在加载nuScenes数据集...")
        nusc = NuScenes(version=version, dataroot=dataroot, verbose=False)
        
        os.makedirs(output_dir, exist_ok=True)
        
        # 收集统计信息
        stats = {
            'scenes': analyze_scenes(nusc),
            'objects': analyze_objects(nusc),
            'sensors': analyze_sensors(nusc),
            'locations': analyze_locations(nusc),
            'weather': analyze_weather(nusc),
            'temporal': analyze_temporal_distribution(nusc)
        }
        
        # 生成报告
        generate_analysis_report(stats, output_dir)
        
        # 生成可视化图表
        generate_visualizations(stats, nusc, output_dir)
        
        print(f"✅ 数据集分析完成，结果保存在: {output_dir}")
        return stats
        
    except Exception as e:
        print(f"错误: {e}")
        return None


def analyze_scenes(nusc):
    """分析场景信息"""
    scenes_stats = {
        'total_scenes': len(nusc.scene),
        'scenes_by_location': defaultdict(int),
        'scene_lengths': [],
        'scene_details': []
    }
    
    for scene in nusc.scene:
        log = nusc.get('log', scene['log_token'])
        location = log['location']
        scenes_stats['scenes_by_location'][location] += 1
        scenes_stats['scene_lengths'].append(scene['nbr_samples'])
        
        scenes_stats['scene_details'].append({
            'name': scene['name'],
            'location': location,
            'nbr_samples': scene['nbr_samples'],
            'description': scene['description']
        })
    
    scenes_stats['avg_scene_length'] = np.mean(scenes_stats['scene_lengths'])
    scenes_stats['total_samples'] = sum(scenes_stats['scene_lengths'])
    
    return dict(scenes_stats)


def analyze_objects(nusc):
    """分析目标对象信息"""
    object_stats = {
        'total_annotations': len(nusc.sample_annotation),
        'categories': defaultdict(int),
        'attributes': defaultdict(int),
        'object_sizes': defaultdict(list),
        'visibility_levels': defaultdict(int)
    }
    
    for ann in nusc.sample_annotation:
        category = ann['category_name']
        object_stats['categories'][category] += 1
        
        # 分析属性
        for attr_token in ann['attribute_tokens']:
            attr = nusc.get('attribute', attr_token)
            object_stats['attributes'][attr['name']] += 1
        
        # 分析尺寸
        size = ann['size']  # [width, length, height]
        object_stats['object_sizes'][category].append(size)
        
        # 可见性
        visibility_token = ann['visibility_token']
        visibility = nusc.get('visibility', visibility_token)
        object_stats['visibility_levels'][visibility['description']] += 1
    
    return dict(object_stats)


def analyze_sensors(nusc):
    """分析传感器信息"""
    sensor_stats = {
        'sensor_types': defaultdict(int),
        'camera_positions': defaultdict(int),
        'sample_data_count': defaultdict(int)
    }
    
    for sample_data in nusc.sample_data:
        sensor = nusc.get('calibrated_sensor', sample_data['calibrated_sensor_token'])
        sensor_modality = sensor['sensor_token']
        sensor_info = nusc.get('sensor', sensor_modality)
        
        modality = sensor_info['modality']
        channel = sensor_info['channel']
        
        sensor_stats['sensor_types'][modality] += 1
        sensor_stats['sample_data_count'][channel] += 1
        
        if modality == 'camera':
            sensor_stats['camera_positions'][channel] += 1
    
    return dict(sensor_stats)


def analyze_locations(nusc):
    """分析地理位置信息"""
    location_stats = defaultdict(lambda: {
        'scenes': 0,
        'total_samples': 0,
        'weather_conditions': defaultdict(int)
    })
    
    for scene in nusc.scene:
        log = nusc.get('log', scene['log_token'])
        location = log['location']
        
        location_stats[location]['scenes'] += 1
        location_stats[location]['total_samples'] += scene['nbr_samples']
        
        # 分析天气条件（如果有的话）
        # 这里简化处理，实际可能需要从log或其他地方获取
    
    return dict(location_stats)


def analyze_weather(nusc):
    """分析天气和光照条件"""
    # nuScenes数据集中天气信息比较有限，这里做简化分析
    weather_stats = {
        'day_scenes': 0,
        'night_scenes': 0,
        'rain_scenes': 0,
        'clear_scenes': 0
    }
    
    for scene in nusc.scene:
        description = scene['description'].lower()
        
        if 'night' in description:
            weather_stats['night_scenes'] += 1
        else:
            weather_stats['day_scenes'] += 1
            
        if 'rain' in description:
            weather_stats['rain_scenes'] += 1
        else:
            weather_stats['clear_scenes'] += 1
    
    return weather_stats


def analyze_temporal_distribution(nusc):
    """分析时间分布"""
    timestamps = []
    
    for sample in nusc.sample:
        timestamps.append(sample['timestamp'])
    
    timestamps = np.array(timestamps)
    
    # 转换为小时
    hours = [(ts // 1000000) % (24 * 3600) // 3600 for ts in timestamps]
    
    temporal_stats = {
        'total_samples': len(timestamps),
        'time_span_hours': (timestamps.max() - timestamps.min()) / (1000000 * 3600),
        'hourly_distribution': Counter(hours)
    }
    
    return temporal_stats


def generate_analysis_report(stats, output_dir):
    """生成分析报告"""
    report_path = os.path.join(output_dir, 'dataset_analysis_report.json')
    
    # 转换不可序列化的对象
    serializable_stats = {}
    for key, value in stats.items():
        if isinstance(value, dict):
            serializable_stats[key] = dict(value)
        else:
            serializable_stats[key] = value
    
    with open(report_path, 'w', encoding='utf-8') as f:
        json.dump(serializable_stats, f, indent=2, ensure_ascii=False, default=str)
    
    # 生成文本报告
    text_report_path = os.path.join(output_dir, 'dataset_summary.txt')
    with open(text_report_path, 'w', encoding='utf-8') as f:
        f.write("nuScenes 数据集分析报告\n")
        f.write("=" * 50 + "\n\n")
        
        # 场景统计
        f.write(f"场景统计:\n")
        f.write(f"  总场景数: {stats['scenes']['total_scenes']}\n")
        f.write(f"  总样本数: {stats['scenes']['total_samples']}\n")
        f.write(f"  平均场景长度: {stats['scenes']['avg_scene_length']:.1f} 样本\n")
        f.write(f"  地点分布:\n")
        for location, count in stats['scenes']['scenes_by_location'].items():
            f.write(f"    {location}: {count} 场景\n")
        f.write("\n")
        
        # 目标统计
        f.write(f"目标对象统计:\n")
        f.write(f"  总标注数: {stats['objects']['total_annotations']}\n")
        f.write(f"  类别分布 (前10个):\n")
        sorted_categories = sorted(stats['objects']['categories'].items(), 
                                 key=lambda x: x[1], reverse=True)
        for category, count in sorted_categories[:10]:
            f.write(f"    {category}: {count}\n")
        f.write("\n")
        
        # 传感器统计
        f.write(f"传感器统计:\n")
        for sensor_type, count in stats['sensors']['sensor_types'].items():
            f.write(f"  {sensor_type}: {count} 样本\n")
        f.write("\n")
        
        # 天气统计
        f.write(f"天气条件:\n")
        for condition, count in stats['weather'].items():
            f.write(f"  {condition}: {count}\n")


def generate_visualizations(stats, nusc, output_dir):
    """生成可视化图表"""
    plt.style.use('seaborn-v0_8')
    
    # 1. 场景长度分布
    plt.figure(figsize=(12, 8))
    
    plt.subplot(2, 3, 1)
    plt.hist(stats['scenes']['scene_lengths'], bins=20, alpha=0.7)
    plt.title('场景长度分布')
    plt.xlabel('样本数')
    plt.ylabel('场景数')
    
    # 2. 地点分布
    plt.subplot(2, 3, 2)
    locations = list(stats['scenes']['scenes_by_location'].keys())
    counts = list(stats['scenes']['scenes_by_location'].values())
    plt.pie(counts, labels=locations, autopct='%1.1f%%')
    plt.title('地点分布')
    
    # 3. 目标类别分布（前10个）
    plt.subplot(2, 3, 3)
    sorted_categories = sorted(stats['objects']['categories'].items(), 
                             key=lambda x: x[1], reverse=True)
    categories = [item[0] for item in sorted_categories[:10]]
    category_counts = [item[1] for item in sorted_categories[:10]]
    
    plt.barh(range(len(categories)), category_counts)
    plt.yticks(range(len(categories)), categories)
    plt.title('目标类别分布 (前10)')
    plt.xlabel('数量')
    
    # 4. 时间分布
    plt.subplot(2, 3, 4)
    hours = list(stats['temporal']['hourly_distribution'].keys())
    hour_counts = list(stats['temporal']['hourly_distribution'].values())
    plt.bar(hours, hour_counts)
    plt.title('小时分布')
    plt.xlabel('小时')
    plt.ylabel('样本数')
    
    # 5. 可见性分布
    plt.subplot(2, 3, 5)
    visibility_levels = list(stats['objects']['visibility_levels'].keys())
    visibility_counts = list(stats['objects']['visibility_levels'].values())
    plt.pie(visibility_counts, labels=visibility_levels, autopct='%1.1f%%')
    plt.title('可见性分布')
    
    # 6. 传感器数据分布
    plt.subplot(2, 3, 6)
    sensor_channels = list(stats['sensors']['sample_data_count'].keys())
    sensor_counts = list(stats['sensors']['sample_data_count'].values())
    plt.bar(range(len(sensor_channels)), sensor_counts)
    plt.xticks(range(len(sensor_channels)), sensor_channels, rotation=45)
    plt.title('传感器数据分布')
    plt.ylabel('样本数')
    
    plt.tight_layout()
    plt.savefig(os.path.join(output_dir, 'dataset_statistics.png'), dpi=300, bbox_inches='tight')
    plt.close()
    
    print(f"✅ 统计图表已保存")


def main():
    parser = argparse.ArgumentParser(
        description='分析nuScenes数据集',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
使用示例:
  python analyze_dataset.py --dataroot /data/nuscenes
  python analyze_dataset.py --dataroot /data/nuscenes --version v1.0-mini --output custom_analysis
        """
    )
    
    parser.add_argument('--dataroot', type=str, required=True,
                        help='nuScenes数据集根目录路径')
    parser.add_argument('--version', type=str, default='v1.0-trainval',
                        choices=['v1.0-trainval', 'v1.0-test', 'v1.0-mini'],
                        help='数据集版本 (默认: v1.0-trainval)')
    parser.add_argument('--output', type=str, default='outputs/analysis',
                        help='输出目录 (默认: outputs/analysis)')
    
    args = parser.parse_args()
    
    # 检查数据集路径
    if not os.path.exists(args.dataroot):
        print(f"错误: 数据集路径不存在: {args.dataroot}")
        return
    
    # 分析数据集
    stats = analyze_dataset(
        dataroot=args.dataroot,
        version=args.version,
        output_dir=args.output
    )
    
    if stats:
        print(f"\n📊 数据集分析完成!")
        print(f"   场景数: {stats['scenes']['total_scenes']}")
        print(f"   样本数: {stats['scenes']['total_samples']}")
        print(f"   标注数: {stats['objects']['total_annotations']}")
        print(f"   结果目录: {args.output}")


if __name__ == '__main__':
    main()