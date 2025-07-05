#!/bin/bash

# Script to safely install packages from conda environment export files
# Handles the VAD requirements.txt format intelligently

CONDA_EXPORT_FILE="$1"
TARGET_ENV="${2:-mapping_models}"

if [ ! -f "$CONDA_EXPORT_FILE" ]; then
    echo "❌ Error: File $CONDA_EXPORT_FILE not found"
    exit 1
fi

echo "🔧 Installing packages from conda export file: $CONDA_EXPORT_FILE"
echo "🎯 Target environment: $TARGET_ENV"

# Activate target environment
source /workspace/miniconda/bin/activate "$TARGET_ENV"

# Categories of packages to handle differently
SYSTEM_PACKAGES="_libgcc_mutex|_openmp_mutex|libffi|libgcc-ng|libgomp|libstdcxx-ng|ld_impl_linux|openssl|ca-certificates|certifi|readline|sqlite|tk|xz|zlib|ncurses"
CONDA_PACKAGES=""
PIP_PACKAGES=""

# Process the file line by line
while IFS= read -r line; do
    # Skip comments and empty lines
    [[ "$line" =~ ^#.*$ ]] && continue
    [[ -z "$line" ]] && continue
    
    # Extract package info
    if [[ "$line" =~ ^([^=]+)=([^=]+)=?(.*)$ ]]; then
        pkg_name="${BASH_REMATCH[1]}"
        pkg_version="${BASH_REMATCH[2]}"
        build_info="${BASH_REMATCH[3]}"
        
        # Skip system packages
        if [[ "$pkg_name" =~ $SYSTEM_PACKAGES ]]; then
            echo "⏭️  Skipping system package: $pkg_name"
            continue
        fi
        
        # Check if it's a pip package
        if [[ "$build_info" == *"pypi"* ]]; then
            PIP_PACKAGES="$PIP_PACKAGES $pkg_name==$pkg_version"
        else
            # Try conda first, fallback to pip
            echo "📦 Installing $pkg_name=$pkg_version via conda..."
            if conda install -y "$pkg_name=$pkg_version" -c conda-forge -c pytorch -c nvidia 2>/dev/null; then
                echo "✅ Successfully installed $pkg_name via conda"
            else
                echo "⚠️  Conda install failed, trying pip for $pkg_name..."
                PIP_PACKAGES="$PIP_PACKAGES $pkg_name==$pkg_version"
            fi
        fi
    fi
done < "$CONDA_EXPORT_FILE"

# Install pip packages in batch
if [ -n "$PIP_PACKAGES" ]; then
    echo "🐍 Installing remaining packages via pip..."
    echo "Packages: $PIP_PACKAGES"
    
    # Install one by one to avoid failure cascade
    for pkg in $PIP_PACKAGES; do
        echo "📦 Installing $pkg via pip..."
        if pip install "$pkg" 2>/dev/null; then
            echo "✅ Successfully installed $pkg via pip"
        else
            echo "❌ Failed to install $pkg"
        fi
    done
fi

echo "🎉 Installation completed!"
echo "🔍 Verifying key packages..."

# Quick verification
python -c "
try:
    import torch
    print(f'✅ PyTorch: {torch.__version__}')
except ImportError:
    print('❌ PyTorch not found')

try:
    import numpy
    print(f'✅ NumPy: {numpy.__version__}')
except ImportError:
    print('❌ NumPy not found')

try:
    import mmcv
    print(f'✅ MMCV: {mmcv.__version__}')
except ImportError:
    print('⚠️  MMCV not found (may need manual installation)')
"