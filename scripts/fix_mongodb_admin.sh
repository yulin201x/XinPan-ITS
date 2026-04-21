#!/bin/bash
# MongoDB 管理员用户修复脚本
# 在宝塔终端执行此脚本

echo "=========================================="
echo "修复 MongoDB 管理员用户"
echo "=========================================="

# 查找 MongoDB 容器
MONGO_CONTAINER=$(docker ps --format "{{.Names}}" | grep -i mongo | head -n 1)

if [ -z "$MONGO_CONTAINER" ]; then
    echo "错误: 未找到 MongoDB 容器"
    docker ps
    exit 1
fi

echo "找到 MongoDB 容器: $MONGO_CONTAINER"
echo "正在创建管理员用户..."

# 创建管理员用户
docker exec -i "$MONGO_CONTAINER" mongo -u admin -p tradingagents123 --authenticationDatabase admin tradingagents << 'EOF'
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
print("✓ 管理员用户创建成功");
EOF

if [ $? -eq 0 ]; then
    echo ""
    echo "=========================================="
    echo "✓ MongoDB 管理员用户修复成功"
    echo "=========================================="
    echo ""
    echo "登录信息:"
    echo "  用户名: admin"
    echo "  密码: admin123"
    echo ""
else
    echo ""
    echo "=========================================="
    echo "✗ 修复失败"
    echo "=========================================="
    exit 1
fi
