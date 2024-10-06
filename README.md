### فارسی

**ربات پشتیبان‌گیری تلگرام:**

ربات تلگرام برای پشتیبان‌گیری خودکار از دیتابیس MySQL و ارسال فایل‌های پشتیبان از طریق تلگرام. این ربات با **systemd** مدیریت می‌شود و به صورت خودکار اجرا و نظارت می‌گردد.

#### مراحل نصب:
1. مخزن را کلون کنید:
   ```bash
   git clone https://github.com/Ahmad10611/telegram-backup-bot.git
   cd telegram-backup-bot
   ```

2. اجرای اسکریپت نصب:
   ```bash
   chmod +x setup.sh
   ./setup.sh
   ```

3. ورود اطلاعات:
   - **توکن ربات تلگرام:** می‌توانید این توکن را از [BotFather](https://t.me/BotFather) دریافت کنید.
   - **آیدی عددی کاربر مجاز:** این آیدی عددی تلگرام شما است که می‌توانید آن را از ربات‌هایی مانند [userinfobot](https://t.me/userinfobot) دریافت کنید.
   - **نام کاربری MySQL:** نام کاربری دیتابیس MySQL.
   - **رمز عبور MySQL:** رمز عبور برای دسترسی به MySQL.
   - **نام دیتابیس MySQL:** نام دیتابیسی که قصد پشتیبان‌گیری از آن را دارید.
   - **هاست MySQL:** معمولاً `localhost` است.

4. مدیریت ربات با systemd:
   - **مشاهده وضعیت:** `systemctl status telegram-backup-bot`
   - **مشاهده لاگ‌ها:** `journalctl -u telegram-backup-bot -f`
   - **متوقف کردن:** `systemctl stop telegram-backup-bot`
   - **راه‌اندازی مجدد:** `systemctl restart telegram-backup-bot`

---

### English

**Telegram Backup Bot:**

A Telegram bot for automatic MySQL database backups and sending files via Telegram. Managed using **systemd** for automated execution and monitoring.

#### Installation Steps:
1. Clone the repository:
   ```bash
   git clone https://github.com/Ahmad10611/telegram-backup-bot.git
   cd telegram-backup-bot
   ```

2. Run the setup script:
   ```bash
   chmod +x setup.sh
   ./setup.sh
   ```

3. Enter information:
   - **Telegram bot token:** You can get this token from [BotFather](https://t.me/BotFather).
   - **Authorized user ID:** This is your Telegram numeric ID, which can be retrieved from bots like [userinfobot](https://t.me/userinfobot).
   - **MySQL username:** Your MySQL database username.
   - **MySQL password:** Your MySQL password.
   - **MySQL database name:** The name of the database you want to back up.
   - **MySQL host:** Usually `localhost`.

4. Manage the bot with systemd:
   - **Check status:** `systemctl status telegram-backup-bot`
   - **View logs:** `journalctl -u telegram-backup-bot -f`
   - **Stop bot:** `systemctl stop telegram-backup-bot`
   - **Restart bot:** `systemctl restart telegram-backup-bot`

---

### 中文

**Telegram 备份机器人：**

用于自动备份 MySQL 数据库并通过 Telegram 发送文件的机器人，使用 **systemd** 进行管理，实现自动运行和监控。

#### 安装步骤:
1. 克隆存储库:
   ```bash
   git clone https://github.com/Ahmad10611/telegram-backup-bot.git
   cd telegram-backup-bot
   ```

2. 运行安装脚本:
   ```bash
   chmod +x setup.sh
   ./setup.sh
   ```

3. 输入信息：
   - **Telegram 机器人令牌:** 您可以从 [BotFather](https://t.me/BotFather) 获取此令牌。
   - **授权用户 ID:** 这是您的 Telegram 数字 ID，可以从 [userinfobot](https://t.me/userinfobot) 等机器人获取。
   - **MySQL 用户名:** 您的 MySQL 数据库用户名。
   - **MySQL 密码:** 您的 MySQL 密码。
   - **MySQL 数据库名称:** 您要备份的数据库名称。
   - **MySQL 主机:** 通常为 `localhost`。

4. 使用 systemd 管理机器人：
   - **查看状态:** `systemctl status telegram-backup-bot`
   - **查看日志:** `journalctl -u telegram-backup-bot -f`
   - **停止机器人:** `systemctl stop telegram-backup-bot`
   - **重启机器人:** `systemctl restart telegram-backup-bot`
