#!/usr/bin/env python3
"""
nuScenes LiDAR BEV视频生成工具
将LiDAR点云转换到车辆BEV空间并生成2D俯瞰视频
"""

import argparse
import cv2
import os
import numpy as np
from pathlib import Path
from tqdm import tqdm
from nuscenes.nuscenes import NuScenes
from nuscenes.utils.data_classes import LidarPointCloud
from nuscenes.utils.geometry_utils import transform_matrix
from pyquaternion import Quaternion


def generate_lidar_bev_video(dataroot, scene_name, output_path, 
                           version='v1.0-trainval', fps=10,
                           bev_size=(800, 800), bev_range=50.0,
                           colormap='height', point_size=1):
    """
    生成LiDAR BEV视频
    
    Args:
        dataroot: nuScenes数据集根目录
        scene_name: 场景名称
        output_path: 输出视频路径
        version: 数据集版本
        fps: 视频帧率
        bev_size: BEV图像尺寸 (width, height)
        bev_range: BEV显示范围 (米)
        colormap: 点云着色方式 ('intensity', 'height', 'distance')
        point_size: 点的大小
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
        
        # 生成BEV图像序列
        bev_images = []
        
        print(f"正在处理LiDAR点云数据...")
        for i, sample_token in enumerate(tqdm(sample_tokens)):
            sample = nusc.get('sample', sample_token)
            
            # 获取LiDAR数据
            lidar_token = sample['data']['LIDAR_TOP']
            lidar_data = nusc.get('sample_data', lidar_token)
            
            # 加载点云
            lidar_path = os.path.join(dataroot, lidar_data['filename'])
            if not os.path.exists(lidar_path):
                print(f"警告: LiDAR文件不存在: {lidar_path}")
                continue
            
            # 读取点云数据
            pc = LidarPointCloud.from_file(lidar_path)
            points = pc.points[:3, :]  # x, y, z
            intensities = pc.points[3, :] if pc.points.shape[0] > 3 else None
            
            # 转换到自车坐标系
            # nuScenes中LiDAR数据已经在自车坐标系中，无需额外转换
            
            # 生成BEV图像
            bev_image = points_to_bev_image(
                points, intensities, 
                bev_size=bev_size, 
                bev_range=bev_range,
                colormap=colormap,
                point_size=point_size
            )
            
            # 添加信息文本
            timestamp = sample['timestamp'] / 1000000  # 转换为秒
            frame_info = f"Frame: {i+1}/{len(sample_tokens)} | Time: {timestamp:.1f}s | LiDAR BEV"
            cv2.putText(bev_image, frame_info, (10, 30), cv2.FONT_HERSHEY_SIMPLEX, 0.7, (255, 255, 255), 2)
            
            # 添加坐标轴和范围信息
            add_bev_overlay(bev_image, bev_range, bev_size)
            
            bev_images.append(bev_image)
        
        if not bev_images:
            print("错误: 未生成有效的BEV图像")
            return False
        
        # 创建输出目录
        os.makedirs(os.path.dirname(output_path), exist_ok=True)
        
        # 创建视频
        height, width = bev_images[0].shape[:2]
        fourcc = cv2.VideoWriter_fourcc(*'mp4v')
        video_writer = cv2.VideoWriter(output_path, fourcc, fps, (width, height))
        
        print(f"正在生成BEV视频: {output_path}")
        for bev_image in tqdm(bev_images, desc="写入视频帧"):
            video_writer.write(bev_image)
        
        video_writer.release()
        
        # 输出统计信息
        video_duration = len(bev_images) / fps
        file_size = os.path.getsize(output_path) / (1024 * 1024)  # MB
        
        print(f"✅ BEV视频生成完成!")
        print(f"   输出文件: {output_path}")
        print(f"   分辨率: {width}x{height}")
        print(f"   帧数: {len(bev_images)}")
        print(f"   帧率: {fps} fps")
        print(f"   时长: {video_duration:.1f} 秒")
        print(f"   文件大小: {file_size:.1f} MB")
        print(f"   BEV范围: ±{bev_range}m")
        
        return True
        
    except Exception as e:
        print(f"错误: {e}")
        return False


def points_to_bev_image(points, intensities, bev_size=(800, 800), 
                       bev_range=50.0, colormap='intensity', point_size=1):
    """
    将3D点云转换为BEV图像
    
    Args:
        points: 3D点云 (3, N)
        intensities: 强度值 (N,)
        bev_size: BEV图像尺寸
        bev_range: BEV范围 (米)
        colormap: 着色方式
        point_size: 点大小
    
    Returns:
        BEV图像 (BGR格式)
    """
    width, height = bev_size
    
    # 创建空的BEV图像
    bev_image = np.zeros((height, width, 3), dtype=np.uint8)
    
    # 过滤范围内的点
    x, y, z = points[0], points[1], points[2]
    mask = (np.abs(x) <= bev_range) & (np.abs(y) <= bev_range)
    
    if not np.any(mask):
        return bev_image
    
    x_filtered = x[mask]
    y_filtered = y[mask]
    z_filtered = z[mask]
    
    # 转换到图像坐标
    # X轴向前，Y轴向左，图像中心为车辆位置
    pixel_x = ((x_filtered + bev_range) / (2 * bev_range) * width).astype(int)
    pixel_y = ((bev_range - y_filtered) / (2 * bev_range) * height).astype(int)
    
    # 确保坐标在图像范围内
    valid_mask = (pixel_x >= 0) & (pixel_x < width) & (pixel_y >= 0) & (pixel_y < height)
    pixel_x = pixel_x[valid_mask]
    pixel_y = pixel_y[valid_mask]
    z_filtered = z_filtered[valid_mask]
    
    if len(pixel_x) == 0:
        return bev_image
    
    # 根据着色方式设置颜色
    if colormap == 'intensity' and intensities is not None:
        intensity_filtered = intensities[mask][valid_mask]
        colors = intensity_to_color(intensity_filtered)
    elif colormap == 'height':
        colors = height_to_color(z_filtered)
    elif colormap == 'distance':
        distances = np.sqrt(x_filtered[valid_mask]**2 + y_filtered[valid_mask]**2)
        colors = distance_to_color(distances, bev_range)
    else:
        # 默认白色
        colors = np.full((len(pixel_x), 3), 255, dtype=np.uint8)
    
    # 绘制点
    for i in range(len(pixel_x)):
        cv2.circle(bev_image, (pixel_x[i], pixel_y[i]), point_size, 
                  colors[i].tolist(), -1)
    
    return bev_image


def intensity_to_color(intensities):
    """将强度值转换为颜色"""
    # 归一化强度值
    if len(intensities) == 0:
        return np.array([[255, 255, 255]])
    
    norm_intensities = (intensities - intensities.min()) / (intensities.max() - intensities.min() + 1e-8)
    
    # 使用热力图着色
    colors = np.zeros((len(intensities), 3), dtype=np.uint8)
    colors[:, 2] = (norm_intensities * 255).astype(np.uint8)  # 红色通道
    colors[:, 1] = ((1 - norm_intensities) * 255).astype(np.uint8)  # 绿色通道
    colors[:, 0] = 0  # 蓝色通道
    
    return colors


def height_to_color(heights):
    """将高度值转换为颜色"""
    if len(heights) == 0:
        return np.array([[255, 255, 255]])
    
    # 设置高度范围
    min_height, max_height = -2.0, 4.0
    norm_heights = np.clip((heights - min_height) / (max_height - min_height), 0, 1)
    
    # 使用蓝-绿-红渐变
    colors = np.zeros((len(heights), 3), dtype=np.uint8)
    colors[:, 0] = ((1 - norm_heights) * 255).astype(np.uint8)  # 蓝色
    colors[:, 1] = (norm_heights * 255).astype(np.uint8)  # 绿色
    colors[:, 2] = (norm_heights * 128).astype(np.uint8)  # 红色
    
    return colors


def distance_to_color(distances, max_distance):
    """将距离值转换为颜色"""
    if len(distances) == 0:
        return np.array([[255, 255, 255]])
    
    norm_distances = distances / max_distance
    
    # 近处亮，远处暗
    intensity = ((1 - norm_distances) * 255).astype(np.uint8)
    colors = np.stack([intensity, intensity, intensity], axis=1)
    
    return colors


def add_bev_overlay(bev_image, bev_range, bev_size):
    """在BEV图像上添加坐标轴和网格"""
    height, width = bev_size
    center_x, center_y = width // 2, height // 2
    
    # 绘制坐标轴
    # X轴（前进方向）
    cv2.line(bev_image, (center_x, center_y), (center_x, 0), (0, 255, 0), 2)
    cv2.putText(bev_image, 'X(front)', (center_x + 5, 20), cv2.FONT_HERSHEY_SIMPLEX, 0.5, (0, 255, 0), 1)
    
    # Y轴（左侧方向）
    cv2.line(bev_image, (center_x, center_y), (0, center_y), (255, 0, 0), 2)
    cv2.putText(bev_image, 'Y(left)', (5, center_y - 5), cv2.FONT_HERSHEY_SIMPLEX, 0.5, (255, 0, 0), 1)
    
    # 绘制距离圆圈
    for r in [10, 20, 30, 40]:
        if r <= bev_range:
            pixel_r = int(r / bev_range * (min(width, height) // 2))
            cv2.circle(bev_image, (center_x, center_y), pixel_r, (100, 100, 100), 1)
            cv2.putText(bev_image, f'{r}m', (center_x + pixel_r - 10, center_y + 15), 
                       cv2.FONT_HERSHEY_SIMPLEX, 0.4, (150, 150, 150), 1)
    
    # 车辆位置标记
    cv2.circle(bev_image, (center_x, center_y), 5, (255, 255, 255), -1)
    cv2.circle(bev_image, (center_x, center_y), 5, (0, 0, 0), 2)


def main():
    parser = argparse.ArgumentParser(
        description='生成nuScenes LiDAR BEV视频',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
着色方式:
  intensity - 基于反射强度着色
  height    - 基于高度着色
  distance  - 基于距离着色

使用示例:
  python generate_lidar_bev_video.py --dataroot /data/nuscenes --scene scene-0001
  python generate_lidar_bev_video.py --dataroot /data/nuscenes --scene scene-0001 --colormap height --fps 20
  python generate_lidar_bev_video.py --dataroot /data/nuscenes --scene scene-0001 --range 30 --size 600 600
        """
    )
    
    parser.add_argument('--dataroot', type=str, required=True,
                        help='nuScenes数据集根目录路径')
    parser.add_argument('--scene', type=str, required=True,
                        help='场景名称 (如: scene-0001)')
    parser.add_argument('--output', type=str,
                        help='输出视频路径 (默认: outputs/{scene}_lidar_bev.mp4)')
    parser.add_argument('--version', type=str, default='v1.0-trainval',
                        choices=['v1.0-trainval', 'v1.0-test', 'v1.0-mini'],
                        help='数据集版本 (默认: v1.0-trainval)')
    parser.add_argument('--fps', type=int, default=10,
                        help='视频帧率 (默认: 10)')
    parser.add_argument('--size', type=int, nargs=2, default=[800, 800],
                        help='BEV图像尺寸 width height (默认: 800 800)')
    parser.add_argument('--range', type=float, default=50.0,
                        help='BEV显示范围(米) (默认: 50.0)')
    parser.add_argument('--colormap', type=str, default='intensity',
                        choices=['intensity', 'height', 'distance'],
                        help='点云着色方式 (默认: intensity)')
    parser.add_argument('--point-size', type=int, default=1,
                        help='点的大小 (默认: 1)')
    
    args = parser.parse_args()
    
    # 检查数据集路径
    if not os.path.exists(args.dataroot):
        print(f"错误: 数据集路径不存在: {args.dataroot}")
        return
    
    # 设置默认输出路径
    if args.output is None:
        script_dir = os.path.dirname(os.path.abspath(__file__))
        output_dir = os.path.join(os.path.dirname(script_dir), 'outputs')
        args.output = os.path.join(output_dir, f"{args.scene}_lidar_bev.mp4")
    
    # 生成BEV视频
    success = generate_lidar_bev_video(
        dataroot=args.dataroot,
        scene_name=args.scene,
        output_path=args.output,
        version=args.version,
        fps=args.fps,
        bev_size=tuple(args.size),
        bev_range=args.range,
        colormap=args.colormap,
        point_size=args.point_size
    )
    
    if not success:
        print("\n❌ BEV视频生成失败")
    
    return success


if __name__ == '__main__':
    main()