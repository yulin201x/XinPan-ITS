#!/bin/bash
# TradingAgents 全面诊断脚本
# 检查所有潜在问题

echo "=========================================="
echo "TradingAgents 全面诊断"
echo "=========================================="

cd /www/wwwroot/XinPan-ITS-main 2>/dev/null || cd /root/XinPan-ITS-main 2>/dev/null || cd .

echo ""
echo "[1] 检查必要文件..."
echo "=========================================="

FILES=(
    "docker-compose.yml"
    "nginx/nginx.conf"
    "Dockerfile.backend"
    "Dockerfile.frontend"
    "frontend/package.json"
    "frontend/.yarnrc"
    "scripts/mongo-init.js"
    ".env.docker"
)

for file in "${FILES[@]}"; do
    if [ -f "$file" ]; then
        echo "✓ $file 存在"
    else
        echo "✗ $file 不存在"
    fi
done

echo ""
echo "[2] 检查 Docker 和 Docker Compose..."
echo "=========================================="

if command -v docker &> /dev/null; then
    echo "✓ Docker 已安装"
    docker --version
else
    echo "✗ Docker 未安装"
fi

if command -v docker-compose &> /dev/null; then
    echo "✓ docker-compose 已安装"
    docker-compose --version
elif docker compose version &> /dev/null; then
    echo "✓ docker compose (插件) 已安装"
    docker compose version
else
    echo "✗ Docker Compose 未安装"
fi

echo ""
echo "[3] 检查端口占用..."
echo "=========================================="

PORTS=(80 8000 3000 27017 6379 8081 8082)
for PORT in "${PORTS[@]}"; do
    if ss -tlnp 2>/dev/null | grep -q ":$PORT " || netstat -tlnp 2>/dev/null | grep -q ":$PORT "; then
        echo "⚠ 端口 $PORT 已被占用"
        ss -tlnp 2>/dev/null | grep ":$PORT " | head -1 || netstat -tlnp 2>/dev/null | grep ":$PORT " | head -1
    else
        echo "✓ 端口 $PORT 可用"
    fi
done

echo ""
echo "[4] 检查 Docker 容器状态..."
echo "=========================================="

if docker ps &> /dev/null; then
    echo "当前运行的容器:"
    docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" 2>/dev/null | grep -E "(NAME|tradingagents)" || echo "无相关容器"
else
    echo "✗ 无法连接到 Docker"
fi

echo ""
echo "[5] 检查 docker-compose.yml 配置..."
echo "=========================================="

# 检查关键配置
if grep -q "VITE_API_BASE_URL: \"\"" docker-compose.yml; then
    echo "✓ VITE_API_BASE_URL 已设置为空"
else
    echo "✗ VITE_API_BASE_URL 配置可能有问题"
fi

if grep -q 'CORS_ORIGINS: "\*"' docker-compose.yml; then
    echo "✓ CORS_ORIGINS 已设置为 *"
else
    echo "✗ CORS_ORIGINS 配置可能有问题"
fi

if grep -q "tradingagents-nginx:" docker-compose.yml; then
    echo "✓ Nginx 服务已定义"
else
    echo "✗ Nginx 服务未定义"
fi

echo ""
echo "[6] 检查 .env 文件..."
echo "=========================================="

if [ -f ".env" ]; then
    echo "✓ .env 文件存在"
    # 检查关键配置
    if grep -q "MONGODB_URL" .env; then
        echo "✓ MONGODB_URL 已配置"
    fi
    if grep -q "JWT_SECRET" .env; then
        echo "✓ JWT_SECRET 已配置"
    fi
else
    echo "✗ .env 文件不存在"
    if [ -f ".env.docker" ]; then
        echo "  可以从 .env.docker 复制"
    fi
fi

echo ""
echo "[7] 检查日志目录..."
echo "=========================================="

if [ -d "logs" ]; then
    echo "✓ logs 目录存在"
    ls -lh logs/ 2>/dev/null | tail -5
else
    echo "✗ logs 目录不存在"
fi

echo ""
echo "[8] 测试服务连通性..."
echo "=========================================="

# 测试后端 API
if curl -s http://localhost:8000/api/health 2>/dev/null | grep -q "healthy\|ok"; then
    echo "✓ 后端 API (localhost:8000) 可访问"
else
    echo "✗ 后端 API (localhost:8000) 无法访问"
fi

# 测试 Nginx
if curl -s http://localhost/api/health 2>/dev/null | grep -q "healthy\|ok"; then
    echo "✓ Nginx (localhost:80) 可访问"
else
    echo "✗ Nginx (localhost:80) 无法访问"
fi

echo ""
echo "=========================================="
echo "诊断完成"
echo "=========================================="
