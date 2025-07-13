# VAD资源清单

## Google Drive链接

### 模型权重
- VAD-Tiny: `https://drive.google.com/file/d/1KgCC_wFqPH0CQqdr6Pp2smBX5ARPaqne/view?usp=sharing`
- VAD-Base: `https://drive.google.com/file/d/1FLX-4LVm4z-RskghFbxGuYlcYOQmV5bS/view?usp=sharing`

### 数据集注释
- Train: `https://drive.google.com/file/d/1OVd6Rw2wYjT_ylihCixzF6_olrAQsctx/view?usp=sharing`
- Val: `https://drive.google.com/file/d/16DZeA-iepMCaeyi57XSXL3vYyhrOQI9S/view?usp=sharing`

### nuScenes CAN Bus数据
- can_bus.zip: `https://drive.google.com/file/d/1Dcj0shqOmxyWStCGfyz3rZegbQccubVm/view?usp=sharing`

### nuScenes Map Expansion
- nuscenes-map-expansion-v1.3.zip: `https://drive.google.com/file/d/1JJik0O7MnWUOLv2SGRVz6mPoPAd2NLga/view?usp=sharing`

### 预训练权重
- ResNet50: `https://download.pytorch.org/models/resnet50-19c8e357.pth`

## 下载目录结构

```
/workspace/data/vad_demo/
├── models/
│   ├── vad_tiny_stage_2.pth
│   └── vad_base_stage_2.pth
├── pretrained/
│   └── resnet50-19c8e357.pth
├── nuscenes_annotations/
│   ├── vad_nuscenes_infos_temporal_train.pkl
│   └── vad_nuscenes_infos_temporal_val.pkl
├── can_bus/
│   └── can_bus.zip
└── map_expansion/
    └── nuscenes-map-expansion-v1.3.zip
```

## 使用方法

```bash
# 运行下载脚本
./download_vad_resources.sh

# 或使用Python脚本
python download_vad_resources.py
```