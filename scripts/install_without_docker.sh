#!/bin/bash
# TradingAgents 免 Docker 安装脚本
# 直接在服务器上运行，不使用 Docker

echo "=========================================="
echo "TradingAgents 免 Docker 安装"
echo "=========================================="

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

cd /www/wwwroot/XinPan-ITS-main

echo ""
echo "[1/6] 检查系统环境..."
echo "=========================================="

# 检查 Python
if ! command -v python3 &> /dev/null; then
    echo -e "${RED}✗ Python3 未安装${NC}"
    echo "正在安装 Python3..."
    apt-get update && apt-get install -y python3 python3-pip python3-venv
fi
echo -e "${GREEN}✓ Python3 已安装${NC}"

# 检查 Node.js
if ! command -v node &> /dev/null; then
    echo -e "${YELLOW}⚠ Node.js 未安装${NC}"
    echo "正在安装 Node.js..."
    curl -fsSL https://deb.nodesource.com/setup_22.x | bash -
    apt-get install -y nodejs
fi
echo -e "${GREEN}✓ Node.js 已安装${NC}"

# 检查 MongoDB
if ! command -v mongod &> /dev/null; then
    echo -e "${YELLOW}⚠ MongoDB 未安装${NC}"
    echo "正在安装 MongoDB..."
    wget -qO - https://www.mongodb.org/static/pgp/server-4.4.asc | apt-key add -
    echo "deb [ arch=amd64,arm64 ] https://repo.mongodb.org/apt/ubuntu focal/mongodb-org/4.4 multiverse" | tee /etc/apt/sources.list.d/mongodb-org-4.4.list
    apt-get update
    apt-get install -y mongodb-org
    systemctl start mongod
    systemctl enable mongod
fi
echo -e "${GREEN}✓ MongoDB 已安装${NC}"

# 检查 Redis
if ! command -v redis-server &> /dev/null; then
    echo -e "${YELLOW}⚠ Redis 未安装${NC}"
    echo "正在安装 Redis..."
    apt-get install -y redis-server
    systemctl start redis
    systemctl enable redis
fi
echo -e "${GREEN}✓ Redis 已安装${NC}"

echo ""
echo "[2/6] 配置 MongoDB..."
echo "=========================================="

# 创建管理员用户
sleep 5
mongo admin --eval '
    db.createUser({
        user: "admin",
        pwd: "tradingagents123",
        roles: [{role: "root", db: "admin"}]
    })
' 2>/dev/null || echo "用户可能已存在"

# 创建应用数据库和用户
mongo -u admin -p tradingagents123 --authenticationDatabase admin tradingagents --eval '
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
'

echo -e "${GREEN}✓ MongoDB 配置完成${NC}"

echo ""
echo "[3/6] 安装后端依赖..."
echo "=========================================="

# 创建虚拟环境
python3 -m venv venv
source venv/bin/activate

# 安装依赖
pip install -i https://pypi.tuna.tsinghua.edu.cn/simple -e .
pip install -i https://pypi.tuna.tsinghua.edu.cn/simple pdfkit

echo -e "${GREEN}✓ 后端依赖安装完成${NC}"

echo ""
echo "[4/6] 构建前端..."
echo "=========================================="

cd frontend

# 安装依赖
npm config set registry https://registry.npmmirror.com
npm install

# 构建
npm run build

cd ..

echo -e "${GREEN}✓ 前端构建完成${NC}"

echo ""
echo "[5/6] 配置环境变量..."
echo "=========================================="

# 创建 .env 文件
cat > .env << 'EOF'
DOCKER_CONTAINER=false
MONGODB_ENABLED=true
REDIS_ENABLED=true
MONGODB_URL=mongodb://admin:tradingagents123@localhost:27017/tradingagents?authSource=admin
REDIS_URL=redis://:tradingagents123@localhost:6379/0
JWT_SECRET=local-jwt-secret-key
CORS_ORIGINS=*
HOST=0.0.0.0
PORT=8000
DEBUG=false
EOF

echo -e "${GREEN}✓ 环境变量配置完成${NC}"

echo ""
echo "[6/6] 创建启动脚本..."
echo "=========================================="

# 创建后端启动脚本
cat > start_backend.sh << 'EOF'
#!/bin/bash
cd /www/wwwroot/XinPan-ITS-main
source venv/bin/activate
python -m uvicorn app.main:app --host 0.0.0.0 --port 8000
EOF
chmod +x start_backend.sh

# 创建前端服务配置（使用 Python 简单 HTTP 服务器）
cat > start_frontend.sh << 'EOF'
#!/bin/bash
cd /www/wwwroot/XinPan-ITS-main/frontend/dist
python3 -m http.server 3000 --bind 0.0.0.0
EOF
chmod +x start_frontend.sh

# 创建 Nginx 配置
cat > /etc/nginx/sites-available/tradingagents << 'EOF'
server {
    listen 80;
    server_name _;

    location / {
        proxy_pass http://localhost:3000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }

    location /api/ {
        proxy_pass http://localhost:8000/api/;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }
}
EOF

ln -sf /etc/nginx/sites-available/tradingagents /etc/nginx/sites-enabled/
rm -f /etc/nginx/sites-enabled/default
nginx -t && systemctl reload nginx

echo -e "${GREEN}✓ 启动脚本创建完成${NC}"

echo ""
echo "=========================================="
echo -e "${GREEN}✓ 安装完成！${NC}"
echo "=========================================="
echo ""
echo -e "${BLUE}启动命令:${NC}"
echo "  后端: bash start_backend.sh"
echo "  前端: bash start_frontend.sh"
echo ""
echo -e "${BLUE}访问地址:${NC}"
echo "  http://服务器IP"
echo ""
echo -e "${BLUE}登录信息:${NC}"
echo "  用户名: admin"
echo "  密码: admin123"
echo "=========================================="
