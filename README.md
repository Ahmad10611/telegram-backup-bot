```markdown
# 🤖 Telegram Backup Bot

<div align="center">

[![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![Python](https://img.shields.io/badge/python-3.7+-brightgreen.svg)](https://www.python.org/)
[![Telegram](https://img.shields.io/badge/telegram-bot-blue.svg)](https://telegram.org/)

**پشتیبان‌گیری خودکار از MySQL/MariaDB با ارسال مستقیم به تلگرام**

[فارسی](#-فارسی) • [English](#-english) • [中文](#-中文)

</div>

---

## 📋 فهرست مطالب

- [ویژگی‌ها](#-ویژگی‌ها)
- [نصب سریع](#-نصب-سریع)
- [پیش‌نیازها](#-پیش‌نیازها)
- [استفاده](#-استفاده)
- [مدیریت](#-مدیریت)
- [پشتیبانی از سیستم‌عامل‌ها](#-سیستم-عامل‌های-پشتیبانی-شده)

---

## 🇮🇷 فارسی

### ✨ ویژگی‌ها

- ✅ **پشتیبان‌گیری فوری و دستی** - دریافت آنی backup
- ✅ **زمانبندی خودکار** - backup دوره‌ای (دقیقه‌ای، ساعتی، روزانه)
- ✅ **فشرده‌سازی خودکار** - کاهش حجم فایل‌ها تا 90%
- ✅ **ارسال به تلگرام** - دریافت مستقیم فایل در چت
- ✅ **رابط کاربری ساده** - منوی inline با دکمه‌های فارسی
- ✅ **امنیت بالا** - محدودیت دسترسی با User ID
- ✅ **لاگ کامل** - ثبت تمام عملیات
- ✅ **سازگار با همه لینوکس‌ها** - Ubuntu، Debian، CentOS، و...
- ✅ **نصب یک خطی** - راه‌اندازی در کمتر از 2 دقیقه

### 🚀 نصب سریع

**دستور یک خطی (توصیه می‌شود):**

```bash
curl -fsSL https://raw.githubusercontent.com/Ahmad10611/telegram-backup-bot/main/setup.sh | sudo bash
```

یا با wget:

```bash
wget -qO- https://raw.githubusercontent.com/Ahmad10611/telegram-backup-bot/main/setup.sh | sudo bash
```

**نصب دستی:**

```bash
git clone https://github.com/Ahmad10611/telegram-backup-bot.git
cd telegram-backup-bot
chmod +x setup.sh
sudo ./setup.sh
```

### 📦 پیش‌نیازها

قبل از نصب این موارد را آماده کنید:

| نیازمندی | توضیحات | لینک |
|---------|---------|------|
| 🐧 **سرور لینوکس** | Ubuntu 18.04+، Debian 9+، CentOS 7+ | - |
| 🐍 **Python** | نسخه 3.7 یا بالاتر (نصب خودکار) | [python.org](https://www.python.org/) |
| 🗄️ **MySQL/MariaDB** | سرور دیتابیس | - |
| 🤖 **Bot Token** | از BotFather دریافت کنید | [@BotFather](https://t.me/BotFather) |
| 👤 **User ID** | شناسه عددی تلگرام شما | [@userinfobot](https://t.me/userinfobot) |

### 📖 استفاده

#### 1️⃣ راه‌اندازی اولیه

بعد از نصب، ربات را در تلگرام پیدا کنید و `/start` بزنید:

```
/start
```

#### 2️⃣ منوی اصلی

<table>
<tr>
<td>

**📦 پشتیبان فوری**
- دریافت آنی فایل backup
- فشرده‌سازی خودکار
- ارسال به چت شما

</td>
<td>

**⏰ زمانبندی**
- تنظیم backup خودکار
- دوره‌های دلخواه (دقیقه)
- اجرا در بک‌گراند

</td>
</tr>
<tr>
<td>

**📊 وضعیت**
- مشاهده تنظیمات فعلی
- زمان backup بعدی
- حجم فایل‌های قبلی

</td>
<td>

**🗑 حذف زمانبندی**
- غیرفعال کردن backup خودکار
- نگه داری backup‌های قبلی
- قابل تنظیم مجدد

</td>
</tr>
</table>

#### 3️⃣ مثال‌های کاربردی

```
# پشتیبان هر ساعت
تنظیم زمانبندی → وارد کردن: 60

# پشتیبان روزانه (ساعت 3 صبح)
تنظیم زمانبندی → وارد کردن: 1440

# پشتیبان هر 6 ساعت
تنظیم زمانبندی → وارد کردن: 360
```

### 🛠 مدیریت

#### دستورات systemd

```bash
# مشاهده وضعیت
sudo systemctl status telegram-backup-bot

# مشاهده لاگ زنده
sudo journalctl -u telegram-backup-bot -f

# ری‌استارت
sudo systemctl restart telegram-backup-bot

# توقف
sudo systemctl stop telegram-backup-bot

# شروع
sudo systemctl start telegram-backup-bot

# غیرفعال کردن auto-start
sudo systemctl disable telegram-backup-bot
```

#### حذف کامل

```bash
sudo systemctl stop telegram-backup-bot
sudo systemctl disable telegram-backup-bot
sudo rm -f /etc/systemd/system/telegram-backup-bot.service
sudo systemctl daemon-reload
sudo rm -rf /root/telegram-backup-bot
sudo rm -rf /root/backups
```

### 🖥 سیستم عامل‌های پشتیبانی شده

<table>
<tr>
<td align="center">✅ Ubuntu 18.04+</td>
<td align="center">✅ Debian 9+</td>
<td align="center">✅ CentOS 7+</td>
</tr>
<tr>
<td align="center">✅ RHEL 7+</td>
<td align="center">✅ Rocky Linux</td>
<td align="center">✅ AlmaLinux</td>
</tr>
<tr>
<td align="center">✅ Fedora 30+</td>
<td align="center">✅ Arch Linux</td>
<td align="center">✅ Alpine Linux</td>
</tr>
</table>

### 🔒 امنیت

- 🔐 فقط User ID مشخص شده دسترسی دارد
- 🗝️ رمزهای عبور در فایل محلی با دسترسی محدود
- 📁 فایل‌های backup در مسیر امن با chmod 700
- 🚫 عدم ذخیره token در لاگ‌ها

### ⚠️ عیب‌یابی

<details>
<summary><b>خطای "Python 3.7+ required"</b></summary>

```bash
# چک کردن نسخه فعلی
python3 --version

# نصب Python جدید (Ubuntu/Debian)
sudo apt update
sudo apt install python3.9 python3.9-venv

# نصب Python جدید (CentOS 7)
sudo yum install python39
```
</details>

<details>
<summary><b>خطای "mysqldump not found"</b></summary>

```bash
# Ubuntu/Debian
sudo apt install mysql-client

# CentOS/RHEL
sudo yum install mariadb

# چک کردن نصب
mysqldump --version
```
</details>

<details>
<summary><b>ربات پاسخ نمی‌دهد</b></summary>

```bash
# بررسی وضعیت سرویس
sudo systemctl status telegram-backup-bot

# مشاهده آخرین خطاها
sudo journalctl -u telegram-backup-bot -n 50

# بررسی اتصال به تلگرام
curl -s https://api.telegram.org/bot<TOKEN>/getMe

# ری‌استارت
sudo systemctl restart telegram-backup-bot
```
</details>

### 📞 پشتیبانی

- 🐛 **گزارش باگ:** [Issues](https://github.com/Ahmad10611/telegram-backup-bot/issues)
- 💬 **سوالات:** [Discussions](https://github.com/Ahmad10611/telegram-backup-bot/discussions)
- 📧 **ایمیل:** support@example.com
- 💎 **تلگرام:** [@YourChannel](https://t.me/YourChannel)

---

## 🇬🇧 English

### ✨ Features

- ✅ **Instant Manual Backup** - Get immediate database dumps
- ✅ **Auto Scheduling** - Periodic backups (minutes, hours, daily)
- ✅ **Auto Compression** - Reduce file size up to 90%
- ✅ **Telegram Delivery** - Direct file upload to your chat
- ✅ **Simple UI** - Inline keyboard with easy navigation
- ✅ **High Security** - User ID restriction
- ✅ **Complete Logging** - Track all operations
- ✅ **Cross-Platform** - Works on all major Linux distros
- ✅ **One-Line Install** - Setup in under 2 minutes

### 🚀 Quick Installation

**One-line command (recommended):**

```bash
curl -fsSL https://raw.githubusercontent.com/Ahmad10611/telegram-backup-bot/main/setup.sh | sudo bash
```

Or with wget:

```bash
wget -qO- https://raw.githubusercontent.com/Ahmad10611/telegram-backup-bot/main/setup.sh | sudo bash
```

**Manual install:**

```bash
git clone https://github.com/Ahmad10611/telegram-backup-bot.git
cd telegram-backup-bot
chmod +x setup.sh
sudo ./setup.sh
```

### 📦 Requirements

| Requirement | Description | Link |
|------------|-------------|------|
| 🐧 **Linux Server** | Ubuntu 18.04+, Debian 9+, CentOS 7+ | - |
| 🐍 **Python** | Version 3.7+ (auto-installed) | [python.org](https://www.python.org/) |
| 🗄️ **MySQL/MariaDB** | Database server | - |
| 🤖 **Bot Token** | Get from BotFather | [@BotFather](https://t.me/BotFather) |
| 👤 **User ID** | Your numeric Telegram ID | [@userinfobot](https://t.me/userinfobot) |

### 📖 Usage

After installation, find your bot on Telegram and send `/start`

**Available Commands:**
- 📦 **Instant Backup** - Get backup now
- ⏰ **Schedule** - Set automatic backups
- 📊 **Status** - View current settings
- 🗑 **Clear Schedule** - Disable auto backups

### 🛠 Management

```bash
# View status
sudo systemctl status telegram-backup-bot

# View live logs
sudo journalctl -u telegram-backup-bot -f

# Restart
sudo systemctl restart telegram-backup-bot

# Stop
sudo systemctl stop telegram-backup-bot

# Remove completely
sudo systemctl stop telegram-backup-bot
sudo systemctl disable telegram-backup-bot
sudo rm -f /etc/systemd/system/telegram-backup-bot.service
sudo systemctl daemon-reload
```

---

## 🇨🇳 中文

### ✨ 特点

- ✅ **即时手动备份** - 立即获取数据库转储
- ✅ **自动调度** - 定期备份（分钟、小时、每天）
- ✅ **自动压缩** - 将文件大小减少高达90%
- ✅ **Telegram传送** - 直接上传文件到您的聊天
- ✅ **简单UI** - 内联键盘，易于导航
- ✅ **高安全性** - 用户ID限制
- ✅ **完整日志** - 跟踪所有操作
- ✅ **跨平台** - 适用于所有主要Linux发行版
- ✅ **一行安装** - 2分钟内设置完成

### 🚀 快速安装

**一行命令（推荐）：**

```bash
curl -fsSL https://raw.githubusercontent.com/Ahmad10611/telegram-backup-bot/main/setup.sh | sudo bash
```

或使用wget：

```bash
wget -qO- https://raw.githubusercontent.com/Ahmad10611/telegram-backup-bot/main/setup.sh | sudo bash
```

**手动安装：**

```bash
git clone https://github.com/Ahmad10611/telegram-backup-bot.git
cd telegram-backup-bot
chmod +x setup.sh
sudo ./setup.sh
```

### 📦 要求

| 要求 | 描述 | 链接 |
|------|------|------|
| 🐧 **Linux服务器** | Ubuntu 18.04+、Debian 9+、CentOS 7+ | - |
| 🐍 **Python** | 3.7+版本（自动安装） | [python.org](https://www.python.org/) |
| 🗄️ **MySQL/MariaDB** | 数据库服务器 | - |
| 🤖 **Bot Token** | 从BotFather获取 | [@BotFather](https://t.me/BotFather) |
| 👤 **User ID** | 您的数字Telegram ID | [@userinfobot](https://t.me/userinfobot) |

### 📖 使用

安装后，在Telegram上找到您的机器人并发送 `/start`

**可用命令：**
- 📦 **即时备份** - 立即获取备份
- ⏰ **计划** - 设置自动备份
- 📊 **状态** - 查看当前设置
- 🗑 **清除计划** - 禁用自动备份

### 🛠 管理

```bash
# 查看状态
sudo systemctl status telegram-backup-bot

# 查看实时日志
sudo journalctl -u telegram-backup-bot -f

# 重启
sudo systemctl restart telegram-backup-bot

# 停止
sudo systemctl stop telegram-backup-bot

# 完全删除
sudo systemctl stop telegram-backup-bot
sudo systemctl disable telegram-backup-bot
sudo rm -f /etc/systemd/system/telegram-backup-bot.service
sudo systemctl daemon-reload
```

---

## 📊 مقایسه با راه‌حل‌های دیگر

| ویژگی | این ربات | cron + script | پنل‌های backup |
|-------|---------|---------------|----------------|
| نصب آسان | ✅ یک خط | ❌ پیچیده | ⚠️ نیاز به پنل |
| رابط گرافیکی | ✅ تلگرام | ❌ خط فرمان | ✅ وب |
| اعلان خودکار | ✅ | ❌ | ✅ |
| مدیریت از راه دور | ✅ | ❌ | ✅ |
| رایگان | ✅ | ✅ | ❌ اکثراً پولی |
| حجم سبک | ✅ | ✅ | ❌ سنگین |

## 🤝 مشارکت

مشارکت‌ها خوشآمدند!

1. 🍴 Fork کنید
2. 🌿 Branch بسازید: `git checkout -b feature/amazing`
3. 💾 Commit کنید: `git commit -m 'Add feature'`
4. 📤 Push کنید: `git push origin feature/amazing`
5. 🔃 Pull Request ایجاد کنید

## 📄 مجوز

این پروژه تحت مجوز MIT منتشر شده است - فایل [LICENSE](LICENSE) را ببینید.

## ⭐ ستاره بدهید!

اگر این پروژه برایتان مفید بود، لطفاً یک ستاره ⭐ بدهید!

---

<div align="center">

**ساخته شده با ❤️ توسط [Ahmad](https://github.com/Ahmad10611)**

[گزارش باگ](https://github.com/Ahmad10611/telegram-backup-bot/issues) · [درخواست ویژگی](https://github.com/Ahmad10611/telegram-backup-bot/issues) · [سوال بپرسید](https://github.com/Ahmad10611/telegram-backup-bot/discussions)

</div>
```

**دستورات یک خطی:**

```bash
# با curl (توصیه می‌شود)
curl -fsSL https://raw.githubusercontent.com/Ahmad10611/telegram-backup-bot/main/setup.sh | sudo bash

# با wget
wget -qO- https://raw.githubusercontent.com/Ahmad10611/telegram-backup-bot/main/setup.sh | sudo bash

# بدون sudo (برای آزمایش)
curl -fsSL https://raw.githubusercontent.com/Ahmad10611/telegram-backup-bot/main/setup.sh | bash -s -- /home/$(whoami)/telegram-backup-bot
```

**نصب با تنظیمات پیش‌فرض:**

```bash
curl -fsSL https://raw.githubusercontent.com/Ahmad10611/telegram-backup-bot/main/setup.sh | sudo bash -s -- --auto \
  --token "YOUR_BOT_TOKEN" \
  --userid "YOUR_USER_ID" \
  --dbuser "mysql_user" \
  --dbpass "mysql_pass" \
  --dbname "database_name"
```
