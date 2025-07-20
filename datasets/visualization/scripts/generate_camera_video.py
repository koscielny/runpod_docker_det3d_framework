#!/usr/bin/env python3
"""
nuScenes 相机视频生成工具
根据场景ID生成指定相机的视频序列
"""

import argparse
import cv2
import os
import numpy as np
from pathlib import Path
from tqdm import tqdm
from nuscenes.nuscenes import NuScenes
from PIL import Image


def generate_camera_video(dataroot, scene_name, camera_channel, output_path, 
                         version='v1.0-trainval', fps=10, quality='high', 
                         add_annotations=False, resize_factor=1.0):
    """
    生成相机视频
    
    Args:
        dataroot: nuScenes数据集根目录
        scene_name: 场景名称
        camera_channel: 相机通道 (CAM_FRONT, CAM_BACK, CAM_FRONT_LEFT, CAM_FRONT_RIGHT, CAM_BACK_LEFT, CAM_BACK_RIGHT)
        output_path: 输出视频路径
        version: 数据集版本
        fps: 视频帧率
        quality: 视频质量 ('high', 'medium', 'low')
        add_annotations: 是否添加2D标注框
        resize_factor: 图像缩放因子
    """
    try:
        # 初始化nuScenes
        print(f"正在加载nuScenes数据集...")
        nusc = NuScenes(version=version, dataroot=dataroot, verbose=False)
        
        # 查找场景
        scene = None
        for s in nusc.scene:
            if s['name'] == scene_name:
                scene = s
                break
        
        if scene is None:
            print(f"错误: 未找到场景 '{scene_name}'")
            return False
        
        print(f"找到场景: {scene_name} (样本数: {scene['nbr_samples']})")
        
        # 获取场景中的所有样本
        sample_tokens = []
        sample_token = scene['first_sample_token']
        while sample_token:
            sample_tokens.append(sample_token)
            sample = nusc.get('sample', sample_token)
            sample_token = sample['next']
        
        # 收集相机图像
        images = []
        camera_data = []
        
        print(f"正在收集 {camera_channel} 相机图像...")
        for sample_token in tqdm(sample_tokens):
            sample = nusc.get('sample', sample_token)
            
            if camera_channel not in sample['data']:
                print(f"警告: 样本中未找到相机通道 {camera_channel}")
                continue
            
            # 获取相机数据
            cam_token = sample['data'][camera_channel]
            cam_data = nusc.get('sample_data', cam_token)
            
            # 加载图像
            img_path = os.path.join(dataroot, cam_data['filename'])
            if not os.path.exists(img_path):
                print(f"警告: 图像文件不存在: {img_path}")
                continue
            
            img = cv2.imread(img_path)
            if img is None:
                print(f"警告: 无法读取图像: {img_path}")
                continue
            
            # 调整图像大小
            if resize_factor != 1.0:
                height, width = img.shape[:2]
                new_width = int(width * resize_factor)
                new_height = int(height * resize_factor)
                img = cv2.resize(img, (new_width, new_height))
            
            # 添加标注（如果需要）
            if add_annotations:
                img = add_2d_annotations(nusc, sample, camera_channel, img, dataroot)
            
            # 添加时间戳和帧信息
            timestamp = sample['timestamp'] / 1000000  # 转换为秒
            frame_info = f"Frame: {len(images)+1}/{len(sample_tokens)} | Time: {timestamp:.1f}s | Camera: {camera_channel}"
            cv2.putText(img, frame_info, (10, 30), cv2.FONT_HERSHEY_SIMPLEX, 0.7, (255, 255, 255), 2)
            
            images.append(img)
            camera_data.append(cam_data)
        
        if not images:
            print("错误: 未找到有效的相机图像")
            return False
        
        # 创建输出目录
        os.makedirs(os.path.dirname(output_path), exist_ok=True)
        
        # 设置视频编码器和质量
        height, width = images[0].shape[:2]
        
        if quality == 'high':
            codec = 'mp4v'
            bitrate = width * height * fps // 50
        elif quality == 'medium':
            codec = 'mp4v'
            bitrate = width * height * fps // 100
        else:  # low
            codec = 'mp4v'
            bitrate = width * height * fps // 200
        
        # 创建视频写入器
        fourcc = cv2.VideoWriter_fourcc(*codec)
        video_writer = cv2.VideoWriter(output_path, fourcc, fps, (width, height))
        
        # 写入视频帧
        print(f"正在生成视频: {output_path}")
        for img in tqdm(images, desc="写入视频帧"):
            video_writer.write(img)
        
        video_writer.release()
        
        # 输出统计信息
        video_duration = len(images) / fps
        file_size = os.path.getsize(output_path) / (1024 * 1024)  # MB
        
        print(f"✅ 视频生成完成!")
        print(f"   输出文件: {output_path}")
        print(f"   分辨率: {width}x{height}")
        print(f"   帧数: {len(images)}")
        print(f"   帧率: {fps} fps")
        print(f"   时长: {video_duration:.1f} 秒")
        print(f"   文件大小: {file_size:.1f} MB")
        
        return True
        
    except Exception as e:
        print(f"错误: {e}")
        return False


def add_2d_annotations(nusc, sample, camera_channel, img, dataroot):
    """在图像上添加2D标注框"""
    try:
        # 获取相机内参和外参
        cam_token = sample['data'][camera_channel]
        cam_data = nusc.get('sample_data', cam_token)
        cam_calib = nusc.get('calibrated_sensor', cam_data['calibrated_sensor_token'])
        
        # 获取所有标注
        for ann_token in sample['anns']:
            ann = nusc.get('sample_annotation', ann_token)
            
            # 过滤掉不在相机视野内的物体
            # 这里简化处理，实际应该进行3D->2D投影
            category = ann['category_name']
            
            # 在图像上绘制简单标记（这里简化处理）
            # 实际实现需要3D到2D的投影变换
            pass
    
    except Exception as e:
        print(f"标注添加失败: {e}")
    
    return img


def main():
    parser = argparse.ArgumentParser(
        description='生成nuScenes相机视频',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
相机通道选项:
  CAM_FRONT       - 前置相机
  CAM_BACK        - 后置相机  
  CAM_FRONT_LEFT  - 前左相机
  CAM_FRONT_RIGHT - 前右相机
  CAM_BACK_LEFT   - 后左相机
  CAM_BACK_RIGHT  - 后右相机

使用示例:
  python generate_camera_video.py --dataroot /data/nuscenes --scene scene-0001 --camera CAM_FRONT
  python generate_camera_video.py --dataroot /data/nuscenes --scene scene-0001 --camera CAM_FRONT --fps 20 --quality high
  python generate_camera_video.py --dataroot /data/nuscenes --scene scene-0001 --camera CAM_FRONT --output custom_video.mp4
        """
    )
    
    parser.add_argument('--dataroot', type=str, required=True,
                        help='nuScenes数据集根目录路径')
    parser.add_argument('--scene', type=str, required=True,
                        help='场景名称 (如: scene-0001)')
    parser.add_argument('--camera', type=str, required=True,
                        choices=['CAM_FRONT', 'CAM_BACK', 'CAM_FRONT_LEFT', 
                                'CAM_FRONT_RIGHT', 'CAM_BACK_LEFT', 'CAM_BACK_RIGHT'],
                        help='相机通道')
    parser.add_argument('--output', type=str,
                        help='输出视频路径 (默认: outputs/{scene}_{camera}.mp4)')
    parser.add_argument('--version', type=str, default='v1.0-trainval',
                        choices=['v1.0-trainval', 'v1.0-test', 'v1.0-mini'],
                        help='数据集版本 (默认: v1.0-trainval)')
    parser.add_argument('--fps', type=int, default=10,
                        help='视频帧率 (默认: 10)')
    parser.add_argument('--quality', type=str, default='medium',
                        choices=['high', 'medium', 'low'],
                        help='视频质量 (默认: medium)')
    parser.add_argument('--annotations', action='store_true',
                        help='添加2D标注框')
    parser.add_argument('--resize', type=float, default=1.0,
                        help='图像缩放因子 (默认: 1.0)')
    
    args = parser.parse_args()
    
    # 检查数据集路径
    if not os.path.exists(args.dataroot):
        print(f"错误: 数据集路径不存在: {args.dataroot}")
        return
    
    # 设置默认输出路径
    if args.output is None:
        script_dir = os.path.dirname(os.path.abspath(__file__))
        output_dir = os.path.join(os.path.dirname(script_dir), 'outputs')
        args.output = os.path.join(output_dir, f"{args.scene}_{args.camera}.mp4")
    
    # 生成视频
    success = generate_camera_video(
        dataroot=args.dataroot,
        scene_name=args.scene,
        camera_channel=args.camera,
        output_path=args.output,
        version=args.version,
        fps=args.fps,
        quality=args.quality,
        add_annotations=args.annotations,
        resize_factor=args.resize
    )
    
    if not success:
        print("\n❌ 视频生成失败")
    
    return success


if __name__ == '__main__':
    main()