#!/bin/bash
# =============================================================================
# TradingAgents 宝塔面板 Docker 部署 - 登录问题修复脚本
# =============================================================================
# 使用方法:
#   1. 进入宝塔面板 -> 文件管理器
#   2. 上传此脚本到项目根目录
#   3. 在终端执行: bash bt_docker_fix.sh
#   或者直接在容器内执行修复命令
# =============================================================================

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}"
echo "============================================================================="
echo "  TradingAgents 宝塔 Docker 部署 - 登录问题修复"
echo "============================================================================="
echo -e "${NC}"

# =============================================================================
# 步骤 1: 检测 Docker 环境
# =============================================================================
echo -e "\n${YELLOW}[步骤 1/4] 检测 Docker 环境...${NC}"

if ! command -v docker &> /dev/null; then
    echo -e "${RED}错误: 未检测到 Docker，请确保 Docker 已安装${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Docker 已安装${NC}"

# 检测运行中的容器
echo -e "\n${BLUE}正在检测 TradingAgents 相关容器...${NC}"

# 查找 MongoDB 容器
MONGO_CONTAINER=$(docker ps --format "{{.Names}}" | grep -i mongo | head -n 1)
if [ -z "$MONGO_CONTAINER" ]; then
    echo -e "${RED}错误: 未找到 MongoDB 容器${NC}"
    echo -e "${YELLOW}提示: 请确保 MongoDB 容器正在运行${NC}"
    docker ps
    exit 1
fi
echo -e "${GREEN}✓ 找到 MongoDB 容器: $MONGO_CONTAINER${NC}"

# 查找后端容器
BACKEND_CONTAINER=$(docker ps --format "{{.Names}}" | grep -E "(backend|api|app)" | grep -v nginx | head -n 1)
if [ -z "$BACKEND_CONTAINER" ]; then
    echo -e "${YELLOW}⚠ 未找到后端容器，将尝试直接连接 MongoDB 修复${NC}"
else
    echo -e "${GREEN}✓ 找到后端容器: $BACKEND_CONTAINER${NC}"
fi

# =============================================================================
# 步骤 2: 检查 MongoDB 连接
# =============================================================================
echo -e "\n${YELLOW}[步骤 2/4] 检查 MongoDB 连接...${NC}"

# 获取 MongoDB 连接信息
MONGO_USER=${MONGO_INITDB_ROOT_USERNAME:-admin}
MONGO_PASS=${MONGO_INITDB_ROOT_PASSWORD:-tradingagents123}
MONGO_DB=${MONGO_INITDB_DATABASE:-tradingagents}

# 测试连接
if docker exec "$MONGO_CONTAINER" mongosh --username "$MONGO_USER" --password "$MONGO_PASS" --authenticationDatabase admin --eval "db.adminCommand('ping')" &> /dev/null; then
    echo -e "${GREEN}✓ MongoDB 连接正常${NC}"
else
    echo -e "${RED}✗ MongoDB 连接失败${NC}"
    echo -e "${YELLOW}尝试使用默认凭据连接...${NC}"
    MONGO_USER="admin"
    MONGO_PASS="tradingagents123"

    if docker exec "$MONGO_CONTAINER" mongosh --username "$MONGO_USER" --password "$MONGO_PASS" --authenticationDatabase admin --eval "db.adminCommand('ping')" &> /dev/null; then
        echo -e "${GREEN}✓ 使用默认凭据连接成功${NC}"
    else
        echo -e "${RED}错误: 无法连接到 MongoDB${NC}"
        echo -e "${YELLOW}请检查 MongoDB 用户名和密码配置${NC}"
        exit 1
    fi
fi

# =============================================================================
# 步骤 3: 创建/修复管理员用户
# =============================================================================
echo -e "\n${YELLOW}[步骤 3/4] 创建/修复管理员用户...${NC}"

# 定义用户名密码
ADMIN_USER="admin"
ADMIN_PASS="admin123"
ADMIN_EMAIL="admin@tradingagents.cn"

# 生成密码哈希 (SHA256)
PASS_HASH=$(echo -n "$ADMIN_PASS" | sha256sum | awk '{print $1}')

echo -e "${BLUE}管理员信息:${NC}"
echo -e "  用户名: ${GREEN}$ADMIN_USER${NC}"
echo -e "  密码: ${GREEN}$ADMIN_PASS${NC}"
echo -e "  邮箱: ${GREEN}$ADMIN_EMAIL${NC}"

# 创建 MongoDB 初始化脚本
docker exec -i "$MONGO_CONTAINER" mongosh --username "$MONGO_USER" --password "$MONGO_PASS" --authenticationDatabase admin "$MONGO_DB" << EOF
// 检查用户是否已存在
var existingUser = db.users.findOne({ username: "$ADMIN_USER" });

if (existingUser) {
    print("用户 '$ADMIN_USER' 已存在，更新密码...");
    db.users.updateOne(
        { username: "$ADMIN_USER" },
        {
            \$set: {
                hashed_password: "$PASS_HASH",
                is_active: true,
                is_admin: true,
                updated_at: new Date()
            }
        }
    );
    print("密码已更新");
} else {
    print("创建新管理员用户...");
    db.users.insertOne({
        username: "$ADMIN_USER",
        email: "$ADMIN_EMAIL",
        hashed_password: "$PASS_HASH",
        is_active: true,
        is_verified: true,
        is_admin: true,
        created_at: new Date(),
        updated_at: new Date(),
        last_login: null,
        preferences: {
            default_market: "A股",
            default_depth: "深度",
            ui_theme: "light",
            language: "zh-CN",
            notifications_enabled: true,
            email_notifications: false
        },
        daily_quota: 10000,
        concurrent_limit: 10,
        total_analyses: 0,
        successful_analyses: 0,
        failed_analyses: 0,
        favorite_stocks: []
    });
    print("用户创建成功");
}

// 验证用户
var user = db.users.findOne({ username: "$ADMIN_USER" });
if (user) {
    print("\n============================================");
    print("✓ 管理员用户验证成功");
    print("============================================");
    print("用户名: " + user.username);
    print("邮箱: " + user.email);
    print("管理员: " + (user.is_admin ? "是" : "否"));
    print("状态: " + (user.is_active ? "激活" : "禁用"));
    print("============================================");
} else {
    print("✗ 用户验证失败");
}
EOF

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ 管理员用户创建/更新成功${NC}"
else
    echo -e "${RED}✗ 管理员用户创建失败${NC}"
    exit 1
fi

# =============================================================================
# 步骤 4: 重启后端服务（如果存在）
# =============================================================================
echo -e "\n${YELLOW}[步骤 4/4] 重启后端服务...${NC}"

if [ -n "$BACKEND_CONTAINER" ]; then
    echo -e "${BLUE}正在重启后端容器: $BACKEND_CONTAINER${NC}"
    docker restart "$BACKEND_CONTAINER"
    echo -e "${GREEN}✓ 后端服务已重启${NC}"
    echo -e "${YELLOW}等待服务启动 (5秒)...${NC}"
    sleep 5
else
    echo -e "${YELLOW}⚠ 未找到后端容器，请手动重启后端服务${NC}"
fi

# =============================================================================
# 完成
# =============================================================================
echo -e "\n${GREEN}"
echo "============================================================================="
echo "  ✓ 修复完成！"
echo "============================================================================="
echo -e "${NC}"
echo -e "${BLUE}登录信息:${NC}"
echo -e "  用户名: ${GREEN}admin${NC}"
echo -e "  密码: ${GREEN}admin123${NC}"
echo ""
echo -e "${BLUE}请尝试使用上述账号登录系统${NC}"
echo ""
echo -e "${YELLOW}如果仍无法登录，请检查:${NC}"
echo "  1. 后端服务日志: docker logs $BACKEND_CONTAINER"
echo "  2. 浏览器开发者工具 (F12) 查看网络请求"
echo "  3. 确认访问的是正确的端口"
echo ""
echo -e "${BLUE}建议: 登录后立即修改默认密码${NC}"
echo ""
