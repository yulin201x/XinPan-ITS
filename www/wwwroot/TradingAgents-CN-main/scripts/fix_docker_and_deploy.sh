#!/bin/bash
# 修复 Docker 配置并部署

echo "=========================================="
echo "修复 Docker 并部署 TradingAgents"
echo "=========================================="

# 1. 修复 Docker 配置
echo ""
echo "[1/4] 修复 Docker 配置..."
echo "=========================================="

# 停止 Docker
systemctl stop docker 2>/dev/null || service docker stop 2>/dev/null || true

# 清空错误的镜像加速器配置，使用默认配置
cat > /etc/docker/daemon.json << 'EOF'
{
    "dns": ["8.8.8.8", "8.8.4.4"]
}
EOF

# 启动 Docker
systemctl start docker 2>/dev/null || service docker start 2>/dev/null

sleep 3

if ! docker info >/dev/null 2>&1; then
    echo "✗ Docker 启动失败"
    exit 1
fi

echo "✓ Docker 已启动"

# 2. 测试拉取镜像
echo ""
echo "[2/4] 测试拉取镜像..."
echo "=========================================="

# 先拉取基础镜像
echo "拉取 Python 镜像..."
docker pull python:3.10-slim-bookworm 2>&1 | tail -3

echo "拉取 Node 镜像..."
docker pull node:22-alpine 2>&1 | tail -3

echo "拉取 Nginx 镜像..."
docker pull nginx:alpine 2>&1 | tail -3

echo "拉取 MongoDB 镜像..."
docker pull mongo:4.4 2>&1 | tail -3

echo "拉取 Redis 镜像..."
docker pull redis:7-alpine 2>&1 | tail -3

echo "✓ 基础镜像拉取完成"

# 3. 准备项目
echo ""
echo "[3/4] 准备项目..."
echo "=========================================="

cd /www/wwwroot/XinPan-ITS-main

# 创建必要目录
mkdir -p logs data config nginx

# 复制 .env
if [ ! -f ".env" ] && [ -f ".env.docker" ]; then
    cp .env.docker .env
fi

# 确保配置正确
sed -i '/^version:/d' docker-compose.yml 2>/dev/null || true

echo "✓ 项目准备完成"

# 4. 启动服务
echo ""
echo "[4/4] 启动服务..."
echo "=========================================="

# 停止旧容器
docker-compose down 2>/dev/null || true

# 启动数据库
docker-compose up -d mongodb redis

echo "等待数据库启动..."
sleep 30

# 初始化 MongoDB
echo "初始化 MongoDB..."
docker exec tradingagents-mongodb mongo -u admin -p tradingagents123 --authenticationDatabase admin tradingagents --eval '
    db.users.deleteOne({ username: "admin" });
    db.users.insertOne({
        username: "admin",
        email: "admin@tradingagents.cn",
        hashed_password: "240be518fabd2724ddb6f04eeb1da5967448d7e831c08c8fa822809f74c720a9",
        is_active: true,
        is_verified: true,
        is_admin: true,
        created_at: new Date(),
        updated_at: new Date(),
        preferences: {
            default_market: "A股",
            default_depth: "深度",
            ui_theme: "light",
            language: "zh-CN",
            notifications_enabled: true
        },
        daily_quota: 10000,
        concurrent_limit: 10,
        total_analyses: 0,
        favorite_stocks: []
    });
    print("管理员用户创建成功");
' 2>/dev/null || echo "MongoDB 初始化可能需要重试"

# 启动所有服务
docker-compose up -d --build

echo "等待服务启动..."
sleep 60

echo ""
echo "=========================================="
echo "部署完成！"
echo "=========================================="
echo ""
echo "访问地址: http://服务器IP"
echo ""
echo "登录信息:"
echo "  用户名: admin"
echo "  密码: admin123"
echo ""
echo "查看状态: docker-compose ps"
echo "查看日志: docker-compose logs -f"
echo "=========================================="
