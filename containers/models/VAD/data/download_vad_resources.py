#!/usr/bin/env python3
"""
VAD资源下载脚本
自动下载VAD项目所需的模型权重、数据集注释文件和预训练权重
"""

import os
import sys
import subprocess
import urllib.request
from pathlib import Path

def install_gdown():
    """安装gdown包"""
    try:
        import gdown
        print("✅ gdown already installed")
    except ImportError:
        print("📦 Installing gdown...")
        subprocess.check_call([sys.executable, "-m", "pip", "install", "gdown"])
        import gdown
        print("✅ gdown installed successfully")

def create_directories(base_path):
    """创建目录结构"""
    directories = {
        'models': base_path / 'models',
        'pretrained': base_path / 'pretrained', 
        'nuscenes_annotations': base_path / 'nuscenes_annotations',
        'datasets': base_path / 'datasets'
    }
    
    for name, path in directories.items():
        path.mkdir(parents=True, exist_ok=True)
        print(f"📁 Created directory: {path}")
    
    return directories

def download_from_gdrive(file_id, output_path, description):
    """从Google Drive下载文件"""
    try:
        import gdown
        url = f"https://drive.google.com/uc?id={file_id}"
        print(f"⬇️  Downloading {description}...")
        print(f"   URL: {url}")
        print(f"   Output: {output_path}")
        
        gdown.download(url, str(output_path), quiet=False)
        
        if output_path.exists():
            file_size = output_path.stat().st_size / (1024*1024)  # MB
            print(f"✅ Downloaded {description} ({file_size:.1f} MB)")
            return True
        else:
            print(f"❌ Failed to download {description}")
            return False
            
    except Exception as e:
        print(f"❌ Error downloading {description}: {e}")
        return False

def download_from_url(url, output_path, description):
    """从普通URL下载文件"""
    try:
        print(f"⬇️  Downloading {description}...")
        print(f"   URL: {url}")
        print(f"   Output: {output_path}")
        
        urllib.request.urlretrieve(url, str(output_path))
        
        if output_path.exists():
            file_size = output_path.stat().st_size / (1024*1024)  # MB
            print(f"✅ Downloaded {description} ({file_size:.1f} MB)")
            return True
        else:
            print(f"❌ Failed to download {description}")
            return False
            
    except Exception as e:
        print(f"❌ Error downloading {description}: {e}")
        return False

def main():
    # 设置基础路径 - 优先使用/workspace，如果不存在则使用当前目录
    if Path('/workspace').exists():
        base_path = Path('/workspace/data/vad_demo')
    else:
        # 使用脚本所在目录的相对路径
        script_dir = Path(__file__).parent
        base_path = script_dir / '../../data/vad_demo'
        base_path = base_path.resolve()  # 转换为绝对路径
    
    print(f"🎯 VAD资源下载脚本")
    print(f"📂 Base directory: {base_path}")
    
    # 安装gdown
    install_gdown()
    
    # 创建目录结构
    dirs = create_directories(base_path)
    
    # 定义下载资源
    downloads = [
        # VAD模型权重
        {
            'type': 'gdrive',
            'file_id': '1KgCC_wFqPH0CQqdr6Pp2smBX5ARPaqne',
            'output': dirs['models'] / 'vad_tiny_stage_2.pth',
            'description': 'VAD-Tiny Model (R50 backbone)'
        },
        {
            'type': 'gdrive', 
            'file_id': '1FLX-4LVm4z-RskghFbxGuYlcYOQmV5bS',
            'output': dirs['models'] / 'vad_base_stage_2.pth',
            'description': 'VAD-Base Model (R50 backbone)'
        },
        
        # nuScenes注释文件
        {
            'type': 'gdrive',
            'file_id': '1OVd6Rw2wYjT_ylihCixzF6_olrAQsctx',
            'output': dirs['nuscenes_annotations'] / 'vad_nuscenes_infos_temporal_train.pkl',
            'description': 'nuScenes Train Annotations'
        },
        {
            'type': 'gdrive',
            'file_id': '16DZeA-iepMCaeyi57XSXL3vYyhrOQI9S', 
            'output': dirs['nuscenes_annotations'] / 'vad_nuscenes_infos_temporal_val.pkl',
            'description': 'nuScenes Val Annotations'
        },
        
        # 预训练权重
        {
            'type': 'url',
            'url': 'https://download.pytorch.org/models/resnet50-19c8e357.pth',
            'output': dirs['pretrained'] / 'resnet50-19c8e357.pth',
            'description': 'ResNet50 Pretrained Weights'
        }
    ]
    
    # 执行下载
    success_count = 0
    total_count = len(downloads)
    
    print(f"\n🚀 Starting downloads ({total_count} files)...")
    print("="*60)
    
    for i, item in enumerate(downloads, 1):
        print(f"\n[{i}/{total_count}] {item['description']}")
        print("-" * 40)
        
        # 检查文件是否已存在
        if item['output'].exists():
            file_size = item['output'].stat().st_size / (1024*1024)  # MB
            print(f"⚠️  File already exists ({file_size:.1f} MB), skipping...")
            success_count += 1
            continue
        
        # 执行下载
        if item['type'] == 'gdrive':
            success = download_from_gdrive(
                item['file_id'], 
                item['output'], 
                item['description']
            )
        elif item['type'] == 'url':
            success = download_from_url(
                item['url'],
                item['output'], 
                item['description']
            )
        
        if success:
            success_count += 1
    
    # 输出结果统计
    print("\n" + "="*60)
    print(f"📊 Download Summary:")
    print(f"   ✅ Successful: {success_count}/{total_count}")
    print(f"   ❌ Failed: {total_count - success_count}/{total_count}")
    
    if success_count == total_count:
        print(f"🎉 All files downloaded successfully!")
    else:
        print(f"⚠️  Some downloads failed. Please check the logs above.")
    
    # 显示目录结构
    print(f"\n📁 Final directory structure:")
    for name, path in dirs.items():
        files = list(path.glob('*'))
        print(f"   {name}: {len(files)} files in {path}")
        for file in files:
            file_size = file.stat().st_size / (1024*1024)  # MB
            print(f"      - {file.name} ({file_size:.1f} MB)")

if __name__ == "__main__":
    main()