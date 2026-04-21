#!/bin/bash
# 配置 Docker 镜像加速器

echo "=========================================="
echo "配置 Docker 镜像加速器"
echo "=========================================="

# 创建 Docker 配置目录
mkdir -p /etc/docker

# 备份原配置
if [ -f /etc/docker/daemon.json ]; then
    cp /etc/docker/daemon.json /etc/docker/daemon.json.bak
fi

# 写入镜像加速器配置
cat > /etc/docker/daemon.json << 'EOF'
{
    "registry-mirrors": [
        "https://docker.mirrors.ustc.edu.cn",
        "https://hub-mirror.c.163.com",
        "https://mirror.baidubce.com"
    ]
}
EOF

echo "✓ 镜像加速器配置已写入"

# 重启 Docker 服务
echo "重启 Docker 服务..."
systemctl daemon-reload
systemctl restart docker

# 检查 Docker 状态
if systemctl is-active --quiet docker; then
    echo "✓ Docker 服务已重启"
else
    echo "✗ Docker 服务重启失败"
    exit 1
fi

echo ""
echo "=========================================="
echo "配置完成"
echo "=========================================="
echo "使用的镜像源:"
echo "  - 中科大镜像 (ustc)"
echo "  - 网易云镜像 (163)"
echo "  - 百度镜像 (baidubce)"
echo ""
echo "现在可以重新运行部署脚本"
echo "=========================================="
