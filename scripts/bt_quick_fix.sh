#!/bin/bash
# TradingAgents 宝塔 Docker 一键修复命令
# 直接在宝塔终端执行此脚本即可修复登录问题

echo "=========================================="
echo "TradingAgents 登录问题一键修复"
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

# 直接在 MongoDB 中创建/更新管理员用户
docker exec "$MONGO_CONTAINER" mongosh --username admin --password tradingagents123 --authenticationDatabase admin tradingagents --eval '
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
'

if [ $? -eq 0 ]; then
    echo ""
    echo "=========================================="
    echo "✓ 修复成功！"
    echo "=========================================="
    echo ""
    echo "登录信息:"
    echo "  用户名: admin"
    echo "  密码: admin123"
    echo ""
    echo "请刷新页面后尝试登录"
    echo "=========================================="
else
    echo ""
    echo "=========================================="
    echo "✗ 修复失败"
    echo "=========================================="
    echo "请检查 MongoDB 是否正常运行"
    exit 1
fi
