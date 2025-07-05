#!/usr/bin/env python3
"""
Convert Conda environment export file to pip requirements.txt
Usage: python convert_conda_to_pip.py input_file.txt output_requirements.txt
"""

import sys
import re
from pathlib import Path

def parse_conda_line(line):
    """Parse a conda package line and convert to pip format if possible"""
    line = line.strip()
    
    # Skip comments and empty lines
    if not line or line.startswith('#'):
        return None
    
    # Skip system packages that don't have pip equivalents
    system_packages = [
        '_libgcc_mutex', '_openmp_mutex', 'ca-certificates', 'certifi',
        'cffi', 'ld_impl_linux-64', 'libffi', 'libgcc-ng', 'libgomp',
        'libstdcxx-ng', 'ncurses', 'openssl', 'readline', 'sqlite',
        'tk', 'wheel', 'xz', 'zlib'
    ]
    
    # Extract package name and version
    # Format: package=version=build or package=version
    if '=' in line:
        parts = line.split('=')
        package_name = parts[0]
        version = parts[1] if len(parts) > 1 else None
        
        # Skip system packages
        if package_name in system_packages:
            return None
            
        # Skip packages with pypi_0 (already pip packages)
        if len(parts) > 2 and 'pypi' in parts[2]:
            if version and version != 'pypi_0':
                return f"{package_name}=={version}"
            else:
                return package_name
        
        # Convert conda packages to pip format
        conda_to_pip_mapping = {
            'pytorch': 'torch',
            'cudatoolkit': None,  # Skip cuda toolkit
            'python': None,  # Skip python version
            'setuptools': None,  # Usually included with pip
            'pip': None,  # Skip pip itself
        }
        
        # Handle version compatibility issues
        version_fixes = {
            'ortools': 'ortools>=9.0,<10.0',  # Use compatible version range
            'tensorboard': 'tensorboard',  # Use latest compatible
            'tensorflow': 'tensorflow',  # Use latest compatible
        }
        
        if package_name in conda_to_pip_mapping:
            pip_name = conda_to_pip_mapping[package_name]
            if pip_name is None:
                return None
            package_name = pip_name
        
        # Apply version fixes if needed
        if package_name in version_fixes:
            return version_fixes[package_name]
        
        if version:
            return f"{package_name}=={version}"
        else:
            return package_name
    
    return None

def convert_conda_to_pip(input_file, output_file):
    """Convert conda environment file to pip requirements"""
    input_path = Path(input_file)
    output_path = Path(output_file)
    
    if not input_path.exists():
        print(f"Error: Input file {input_file} not found")
        return False
    
    pip_packages = []
    
    with open(input_path, 'r') as f:
        for line_num, line in enumerate(f, 1):
            try:
                pip_line = parse_conda_line(line)
                if pip_line:
                    pip_packages.append(pip_line)
            except Exception as e:
                print(f"Warning: Error parsing line {line_num}: {line.strip()}")
                print(f"Error: {e}")
    
    # Remove duplicates and sort
    pip_packages = sorted(list(set(pip_packages)))
    
    # Write to output file
    with open(output_path, 'w') as f:
        f.write("# Converted from conda environment export\n")
        f.write("# Some packages may need manual adjustment\n\n")
        
        for package in pip_packages:
            f.write(f"{package}\n")
    
    print(f"Converted {len(pip_packages)} packages to pip format")
    print(f"Output written to: {output_file}")
    
    # Print packages that might need attention
    torch_packages = [p for p in pip_packages if 'torch' in p.lower()]
    if torch_packages:
        print(f"\nTorch-related packages found: {torch_packages}")
        print("Note: You may need to install PyTorch from specific index:")
        print("pip install torch torchvision torchaudio -f https://download.pytorch.org/whl/torch_stable.html")
    
    return True

def main():
    if len(sys.argv) != 3:
        print("Usage: python convert_conda_to_pip.py input_file.txt output_requirements.txt")
        print("Example: python convert_conda_to_pip.py environment.yml requirements.txt")
        sys.exit(1)
    
    input_file = sys.argv[1]
    output_file = sys.argv[2]
    
    success = convert_conda_to_pip(input_file, output_file)
    if success:
        print("Conversion completed successfully!")
    else:
        print("Conversion failed!")
        sys.exit(1)

if __name__ == "__main__":
    main()