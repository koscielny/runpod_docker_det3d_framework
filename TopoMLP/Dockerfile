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

# Install Python dependencies
# We will install mmcv-full from a specific wheel for CUDA 11.8 and PyTorch 2.1.0
# The rest of the dependencies will be from requirements.txt
RUN pip install mmcv-full==1.5.2 -f https://download.openmmlab.com/mmcv/dist/cu111/torch1.9.0/index.html
COPY requirements.txt .
RUN pip install -r requirements.txt
RUN pip install psutil  # For GPU monitoring

# Clone TopoMLP with pinned version
RUN git clone https://github.com/koscielny/TopoMLP.git /app/TopoMLP && \
    cd /app/TopoMLP && \
    git checkout runpod/init

# Model weights will be mounted at runtime

# Copy inference script and GPU monitoring utilities
COPY inference.py /app/TopoMLP/inference.py
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

