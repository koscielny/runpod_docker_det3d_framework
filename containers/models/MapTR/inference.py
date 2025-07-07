
import os
import sys
import subprocess
import argparse

def main():
    """
    This script acts as a simple wrapper to call the main demo script
    inside the MapTR project directory. It passes along all arguments.
    """
    parser = argparse.ArgumentParser(description="Runpod MapTR Inference Wrapper")
    
    parser.add_argument('--config', required=True, help='Path to the model config file.')
    parser.add_argument('--model-path', required=True, help='Path to the model checkpoint file (.pth).')
    parser.add_argument('--input', required=True, help='Path to the input file containing a single nuScenes sample_token.')
    parser.add_argument('--output', required=True, help='Path to save the inference results in JSON format.')
    parser.add_argument('--dataroot', default='/app/data/nuscenes', help='Root path of the nuScenes dataset.')

    args = parser.parse_args()

    try:
        with open(args.input, 'r') as f:
            sample_token = f.read().strip()
        if not sample_token:
            raise ValueError("Input file is empty or contains only whitespace.")
    except FileNotFoundError:
        print(f"Error: Input file not found at {args.input}", file=sys.stderr)
        sys.exit(1)
    except Exception as e:
        print(f"Error reading input file: {e}", file=sys.stderr)
        sys.exit(1)

    demo_script_path = '/app/MapTR/tools/demo.py'
    
    command = [
        'python3',
        demo_script_path,
        args.config,
        args.model_path,
        '--sample-token', sample_token,
        '--dataroot', args.dataroot,
        '--out-file', args.output,
        '--device', 'cuda:0'
    ]

    print(f"Executing command: {' '.join(command)}")

    try:
        # Add timeout protection (10 minutes for inference)
        result = subprocess.run(command, check=True, timeout=600)
        print("Inference completed successfully")
    except subprocess.TimeoutExpired:
        print(f"Error: Inference timed out after 600 seconds", file=sys.stderr)
        sys.exit(1)
    except FileNotFoundError:
        print(f"Error: The demo script was not found at {demo_script_path}", file=sys.stderr)
        sys.exit(1)
    except subprocess.CalledProcessError as e:
        print(f"Error executing demo script: {e}", file=sys.stderr)
        sys.exit(1)

if __name__ == "__main__":
    main()
