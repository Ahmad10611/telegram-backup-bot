#!/bin/bash

# شناسایی سیستم عامل
OS=$(cat /etc/os-release | grep -w ID | cut -d '=' -f 2 | tr -d '"')

# دریافت اطلاعات لازم از کاربر
read -p "Please enter your Telegram bot token: " BOT_TOKEN
read -p "Please enter your authorized user ID (your Telegram numeric ID): " AUTHORIZED_USER_ID
read -p "Please enter your MySQL username: " MYSQL_USER
read -p "Please enter your MySQL password: " MYSQL_PASSWORD
read -p "Please enter your MySQL database name: " MYSQL_DB
read -p "Please enter your MySQL database host (e.g., localhost): " MYSQL_HOST

# تنظیم پیکربندی‌ها در فایل config.cfg
cat <<EOL >config.cfg
BOT_TOKEN=$BOT_TOKEN
AUTHORIZED_USER_ID=$AUTHORIZED_USER_ID
MYSQL_USER=$MYSQL_USER
MYSQL_PASSWORD=$MYSQL_PASSWORD
MYSQL_DB=$MYSQL_DB
MYSQL_HOST=$MYSQL_HOST
EOL

# نصب پیش‌نیازها
if [[ "$OS" == "ubuntu" || "$OS" == "debian" ]]; then
    echo "Ubuntu or Debian detected. Installing dependencies..."
    apt update -y
    apt install -y curl python3-pip mariadb-client libmariadb-dev

elif [[ "$OS" == "centos" || "$OS" == "rhel" ]]; then
    echo "CentOS or RHEL detected. Installing dependencies..."
    yum update -y
    yum install -y curl python3-pip mariadb mariadb-devel

else
    echo "Unsupported operating system: $OS"
    exit 1
fi

# نصب کتابخانه‌های پایتون با استفاده از مسیر کامل به فایل requirements.txt
pip3 install -r /root/telegram-backup-bot/requirements.txt

# ایجاد سرویس systemd
cat <<EOL >/etc/systemd/system/telegram-backup-bot.service
[Unit]
Description=Telegram Backup Bot
After=network.target

[Service]
ExecStart=/usr/bin/python3 /root/telegram-backup-bot/telegram_bot.py
WorkingDirectory=/root/telegram-backup-bot
StandardOutput=journal
StandardError=journal
Restart=on-failure
User=root

[Install]
WantedBy=multi-user.target
EOL

# بارگذاری مجدد systemd و فعال کردن سرویس
systemctl daemon-reload
systemctl enable telegram-backup-bot.service
systemctl start telegram-backup-bot.service

# بررسی وضعیت سرویس
systemctl status telegram-backup-bot.service
