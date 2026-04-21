#!/bin/bash
# TradingAgents 完整安装部署脚本
# 一键完成所有配置和部署

set -e

echo "=========================================="
echo "TradingAgents 完整安装部署"
echo "=========================================="

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# 进入项目目录
cd /www/wwwroot/XinPan-ITS-main

# ===== 步骤 1: 环境检查 =====
echo -e "\n${BLUE}[步骤 1/8] 环境检查...${NC}"

# 检查是否为 root
if [ "$EUID" -ne 0 ]; then
    echo -e "${YELLOW}⚠ 建议使用 root 权限运行${NC}"
fi

# 检查 Docker
if ! command -v docker &> /dev/null; then
    echo -e "${RED}✗ Docker 未安装${NC}"
    exit 1
fi

# 检查 Docker Compose (支持新版 docker compose)
if command -v docker-compose &> /dev/null; then
    DOCKER_COMPOSE="docker-compose"
    echo -e "${GREEN}✓ 使用 docker-compose${NC}"
elif docker compose version &> /dev/null; then
    DOCKER_COMPOSE="docker compose"
    echo -e "${GREEN}✓ 使用 docker compose${NC}"
else
    echo -e "${RED}✗ Docker Compose 未安装${NC}"
    exit 1
fi

echo -e "${GREEN}✓ 环境检查通过${NC}"

# ===== 步骤 2: 端口检查 =====
echo -e "\n${BLUE}[步骤 2/8] 端口检查...${NC}"

# 检查端口 80 是否被占用
if ss -tlnp 2>/dev/null | grep -q ":80 " || netstat -tlnp 2>/dev/null | grep -q ":80 "; then
    echo -e "${YELLOW}⚠ 端口 80 已被占用${NC}"
    
    # 尝试停止宝塔 Nginx
    if [ -f "/etc/init.d/nginx" ]; then
        /etc/init.d/nginx stop 2>/dev/null || true
    fi
    
    # 尝试停止系统 Nginx
    systemctl stop nginx 2>/dev/null || true
    
    # 等待端口释放
    sleep 3
    
    if ss -tlnp 2>/dev/null | grep -q ":80 " || netstat -tlnp 2>/dev/null | grep -q ":80 "; then
        echo -e "${YELLOW}⚠ 端口 80 仍被占用，尝试使用其他端口...${NC}"
        # 修改 docker-compose.yml 使用 8080 端口
        sed -i 's/- "80:80"/- "8080:80"/g' docker-compose.yml
        echo -e "${YELLOW}已将 Nginx 端口改为 8080${NC}"
    fi
fi

echo -e "${GREEN}✓ 端口检查完成${NC}"

# ===== 步骤 3: 准备配置文件 =====
echo -e "\n${BLUE}[步骤 3/8] 准备配置文件...${NC}"

# 创建必要目录
mkdir -p logs data config nginx

# 复制 .env 文件
if [ ! -f ".env" ]; then
    if [ -f ".env.docker" ]; then
        cp .env.docker .env
        echo -e "${GREEN}✓ 创建 .env 文件${NC}"
    else
        echo -e "${RED}✗ .env.docker 文件不存在${NC}"
        exit 1
    fi
else
    echo -e "${GREEN}✓ .env 文件已存在${NC}"
fi

# 检查 nginx.conf 是否存在
if [ ! -f "nginx/nginx.conf" ]; then
    echo -e "${RED}✗ nginx/nginx.conf 不存在${NC}"
    exit 1
fi

# 修复 docker-compose.yml
echo -e "${YELLOW}修复 docker-compose.yml...${NC}"

# 删除过时的 version 行
sed -i '/^version:/d' docker-compose.yml 2>/dev/null || true

# 确保 VITE_API_BASE_URL 为空
sed -i 's|VITE_API_BASE_URL: "http://localhost:8000"|VITE_API_BASE_URL: ""|g' docker-compose.yml
sed -i "s|VITE_API_BASE_URL: 'http://localhost:8000'|VITE_API_BASE_URL: ''|g" docker-compose.yml

# 确保 CORS_ORIGINS 为 *
sed -i 's|CORS_ORIGINS: ".*"|CORS_ORIGINS: "*"|g' docker-compose.yml

echo -e "${GREEN}✓ 配置文件准备完成${NC}"

# ===== 步骤 4: 停止旧容器 =====
echo -e "\n${BLUE}[步骤 4/8] 停止旧容器...${NC}"

# 停止并删除旧容器
$DOCKER_COMPOSE down 2>/dev/null || true

# 删除可能存在的孤立容器
docker ps -a --format "{{.Names}}" 2>/dev/null | grep -E "tradingagents" | while read container; do
    docker rm -f "$container" 2>/dev/null || true
done

echo -e "${GREEN}✓ 旧容器已清理${NC}"

# ===== 步骤 5: 构建并启动服务 =====
echo -e "\n${BLUE}[步骤 5/8] 构建并启动服务...${NC}"

# 构建并启动
$DOCKER_COMPOSE up -d --build

# 等待服务启动
echo -e "${YELLOW}等待服务启动 (60秒)...${NC}"
sleep 60

echo -e "${GREEN}✓ 服务已启动${NC}"

# ===== 步骤 6: 检查服务健康状态 =====
echo -e "\n${BLUE}[步骤 6/8] 检查服务健康状态...${NC}"

# 检查容器状态
CONTAINERS=("tradingagents-backend" "tradingagents-frontend" "tradingagents-nginx" "tradingagents-mongodb" "tradingagents-redis")
ALL_HEALTHY=true

for CONTAINER in "${CONTAINERS[@]}"; do
    if docker ps --format "{{.Names}}" 2>/dev/null | grep -q "^${CONTAINER}$"; then
        STATUS=$(docker inspect --format='{{.State.Status}}' "$CONTAINER" 2>/dev/null || echo "unknown")
        if [ "$STATUS" = "running" ]; then
            echo -e "${GREEN}✓ $CONTAINER 运行中${NC}"
        else
            echo -e "${RED}✗ $CONTAINER 状态异常: $STATUS${NC}"
            ALL_HEALTHY=false
        fi
    else
        echo -e "${RED}✗ $CONTAINER 未启动${NC}"
        ALL_HEALTHY=false
    fi
done

if [ "$ALL_HEALTHY" = false ]; then
    echo -e "${YELLOW}部分服务未正常启动，查看日志...${NC}"
    $DOCKER_COMPOSE logs --tail=50 || true
fi

# ===== 步骤 7: 初始化 MongoDB 管理员 =====
echo -e "\n${BLUE}[步骤 7/8] 初始化 MongoDB 管理员...${NC}"

# 等待 MongoDB 完全启动
echo -e "${YELLOW}等待 MongoDB 就绪 (20秒)...${NC}"
sleep 20

# 执行管理员初始化
MAX_RETRIES=10
RETRY_COUNT=0
MONGO_SUCCESS=false

while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
    echo -e "${YELLOW}尝试连接 MongoDB ($((RETRY_COUNT+1))/$MAX_RETRIES)...${NC}"
    
    # 使用 mongo 命令（MongoDB 4.4 使用 mongo 而不是 mongosh）
    if docker exec tradingagents-mongodb mongo -u admin -p tradingagents123 --authenticationDatabase admin --eval 'db.adminCommand("ping")' 2>/dev/null | grep -q "ok"; then
        echo -e "${GREEN}✓ MongoDB 连接成功${NC}"
        
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
            echo -e "${GREEN}✓ MongoDB 管理员初始化成功${NC}"
            MONGO_SUCCESS=true
            break
        }
    fi
    
    RETRY_COUNT=$((RETRY_COUNT + 1))
    sleep 5
done

if [ "$MONGO_SUCCESS" = false ]; then
    echo -e "${RED}✗ MongoDB 管理员初始化失败${NC}"
    echo "请稍后手动执行: bash scripts/fix_mongodb_admin.sh"
fi

# ===== 步骤 8: 最终验证 =====
echo -e "\n${BLUE}[步骤 8/8] 最终验证...${NC}"

# 获取实际使用的端口
NGINX_PORT=$(grep -oP '(?<=- ")\d+(?=:80)' docker-compose.yml | head -1)
NGINX_PORT=${NGINX_PORT:-80}

# 测试后端 API
if curl -s http://localhost:8000/api/health 2>/dev/null | grep -q "healthy\|ok"; then
    echo -e "${GREEN}✓ 后端 API 可访问${NC}"
else
    echo -e "${YELLOW}⚠ 后端 API 暂时无法访问，可能需要更多启动时间${NC}"
fi

# 测试 Nginx
if curl -s http://localhost:$NGINX_PORT/health 2>/dev/null | grep -q "healthy\|ok"; then
    echo -e "${GREEN}✓ Nginx 可访问 (端口: $NGINX_PORT)${NC}"
else
    echo -e "${YELLOW}⚠ Nginx 暂时无法访问${NC}"
fi

# ===== 完成 =====
echo -e "\n=========================================="
echo -e "${GREEN}✓ 安装部署完成！${NC}"
echo "=========================================="
echo ""
echo -e "${BLUE}访问地址:${NC}"
if [ "$NGINX_PORT" = "80" ]; then
    echo "  前端界面: http://服务器IP"
    echo "  后端API: http://服务器IP/api"
else
    echo "  前端界面: http://服务器IP:$NGINX_PORT"
    echo "  后端API: http://服务器IP:$NGINX_PORT/api"
fi
echo ""
echo -e "${BLUE}登录信息:${NC}"
echo "  用户名: admin"
echo "  密码: admin123"
echo ""
echo -e "${BLUE}常用命令:${NC}"
echo "  查看日志: $DOCKER_COMPOSE logs -f"
echo "  停止服务: $DOCKER_COMPOSE down"
echo "  重启服务: $DOCKER_COMPOSE restart"
echo "  查看状态: $DOCKER_COMPOSE ps"
echo ""
echo -e "${BLUE}管理界面（可选）:${NC}"
echo "  MongoDB: $DOCKER_COMPOSE --profile management up -d mongo-express"
echo "  Redis: $DOCKER_COMPOSE --profile management up -d redis-commander"
echo "=========================================="
