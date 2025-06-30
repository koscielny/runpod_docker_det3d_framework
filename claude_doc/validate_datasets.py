#!/usr/bin/env python3
"""
数据集验证脚本
验证已下载的 nuScenes, Waymo, Argoverse 数据集的完整性和可用性
"""

import os
import sys
import json
import logging
import argparse
from pathlib import Path
from typing import Dict, List, Optional, Tuple
import subprocess

# 设置日志
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler('dataset_validation.log'),
        logging.StreamHandler(sys.stdout)
    ]
)
logger = logging.getLogger(__name__)

class DatasetValidator:
    """数据集验证器基类"""
    
    def __init__(self, dataset_root: str):
        self.dataset_root = Path(dataset_root)
        self.validation_results = {}
    
    def validate(self) -> Dict:
        """验证数据集"""
        raise NotImplementedError
    
    def check_file_exists(self, file_path: str) -> bool:
        """检查文件是否存在"""
        return Path(file_path).exists()
    
    def check_directory_exists(self, dir_path: str) -> bool:
        """检查目录是否存在"""
        return Path(dir_path).is_dir()
    
    def get_file_size(self, file_path: str) -> int:
        """获取文件大小 (bytes)"""
        try:
            return Path(file_path).stat().st_size
        except OSError:
            return 0
    
    def get_directory_size(self, dir_path: str) -> int:
        """获取目录大小 (bytes)"""
        try:
            total_size = 0
            for path in Path(dir_path).rglob('*'):
                if path.is_file():
                    total_size += path.stat().st_size
            return total_size
        except OSError:
            return 0

class NuScenesValidator(DatasetValidator):
    """nuScenes 数据集验证器"""
    
    def validate(self) -> Dict:
        logger.info("验证 nuScenes 数据集...")
        
        results = {
            'dataset': 'nuScenes',
            'root_path': str(self.dataset_root),
            'status': 'unknown',
            'details': {}
        }
        
        try:
            # 检查 v1.0-mini 目录
            mini_path = self.dataset_root / 'v1.0-mini'
            if not self.check_directory_exists(mini_path):
                results['status'] = 'failed'
                results['details']['error'] = 'v1.0-mini directory not found'
                return results
            
            # 验证关键文件
            required_files = [
                'scene.json', 'sample.json', 'sample_data.json', 
                'ego_pose.json', 'calibrated_sensor.json', 'sensor.json'
            ]
            
            missing_files = []
            for file_name in required_files:
                file_path = mini_path / file_name
                if not self.check_file_exists(file_path):
                    missing_files.append(file_name)
            
            if missing_files:
                results['status'] = 'incomplete'
                results['details']['missing_files'] = missing_files
            else:
                results['status'] = 'valid'
            
            # 验证数据集内容
            try:
                import json
                
                # 读取场景信息
                scene_file = mini_path / 'scene.json'
                with open(scene_file, 'r') as f:
                    scenes = json.load(f)
                
                # 读取样本信息
                sample_file = mini_path / 'sample.json'
                with open(sample_file, 'r') as f:
                    samples = json.load(f)
                
                results['details'].update({
                    'scene_count': len(scenes),
                    'sample_count': len(samples),
                    'dataset_size_mb': round(self.get_directory_size(self.dataset_root) / (1024 * 1024), 2)
                })
                
                # 验证 API 可用性
                try:
                    from nuscenes.nuscenes import NuScenes
                    nusc = NuScenes(version='v1.0-mini', dataroot=str(self.dataset_root), verbose=False)
                    results['details']['api_available'] = True
                    results['details']['api_scene_count'] = len(nusc.scene)
                    results['details']['api_sample_count'] = len(nusc.sample)
                    
                    # 测试加载第一个场景
                    if len(nusc.scene) > 0:
                        first_scene = nusc.scene[0]
                        results['details']['first_scene_token'] = first_scene['token']
                        results['details']['first_scene_name'] = first_scene['name']
                        
                except ImportError:
                    results['details']['api_available'] = False
                    results['details']['api_error'] = 'nuscenes-devkit not installed'
                except Exception as e:
                    results['details']['api_available'] = False
                    results['details']['api_error'] = str(e)
                
            except Exception as e:
                results['details']['metadata_error'] = str(e)
                
        except Exception as e:
            results['status'] = 'error'
            results['details']['error'] = str(e)
        
        return results

class WaymoValidator(DatasetValidator):
    """Waymo Open Dataset 验证器"""
    
    def validate(self) -> Dict:
        logger.info("验证 Waymo Open Dataset...")
        
        results = {
            'dataset': 'Waymo',
            'root_path': str(self.dataset_root),
            'status': 'unknown',
            'details': {}
        }
        
        try:
            # 检查验证集目录
            validation_path = self.dataset_root / 'validation'
            if not self.check_directory_exists(validation_path):
                results['status'] = 'failed'
                results['details']['error'] = 'validation directory not found'
                return results
            
            # 查找 TFRecord 文件
            tfrecord_files = list(validation_path.glob('*.tfrecord'))
            
            if not tfrecord_files:
                results['status'] = 'failed'
                results['details']['error'] = 'no tfrecord files found'
                return results
            
            results['status'] = 'valid'
            results['details'].update({
                'tfrecord_count': len(tfrecord_files),
                'dataset_size_mb': round(self.get_directory_size(validation_path) / (1024 * 1024), 2)
            })
            
            # 验证文件完整性
            file_sizes = []
            for tf_file in tfrecord_files[:5]:  # 检查前5个文件
                size_mb = round(self.get_file_size(tf_file) / (1024 * 1024), 2)
                file_sizes.append({
                    'filename': tf_file.name,
                    'size_mb': size_mb
                })
            
            results['details']['sample_files'] = file_sizes
            
            # 验证 API 可用性
            try:
                import tensorflow as tf
                results['details']['tensorflow_available'] = True
                results['details']['tensorflow_version'] = tf.__version__
                
                try:
                    from waymo_open_dataset import dataset_pb2
                    results['details']['waymo_api_available'] = True
                    
                    # 尝试读取第一个文件的第一个记录
                    if tfrecord_files:
                        first_file = str(tfrecord_files[0])
                        dataset = tf.data.TFRecordDataset([first_file])
                        
                        for i, data in enumerate(dataset.take(1)):
                            frame = dataset_pb2.Frame()
                            frame.ParseFromString(data.numpy())
                            
                            results['details']['sample_frame'] = {
                                'timestamp_micros': frame.timestamp_micros,
                                'context_name': frame.context.name,
                                'camera_labels_count': len(frame.camera_labels),
                                'laser_labels_count': len(frame.laser_labels)
                            }
                            break
                        
                except ImportError as e:
                    results['details']['waymo_api_available'] = False
                    results['details']['waymo_api_error'] = f'waymo-open-dataset not installed: {e}'
                except Exception as e:
                    results['details']['waymo_api_available'] = False
                    results['details']['waymo_api_error'] = str(e)
                    
            except ImportError:
                results['details']['tensorflow_available'] = False
                results['details']['api_error'] = 'tensorflow not installed'
                
        except Exception as e:
            results['status'] = 'error'
            results['details']['error'] = str(e)
        
        return results

class ArgoverseValidator(DatasetValidator):
    """Argoverse 2 数据集验证器"""
    
    def validate(self) -> Dict:
        logger.info("验证 Argoverse 2 数据集...")
        
        results = {
            'dataset': 'Argoverse2',
            'root_path': str(self.dataset_root),
            'status': 'unknown',
            'details': {}
        }
        
        try:
            # 检查 motion_forecasting 目录
            motion_path = self.dataset_root / 'motion_forecasting'
            if not self.check_directory_exists(motion_path):
                results['status'] = 'failed'
                results['details']['error'] = 'motion_forecasting directory not found'
                return results
            
            # 查找验证集文件
            val_path = motion_path / 'val'
            parquet_files = []
            
            if self.check_directory_exists(val_path):
                parquet_files = list(val_path.glob('*.parquet'))
            else:
                # 检查根目录下的 parquet 文件
                parquet_files = list(motion_path.glob('*.parquet'))
            
            if not parquet_files:
                results['status'] = 'failed'
                results['details']['error'] = 'no parquet files found'
                return results
            
            results['status'] = 'valid'
            results['details'].update({
                'scenario_count': len(parquet_files),
                'dataset_size_mb': round(self.get_directory_size(motion_path) / (1024 * 1024), 2)
            })
            
            # 验证文件完整性
            file_sizes = []
            for pq_file in parquet_files[:5]:  # 检查前5个文件
                size_kb = round(self.get_file_size(pq_file) / 1024, 2)
                file_sizes.append({
                    'filename': pq_file.name,
                    'size_kb': size_kb
                })
            
            results['details']['sample_files'] = file_sizes
            
            # 验证 API 可用性
            try:
                from av2.datasets.motion_forecasting import scenario_serialization
                results['details']['av2_api_available'] = True
                
                # 尝试加载第一个场景
                if parquet_files:
                    first_file = parquet_files[0]
                    try:
                        scenario = scenario_serialization.load_argoverse_scenario_parquet(first_file)
                        
                        results['details']['sample_scenario'] = {
                            'scenario_id': scenario.scenario_id,
                            'track_count': len(scenario.tracks),
                            'timestep_count': len(scenario.tracks[0].object_states) if scenario.tracks else 0,
                            'map_id': scenario.map_id
                        }
                        
                    except Exception as e:
                        results['details']['scenario_load_error'] = str(e)
                
            except ImportError:
                results['details']['av2_api_available'] = False
                results['details']['av2_api_error'] = 'av2 package not installed'
            except Exception as e:
                results['details']['av2_api_available'] = False
                results['details']['av2_api_error'] = str(e)
                
        except Exception as e:
            results['status'] = 'error'
            results['details']['error'] = str(e)
        
        return results

def validate_all_datasets(base_data_dir: str) -> Dict:
    """验证所有数据集"""
    logger.info(f"开始验证数据集，根目录: {base_data_dir}")
    
    base_path = Path(base_data_dir)
    all_results = {
        'validation_time': subprocess.check_output(['date'], text=True).strip(),
        'base_directory': str(base_path),
        'datasets': {}
    }
    
    # 验证 nuScenes
    nuscenes_path = base_path / 'nuscenes'
    if nuscenes_path.exists():
        validator = NuScenesValidator(str(nuscenes_path))
        all_results['datasets']['nuscenes'] = validator.validate()
    else:
        all_results['datasets']['nuscenes'] = {
            'dataset': 'nuScenes',
            'status': 'not_found',
            'details': {'error': f'Directory not found: {nuscenes_path}'}
        }
    
    # 验证 Waymo
    waymo_path = base_path / 'waymo'
    if waymo_path.exists():
        validator = WaymoValidator(str(waymo_path))
        all_results['datasets']['waymo'] = validator.validate()
    else:
        all_results['datasets']['waymo'] = {
            'dataset': 'Waymo',
            'status': 'not_found',
            'details': {'error': f'Directory not found: {waymo_path}'}
        }
    
    # 验证 Argoverse 2
    argoverse_path = base_path / 'argoverse2'
    if argoverse_path.exists():
        validator = ArgoverseValidator(str(argoverse_path))
        all_results['datasets']['argoverse2'] = validator.validate()
    else:
        all_results['datasets']['argoverse2'] = {
            'dataset': 'Argoverse2',
            'status': 'not_found',
            'details': {'error': f'Directory not found: {argoverse_path}'}
        }
    
    return all_results

def print_validation_summary(results: Dict):
    """打印验证结果摘要"""
    print("\n" + "="*80)
    print("📊 数据集验证结果摘要")
    print("="*80)
    
    total_size_mb = 0
    valid_datasets = 0
    
    for dataset_name, dataset_result in results['datasets'].items():
        status = dataset_result['status']
        details = dataset_result.get('details', {})
        
        # 状态图标
        if status == 'valid':
            icon = "✅"
            valid_datasets += 1
        elif status == 'incomplete':
            icon = "⚠️"
        elif status == 'not_found':
            icon = "❌"
        else:
            icon = "❓"
        
        print(f"\n{icon} {dataset_result['dataset']}:")
        print(f"   状态: {status}")
        
        if 'dataset_size_mb' in details:
            size_mb = details['dataset_size_mb']
            total_size_mb += size_mb
            print(f"   大小: {size_mb:.1f} MB")
        
        # 数据集特定信息
        if dataset_name == 'nuscenes':
            if 'scene_count' in details:
                print(f"   场景数: {details['scene_count']}")
            if 'sample_count' in details:
                print(f"   样本数: {details['sample_count']}")
            if 'api_available' in details:
                api_status = "✅" if details['api_available'] else "❌"
                print(f"   API: {api_status}")
        
        elif dataset_name == 'waymo':
            if 'tfrecord_count' in details:
                print(f"   TFRecord 文件数: {details['tfrecord_count']}")
            if 'tensorflow_available' in details:
                tf_status = "✅" if details['tensorflow_available'] else "❌"
                print(f"   TensorFlow: {tf_status}")
            if 'waymo_api_available' in details:
                api_status = "✅" if details['waymo_api_available'] else "❌"
                print(f"   Waymo API: {api_status}")
        
        elif dataset_name == 'argoverse2':
            if 'scenario_count' in details:
                print(f"   场景文件数: {details['scenario_count']}")
            if 'av2_api_available' in details:
                api_status = "✅" if details['av2_api_available'] else "❌"
                print(f"   AV2 API: {api_status}")
        
        # 错误信息
        if 'error' in details:
            print(f"   ❌ 错误: {details['error']}")
    
    print(f"\n📊 总结:")
    print(f"   有效数据集: {valid_datasets}/3")
    print(f"   总大小: {total_size_mb:.1f} MB ({total_size_mb/1024:.1f} GB)")
    print(f"   验证时间: {results['validation_time']}")

def generate_config_file(results: Dict, output_path: str):
    """生成模型配置文件"""
    config = {
        'datasets': {},
        'metadata': {
            'generated_at': results['validation_time'],
            'base_directory': results['base_directory']
        }
    }
    
    for dataset_name, dataset_result in results['datasets'].items():
        if dataset_result['status'] == 'valid':
            if dataset_name == 'nuscenes':
                config['datasets']['nuscenes'] = {
                    'dataroot': dataset_result['root_path'],
                    'version': 'v1.0-mini',
                    'available': True
                }
            elif dataset_name == 'waymo':
                config['datasets']['waymo'] = {
                    'dataroot': dataset_result['root_path'],
                    'data_split': 'validation',
                    'available': True
                }
            elif dataset_name == 'argoverse2':
                config['datasets']['argoverse2'] = {
                    'dataroot': dataset_result['root_path'],
                    'split': 'val',
                    'available': True
                }
        else:
            config['datasets'][dataset_name] = {'available': False}
    
    with open(output_path, 'w') as f:
        json.dump(config, f, indent=2)
    
    logger.info(f"配置文件已生成: {output_path}")

def main():
    parser = argparse.ArgumentParser(description='验证自动驾驶数据集')
    parser.add_argument('--data-dir', type=str, default='/data/datasets',
                       help='数据集根目录 (默认: /data/datasets)')
    parser.add_argument('--output', type=str, default='validation_results.json',
                       help='验证结果输出文件 (默认: validation_results.json)')
    parser.add_argument('--config', type=str, default='dataset_config.json',
                       help='生成的配置文件 (默认: dataset_config.json)')
    parser.add_argument('--quiet', action='store_true',
                       help='静默模式，仅输出错误')
    
    args = parser.parse_args()
    
    if args.quiet:
        logging.getLogger().setLevel(logging.ERROR)
    
    try:
        # 验证数据集
        results = validate_all_datasets(args.data_dir)
        
        # 保存验证结果
        with open(args.output, 'w') as f:
            json.dump(results, f, indent=2)
        
        logger.info(f"验证结果已保存: {args.output}")
        
        # 生成配置文件
        generate_config_file(results, args.config)
        
        # 打印摘要
        if not args.quiet:
            print_validation_summary(results)
        
        # 检查是否有有效的数据集
        valid_count = sum(1 for dataset in results['datasets'].values() 
                         if dataset['status'] == 'valid')
        
        if valid_count == 0:
            logger.error("没有找到有效的数据集！")
            sys.exit(1)
        else:
            logger.info(f"验证完成，找到 {valid_count} 个有效数据集")
            
    except Exception as e:
        logger.error(f"验证过程中出现错误: {e}")
        sys.exit(1)

if __name__ == '__main__':
    main()