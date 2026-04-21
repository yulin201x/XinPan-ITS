#!/bin/bash
# XinPan-ITS 宝塔面板 Docker 更新脚本
# 用途：在宝塔面板中执行，一键更新项目
# 数据说明：MongoDB和Redis数据使用Docker数据卷存储，更新不会丢失

set -e

echo "========================================"
echo "  XinPan-ITS Docker 更新脚本"
echo "========================================"
echo ""

# 获取脚本所在目录
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

echo "📁 项目路径: $SCRIPT_DIR"
echo ""

# 检查 Docker 是否安装
if ! command -v docker &> /dev/null; then
    echo "❌ Docker 未安装，请先在宝塔面板安装 Docker"
    exit 1
fi

# 检查 Docker Compose 是否可用
if ! docker compose version &> /dev/null; then
    echo "❌ Docker Compose 未安装"
    exit 1
fi

echo "✅ Docker 环境检查通过"
echo ""

# ========== 步骤 1: 检查代码更新 ==========
echo "📦 步骤 1/5: 检查代码更新..."
echo "✅ 使用当前目录代码进行构建"
echo ""

# ========== 步骤 2: 停止现有服务 ==========
echo "📦 步骤 2/5: 停止现有服务..."
docker compose down
echo "✅ 服务已停止"
echo ""

# ========== 步骤 3: 增量构建镜像 ==========
echo "📦 步骤 3/5: 构建 Docker 镜像（增量构建，仅重新构建修改过的部分）..."
docker compose build
echo "✅ 镜像构建完成"
echo ""

# ========== 步骤 4: 启动服务 ==========
echo "📦 步骤 4/5: 启动服务..."
docker compose up -d
echo "✅ 服务已启动"
echo ""

# ========== 步骤 5: 检查服务状态 ==========
echo "📦 步骤 5/5: 检查服务状态..."
sleep 10

echo ""
echo "📊 容器运行状态："
docker compose ps
echo ""

# 检查关键服务健康状态
echo "🔍 健康检查："
if docker compose ps | grep -q "Up"; then
    echo "  ✅ 服务运行中"
else
    echo "  ⚠️ 部分服务可能未正常启动，请查看日志"
fi

echo ""
echo "========================================"
echo "  ✅ 更新完成！"
echo "========================================"
echo ""
echo "📊 服务访问地址："
echo "  - 前端: http://你的域名或IP:3000"
echo "  - 后端: http://你的域名或IP:8000"
echo "  - Nginx: http://你的域名或IP:80"
echo ""
echo "📁 数据存储位置（不会丢失）："
echo "  - MongoDB: Docker 数据卷 tradingagents_mongodb_data"
echo "  - Redis: Docker 数据卷 tradingagents_redis_data"
echo "  - 日志: $SCRIPT_DIR/logs"
echo "  - 配置: $SCRIPT_DIR/config"
echo "  - 数据: $SCRIPT_DIR/data"
echo ""
echo "📝 常用命令："
echo "  - 查看日志: cd $SCRIPT_DIR && docker compose logs -f"
echo "  - 重启服务: cd $SCRIPT_DIR && docker compose restart"
echo "  - 停止服务: cd $SCRIPT_DIR && docker compose down"
echo "  - 启动服务: cd $SCRIPT_DIR && docker compose up -d"
echo ""