در اینجا کد نهایی شما با بخش‌های کلیکی برای انتخاب زبان (فارسی، انگلیسی، چینی) آمده است:

```markdown
### 📦 Telegram Backup Bot - Multilingual Guide

#### [🇮🇷 فارسی](#فارسی) | [🌍 English](#english) | [📦 简体中文](#中文)

<details id="فارسی">
  <summary>🇮🇷 فارسی</summary>

### 📦 ربات پشتیبان‌گیری تلگرام - راهنمای خلاصه

**توضیحات:**
این ربات به طور خودکار از دیتابیس MySQL پشتیبان تهیه می‌کند و فایل‌های پشتیبان را از طریق تلگرام ارسال می‌کند. **systemd** برای مدیریت و اجرای خودکار ربات استفاده می‌شود.

---

### نیازمندی‌ها:
1. سرور لینوکسی (Ubuntu، Debian، CentOS)
2. نصب MySQL و Python 3.8+
3. توکن ربات تلگرام از [BotFather](https://t.me/BotFather)
4. آیدی عددی کاربر مجاز از [userinfobot](https://t.me/userinfobot)

---

### نصب ربات:

1. **کلون کردن مخزن:**
   ```bash
   git clone https://github.com/Ahmad10611/telegram-backup-bot.git
   cd telegram-backup-bot
   ```

2. **اجرای اسکریپت نصب:**
   ```bash
   chmod +x setup.sh
   ./setup.sh
   ```

3. **ورودی‌های لازم:**
   - توکن ربات تلگرام از [BotFather](https://t.me/BotFather)
   - آیدی عددی کاربر مجاز از [userinfobot](https://t.me/userinfobot)
   - اطلاعات اتصال MySQL (نام کاربری، رمز عبور، دیتابیس، هاست)

---

### مدیریت ربات:

- **مشاهده لاگ‌ها:**  
  ```bash
  journalctl -u telegram-backup-bot.service -f
  ```

- **توقف ربات:**  
  ```bash
  systemctl stop telegram-backup-bot
  ```

- **راه‌اندازی مجدد ربات:**  
  ```bash
  systemctl restart telegram-backup-bot
  ```

- **حذف ربات:**  
  ```bash
  systemctl stop telegram-backup-bot
  systemctl disable telegram-backup-bot
  rm /etc/systemd/system/telegram-backup-bot.service
  systemctl daemon-reload
  systemctl reset-failed
  ```

</details>

<details id="english">
  <summary>🌍 English</summary>

### 🌍 Telegram Backup Bot - Quick Guide

**Overview:**
Automatically backs up MySQL and sends the files via Telegram using **systemd** for process management.

---

### Requirements:
1. Linux server (Ubuntu, Debian, CentOS)
2. MySQL and Python 3.8+
3. Telegram Bot Token from [BotFather](https://t.me/BotFather)
4. Authorized User ID from [userinfobot](https://t.me/userinfobot)

---

### Bot Installation:

1. **Clone the repository:**
   ```bash
   git clone https://github.com/Ahmad10611/telegram-backup-bot.git
   cd telegram-backup-bot
   ```

2. **Run the setup script:**
   ```bash
   chmod +x setup.sh
   ./setup.sh
   ```

3. **Required inputs:**
   - Telegram Bot Token from [BotFather](https://t.me/BotFather)
   - Authorized User ID from [userinfobot](https://t.me/userinfobot)
   - MySQL connection info (username, password, database, host)

---

### Bot Management:

- **View logs:**  
  ```bash
  journalctl -u telegram-backup-bot.service -f
  ```

- **Stop bot:**  
  ```bash
  systemctl stop telegram-backup-bot
  ```

- **Restart bot:**  
  ```bash
  systemctl restart telegram-backup-bot
  ```

- **Remove bot:**  
  ```bash
  systemctl stop telegram-backup-bot
  systemctl disable telegram-backup-bot
  rm /etc/systemd/system/telegram-backup-bot.service
  systemctl daemon-reload
  systemctl reset-failed
  ```

</details>

<details id="中文">
  <summary>📦 简体中文</summary>

### 📦 电报备份机器人 - 简要指南

**概述:**
自动备份 MySQL 并通过 Telegram 发送，使用 **systemd** 管理进程。

---

### 要求:
1. Linux服务器 (Ubuntu, Debian, CentOS)
2. MySQL 和 Python 3.8+
3. Telegram 机器人令牌来自 [BotFather](https://t.me/BotFather)
4. 授权用户ID来自 [userinfobot](https://t.me/userinfobot)

---

### 安装机器人:

1. **克隆仓库:**
   ```bash
   git clone https://github.com/Ahmad10611/telegram-backup-bot.git
   cd telegram-backup-bot
   ```

2. **运行安装脚本:**
   ```bash
   chmod +x setup.sh
   ./setup.sh
   ```

3. **输入信息:**
   - Telegram 机器人令牌来自 [BotFather](https://t.me/BotFather)
   - 授权用户ID来自 [userinfobot](https://t.me/userinfobot)
   - MySQL 连接信息 (用户名, 密码, 数据库, 主机)

---

### 机器人管理:

- **查看日志:**  
  ```bash
  journalctl -u telegram-backup-bot.service -f
  ```

- **停止机器人:**  
  ```bash
  systemctl stop telegram-backup-bot
  ```

- **重启机器人:**  
  ```bash
  systemctl restart telegram-backup-bot
  ```

- **删除机器人:**  
  ```bash
  systemctl stop telegram-backup-bot
  systemctl disable telegram-backup-bot
  rm /etc/systemd/system/telegram-backup-bot.service
  systemctl daemon-reload
  systemctl reset-failed
  ```

</details>
```

### توضیحات:
- سه زبان فارسی، انگلیسی و چینی با استفاده از تگ‌های HTML و تگ‌های `details` پیاده‌سازی شده‌اند.
- کاربران می‌توانند با کلیک بر روی هر زبان، توضیحات مربوط به آن زبان را مشاهده کنند.
