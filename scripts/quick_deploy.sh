#!/bin/bash
# TradingAgents 快速部署脚本（使用预构建镜像）
# 如果构建失败，使用此脚本

set -e

echo "=========================================="
echo "TradingAgents 快速部署"
echo "=========================================="

cd /www/wwwroot/XinPan-ITS-main 2>/dev/null || cd /root/XinPan-ITS-main 2>/dev/null || cd .

# 检查 Docker
if ! command -v docker &> /dev/null; then
    echo "✗ Docker 未安装"
    exit 1
fi

# 确定 Docker Compose 命令
if command -v docker-compose &> /dev/null; then
    DOCKER_COMPOSE="docker-compose"
elif docker compose version &> /dev/null; then
    DOCKER_COMPOSE="docker compose"
else
    echo "✗ Docker Compose 未安装"
    exit 1
fi

echo ""
echo "[1/5] 准备环境..."
echo "=========================================="

# 创建必要目录
mkdir -p logs data config nginx

# 复制 .env
if [ ! -f ".env" ] && [ -f ".env.docker" ]; then
    cp .env.docker .env
    echo "✓ 创建 .env 文件"
fi

# 修复配置
sed -i '/^version:/d' docker-compose.yml 2>/dev/null || true

echo ""
echo "[2/5] 停止旧容器..."
echo "=========================================="

$DOCKER_COMPOSE down 2>/dev/null || true
docker ps -a --format "{{.Names}}" 2>/dev/null | grep "tradingagents" | xargs -r docker rm -f 2>/dev/null || true

echo ""
echo "[3/5] 启动数据库服务..."
echo "=========================================="

# 只启动数据库
$DOCKER_COMPOSE up -d mongodb redis

echo "等待数据库启动 (30秒)..."
sleep 30

echo ""
echo "[4/5] 初始化数据库..."
echo "=========================================="

# 初始化 MongoDB
MAX_RETRIES=5
RETRY=0

while [ $RETRY -lt $MAX_RETRIES ]; do
    if docker exec tradingagents-mongodb mongo -u admin -p tradingagents123 --authenticationDatabase admin --eval 'db.adminCommand("ping")' 2>/dev/null | grep -q "ok"; then
        echo "✓ MongoDB 连接成功"
        
        # 创建管理员用户
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
        ' 2>/dev/null && {
            echo "✓ 管理员用户创建成功"
            break
        }
    fi
    
    RETRY=$((RETRY + 1))
    echo "重试 $RETRY/$MAX_RETRIES..."
    sleep 5
done

echo ""
echo "[5/5] 启动所有服务..."
echo "=========================================="

# 启动所有服务
$DOCKER_COMPOSE up -d

echo "等待服务启动 (60秒)..."
sleep 60

echo ""
echo "=========================================="
echo "部署完成！"
echo "=========================================="
echo ""
echo "访问地址:"
echo "  http://服务器IP"
echo ""
echo "登录信息:"
echo "  用户名: admin"
echo "  密码: admin123"
echo ""
echo "查看状态: $DOCKER_COMPOSE ps"
echo "查看日志: $DOCKER_COMPOSE logs -f"
echo "=========================================="
