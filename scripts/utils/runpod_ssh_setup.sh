#!/bin/bash

# RunPod SSH 设置脚本
# 为RunPod平台配置SSH服务和公钥认证

set -e

echo "🔧 配置RunPod SSH服务..."

# 生成SSH主机密钥
echo "📋 生成SSH主机密钥..."
ssh-keygen -A

# 创建SSH配置目录
mkdir -p /root/.ssh
chmod 700 /root/.ssh

# 配置SSH服务器
echo "📋 配置SSH服务器..."
cat > /etc/ssh/sshd_config << 'EOF'
# RunPod SSH配置
Port 22
Protocol 2
HostKey /etc/ssh/ssh_host_rsa_key
HostKey /etc/ssh/ssh_host_dsa_key
HostKey /etc/ssh/ssh_host_ecdsa_key
HostKey /etc/ssh/ssh_host_ed25519_key

# 认证配置
PubkeyAuthentication yes
AuthorizedKeysFile .ssh/authorized_keys
PasswordAuthentication yes
PermitEmptyPasswords no

# Root登录配置
PermitRootLogin yes

# 其他配置
X11Forwarding yes
PrintMotd no
AcceptEnv LANG LC_*
Subsystem sftp /usr/lib/openssh/sftp-server

# 安全配置
StrictModes yes
IgnoreRhosts yes
HostbasedAuthentication no
PermitUserEnvironment no
Compression delayed
ClientAliveInterval 60
ClientAliveCountMax 3
EOF

# 设置root密码 (RunPod可能需要)
echo "root:runpod123" | chpasswd

# 从环境变量设置SSH公钥 (RunPod会注入)
if [ -n "$PUBLIC_KEY" ]; then
    echo "📋 设置SSH公钥从环境变量..."
    echo "$PUBLIC_KEY" > /root/.ssh/authorized_keys
    chmod 600 /root/.ssh/authorized_keys
    echo "✅ SSH公钥已设置"
else
    echo "⚠️  未找到PUBLIC_KEY环境变量"
    echo "💡 RunPod会在运行时注入SSH公钥"
fi

# 启动SSH服务
echo "📋 启动SSH服务..."
service ssh start

# 验证SSH服务状态
if service ssh status >/dev/null 2>&1; then
    echo "✅ SSH服务启动成功"
    echo "📡 SSH端口: 22"
    echo "👤 用户: root"
    echo "🔑 密码: runpod123"
    if [ -f /root/.ssh/authorized_keys ]; then
        echo "🔐 公钥认证: 已配置"
    fi
else
    echo "❌ SSH服务启动失败"
    exit 1
fi

echo "🎉 RunPod SSH配置完成!"