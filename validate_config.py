#!/usr/bin/env python3
"""
配置文件验证工具
验证模型配置文件的有效性和兼容性
"""

import os
import sys
import argparse
import importlib.util
from pathlib import Path
from typing import Dict, List, Optional, Any
import tempfile
import shutil

def load_config_file(config_path: str) -> Dict[str, Any]:
    """动态加载配置文件"""
    try:
        # 创建临时目录和文件
        with tempfile.TemporaryDirectory() as temp_dir:
            temp_config = os.path.join(temp_dir, "temp_config.py")
            shutil.copy2(config_path, temp_config)
            
            # 动态导入配置
            spec = importlib.util.spec_from_file_location("config", temp_config)
            config_module = importlib.util.module_from_spec(spec)
            
            # 设置基本的mmcv mock以避免导入错误
            sys.modules['mmcv'] = type('MockModule', (), {
                'Config': type('MockConfig', (), {'fromfile': lambda x: {}})
            })()
            
            spec.loader.exec_module(config_module)
            
            # 提取配置变量
            config_dict = {}
            for attr_name in dir(config_module):
                if not attr_name.startswith('_'):
                    config_dict[attr_name] = getattr(config_module, attr_name)
            
            return config_dict
            
    except Exception as e:
        print(f"❌ 配置文件加载失败: {e}")
        return {}

def validate_model_config(model_name: str, config_path: str) -> Dict[str, Any]:
    """验证特定模型的配置文件"""
    result = {
        'model': model_name,
        'config_path': config_path,
        'valid': False,
        'errors': [],
        'warnings': [],
        'info': {}
    }
    
    if not os.path.exists(config_path):
        result['errors'].append(f"配置文件不存在: {config_path}")
        return result
    
    print(f"🔍 验证 {model_name} 配置文件: {config_path}")
    
    # 加载配置
    config = load_config_file(config_path)
    if not config:
        result['errors'].append("配置文件加载失败")
        return result
    
    # 通用验证
    required_keys = ['model', 'data', 'optimizer', 'lr_config']
    missing_keys = [key for key in required_keys if key not in config]
    if missing_keys:
        result['warnings'].extend([f"缺少配置项: {key}" for key in missing_keys])
    
    # 模型特定验证
    if model_name.upper() == "MAPTR":
        result.update(validate_maptr_config(config))
    elif model_name.upper() == "PETR":
        result.update(validate_petr_config(config))
    elif model_name.upper() == "STREAMPETR":
        result.update(validate_streampetr_config(config))
    elif model_name.upper() == "TOPOMLP":
        result.update(validate_topomlp_config(config))
    elif model_name.upper() == "VAD":
        result.update(validate_vad_config(config))
    else:
        result['warnings'].append(f"未知模型类型: {model_name}")
    
    # 数据集路径验证
    if 'data' in config:
        data_config = config['data']
        if isinstance(data_config, dict):
            for split in ['train', 'val', 'test']:
                if split in data_config and isinstance(data_config[split], dict):
                    if 'data_root' in data_config[split]:
                        data_root = data_config[split]['data_root']
                        result['info'][f'{split}_data_root'] = data_root
                        # 注意：在Docker环境中路径可能不同，这里只记录不验证
    
    # 设置验证结果
    result['valid'] = len(result['errors']) == 0
    
    return result

def validate_maptr_config(config: Dict) -> Dict:
    """验证MapTR配置"""
    validation = {'errors': [], 'warnings': [], 'info': {}}
    
    # 检查MapTR特定配置
    if 'model' in config and isinstance(config['model'], dict):
        model_config = config['model']
        if 'type' in model_config:
            model_type = model_config['type']
            validation['info']['model_type'] = model_type
            if 'MapTR' not in str(model_type):
                validation['warnings'].append(f"模型类型可能不匹配: {model_type}")
    
    # 检查地图相关配置
    if 'map_grid_conf' in config:
        validation['info']['has_map_config'] = True
    else:
        validation['warnings'].append("缺少地图网格配置 (map_grid_conf)")
    
    return validation

def validate_petr_config(config: Dict) -> Dict:
    """验证PETR配置"""
    validation = {'errors': [], 'warnings': [], 'info': {}}
    
    if 'model' in config and isinstance(config['model'], dict):
        model_config = config['model']
        if 'type' in model_config:
            model_type = model_config['type']
            validation['info']['model_type'] = model_type
            if 'PETR' not in str(model_type):
                validation['warnings'].append(f"模型类型可能不匹配: {model_type}")
    
    # 检查位置编码配置
    if 'position_encoding' in config:
        validation['info']['has_position_encoding'] = True
    
    return validation

def validate_streampetr_config(config: Dict) -> Dict:
    """验证StreamPETR配置"""
    validation = {'errors': [], 'warnings': [], 'info': {}}
    
    if 'model' in config and isinstance(config['model'], dict):
        model_config = config['model']
        if 'type' in model_config:
            model_type = model_config['type']
            validation['info']['model_type'] = model_type
            if 'StreamPETR' not in str(model_type):
                validation['warnings'].append(f"模型类型可能不匹配: {model_type}")
    
    # 检查时序配置
    if 'queue_length' in config:
        queue_length = config['queue_length']
        validation['info']['queue_length'] = queue_length
        if queue_length <= 1:
            validation['warnings'].append("时序队列长度较短，可能影响时序建模效果")
    
    return validation

def validate_topomlp_config(config: Dict) -> Dict:
    """验证TopoMLP配置"""
    validation = {'errors': [], 'warnings': [], 'info': {}}
    
    if 'model' in config and isinstance(config['model'], dict):
        model_config = config['model']
        if 'type' in model_config:
            model_type = model_config['type']
            validation['info']['model_type'] = model_type
            if 'TopoMLP' not in str(model_type):
                validation['warnings'].append(f"模型类型可能不匹配: {model_type}")
    
    return validation

def validate_vad_config(config: Dict) -> Dict:
    """验证VAD配置"""
    validation = {'errors': [], 'warnings': [], 'info': {}}
    
    if 'model' in config and isinstance(config['model'], dict):
        model_config = config['model']
        if 'type' in model_config:
            model_type = model_config['type']
            validation['info']['model_type'] = model_type
            if 'VAD' not in str(model_type):
                validation['warnings'].append(f"模型类型可能不匹配: {model_type}")
    
    # 检查规划相关配置
    if 'planning' in config:
        validation['info']['has_planning_config'] = True
    else:
        validation['warnings'].append("缺少规划配置 (planning)")
    
    return validation

def print_validation_result(result: Dict):
    """打印验证结果"""
    model = result['model']
    config_path = result['config_path']
    
    print(f"\n📋 {model} 配置验证结果")
    print("-" * 50)
    print(f"配置文件: {config_path}")
    
    if result['valid']:
        print("✅ 配置文件有效")
    else:
        print("❌ 配置文件存在问题")
    
    # 显示错误
    if result['errors']:
        print(f"\n❌ 错误 ({len(result['errors'])}):")
        for error in result['errors']:
            print(f"  • {error}")
    
    # 显示警告
    if result['warnings']:
        print(f"\n⚠️  警告 ({len(result['warnings'])}):")
        for warning in result['warnings']:
            print(f"  • {warning}")
    
    # 显示信息
    if result['info']:
        print(f"\n📊 配置信息:")
        for key, value in result['info'].items():
            print(f"  • {key}: {value}")

def main():
    parser = argparse.ArgumentParser(description='验证模型配置文件')
    parser.add_argument('model', help='模型名称 (MapTR, PETR, StreamPETR, TopoMLP, VAD)')
    parser.add_argument('config', help='配置文件路径')
    parser.add_argument('--quiet', action='store_true', help='静默模式，仅显示结果')
    
    args = parser.parse_args()
    
    if args.quiet:
        # 重定向stdout用于静默模式
        import io
        old_stdout = sys.stdout
        sys.stdout = io.StringIO()
    
    try:
        result = validate_model_config(args.model, args.config)
        
        if args.quiet:
            sys.stdout = old_stdout
            # 静默模式只输出最终结果
            if result['valid']:
                print("✅ VALID")
                sys.exit(0)
            else:
                print("❌ INVALID")
                for error in result['errors']:
                    print(f"ERROR: {error}")
                sys.exit(1)
        else:
            print_validation_result(result)
            
            if not result['valid']:
                sys.exit(1)
                
    except Exception as e:
        if args.quiet:
            sys.stdout = old_stdout
        print(f"❌ 验证过程中出现错误: {e}")
        sys.exit(1)

if __name__ == '__main__':
    main()