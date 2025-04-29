#!/bin/bash

# شناسایی سیستم عامل بهبود یافته
if grep -q '^ID_LIKE=' /etc/os-release; then
    OS=$(grep -w ID_LIKE /etc/os-release | cut -d '=' -f 2 | tr -d '"')
else
    OS=$(grep -w ID /etc/os-release | cut -d '=' -f 2 | tr -d '"')
fi

# بررسی وجود ابزارهای لازم
command -v curl >/dev/null 2>&1 || { echo "curl نصب نشده است."; exit 1; }
command -v python3 >/dev/null 2>&1 || { echo "python3 نصب نشده است."; exit 1; }
command -v pip3 >/dev/null 2>&1 || { echo "pip3 نصب نشده است."; exit 1; }

# دریافت مسیر نصب
read -p "Enter the bot installation directory (default: /root/telegram-backup-bot): " INSTALL_DIR
INSTALL_DIR=${INSTALL_DIR:-/root/telegram-backup-bot}

# دریافت اطلاعات لازم
read -p "Please enter your Telegram bot token: " BOT_TOKEN
read -p "Please enter your authorized user ID (your Telegram numeric ID): " AUTHORIZED_USER_ID
read -p "Please enter your MySQL username: " MYSQL_USER
read -p "Please enter your MySQL password: " MYSQL_PASSWORD
read -p "Please enter your MySQL database name: " MYSQL_DB
read -p "Please enter your MySQL database host (e.g., localhost): " MYSQL_HOST

# تنظیم فایل config.cfg
mkdir -p "$INSTALL_DIR"
cat <<EOL >"$INSTALL_DIR/config.cfg"
[DEFAULT]
BOT_TOKEN=$BOT_TOKEN
AUTHORIZED_USER_ID=$AUTHORIZED_USER_ID
DB_USER=$MYSQL_USER
DB_PASSWORD=$MYSQL_PASSWORD
DB_NAME=$MYSQL_DB
DB_HOST=$MYSQL_HOST
EOL

# نصب پیش نیازها
if [[ "$OS" == *"ubuntu"* || "$OS" == *"debian"* ]]; then
    apt update -y
    apt install -y curl python3-pip mariadb-client libmariadb-dev
elif [[ "$OS" == *"centos"* || "$OS" == *"rhel"* ]]; then
    yum update -y
    yum install -y curl python3-pip mariadb mariadb-devel
else
    echo "Unsupported OS: $OS"
    exit 1
fi

# نصب کتابخانه های پایتون
pip3 install -r "$INSTALL_DIR/requirements.txt"

# ایجاد سرویس systemd
cat <<EOL >/etc/systemd/system/telegram-backup-bot.service
[Unit]
Description=Telegram Backup Bot
After=network.target

[Service]
ExecStart=/usr/bin/python3 $INSTALL_DIR/telegram_bot.py
WorkingDirectory=$INSTALL_DIR
StandardOutput=journal
StandardError=journal
Restart=on-failure
User=root

[Install]
WantedBy=multi-user.target
EOL

# بارگذاری و فعالسازی سرویس
systemctl daemon-reload
systemctl enable telegram-backup-bot.service
systemctl start telegram-backup-bot.service

# بررسی وضعیت
if systemctl is-active --quiet telegram-backup-bot.service; then
    echo "✅ سرویس telegram-backup-bot با موفقیت اجرا شد."
else
    echo "❌ خطا در اجرای سرویس."
    journalctl -u telegram-backup-bot.service
fi
