# Base image with CUDA 11.1 to match StreamPETR requirements (closest available to CUDA 11.2)
FROM pytorch/pytorch:1.9.0-cuda11.1-cudnn8-devel

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

# Install Python dependencies from requirements.txt
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
RUN pip install psutil  # For GPU monitoring

# Install OpenMMLab dependencies for PyTorch 1.9.0 and CUDA 11.1
RUN pip install mmcv-full==1.6.0 -f https://download.openmmlab.com/mmcv/dist/cu111/torch1.9.0/index.html

# Clone StreamPETR and its dependencies with pinned versions
RUN git clone https://github.com/koscielny/StreamPETR-docker.git /app/StreamPETR && \
    cd /app/StreamPETR && \
    git checkout runpod/init
RUN git clone https://github.com/open-mmlab/mmdetection3d.git /app/mmdetection3d && \
    cd /app/mmdetection3d && \
    git checkout v1.0.0rc6

# Install mmdetection3d
WORKDIR /app/mmdetection3d
RUN git checkout v1.0.0rc6
RUN pip install -e .

# Install flash-attn (optional)
# RUN pip install flash-attn==0.2.2

# Copy StreamPETR project files
WORKDIR /app/StreamPETR

# Model weights will be mounted at runtime

# Copy inference script and GPU monitoring utilities
COPY inference.py /app/StreamPETR/inference.py
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
