#!/bin/bash
# TradingAgents 全面诊断和修复脚本
# 自动检查并修复常见问题

set -e

echo "=========================================="
echo "TradingAgents 全面诊断和修复"
echo "=========================================="

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

cd /www/wwwroot/XinPan-ITS-main

# ===== 1. 检查端口占用 =====
echo -e "\n${BLUE}[1/6] 检查端口占用...${NC}"

PORTS=("80" "8000" "3000" "27017" "6379")
PORT_CONFLICT=false

for PORT in "${PORTS[@]}"; do
    if netstat -tlnp 2>/dev/null | grep -q ":$PORT "; then
        echo -e "${YELLOW}⚠ 端口 $PORT 已被占用${NC}"
        netstat -tlnp 2>/dev/null | grep ":$PORT " | head -1
        PORT_CONFLICT=true
    else
        echo -e "${GREEN}✓ 端口 $PORT 可用${NC}"
    fi
done

if [ "$PORT_CONFLICT" = true ]; then
    echo -e "${YELLOW}⚠ 发现端口冲突，尝试释放...${NC}"
    # 尝试停止可能占用端口的服务
    docker stop tradingagents-nginx tradingagents-backend tradingagents-frontend 2>/dev/null || true
    docker rm tradingagents-nginx tradingagents-backend tradingagents-frontend 2>/dev/null || true
fi

# ===== 2. 检查 Docker 服务 =====
echo -e "\n${BLUE}[2/6] 检查 Docker 服务...${NC}"

if ! systemctl is-active --quiet docker; then
    echo -e "${YELLOW}⚠ Docker 服务未运行，尝试启动...${NC}"
    systemctl start docker
    sleep 2
fi

if systemctl is-active --quiet docker; then
    echo -e "${GREEN}✓ Docker 服务运行正常${NC}"
else
    echo -e "${RED}✗ Docker 服务启动失败${NC}"
    exit 1
fi

# ===== 3. 检查容器状态 =====
echo -e "\n${BLUE}[3/6] 检查容器状态...${NC}"

# 检查现有容器
EXISTING_CONTAINERS=$(docker ps -a --format "{{.Names}}" | grep -E "tradingagents" || true)

if [ -n "$EXISTING_CONTAINERS" ]; then
    echo -e "${YELLOW}发现现有容器:${NC}"
    echo "$EXISTING_CONTAINERS"
    
    # 检查是否有容器正在运行
    RUNNING_CONTAINERS=$(docker ps --format "{{.Names}}" | grep -E "tradingagents" || true)
    
    if [ -n "$RUNNING_CONTAINERS" ]; then
        echo -e "${YELLOW}停止现有容器...${NC}"
        docker-compose down 2>/dev/null || docker stop $(docker ps -q --filter "name=tradingagents") 2>/dev/null || true
    fi
fi

echo -e "${GREEN}✓ 容器状态检查完成${NC}"

# ===== 4. 检查目录和文件权限 =====
echo -e "\n${BLUE}[4/6] 检查目录和文件权限...${NC}"

# 创建必要的目录
mkdir -p logs data config

# 检查 nginx.conf 是否存在
if [ ! -f "nginx/nginx.conf" ]; then
    echo -e "${RED}✗ nginx/nginx.conf 不存在${NC}"
    exit 1
fi

# 检查 .env 是否存在
if [ ! -f ".env" ]; then
    echo -e "${YELLOW}⚠ .env 文件不存在，从 .env.docker 复制...${NC}"
    cp .env.docker .env
fi

echo -e "${GREEN}✓ 目录和文件检查完成${NC}"

# ===== 5. 检查 MongoDB 初始化 =====
echo -e "\n${BLUE}[5/6] 检查 MongoDB 初始化...${NC}"

# 检查 mongo-init.js 是否存在
if [ ! -f "scripts/mongo-init.js" ]; then
    echo -e "${RED}✗ scripts/mongo-init.js 不存在${NC}"
    exit 1
fi

echo -e "${GREEN}✓ MongoDB 初始化脚本存在${NC}"

# ===== 6. 修复常见问题 =====
echo -e "\n${BLUE}[6/6] 修复常见问题...${NC}"

# 修复 1: 确保 VITE_API_BASE_URL 为空
if grep -q 'VITE_API_BASE_URL: "http://localhost:8000"' docker-compose.yml; then
    echo -e "${YELLOW}修复: VITE_API_BASE_URL 配置...${NC}"
    sed -i 's|VITE_API_BASE_URL: "http://localhost:8000"|VITE_API_BASE_URL: ""|g' docker-compose.yml
fi

# 修复 2: 确保 CORS_ORIGINS 为 *
if ! grep -q 'CORS_ORIGINS: "\*"' docker-compose.yml; then
    echo -e "${YELLOW}修复: CORS_ORIGINS 配置...${NC}"
    sed -i 's|CORS_ORIGINS: ".*"|CORS_ORIGINS: "*"|g' docker-compose.yml
fi

# 修复 3: 删除过时的 version 属性
if grep -q "^version:" docker-compose.yml; then
    echo -e "${YELLOW}修复: 删除过时的 version 属性...${NC}"
    sed -i '/^version:/d' docker-compose.yml
fi

echo -e "${GREEN}✓ 常见问题修复完成${NC}"

# ===== 总结 =====
echo -e "\n=========================================="
echo -e "${GREEN}诊断和修复完成！${NC}"
echo "=========================================="
echo ""
echo "接下来可以执行:"
echo "  1. 启动服务: docker-compose up -d --build"
echo "  2. 查看日志: docker-compose logs -f"
echo "  3. 修复管理员: bash scripts/fix_mongodb_admin.sh"
echo ""
echo "访问地址:"
echo "  前端: http://服务器IP"
echo "  后端API: http://服务器IP/api"
echo "=========================================="
