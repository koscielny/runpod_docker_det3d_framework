#!/usr/bin/env python3
"""
nuScenes 批量可视化工具
一键生成多种可视化内容
"""

import argparse
import os
import subprocess
import json
from concurrent.futures import ThreadPoolExecutor, as_completed
from pathlib import Path


def run_command(cmd, description):
    """运行命令并返回结果"""
    try:
        print(f"正在执行: {description}")
        result = subprocess.run(cmd, shell=True, capture_output=True, text=True)
        if result.returncode == 0:
            print(f"✅ {description} - 完成")
            return True, result.stdout
        else:
            print(f"❌ {description} - 失败: {result.stderr}")
            return False, result.stderr
    except Exception as e:
        print(f"❌ {description} - 异常: {e}")
        return False, str(e)


def batch_visualize(dataroot, scenes, cameras, output_dir, 
                   version='v1.0-trainval', fps=10, max_workers=4):
    """
    批量生成可视化内容
    
    Args:
        dataroot: nuScenes数据集路径
        scenes: 场景列表
        cameras: 相机列表
        output_dir: 输出目录
        version: 数据集版本
        fps: 视频帧率
        max_workers: 最大并发数
    """
    script_dir = os.path.dirname(os.path.abspath(__file__))
    os.makedirs(output_dir, exist_ok=True)
    
    # 生成任务列表
    tasks = []
    
    for scene in scenes:
        # LiDAR BEV视频任务
        lidar_output = os.path.join(output_dir, f"{scene}_lidar_bev.mp4")
        lidar_cmd = f"python {script_dir}/generate_lidar_bev_video.py --dataroot {dataroot} --scene {scene} --version {version} --fps {fps} --output {lidar_output}"
        tasks.append((lidar_cmd, f"LiDAR BEV - {scene}"))
        
        # 相机视频任务
        for camera in cameras:
            camera_output = os.path.join(output_dir, f"{scene}_{camera}.mp4")
            camera_cmd = f"python {script_dir}/generate_camera_video.py --dataroot {dataroot} --scene {scene} --camera {camera} --version {version} --fps {fps} --output {camera_output}"
            tasks.append((camera_cmd, f"Camera {camera} - {scene}"))
    
    print(f"总共 {len(tasks)} 个任务，使用 {max_workers} 个并发")
    
    # 并发执行任务
    completed_tasks = 0
    failed_tasks = 0
    
    with ThreadPoolExecutor(max_workers=max_workers) as executor:
        # 提交所有任务
        future_to_task = {executor.submit(run_command, cmd, desc): (cmd, desc) 
                         for cmd, desc in tasks}
        
        # 处理结果
        for future in as_completed(future_to_task):
            cmd, desc = future_to_task[future]
            try:
                success, output = future.result()
                if success:
                    completed_tasks += 1
                else:
                    failed_tasks += 1
            except Exception as e:
                print(f"❌ 任务异常: {desc} - {e}")
                failed_tasks += 1
    
    print(f"\n📊 批量处理完成:")
    print(f"   成功: {completed_tasks}")
    print(f"   失败: {failed_tasks}")
    print(f"   输出目录: {output_dir}")
    
    return completed_tasks, failed_tasks


def main():
    parser = argparse.ArgumentParser(
        description='nuScenes批量可视化工具',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
使用示例:
  # 为指定场景生成所有相机和LiDAR视频
  python batch_visualize.py --dataroot /data/nuscenes --scenes scene-0001 scene-0002
  
  # 只生成前置和后置相机视频
  python batch_visualize.py --dataroot /data/nuscenes --scenes scene-0001 --cameras CAM_FRONT CAM_BACK
  
  # 使用JSON文件指定场景列表
  python batch_visualize.py --dataroot /data/nuscenes --scenes-json scenes_list.json
        """
    )
    
    parser.add_argument('--dataroot', type=str, required=True,
                        help='nuScenes数据集根目录路径')
    parser.add_argument('--scenes', type=str, nargs='+',
                        help='场景名称列表')
    parser.add_argument('--scenes-json', type=str,
                        help='包含场景列表的JSON文件')
    parser.add_argument('--cameras', type=str, nargs='+',
                        default=['CAM_FRONT', 'CAM_BACK'],
                        choices=['CAM_FRONT', 'CAM_BACK', 'CAM_FRONT_LEFT', 
                                'CAM_FRONT_RIGHT', 'CAM_BACK_LEFT', 'CAM_BACK_RIGHT'],
                        help='相机通道列表 (默认: CAM_FRONT CAM_BACK)')
    parser.add_argument('--output-dir', type=str, default='outputs/batch',
                        help='输出目录 (默认: outputs/batch)')
    parser.add_argument('--version', type=str, default='v1.0-trainval',
                        choices=['v1.0-trainval', 'v1.0-test', 'v1.0-mini'],
                        help='数据集版本 (默认: v1.0-trainval)')
    parser.add_argument('--fps', type=int, default=10,
                        help='视频帧率 (默认: 10)')
    parser.add_argument('--max-workers', type=int, default=4,
                        help='最大并发数 (默认: 4)')
    parser.add_argument('--list-first', action='store_true',
                        help='先列出所有场景供选择')
    
    args = parser.parse_args()
    
    # 检查数据集路径
    if not os.path.exists(args.dataroot):
        print(f"错误: 数据集路径不存在: {args.dataroot}")
        return
    
    # 获取场景列表
    scenes = []
    
    if args.list_first or (not args.scenes and not args.scenes_json):
        # 先列出场景
        script_dir = os.path.dirname(os.path.abspath(__file__))
        list_cmd = f"python {script_dir}/list_scenes.py --dataroot {args.dataroot} --format simple"
        success, output = run_command(list_cmd, "获取场景列表")
        
        if success:
            available_scenes = output.strip().split('\n')
            print(f"\n可用场景 ({len(available_scenes)} 个):")
            for i, scene in enumerate(available_scenes[:20]):  # 只显示前20个
                print(f"  {i+1:2d}. {scene}")
            if len(available_scenes) > 20:
                print(f"  ... 还有 {len(available_scenes) - 20} 个场景")
            
            if not args.scenes and not args.scenes_json:
                print("\n请使用 --scenes 或 --scenes-json 参数指定要处理的场景")
                return
        else:
            print("无法获取场景列表")
            return
    
    if args.scenes:
        scenes = args.scenes
    elif args.scenes_json:
        if not os.path.exists(args.scenes_json):
            print(f"错误: JSON文件不存在: {args.scenes_json}")
            return
        
        try:
            with open(args.scenes_json, 'r', encoding='utf-8') as f:
                data = json.load(f)
                if isinstance(data, list):
                    if isinstance(data[0], str):
                        scenes = data
                    else:
                        scenes = [item['scene_name'] for item in data]
                else:
                    scenes = [data['scene_name']]
        except Exception as e:
            print(f"错误: 读取JSON文件失败: {e}")
            return
    
    if not scenes:
        print("错误: 未指定要处理的场景")
        return
    
    print(f"将处理 {len(scenes)} 个场景: {scenes[:5]}{'...' if len(scenes) > 5 else ''}")
    print(f"相机通道: {args.cameras}")
    
    # 执行批量可视化
    completed, failed = batch_visualize(
        dataroot=args.dataroot,
        scenes=scenes,
        cameras=args.cameras,
        output_dir=args.output_dir,
        version=args.version,
        fps=args.fps,
        max_workers=args.max_workers
    )
    
    if completed > 0:
        print(f"\n🎉 批量可视化完成，生成了 {completed} 个视频文件")
    if failed > 0:
        print(f"\n⚠️  有 {failed} 个任务失败，请检查日志")


if __name__ == '__main__':
    main()