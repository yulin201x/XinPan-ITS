#!/bin/bash
# 网络诊断脚本

echo "=========================================="
echo "网络诊断"
echo "=========================================="

echo ""
echo "1. 检查网络连通性..."
ping -c 3 8.8.8.8

echo ""
echo "2. 检查 DNS 解析..."
cat /etc/resolv.conf

echo ""
echo "3. 测试访问 Docker Hub..."
curl -v https://registry-1.docker.io/v2/ 2>&1 | head -20

echo ""
echo "4. 检查路由..."
ip route

echo ""
echo "5. 检查防火墙..."
iptables -L -n 2>/dev/null | head -10

echo ""
echo "=========================================="
echo "诊断完成"
echo "=========================================="
