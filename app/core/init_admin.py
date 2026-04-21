"""
管理员用户自动初始化模块

功能：
- 在应用启动时自动检查并创建默认管理员用户
- 如果用户已存在，则跳过创建
- 支持通过环境变量配置默认用户

环境变量：
- DEFAULT_ADMIN_USERNAME: 默认管理员用户名（默认: admin）
- DEFAULT_ADMIN_PASSWORD: 默认管理员密码（默认: admin123）
- DEFAULT_ADMIN_EMAIL: 默认管理员邮箱（默认: admin@tradingagents.cn）
- SKIP_ADMIN_INIT: 设置为 "true" 跳过自动初始化
"""

import os
import logging
from typing import Optional

from app.core.config import settings
from app.models.user import UserCreate

# 尝试导入日志管理器
try:
    from tradingagents.utils.logging_manager import get_logger
except ImportError:
    def get_logger(name: str) -> logging.Logger:
        return logging.getLogger(name)

logger = get_logger('init_admin')


async def init_default_admin() -> bool:
    """
    初始化默认管理员用户

    Returns:
        bool: 是否成功创建或已存在
    """
    # 检查是否跳过初始化
    if os.getenv("SKIP_ADMIN_INIT", "").lower() == "true":
        logger.info("⏭️  跳过管理员初始化 (SKIP_ADMIN_INIT=true)")
        return True

    try:
        # 延迟导入，避免循环依赖
        from app.services.user_service import user_service

        # 获取配置
        username = os.getenv("DEFAULT_ADMIN_USERNAME", "admin")
        password = os.getenv("DEFAULT_ADMIN_PASSWORD", "admin123")
        email = os.getenv("DEFAULT_ADMIN_EMAIL", f"{username}@tradingagents.cn")

        logger.info(f"🔐 检查默认管理员用户: {username}")

        # 检查用户是否已存在
        existing_user = await user_service.get_user_by_username(username)
        if existing_user:
            logger.info(f"✅ 管理员用户已存在: {username}")
            return True

        # 创建管理员用户
        user_create = UserCreate(
            username=username,
            email=email,
            password=password
        )

        new_user = await user_service.create_user(user_create)
        if not new_user:
            logger.error(f"❌ 创建管理员用户失败: {username}")
            return False

        # 设置为管理员
        from pymongo import MongoClient
        client = MongoClient(settings.MONGO_URI)
        db = client[settings.MONGO_DB]
        db.users.update_one(
            {"username": username},
            {"$set": {"is_admin": True, "is_verified": True}}
        )
        client.close()

        logger.info("=" * 60)
        logger.info("✅ 默认管理员用户创建成功")
        logger.info("=" * 60)
        logger.info(f"   用户名: {username}")
        logger.info(f"   密码: {password}")
        logger.info(f"   邮箱: {email}")
        logger.info("=" * 60)
        logger.info("⚠️  请登录后立即修改默认密码！")
        logger.info("=" * 60)

        return True

    except Exception as e:
        logger.error(f"❌ 初始化管理员用户失败: {e}")
        return False


async def reset_admin_password(username: str, new_password: str) -> bool:
    """
    重置管理员密码

    Args:
        username: 用户名
        new_password: 新密码

    Returns:
        bool: 是否成功
    """
    try:
        from app.services.user_service import user_service

        success = await user_service.reset_password(username, new_password)
        if success:
            logger.info(f"✅ 管理员 {username} 密码已重置")
        else:
            logger.error(f"❌ 重置管理员 {username} 密码失败")
        return success

    except Exception as e:
        logger.error(f"❌ 重置密码失败: {e}")
        return False


async def list_all_users() -> None:
    """列出所有用户（调试用）"""
    try:
        from app.services.user_service import user_service

        users = await user_service.list_users()
        if not users:
            logger.info("📋 当前没有用户")
            return

        logger.info(f"📋 用户列表 ({len(users)} 个):")
        for user in users:
            role = "管理员" if user.is_admin else "普通用户"
            status = "激活" if user.is_active else "禁用"
            logger.info(f"   - {user.username} ({user.email}) | {role} | {status}")

    except Exception as e:
        logger.error(f"❌ 获取用户列表失败: {e}")
