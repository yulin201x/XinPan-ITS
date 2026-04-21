#!/bin/bash
# 修复网络配置

echo "=========================================="
echo "修复网络配置"
echo "=========================================="

# 修改 DNS
echo "nameserver 8.8.8.8" > /etc/resolv.conf
echo "nameserver 114.114.114.114" >> /etc/resolv.conf
echo "✓ DNS 已配置"

# 测试网络
echo ""
echo "测试网络连接..."
ping -c 3 docker.io 2>/dev/null && echo "✓ docker.io 可访问" || echo "✗ docker.io 无法访问"

# 重启 Docker
echo ""
echo "重启 Docker..."
systemctl restart docker
sleep 3

if systemctl is-active --quiet docker; then
    echo "✓ Docker 已重启"
else
    echo "✗ Docker 重启失败"
fi

echo ""
echo "=========================================="
echo "完成"
echo "=========================================="
