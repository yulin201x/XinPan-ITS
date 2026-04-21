#!/bin/bash
# TradingAgents 完全重建和部署脚本
# 在宝塔终端执行此脚本

echo "=========================================="
echo "TradingAgents 重建和部署"
echo "=========================================="

# 进入项目目录
cd /www/wwwroot/XinPan-ITS-main

echo ""
echo "[1/4] 停止现有容器..."
docker-compose down

echo ""
echo "[2/4] 重新构建并启动服务..."
docker-compose up -d --build

echo ""
echo "[3/4] 等待服务启动..."
sleep 30

echo ""
echo "[4/4] 检查服务状态..."
docker-compose ps

echo ""
echo "=========================================="
echo "✓ 部署完成"
echo "=========================================="
echo ""
echo "访问地址:"
echo "  前端: http://服务器IP"
echo "  后端API: http://服务器IP/api"
echo ""
echo "登录信息:"
echo "  用户名: admin"
echo "  密码: admin123"
echo ""
echo "如果需要修复管理员用户，请执行:"
echo "  bash scripts/fix_mongodb_admin.sh"
echo "=========================================="
