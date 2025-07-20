#!/usr/bin/env python3
"""
nuScenes 场景列表工具
列出数据集中所有可用的场景ID及其基本信息
"""

import argparse
import json
import os
from pathlib import Path
from nuscenes.nuscenes import NuScenes


def list_scenes(dataroot, version='v1.0-trainval', output_format='table', save_json=None):
    """
    列出nuScenes数据集中的所有场景
    
    Args:
        dataroot: nuScenes数据集根目录
        version: 数据集版本
        output_format: 输出格式 ('table', 'json', 'simple')
        save_json: 保存JSON文件路径
    """
    try:
        # 初始化nuScenes
        print(f"正在加载nuScenes数据集 (版本: {version})...")
        nusc = NuScenes(version=version, dataroot=dataroot, verbose=False)
        
        # 获取场景信息
        scenes_info = []
        for scene in nusc.scene:
            # 获取第一个样本的时间戳
            first_sample = nusc.get('sample', scene['first_sample_token'])
            
            scene_info = {
                'scene_token': scene['token'],
                'scene_name': scene['name'],
                'description': scene['description'],
                'nbr_samples': scene['nbr_samples'],
                'location': nusc.get('log', scene['log_token'])['location'],
                'timestamp': first_sample['timestamp']
            }
            scenes_info.append(scene_info)
        
        # 按场景名称排序
        scenes_info.sort(key=lambda x: x['scene_name'])
        
        # 输出结果
        if output_format == 'table':
            print(f"\n找到 {len(scenes_info)} 个场景:")
            print("-" * 120)
            print(f"{'序号':<4} {'场景名称':<20} {'位置':<15} {'样本数':<6} {'描述':<40}")
            print("-" * 120)
            
            for i, scene in enumerate(scenes_info, 1):
                description = scene['description'][:37] + "..." if len(scene['description']) > 40 else scene['description']
                print(f"{i:<4} {scene['scene_name']:<20} {scene['location']:<15} {scene['nbr_samples']:<6} {description:<40}")
        
        elif output_format == 'json':
            print(json.dumps(scenes_info, indent=2, ensure_ascii=False))
        
        elif output_format == 'simple':
            for scene in scenes_info:
                print(scene['scene_name'])
        
        # 保存JSON文件
        if save_json:
            os.makedirs(os.path.dirname(save_json), exist_ok=True)
            with open(save_json, 'w', encoding='utf-8') as f:
                json.dump(scenes_info, f, indent=2, ensure_ascii=False)
            print(f"\n场景信息已保存到: {save_json}")
        
        return scenes_info
        
    except Exception as e:
        print(f"错误: {e}")
        return None


def main():
    parser = argparse.ArgumentParser(
        description='列出nuScenes数据集中的所有场景',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
使用示例:
  python list_scenes.py --dataroot /data/nuscenes
  python list_scenes.py --dataroot /data/nuscenes --format json
  python list_scenes.py --dataroot /data/nuscenes --save-json scenes_info.json
  python list_scenes.py --dataroot /data/nuscenes --version v1.0-mini
        """
    )
    
    parser.add_argument('--dataroot', type=str, required=True,
                        help='nuScenes数据集根目录路径')
    parser.add_argument('--version', type=str, default='v1.0-trainval',
                        choices=['v1.0-trainval', 'v1.0-test', 'v1.0-mini'],
                        help='数据集版本 (默认: v1.0-trainval)')
    parser.add_argument('--format', type=str, default='table',
                        choices=['table', 'json', 'simple'],
                        help='输出格式 (默认: table)')
    parser.add_argument('--save-json', type=str, 
                        help='保存场景信息到JSON文件')
    
    args = parser.parse_args()
    
    # 检查数据集路径
    if not os.path.exists(args.dataroot):
        print(f"错误: 数据集路径不存在: {args.dataroot}")
        return
    
    # 执行场景列表
    scenes_info = list_scenes(
        dataroot=args.dataroot,
        version=args.version,
        output_format=args.format,
        save_json=args.save_json
    )
    
    if scenes_info:
        print(f"\n✅ 成功列出 {len(scenes_info)} 个场景")
    else:
        print("\n❌ 场景列表获取失败")


if __name__ == '__main__':
    main()