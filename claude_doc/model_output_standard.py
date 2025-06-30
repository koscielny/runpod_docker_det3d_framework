#!/usr/bin/env python3
"""
统一模型输出格式标准
用于多模型评测和比较的标准化输出格式定义
"""

from typing import Dict, List, Optional, Any, Union
from dataclasses import dataclass, asdict
from datetime import datetime
import json
import numpy as np

@dataclass
class BoundingBox3D:
    """3D边界框标准格式"""
    center: List[float]  # [x, y, z] 中心点坐标
    size: List[float]    # [w, l, h] 宽度、长度、高度
    rotation: List[float] # [roll, pitch, yaw] 旋转角度
    confidence: float    # 置信度 [0, 1]

@dataclass
class Detection3D:
    """3D检测结果标准格式"""
    id: int                    # 检测目标ID
    class_name: str           # 类别名称 (car, truck, pedestrian, etc.)
    class_id: int             # 类别ID
    bbox_3d: BoundingBox3D    # 3D边界框
    confidence: float         # 整体置信度
    attributes: Dict[str, Any] # 额外属性 (速度、方向等)

@dataclass
class VectorElement:
    """向量化地图元素标准格式"""
    id: int                   # 元素ID
    type: str                 # 类型 (lane, divider, ped_crossing, etc.)
    points: List[List[float]] # 点序列 [[x1,y1], [x2,y2], ...]
    confidence: float         # 置信度
    attributes: Dict[str, Any] # 额外属性

@dataclass
class TrajectoryPrediction:
    """轨迹预测标准格式"""
    object_id: int            # 目标对象ID
    trajectory: List[List[float]] # 轨迹点序列 [[x1,y1,t1], [x2,y2,t2], ...]
    confidence: float         # 轨迹置信度
    prediction_horizon: float # 预测时间范围 (秒)

@dataclass
class PlanningTrajectory:
    """规划轨迹标准格式"""
    waypoints: List[List[float]] # 路径点 [[x,y,v,t], ...]
    total_time: float            # 总时间
    total_distance: float        # 总距离
    safety_score: float          # 安全性评分

@dataclass
class ModelMetadata:
    """模型元数据"""
    model_name: str           # 模型名称
    model_version: str        # 模型版本
    config_file: str          # 配置文件路径
    checkpoint_file: str      # 权重文件路径
    inference_time: float     # 推理时间 (秒)
    gpu_memory_used: float    # 使用的GPU内存 (MB)
    timestamp: str            # 推理时间戳

@dataclass
class StandardOutput:
    """统一的模型输出格式"""
    # 元数据
    metadata: ModelMetadata
    
    # 检测结果 (3D目标检测)
    detections_3d: Optional[List[Detection3D]] = None
    
    # 地图元素 (向量化地图)
    map_elements: Optional[List[VectorElement]] = None
    
    # 轨迹预测
    trajectory_predictions: Optional[List[TrajectoryPrediction]] = None
    
    # 规划轨迹
    planning_trajectory: Optional[PlanningTrajectory] = None
    
    # 原始输出 (保留原始格式以备调试)
    raw_output: Optional[Dict[str, Any]] = None
    
    # 错误信息
    error: Optional[str] = None
    
    def to_dict(self) -> Dict[str, Any]:
        """转换为字典格式"""
        return asdict(self)
    
    def to_json(self, indent: int = 2) -> str:
        """转换为JSON格式"""
        def json_serializer(obj):
            if isinstance(obj, np.ndarray):
                return obj.tolist()
            if isinstance(obj, np.float32):
                return float(obj)
            if isinstance(obj, np.int64):
                return int(obj)
            raise TypeError(f"Object of type {type(obj)} is not JSON serializable")
        
        return json.dumps(self.to_dict(), indent=indent, default=json_serializer)

class OutputStandardizer:
    """输出格式标准化器"""
    
    def __init__(self, model_name: str):
        self.model_name = model_name
        self.class_names = {
            'nuscenes': ['car', 'truck', 'bus', 'trailer', 'construction_vehicle',
                        'pedestrian', 'motorcycle', 'bicycle', 'traffic_cone', 'barrier'],
            'map_elements': ['divider', 'ped_crossing', 'boundary', 'lane_line']
        }
    
    def standardize(self, raw_output: Any, metadata: Dict[str, Any]) -> StandardOutput:
        """将原始输出转换为标准格式"""
        
        # 创建元数据
        model_metadata = ModelMetadata(
            model_name=self.model_name,
            model_version=metadata.get('model_version', 'unknown'),
            config_file=metadata.get('config_file', ''),
            checkpoint_file=metadata.get('checkpoint_file', ''),
            inference_time=metadata.get('inference_time', 0.0),
            gpu_memory_used=metadata.get('gpu_memory_used', 0.0),
            timestamp=datetime.now().isoformat()
        )
        
        # 根据模型类型转换输出
        try:
            if self.model_name.upper() == 'MAPTR':
                return self._standardize_maptr(raw_output, model_metadata)
            elif self.model_name.upper() == 'PETR':
                return self._standardize_petr(raw_output, model_metadata)
            elif self.model_name.upper() == 'STREAMPETR':
                return self._standardize_streampetr(raw_output, model_metadata)
            elif self.model_name.upper() == 'TOPOMLP':
                return self._standardize_topomlp(raw_output, model_metadata)
            elif self.model_name.upper() == 'VAD':
                return self._standardize_vad(raw_output, model_metadata)
            else:
                return StandardOutput(
                    metadata=model_metadata,
                    error=f"Unsupported model: {self.model_name}",
                    raw_output=raw_output if isinstance(raw_output, dict) else str(raw_output)
                )
        except Exception as e:
            return StandardOutput(
                metadata=model_metadata,
                error=f"Standardization failed: {str(e)}",
                raw_output=raw_output if isinstance(raw_output, dict) else str(raw_output)
            )
    
    def _standardize_maptr(self, raw_output: Any, metadata: ModelMetadata) -> StandardOutput:
        """标准化MapTR输出"""
        detections = []
        map_elements = []
        
        if isinstance(raw_output, list) and len(raw_output) > 0:
            for i, item in enumerate(raw_output):
                if item.get('class_name') in self.class_names['map_elements']:
                    # 地图元素
                    map_elements.append(VectorElement(
                        id=i,
                        type=item['class_name'],
                        points=item.get('pts', []),
                        confidence=item.get('confidence', 0.0),
                        attributes={'num_pts': item.get('num_pts', 0)}
                    ))
                else:
                    # 3D目标
                    bbox = item.get('bbox', [0, 0, 0, 0])
                    detections.append(Detection3D(
                        id=i,
                        class_name=item.get('class_name', 'unknown'),
                        class_id=item.get('class_id', -1),
                        bbox_3d=BoundingBox3D(
                            center=[bbox[0], bbox[1], 0.0],
                            size=[bbox[2]-bbox[0], bbox[3]-bbox[1], 1.0],
                            rotation=[0.0, 0.0, 0.0],
                            confidence=item.get('confidence', 0.0)
                        ),
                        confidence=item.get('confidence', 0.0),
                        attributes={}
                    ))
        
        return StandardOutput(
            metadata=metadata,
            detections_3d=detections if detections else None,
            map_elements=map_elements if map_elements else None,
            raw_output=raw_output
        )
    
    def _standardize_petr(self, raw_output: Any, metadata: ModelMetadata) -> StandardOutput:
        """标准化PETR输出"""
        detections = []
        
        # PETR主要用于3D目标检测
        if isinstance(raw_output, dict) and 'pts_bbox' in raw_output:
            pts_bbox = raw_output['pts_bbox']
            boxes_3d = pts_bbox.get('boxes_3d', [])
            scores_3d = pts_bbox.get('scores_3d', [])
            labels_3d = pts_bbox.get('labels_3d', [])
            
            for i, (box, score, label) in enumerate(zip(boxes_3d, scores_3d, labels_3d)):
                class_name = self.class_names['nuscenes'][label] if label < len(self.class_names['nuscenes']) else f'class_{label}'
                
                detections.append(Detection3D(
                    id=i,
                    class_name=class_name,
                    class_id=int(label),
                    bbox_3d=BoundingBox3D(
                        center=box[:3].tolist() if hasattr(box, 'tolist') else box[:3],
                        size=box[3:6].tolist() if hasattr(box, 'tolist') else box[3:6],
                        rotation=[0.0, 0.0, box[6]] if len(box) > 6 else [0.0, 0.0, 0.0],
                        confidence=float(score)
                    ),
                    confidence=float(score),
                    attributes={}
                ))
        
        return StandardOutput(
            metadata=metadata,
            detections_3d=detections if detections else None,
            raw_output=raw_output
        )
    
    def _standardize_streampetr(self, raw_output: Any, metadata: ModelMetadata) -> StandardOutput:
        """标准化StreamPETR输出"""
        # StreamPETR输出格式类似PETR，但包含时序信息
        return self._standardize_petr(raw_output, metadata)
    
    def _standardize_topomlp(self, raw_output: Any, metadata: ModelMetadata) -> StandardOutput:
        """标准化TopoMLP输出"""
        # TopoMLP主要用于拓扑感知检测
        return self._standardize_petr(raw_output, metadata)
    
    def _standardize_vad(self, raw_output: Any, metadata: ModelMetadata) -> StandardOutput:
        """标准化VAD输出"""
        detections = []
        trajectory_predictions = []
        planning_trajectory = None
        
        # VAD包含检测、预测和规划
        if isinstance(raw_output, dict):
            # 检测结果
            if 'detections' in raw_output:
                det_results = raw_output['detections']
                for i, det in enumerate(det_results):
                    detections.append(Detection3D(
                        id=i,
                        class_name=det.get('class_name', 'unknown'),
                        class_id=det.get('class_id', -1),
                        bbox_3d=BoundingBox3D(
                            center=det.get('center', [0, 0, 0]),
                            size=det.get('size', [1, 1, 1]),
                            rotation=det.get('rotation', [0, 0, 0]),
                            confidence=det.get('confidence', 0.0)
                        ),
                        confidence=det.get('confidence', 0.0),
                        attributes=det.get('attributes', {})
                    ))
            
            # 轨迹预测
            if 'trajectory_predictions' in raw_output:
                pred_results = raw_output['trajectory_predictions']
                for i, pred in enumerate(pred_results):
                    trajectory_predictions.append(TrajectoryPrediction(
                        object_id=pred.get('object_id', i),
                        trajectory=pred.get('trajectory', []),
                        confidence=pred.get('confidence', 0.0),
                        prediction_horizon=pred.get('prediction_horizon', 3.0)
                    ))
            
            # 规划轨迹
            if 'planning' in raw_output:
                plan = raw_output['planning']
                planning_trajectory = PlanningTrajectory(
                    waypoints=plan.get('waypoints', []),
                    total_time=plan.get('total_time', 0.0),
                    total_distance=plan.get('total_distance', 0.0),
                    safety_score=plan.get('safety_score', 0.0)
                )
        
        return StandardOutput(
            metadata=metadata,
            detections_3d=detections if detections else None,
            trajectory_predictions=trajectory_predictions if trajectory_predictions else None,
            planning_trajectory=planning_trajectory,
            raw_output=raw_output
        )

def create_standardizer(model_name: str) -> OutputStandardizer:
    """创建输出标准化器"""
    return OutputStandardizer(model_name)

# 使用示例
if __name__ == "__main__":
    # 示例：MapTR输出标准化
    maptr_raw = [
        {
            "id": 0,
            "class_name": "divider",
            "class_id": 0,
            "confidence": 0.85,
            "bbox": [10.2, 15.3, 25.7, 18.9],
            "pts": [[10.5, 16.0], [11.2, 16.1], [12.0, 16.2]],
            "num_pts": 20
        }
    ]
    
    metadata = {
        "model_version": "v1.0",
        "config_file": "/app/config.py",
        "checkpoint_file": "/app/model.pth",
        "inference_time": 0.25,
        "gpu_memory_used": 2048.0
    }
    
    standardizer = create_standardizer("MapTR")
    result = standardizer.standardize(maptr_raw, metadata)
    
    print("标准化输出:")
    print(result.to_json())