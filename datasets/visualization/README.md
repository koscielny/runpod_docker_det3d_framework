# nuScenes 数据集可视化工具

本目录包含用于 nuScenes 数据集可视化的工具脚本，帮助你快速理解和分析数据集内容。

## 目录结构

```
visualization/
├── scripts/           # 可视化脚本
│   ├── list_scenes.py                  # 列出所有场景
│   ├── generate_camera_video.py        # 生成相机视频
│   └── generate_lidar_bev_video.py     # 生成LiDAR BEV视频
├── outputs/           # 输出文件目录
├── configs/           # 配置文件目录
└── README.md          # 使用说明
```

## 安装依赖

确保安装以下Python包：

```bash
pip install nuscenes-devkit opencv-python tqdm numpy pillow pyquaternion
```

## 工具使用指南

### 1. 列出场景信息 (list_scenes.py)

查看数据集中所有可用的场景及其基本信息。

**基本用法：**
```bash
python scripts/list_scenes.py --dataroot /path/to/nuscenes
```

**输出格式选项：**
```bash
# 表格格式（默认）
python scripts/list_scenes.py --dataroot /data/nuscenes --format table

# JSON格式
python scripts/list_scenes.py --dataroot /data/nuscenes --format json

# 简单列表
python scripts/list_scenes.py --dataroot /data/nuscenes --format simple
```

**保存结果：**
```bash
python scripts/list_scenes.py --dataroot /data/nuscenes --save-json outputs/scenes_info.json
```

**示例输出：**
```
找到 850 个场景:
------------------------------------------------------------------------------------------------------------------------
序号   场景名称               位置            样本数   描述                                      
------------------------------------------------------------------------------------------------------------------------
1    scene-0001           singapore-onenorth    39     Dense traffic with many vehicles and...
2    scene-0002           singapore-hollandvillage 39  Night scene with moderate traffic...
```

### 2. 生成相机视频 (generate_camera_video.py)

将指定场景的相机数据生成视频序列。

**基本用法：**
```bash
python scripts/generate_camera_video.py --dataroot /data/nuscenes --scene scene-0001 --camera CAM_FRONT
```

**相机选项：**
- `CAM_FRONT` - 前置相机
- `CAM_BACK` - 后置相机
- `CAM_FRONT_LEFT` - 前左相机
- `CAM_FRONT_RIGHT` - 前右相机
- `CAM_BACK_LEFT` - 后左相机
- `CAM_BACK_RIGHT` - 后右相机

**高级选项：**
```bash
# 高质量、高帧率视频
python scripts/generate_camera_video.py \
    --dataroot /data/nuscenes \
    --scene scene-0001 \
    --camera CAM_FRONT \
    --fps 20 \
    --quality high \
    --output custom_output.mp4

# 缩放图像并添加标注
python scripts/generate_camera_video.py \
    --dataroot /data/nuscenes \
    --scene scene-0001 \
    --camera CAM_FRONT \
    --resize 0.5 \
    --annotations
```

### 3. 生成LiDAR BEV视频 (generate_lidar_bev_video.py)

将LiDAR点云转换为鸟瞰图(BEV)视频。

**基本用法：**
```bash
python scripts/generate_lidar_bev_video.py --dataroot /data/nuscenes --scene scene-0001
```

**着色选项：**
```bash
# 基于反射强度着色
python scripts/generate_lidar_bev_video.py \
    --dataroot /data/nuscenes \
    --scene scene-0001 \
    --colormap intensity

# 基于高度着色
python scripts/generate_lidar_bev_video.py \
    --dataroot /data/nuscenes \
    --scene scene-0001 \
    --colormap height

# 基于距离着色
python scripts/generate_lidar_bev_video.py \
    --dataroot /data/nuscenes \
    --scene scene-0001 \
    --colormap distance
```

**自定义参数：**
```bash
# 调整显示范围和图像尺寸
python scripts/generate_lidar_bev_video.py \
    --dataroot /data/nuscenes \
    --scene scene-0001 \
    --range 30 \
    --size 600 600 \
    --fps 15 \
    --point-size 2
```

## 快速开始示例

假设你的nuScenes数据集位于 `/data/nuscenes`：

1. **查看可用场景：**
```bash
python scripts/list_scenes.py --dataroot /data/nuscenes --format simple | head -10
```

2. **生成前置相机视频：**
```bash
python scripts/generate_camera_video.py \
    --dataroot /data/nuscenes \
    --scene scene-0001 \
    --camera CAM_FRONT \
    --output outputs/scene-0001_front_camera.mp4
```

3. **生成LiDAR BEV视频：**
```bash
python scripts/generate_lidar_bev_video.py \
    --dataroot /data/nuscenes \
    --scene scene-0001 \
    --colormap height \
    --output outputs/scene-0001_lidar_bev.mp4
```

## 输出文件

所有生成的视频默认保存在 `outputs/` 目录下，文件命名格式：
- 相机视频: `{scene_name}_{camera_channel}.mp4`
- LiDAR BEV视频: `{scene_name}_lidar_bev.mp4`

## 性能优化建议

1. **大批量处理：** 对于多个场景，建议写简单的批处理脚本
2. **内存使用：** 处理长场景时可以调整图像分辨率和点云密度
3. **存储空间：** 视频文件较大，建议监控磁盘空间
4. **GPU加速：** 未来版本可能支持GPU加速的点云处理

## 故障排除

### 常见问题

1. **"nuscenes-devkit" 导入错误**
   ```bash
   pip install nuscenes-devkit
   ```

2. **数据集路径错误**
   - 确保路径包含 `maps/`, `samples/`, `sweeps/` 等目录
   - 检查版本标识文件是否存在

3. **内存不足**
   - 减小图像尺寸: `--resize 0.5`
   - 减小BEV范围: `--range 30`
   - 降低视频质量: `--quality low`

4. **视频播放问题**
   - 某些播放器可能不支持生成的编码格式
   - 建议使用VLC或其他兼容性好的播放器

### 4. 数据集分析工具 (analyze_dataset.py)

分析数据集的统计信息并生成报告。

**基本用法：**
```bash
python scripts/analyze_dataset.py --dataroot /data/nuscenes
```

**自定义输出：**
```bash
python scripts/analyze_dataset.py \
    --dataroot /data/nuscenes \
    --version v1.0-mini \
    --output custom_analysis
```

**分析内容：**
- 场景统计（数量、长度、地理分布）
- 目标对象分析（类别、属性、尺寸）
- 传感器数据统计
- 时间和天气分布
- 可见性等级分析

### 5. 批量处理工具 (batch_visualize.py)

一键生成多个场景的所有可视化内容。

**基本用法：**
```bash
# 先列出可用场景
python scripts/batch_visualize.py --dataroot /data/nuscenes --list-first

# 批量处理指定场景
python scripts/batch_visualize.py \
    --dataroot /data/nuscenes \
    --scenes scene-0001 scene-0002 scene-0003
```

**使用JSON文件：**
```bash
# 从JSON文件读取场景列表
python scripts/batch_visualize.py \
    --dataroot /data/nuscenes \
    --scenes-json outputs/scenes_info.json \
    --cameras CAM_FRONT CAM_BACK \
    --max-workers 8
```

## 工具建议的额外可视化功能

基于你的需求，我建议以下额外的数据理解可视化：

### 🎯 **高级可视化功能建议**

1. **多传感器融合可视化**
   - 将LiDAR点云投影到相机图像上
   - 显示传感器之间的时间同步情况
   - 可视化传感器校准精度

2. **轨迹和动态分析**
   - 车辆行驶轨迹可视化
   - 目标对象运动轨迹追踪
   - 速度和加速度分析

3. **场景理解可视化**
   - 道路拓扑和车道线检测
   - 交通场景复杂度分析
   - 驾驶行为模式识别

4. **数据质量分析**
   - 传感器数据缺失检测
   - 标注质量评估
   - 数据分布均衡性分析

5. **交互式可视化界面**
   - Web界面浏览数据集
   - 实时数据流播放
   - 标注编辑和验证工具

### 📊 **实用的分析工具**

```bash
# 快速生成数据集概览
python scripts/analyze_dataset.py --dataroot /data/nuscenes

# 批量生成指定场景的所有视频
python scripts/batch_visualize.py --dataroot /data/nuscenes --scenes scene-0001 scene-0002

# 导出场景信息用于进一步分析
python scripts/list_scenes.py --dataroot /data/nuscenes --format json --save-json scene_analysis.json
```

## 扩展功能

基于现有工具，你可以进一步开发：
- 多传感器融合可视化
- 轨迹预测可视化  
- 目标检测结果叠加
- 语义分割可视化
- 实时数据流处理
- 交互式Web界面
- 自动化数据质量检查