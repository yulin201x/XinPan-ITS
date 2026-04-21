#!/usr/bin/env python3
"""
登录问题修复脚本

一键修复部署后无法登录的问题：
1. 检查 MongoDB 连接
2. 检查/创建默认管理员用户
3. 重置密码（如果需要）

使用方法：
    python scripts/fix_login_issue.py
    python scripts/fix_login_issue.py --reset-password newpassword
    python scripts/fix_login_issue.py --username admin --password admin123
"""

import sys
import os
import argparse
from pathlib import Path

# 添加项目根目录到路径
project_root = Path(__file__).parent.parent
sys.path.insert(0, str(project_root))


def check_mongodb_connection():
    """检查 MongoDB 连接"""
    print("\n" + "=" * 60)
    print("🔍 步骤 1: 检查 MongoDB 连接")
    print("=" * 60)

    try:
        from app.core.config import settings
        from pymongo import MongoClient

        print(f"   MongoDB URI: {settings.MONGO_URI.replace(settings.MONGODB_PASSWORD, '***') if settings.MONGODB_PASSWORD else settings.MONGO_URI}")
        print(f"   数据库: {settings.MONGO_DB}")

        client = MongoClient(settings.MONGO_URI, serverSelectionTimeoutMS=5000)
        client.admin.command('ping')
        print("   ✅ MongoDB 连接成功")
        client.close()
        return True

    except Exception as e:
        print(f"   ❌ MongoDB 连接失败: {e}")
        print("\n   可能的解决方案:")
        print("   1. 检查 MongoDB 容器是否运行: docker ps | grep mongo")
        print("   2. 检查 MongoDB 配置是否正确 (.env 文件)")
        print("   3. 重启 MongoDB 容器: docker restart <mongodb容器名>")
        return False


def check_and_create_admin(username="admin", password="admin123", email=None, force=False):
    """检查并创建管理员用户"""
    print("\n" + "=" * 60)
    print("🔍 步骤 2: 检查/创建管理员用户")
    print("=" * 60)

    if email is None:
        email = f"{username}@tradingagents.cn"

    try:
        import asyncio
        from app.services.user_service import user_service

        async def _check_and_create():
            # 检查用户是否存在
            existing_user = await user_service.get_user_by_username(username)

            if existing_user:
                print(f"   ✅ 用户 '{username}' 已存在")
                print(f"      邮箱: {existing_user.email}")
                print(f"      管理员: {'是' if existing_user.is_admin else '否'}")
                print(f"      状态: {'激活' if existing_user.is_active else '禁用'}")

                if force:
                    print(f"\n   🔄 强制重置密码...")
                    from app.core.config import settings
                    from pymongo import MongoClient

                    client = MongoClient(settings.MONGO_URI)
                    db = client[settings.MONGO_DB]

                    # 删除旧用户
                    db.users.delete_one({"username": username})
                    client.close()
                    print(f"   ✅ 已删除旧用户")
                else:
                    return True

            # 创建新用户
            from app.models.user import UserCreate

            user_create = UserCreate(
                username=username,
                email=email,
                password=password
            )

            new_user = await user_service.create_user(user_create)
            if not new_user:
                print(f"   ❌ 创建用户失败")
                return False

            # 设置为管理员
            from app.core.config import settings
            from pymongo import MongoClient

            client = MongoClient(settings.MONGO_URI)
            db = client[settings.MONGO_DB]
            db.users.update_one(
                {"username": username},
                {"$set": {"is_admin": True, "is_verified": True}}
            )
            client.close()

            print(f"   ✅ 管理员用户创建成功")
            return True

        return asyncio.run(_check_and_create())

    except Exception as e:
        print(f"   ❌ 操作失败: {e}")
        import traceback
        traceback.print_exc()
        return False


def reset_password(username, new_password):
    """重置用户密码"""
    print("\n" + "=" * 60)
    print(f"🔍 重置密码: {username}")
    print("=" * 60)

    try:
        import asyncio
        from app.services.user_service import user_service

        async def _reset():
            success = await user_service.reset_password(username, new_password)
            if success:
                print(f"   ✅ 密码重置成功")
                return True
            else:
                print(f"   ❌ 密码重置失败")
                return False

        return asyncio.run(_reset())

    except Exception as e:
        print(f"   ❌ 重置密码失败: {e}")
        return False


def list_all_users():
    """列出所有用户"""
    print("\n" + "=" * 60)
    print("📋 所有用户列表")
    print("=" * 60)

    try:
        import asyncio
        from app.services.user_service import user_service

        async def _list():
            users = await user_service.list_users()
            if not users:
                print("   当前没有用户")
                return

            print(f"   共 {len(users)} 个用户:\n")
            print(f"   {'用户名':<15} {'邮箱':<30} {'角色':<10} {'状态':<10}")
            print("   " + "-" * 65)

            for user in users:
                role = "管理员" if user.is_admin else "普通用户"
                status = "激活" if user.is_active else "禁用"
                print(f"   {user.username:<15} {user.email:<30} {role:<10} {status:<10}")

        asyncio.run(_list())

    except Exception as e:
        print(f"   ❌ 获取用户列表失败: {e}")


def main():
    parser = argparse.ArgumentParser(
        description="修复 TradingAgents 登录问题",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
示例:
  # 检查并创建默认管理员（推荐）
  python scripts/fix_login_issue.py

  # 强制重新创建用户（重置密码）
  python scripts/fix_login_issue.py --force

  # 使用自定义用户名密码
  python scripts/fix_login_issue.py --username myuser --password mypass123

  # 仅重置现有用户密码
  python scripts/fix_login_issue.py --reset-password newpassword

  # 查看所有用户
  python scripts/fix_login_issue.py --list
        """
    )

    parser.add_argument(
        "--username",
        default="admin",
        help="用户名（默认: admin）"
    )
    parser.add_argument(
        "--password",
        default="admin123",
        help="密码（默认: admin123）"
    )
    parser.add_argument(
        "--email",
        help="邮箱（默认: <username>@tradingagents.cn）"
    )
    parser.add_argument(
        "--force",
        action="store_true",
        help="强制重新创建用户（会删除旧用户）"
    )
    parser.add_argument(
        "--reset-password",
        dest="reset_pass",
        metavar="NEW_PASSWORD",
        help="重置现有用户密码"
    )
    parser.add_argument(
        "--list",
        action="store_true",
        dest="list_users",
        help="列出所有用户"
    )

    args = parser.parse_args()

    print("\n" + "=" * 60)
    print("🔧 TradingAgents 登录问题修复工具")
    print("=" * 60)

    # 仅列出用户
    if args.list_users:
        list_all_users()
        return

    # 仅重置密码
    if args.reset_pass:
        if not check_mongodb_connection():
            sys.exit(1)
        if reset_password(args.username, args.reset_pass):
            print("\n" + "=" * 60)
            print("✅ 密码重置成功")
            print("=" * 60)
            print(f"\n   用户名: {args.username}")
            print(f"   新密码: {args.reset_pass}")
            print("\n   请使用新密码登录")
        else:
            print("\n   ❌ 密码重置失败")
            sys.exit(1)
        return

    # 完整修复流程
    print("\n开始修复流程...")

    # 步骤 1: 检查 MongoDB
    if not check_mongodb_connection():
        print("\n" + "=" * 60)
        print("❌ 修复失败: MongoDB 连接问题")
        print("=" * 60)
        sys.exit(1)

    # 步骤 2: 检查/创建管理员
    email = args.email or f"{args.username}@tradingagents.cn"
    if not check_and_create_admin(args.username, args.password, email, args.force):
        print("\n" + "=" * 60)
        print("❌ 修复失败: 无法创建管理员用户")
        print("=" * 60)
        sys.exit(1)

    # 显示结果
    print("\n" + "=" * 60)
    print("✅ 修复完成！")
    print("=" * 60)
    print("\n📋 登录信息:")
    print(f"   用户名: {args.username}")
    print(f"   密码: {args.password}")
    print(f"   邮箱: {email}")
    print("\n📝 后续步骤:")
    print("   1. 访问前端界面")
    print("   2. 使用上述账号登录")
    print("   3. 建议立即修改密码")
    print("\n⚠️  如果仍无法登录，请检查:")
    print("   - 后端服务是否正常运行")
    print("   - 浏览器控制台是否有错误")
    print("   - 网络连接是否正常")
    print("=" * 60)


if __name__ == "__main__":
    main()
