#!/bin/bash
# 修复 Docker 守护进程配置

echo "=========================================="
echo "修复 Docker 守护进程配置"
echo "=========================================="

# 停止 Docker
systemctl stop docker

# 创建/修改 daemon.json
cat > /etc/docker/daemon.json << 'EOF'
{
    "registry-mirrors": [
        "https://hub-mirror.c.163.com",
        "https://mirror.baidubce.com"
    ],
    "dns": ["8.8.8.8", "114.114.114.114"]
}
EOF

echo "✓ 配置已更新"

# 启动 Docker
systemctl start docker

# 等待 Docker 启动
sleep 3

if systemctl is-active --quiet docker; then
    echo "✓ Docker 已启动"
    echo ""
    echo "测试拉取镜像..."
    docker pull hello-world 2>/dev/null && echo "✓ 镜像拉取正常" || echo "⚠ 镜像拉取可能有问题"
else
    echo "✗ Docker 启动失败"
fi

echo ""
echo "=========================================="
echo "完成"
echo "=========================================="
