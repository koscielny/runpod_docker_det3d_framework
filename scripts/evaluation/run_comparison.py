import os
import json
import subprocess
import argparse
import time

# Get the directory where the script is located
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
MODELS_CONFIG_PATH = os.path.join(SCRIPT_DIR, "../config/models_config.json")

def run_inference_in_docker(
    model_name: str,
    image_name: str,
    config_path: str,
    input_data_path: str,
    output_results_path: str,
    model_weights_path: str,
    dataroot_path: str,
):
    """在 Docker 容器中运行模型推理"""
    print(f"\n--- 运行模型: {model_name} ---")
    
    # 确保输出目录存在
    os.makedirs(os.path.dirname(output_results_path), exist_ok=True)

    # --- 构建 Docker 运行命令 ---
    # 基础命令
    command = [
        "docker", "run", "--rm", "--gpus", "all",
    ]

    # --- 挂载卷 ---
    # 1. 模型权重
    container_model_path = f"/app/checkpoints/{os.path.basename(model_weights_path)}"
    command.extend(["-v", f"{os.path.abspath(model_weights_path)}:{container_model_path}:ro"])

    # 2. 输入文件 (包含 sample_token)
    container_input_file = f"/app/input_data/{os.path.basename(input_data_path)}"
    command.extend(["-v", f"{os.path.abspath(input_data_path)}:{container_input_file}:ro"])

    # 3. 输出文件
    container_output_file = f"/app/output_results/{os.path.basename(output_results_path)}"
    command.extend(["-v", f"{os.path.abspath(output_results_path)}:{container_output_file}:rw"])
    
    # 4. nuScenes 数据集
    command.extend(["-v", f"{os.path.abspath(dataroot_path)}:/app/data/nuscenes:ro"])

    # --- 指定镜像和执行命令 ---
    # 容器内固定的推理脚本路径
    container_inference_script = f"/app/{model_name}/inference.py"
    
    command.extend([
        image_name,
        "python3",
        container_inference_script,
        "--config", config_path,
        "--model-path", container_model_path,
        "--input", container_input_file,
        "--output", container_output_file,
        "--dataroot", "/app/data/nuscenes",
    ])

    print(f"执行命令: {' '.join(command)}")
    try:
        start_time = time.time()
        result = subprocess.run(command, capture_output=True, text=True, check=True)
        end_time = time.time()
        print("Stdout:", result.stdout)
        if result.stderr:
            print("Stderr:", result.stderr)
        print(f"推理完成。耗时: {end_time - start_time:.2f} 秒")
        return True, end_time - start_time
    except subprocess.CalledProcessError as e:
        print(f"错误: 模型 {model_name} 推理失败。")
        print("Stdout:", e.stdout)
        print("Stderr:", e.stderr)
        return False, 0
    except FileNotFoundError:
        print(f"错误: Docker 命令未找到。请确保 Docker 已安装并运行。")
        return False, 0

def calculate_metrics(model_name: str, input_data_path: str, output_results_path: str):
    """计算模型性能指标 (占位符)"""
    print(f"\n--- 计算 {model_name} 的指标 ---")
    # TODO: 在这里实现你的指标计算逻辑。
    # 这将高度依赖于你的模型输出格式和你想要计算的指标。
    # 你可能需要读取 output_results_path 和 input_data_path 来进行比较。
    try:
        with open(output_results_path, "r") as f:
            results_content = f.read()
        print(f"读取到结果文件内容: {results_content[:100]}...") # 打印前100个字符
        # 示例指标：
        metric_value = len(results_content) / 100.0 # 假设一个简单的指标
        print(f"示例指标 ({model_name}): {metric_value:.2f}")
        return {"example_metric": metric_value}
    except FileNotFoundError:
        print(f"错误: 结果文件 {output_results_path} 未找到。")
        return {}
    except Exception as e:
        print(f"计算指标时发生错误: {e}")
        return {}

def main():
    parser = argparse.ArgumentParser(description="模型推理和比较框架")
    parser.add_argument("--data_dir", type=str, required=True, help="包含输入数据文件（每个文件包含一个 sample_token）的目录")
    parser.add_argument("--output_dir", type=str, default="./comparison_results", help="保存推理结果和指标的目录")
    parser.add_argument("--model_weights_dir", type=str, required=True, help="包含所有模型权重文件 (.pth) 的目录")
    parser.add_argument("--dataroot", type=str, required=True, help="nuScenes 数据集的根目录")
    args = parser.parse_args()

    # 加载模型配置
    with open(MODELS_CONFIG_PATH, "r") as f:
        models_config = json.load(f)

    # 确保输出目录存在
    os.makedirs(args.output_dir, exist_ok=True)

    # 获取所有输入数据文件
    input_files = [os.path.join(args.data_dir, f) for f in os.listdir(args.data_dir) if os.path.isfile(os.path.join(args.data_dir, f))]
    if not input_files:
        print(f"错误: 在 {args.data_dir} 中未找到任何输入数据文件。")
        return

    comparison_summary = {}

    for model_info in models_config:
        model_name = model_info["name"]
        image_name = model_info["image"]
        config_path = model_info["config_path"] # 从 config 中获取
        
        model_summary = {"inference_times": [], "metrics": {}}

        # 查找对应的模型权重文件
        model_weights_path = os.path.join(args.model_weights_dir, model_info["weight_file"])
        if not os.path.exists(model_weights_path):
            print(f"警告: 未找到 {model_name} 的模型权重文件: {model_weights_path}，跳过该模型。")
            continue

        for input_file in input_files:
            data_filename = os.path.basename(input_file)
            output_subdir = os.path.join(args.output_dir, model_name)
            # 为每个输入文件生成一个唯一的JSON输出文件名
            output_results_file = os.path.join(output_subdir, f"{os.path.splitext(data_filename)[0]}_results.json")
            
            success, inference_time = run_inference_in_docker(
                model_name=model_name,
                image_name=image_name,
                config_path=config_path,
                input_data_path=input_file,
                output_results_path=output_results_file,
                model_weights_path=model_weights_path,
                dataroot_path=args.dataroot
            )
            
            if success:
                model_summary["inference_times"].append(inference_time)
                metrics = calculate_metrics(model_name, input_file, output_results_file)
                # 合并指标，如果存在多个数据文件，可能需要平均或累积
                for k, v in metrics.items():
                    model_summary["metrics"].setdefault(k, []).append(v)
            else:
                print(f"跳过 {model_name} 在 {data_filename} 上的指标计算，因为推理失败。")
        
        # 对每个模型的指标进行平均 (如果适用)
        if model_summary["inference_times"]:
             model_summary["avg_inference_time"] = sum(model_summary["inference_times"]) / len(model_summary["inference_times"])
        for k, v_list in model_summary["metrics"].items():
            if v_list:
                model_summary["metrics"][k] = sum(v_list) / len(v_list)
            else:
                model_summary["metrics"][k] = None

        comparison_summary[model_name] = model_summary

    # 保存总览报告
    summary_report_path = os.path.join(args.output_dir, "comparison_summary.json")
    with open(summary_report_path, "w", encoding="utf-8") as f:
        json.dump(comparison_summary, f, indent=4, ensure_ascii=False)
    print(f"\n所有模型比较完成。总结报告已保存到: {summary_report_path}")

if __name__ == "__main__":
    main()