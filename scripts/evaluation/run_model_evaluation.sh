#!/bin/bash

# 多模型评测和比较脚本
# 集成健康检查、标准化输出、模型比较功能
# 适用于构建个人的多模型Docker评测项目

set -e

# 颜色输出
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUTPUT_DIR="$SCRIPT_DIR/evaluation_results"
MODELS=("MapTR" "PETR" "StreamPETR" "TopoMLP" "VAD")

# 日志函数
log() {
    echo -e "${GREEN}[$(date '+%H:%M:%S')]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[$(date '+%H:%M:%S')] WARNING:${NC} $1"
}

error() {
    echo -e "${RED}[$(date '+%H:%M:%S')] ERROR:${NC} $1"
}

info() {
    echo -e "${BLUE}[$(date '+%H:%M:%S')] INFO:${NC} $1"
}

# 显示帮助信息
show_help() {
    echo "🚀 多模型评测和比较工具"
    echo "=========================="
    echo ""
    echo "用法: $0 [选项]"
    echo ""
    echo "模式选项:"
    echo "  --health-check         运行所有模型的健康检查"
    echo "  --single-model MODEL   评测单个模型"
    echo "  --compare-models       比较多个模型 (需要先运行单个模型评测)"
    echo "  --full-evaluation      完整评测流程 (健康检查 + 单模型评测 + 比较)"
    echo ""
    echo "配置选项:"
    echo "  --data-path PATH       数据文件路径 (默认: /data/sample.txt)"
    echo "  --models LIST          指定要评测的模型，逗号分隔 (默认: 所有模型)"
    echo "  --output-dir DIR       输出目录 (默认: ./evaluation_results)"
    echo "  --skip-health          跳过健康检查"
    echo "  --keep-containers      保持容器运行以便调试"
    echo ""
    echo "示例:"
    echo "  $0 --health-check                              # 检查所有模型健康状态"
    echo "  $0 --single-model MapTR --data-path /data/test.txt  # 评测MapTR模型"
    echo "  $0 --compare-models                            # 比较已评测的模型"
    echo "  $0 --full-evaluation --models MapTR,PETR      # 完整评测MapTR和PETR"
    echo ""
    echo "输出文件:"
    echo "  - health_reports/       健康检查报告"
    echo "  - model_outputs/        单模型输出结果"
    echo "  - comparison/           模型比较分析"
    echo "  - evaluation_summary.json  评测总结"
}

# 检查依赖
check_dependencies() {
    log "检查运行依赖..."
    
    # 检查Docker
    if ! command -v docker &> /dev/null; then
        error "Docker 未安装或不可用"
        exit 1
    fi
    
    # 检查Python
    if ! command -v python3 &> /dev/null; then
        error "Python3 未安装或不可用"
        exit 1
    fi
    
    # 检查必要的Python包
    python3 -c "import pandas, matplotlib, seaborn" 2>/dev/null || {
        warn "缺少Python依赖包，尝试安装..."
        pip install pandas matplotlib seaborn || {
            error "无法安装Python依赖包"
            exit 1
        }
    }
    
    info "依赖检查完成"
}

# 创建输出目录结构
setup_output_dirs() {
    log "创建输出目录结构..."
    
    mkdir -p "$OUTPUT_DIR"/{health_reports,model_outputs,comparison,logs}
    
    # 复制标准化和比较工具
    cp "$SCRIPT_DIR/../tools/model_output_standard.py" "$OUTPUT_DIR/"
    cp "$SCRIPT_DIR/../tools/model_comparison.py" "$OUTPUT_DIR/"
    cp "$SCRIPT_DIR/../tools/health_check.py" "$OUTPUT_DIR/"
    
    info "输出目录已创建: $OUTPUT_DIR"
}

# 健康检查
run_health_checks() {
    local models_to_check=("$@")
    
    log "运行模型健康检查..."
    
    for model in "${models_to_check[@]}"; do
        info "检查 $model 健康状态..."
        
        local image_name="${model,,}-model:latest"
        local health_output="$OUTPUT_DIR/health_reports/${model}_health.json"
        
        # 检查Docker镜像是否存在
        if ! docker image inspect "$image_name" &> /dev/null; then
            warn "Docker镜像不存在: $image_name"
            echo '{"error": "Docker image not found", "model": "'$model'", "image": "'$image_name'"}' > "$health_output"
            continue
        fi
        
        # 运行健康检查
        if docker run --rm --gpus all -v "$OUTPUT_DIR:/output" "$image_name" \
            python3 /app/health_check.py --model "$model" --mode comprehensive > "$health_output" 2>&1; then
            info "✅ $model 健康检查完成"
        else
            warn "❌ $model 健康检查失败"
            echo '{"error": "Health check failed", "model": "'$model'"}' > "$health_output"
        fi
    done
    
    # 生成健康检查汇总
    python3 -c "
import json
import os
from pathlib import Path

health_dir = Path('$OUTPUT_DIR/health_reports')
summary = {'timestamp': '$(date -Iseconds)', 'models': {}}

for health_file in health_dir.glob('*_health.json'):
    model_name = health_file.stem.replace('_health', '')
    try:
        with open(health_file) as f:
            data = json.load(f)
        
        if 'error' in data:
            summary['models'][model_name] = {'status': 'failed', 'error': data['error']}
        else:
            system_status = data.get('system_health', {}).get('status', 'unknown')
            model_status = data.get('model_health', {}).get('status', 'unknown')
            test_status = data.get('functionality_test', {}).get('status', 'unknown')
            
            overall_status = 'healthy'
            if any(s in ['error', 'broken', 'failed'] for s in [system_status, model_status, test_status]):
                overall_status = 'unhealthy'
            elif any(s in ['warning', 'partial', 'mostly_passed'] for s in [system_status, model_status, test_status]):
                overall_status = 'warning'
            
            summary['models'][model_name] = {
                'status': overall_status,
                'system': system_status,
                'model': model_status,
                'test': test_status
            }
    except Exception as e:
        summary['models'][model_name] = {'status': 'error', 'error': str(e)}

with open('$OUTPUT_DIR/health_summary.json', 'w') as f:
    json.dump(summary, f, indent=2)

print('健康检查汇总:')
for model, status in summary['models'].items():
    status_icon = '✅' if status['status'] == 'healthy' else '⚠️' if status['status'] == 'warning' else '❌'
    print(f'  {status_icon} {model}: {status[\"status\"]}')
"
}

# 单模型评测
run_single_model_evaluation() {
    local model="$1"
    local data_path="$2"
    local checkpoint_path="$3"
    
    info "评测模型: $model"
    
    if [ ! -f "$data_path" ]; then
        error "数据文件不存在: $data_path"
        return 1
    fi
    
    local image_name="${model,,}-model:latest"
    local output_dir="$OUTPUT_DIR/model_outputs/$model"
    mkdir -p "$output_dir"
    
    # 检查Docker镜像
    if ! docker image inspect "$image_name" &> /dev/null; then
        error "Docker镜像不存在: $image_name，请先构建镜像"
        return 1
    fi
    
    # 准备输入数据
    local input_dir="$output_dir/input"
    local output_results="$output_dir/output"
    mkdir -p "$input_dir" "$output_results"
    
    # 复制数据文件
    cp "$data_path" "$input_dir/sample.txt"
    
    log "开始 $model 推理..."
    local start_time=$(date +%s.%N)
    
    # 运行推理，记录GPU内存使用
    if [ -n "$checkpoint_path" ] && [ -f "$checkpoint_path" ]; then
        # 使用指定的checkpoint
        docker run --rm --gpus all \
            -v "$checkpoint_path:/app/checkpoints/model.pth:ro" \
            -v "$input_dir:/app/input_data:ro" \
            -v "$output_results:/app/output_results:rw" \
            -v "$OUTPUT_DIR:/output:rw" \
            "$image_name" \
            python3 "/app/$model/inference.py" \
            --config "/app/$model/projects/configs/${model,,}/${model,,}_config.py" \
            --model-path "/app/checkpoints/model.pth" \
            --input "/app/input_data/sample.txt" \
            --output "/app/output_results/results.json" \
            --enable-monitoring
    else
        # 使用默认配置 (假设有预训练模型)
        warn "未指定checkpoint，使用默认配置运行演示模式"
        docker run --rm --gpus all \
            -v "$input_dir:/app/input_data:ro" \
            -v "$output_results:/app/output_results:rw" \
            -v "$OUTPUT_DIR:/output:rw" \
            "$image_name" \
            python3 "/app/$model/tools/demo.py" \
            --input "/app/input_data/sample.txt" \
            --output "/app/output_results/results.json"
    fi
    
    local end_time=$(date +%s.%N)
    local inference_time=$(echo "$end_time - $start_time" | bc -l)
    
    # 检查输出文件
    if [ -f "$output_results/results.json" ]; then
        log "✅ $model 推理完成，用时: ${inference_time}s"
        
        # 使用标准化工具处理输出
        python3 -c "
import sys
sys.path.append('$OUTPUT_DIR')
from model_output_standard import create_standardizer
import json

# 加载原始输出
with open('$output_results/results.json') as f:
    raw_output = json.load(f)

# 创建元数据
metadata = {
    'model_version': 'v1.0',
    'config_file': 'default_config.py',
    'checkpoint_file': '${checkpoint_path:-default}',
    'inference_time': float('$inference_time'),
    'gpu_memory_used': 0.0  # TODO: 从监控中获取
}

# 标准化输出
standardizer = create_standardizer('$model')
standardized = standardizer.standardize(raw_output, metadata)

# 保存标准化结果
with open('$output_dir/standardized_output.json', 'w') as f:
    f.write(standardized.to_json())

print(f'$model 标准化输出已保存')
"
        
    else
        error "❌ $model 推理失败，未生成输出文件"
        return 1
    fi
}

# 模型比较
run_model_comparison() {
    log "开始模型比较分析..."
    
    local comparison_output="$OUTPUT_DIR/comparison"
    mkdir -p "$comparison_output"
    
    # 使用比较工具
    python3 -c "
import sys
sys.path.append('$OUTPUT_DIR')
from model_comparison import ModelComparator
from model_output_standard import StandardOutput
import json
from pathlib import Path

# 创建比较器
comparator = ModelComparator('$comparison_output')

# 加载所有标准化输出
output_dir = Path('$OUTPUT_DIR/model_outputs')
loaded_count = 0

for model_dir in output_dir.iterdir():
    if model_dir.is_dir():
        standardized_file = model_dir / 'standardized_output.json'
        if standardized_file.exists():
            try:
                with open(standardized_file) as f:
                    data = json.load(f)
                
                # 重构StandardOutput对象
                # 这里简化处理，实际应该完整重构对象
                result = type('StandardOutput', (), data)()
                comparator.add_result(result)
                loaded_count += 1
                print(f'加载模型结果: {model_dir.name}')
            except Exception as e:
                print(f'加载 {model_dir.name} 失败: {e}')

if loaded_count >= 2:
    # 生成比较报告
    report = comparator.generate_comparison_report()
    
    # 创建可视化
    try:
        comparator.create_visualizations()
    except Exception as e:
        print(f'创建可视化时出错: {e}')
    
    # 保存结果
    comparator.save_results()
    
    print(f'✅ 模型比较完成，共比较 {loaded_count} 个模型')
else:
    print(f'❌ 需要至少2个模型结果进行比较，当前只有 {loaded_count} 个')
"
    
    if [ -f "$comparison_output/comparison_report.json" ]; then
        log "✅ 模型比较报告已生成"
        
        # 显示简要比较结果
        python3 -c "
import json
with open('$comparison_output/comparison_report.json') as f:
    report = json.load(f)

print('\n📊 模型比较摘要:')
print(f'总模型数: {report[\"summary\"][\"total_models\"]}')
print(f'成功模型: {report[\"summary\"][\"successful_models\"]}')

if 'performance_ranking' in report:
    ranking = report['performance_ranking']
    print('\n🏆 性能排名:')
    for metric, model in ranking.items():
        print(f'  {metric}: {model}')

if 'insights' in report:
    print('\n💡 分析洞察:')
    for insight in report['insights']:
        print(f'  • {insight}')
"
    else
        warn "模型比较未能生成报告"
    fi
}

# 生成评测总结
generate_evaluation_summary() {
    log "生成评测总结..."
    
    python3 -c "
import json
import os
from pathlib import Path
from datetime import datetime

summary = {
    'evaluation_info': {
        'timestamp': datetime.now().isoformat(),
        'output_directory': '$OUTPUT_DIR',
        'script_version': '1.0'
    },
    'health_status': {},
    'model_evaluations': {},
    'comparison_results': {},
    'recommendations': []
}

# 加载健康检查结果
health_file = Path('$OUTPUT_DIR/health_summary.json')
if health_file.exists():
    with open(health_file) as f:
        summary['health_status'] = json.load(f)

# 加载模型评测结果
output_dir = Path('$OUTPUT_DIR/model_outputs')
for model_dir in output_dir.iterdir():
    if model_dir.is_dir() and (model_dir / 'standardized_output.json').exists():
        with open(model_dir / 'standardized_output.json') as f:
            data = json.load(f)
        
        summary['model_evaluations'][model_dir.name] = {
            'status': 'completed',
            'inference_time': data.get('metadata', {}).get('inference_time', 0),
            'detection_count': len(data.get('detections_3d', [])) if data.get('detections_3d') else 0,
            'map_element_count': len(data.get('map_elements', [])) if data.get('map_elements') else 0,
            'has_error': data.get('error') is not None
        }

# 加载比较结果
comparison_file = Path('$OUTPUT_DIR/comparison/comparison_report.json')
if comparison_file.exists():
    with open(comparison_file) as f:
        summary['comparison_results'] = json.load(f)

# 生成建议
healthy_models = []
if 'models' in summary['health_status']:
    healthy_models = [model for model, status in summary['health_status']['models'].items() 
                     if status.get('status') == 'healthy']

if healthy_models:
    summary['recommendations'].append(f'推荐使用的健康模型: {", ".join(healthy_models)}')

if summary['comparison_results']:
    ranking = summary['comparison_results'].get('performance_ranking', {})
    if ranking:
        summary['recommendations'].append(f'推理速度最快: {ranking.get("fastest_inference", "N/A")}')
        summary['recommendations'].append(f'内存使用最少: {ranking.get("lowest_memory", "N/A")}')

# 保存总结
with open('$OUTPUT_DIR/evaluation_summary.json', 'w') as f:
    json.dump(summary, f, indent=2, ensure_ascii=False)

print('📋 评测总结已生成: $OUTPUT_DIR/evaluation_summary.json')
"
}

# 主函数
main() {
    local mode=""
    local single_model=""
    local data_path="/data/sample.txt"
    local checkpoint_path=""
    local models_list=""
    local skip_health=false
    local keep_containers=false
    
    # 解析命令行参数
    while [[ $# -gt 0 ]]; do
        case $1 in
            --health-check)
                mode="health"
                shift
                ;;
            --single-model)
                mode="single"
                single_model="$2"
                shift 2
                ;;
            --compare-models)
                mode="compare"
                shift
                ;;
            --full-evaluation)
                mode="full"
                shift
                ;;
            --data-path)
                data_path="$2"
                shift 2
                ;;
            --checkpoint)
                checkpoint_path="$2"
                shift 2
                ;;
            --models)
                models_list="$2"
                shift 2
                ;;
            --output-dir)
                OUTPUT_DIR="$2"
                shift 2
                ;;
            --skip-health)
                skip_health=true
                shift
                ;;
            --keep-containers)
                keep_containers=true
                shift
                ;;
            --help)
                show_help
                exit 0
                ;;
            *)
                error "未知选项: $1"
                show_help
                exit 1
                ;;
        esac
    done
    
    # 设置要评测的模型列表
    local models_to_eval=()
    if [ -n "$models_list" ]; then
        IFS=',' read -ra models_to_eval <<< "$models_list"
    else
        models_to_eval=("${MODELS[@]}")
    fi
    
    # 如果没有指定模式，显示帮助
    if [ -z "$mode" ]; then
        show_help
        exit 1
    fi
    
    log "🚀 开始多模型评测流程"
    info "输出目录: $OUTPUT_DIR"
    info "评测模型: ${models_to_eval[*]}"
    
    # 检查依赖和设置
    check_dependencies
    setup_output_dirs
    
    # 执行相应的模式
    case $mode in
        "health")
            run_health_checks "${models_to_eval[@]}"
            ;;
        "single")
            if [ -z "$single_model" ]; then
                error "单模型模式需要指定模型名称"
                exit 1
            fi
            
            if [ "$skip_health" = false ]; then
                run_health_checks "$single_model"
            fi
            
            run_single_model_evaluation "$single_model" "$data_path" "$checkpoint_path"
            ;;
        "compare")
            run_model_comparison
            ;;
        "full")
            if [ "$skip_health" = false ]; then
                run_health_checks "${models_to_eval[@]}"
            fi
            
            # 评测每个模型
            for model in "${models_to_eval[@]}"; do
                run_single_model_evaluation "$model" "$data_path" "$checkpoint_path"
            done
            
            # 比较模型
            run_model_comparison
            
            # 生成总结
            generate_evaluation_summary
            ;;
    esac
    
    log "🎉 评测流程完成！"
    info "结果保存在: $OUTPUT_DIR"
    
    # 显示结果文件
    echo ""
    echo "📁 生成的文件:"
    find "$OUTPUT_DIR" -name "*.json" -o -name "*.png" -o -name "*.csv" | head -10 | while read file; do
        echo "  $(basename "$file")"
    done
    
    if [ "$(find "$OUTPUT_DIR" -name "*.json" -o -name "*.png" -o -name "*.csv" | wc -l)" -gt 10 ]; then
        echo "  ... 和更多文件"
    fi
}

# 运行主函数
main "$@"