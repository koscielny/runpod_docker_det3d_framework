
# Base image with CUDA 11.1 to match requirements.txt (torch==1.9.1+cu111)
FROM pytorch/pytorch:1.9.1-cuda11.1-cudnn8-devel

WORKDIR /app

# Install build tools and dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    git \
    wget \
    openssh-server \
    sudo \
    vim \
    libgl1-mesa-glx \
    libsm6 \
    libxext6 \
    libxrender1 \
    && rm -rf /var/lib/apt/lists/*

# Install OpenMMLab dependencies for PyTorch 2.1.0 and CUDA 11.8
# Note: mmcv-full 1.4.0 might have compatibility issues with PyTorch 2.1.0.
# We are using the closest available pre-built wheel. You may need to compile from source if issues arise.
RUN pip install mmcv-full==1.4.0 -f https://download.openmmlab.com/mmcv/dist/cu111/torch1.9.0/index.html
RUN pip install mmdet==2.14.0
RUN pip install mmsegmentation==0.14.1
RUN pip install timm
RUN pip install psutil  # For GPU monitoring

# Clone MapTR and its dependencies with pinned versions
RUN git clone https://github.com/koscielny/MapTR_docker.git /app/MapTR && \
    cd /app/MapTR && \
    git checkout runpod/init
RUN git clone https://github.com/open-mmlab/mmdetection3d.git /app/mmdetection3d && \
    cd /app/mmdetection3d && \
    git checkout v1.0.0rc6

# Install mmdetection3d
WORKDIR /app/mmdetection3d
RUN pip install -e .

# Install GKT (Geometric Kernel Attention)
WORKDIR /app/MapTR/projects/mmdet3d_plugin/maptr/modules/ops/geometric_kernel_attn
RUN python setup.py build install

# Copy MapTR project files
WORKDIR /app/MapTR

# Model weights will be mounted at runtime

# Copy inference script and GPU monitoring utilities
COPY inference.py /app/MapTR/inference.py
COPY gpu_utils.py /app/gpu_utils.py

# Configure SSH server
RUN mkdir /var/run/sshd && \
    echo 'root:runpod123' | chpasswd && \
    sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config && \
    sed -i 's/#PasswordAuthentication yes/PasswordAuthentication yes/' /etc/ssh/sshd_config && \
    sed -i 's/UsePAM yes/UsePAM no/' /etc/ssh/sshd_config

# Create non-root user for security with sudo access
RUN useradd -m -u 1000 -s /bin/bash runpod && \
    echo 'runpod:runpod123' | chpasswd && \
    usermod -aG sudo runpod && \
    echo 'runpod ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers && \
    chown -R runpod:runpod /app

# Copy SSH startup script
COPY start_ssh.sh /usr/local/bin/start_ssh.sh
RUN chmod +x /usr/local/bin/start_ssh.sh

# Expose SSH port
EXPOSE 22

# Switch to non-root user
USER runpod

# Set entrypoint for Runpod
# CMD ["python", "inference.py"]

