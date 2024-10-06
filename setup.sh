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

# ایجاد فایل config.cfg و نوشتن مقادیر در آن
cat <<EOL >config.cfg
[DEFAULT]
BOT_TOKEN=$BOT_TOKEN
AUTHORIZED_USER_ID=$AUTHORIZED_USER_ID
DB_USER=$MYSQL_USER
DB_PASSWORD=$MYSQL_PASSWORD
DB_NAME=$MYSQL_DB
DB_HOST=$MYSQL_HOST
EOL

# نصب پیش‌نیازها بر اساس سیستم عامل
if [[ "$OS" == "ubuntu" || "$OS" == "debian" ]]; then
    echo "Ubuntu or Debian detected. Installing dependencies..."
    apt update -y
    apt install -y curl python3-pip mariadb-client libmariadb-dev build-essential libssl-dev zlib1g-dev libncurses5-dev libnss3-dev libreadline-dev libffi-dev wget

elif [[ "$OS" == "centos" || "$OS" == "rhel" ]]; then
    echo "CentOS or RHEL detected. Installing dependencies and Python 3.8..."
    yum update -y
    yum install -y gcc openssl-devel bzip2-devel libffi-devel curl wget make

    # دانلود و نصب Python 3.8
    cd /usr/src
    wget https://www.python.org/ftp/python/3.8.10/Python-3.8.10.tgz
    tar xzf Python-3.8.10.tgz
    cd Python-3.8.10
    ./configure --enable-optimizations
    make altinstall

    # تنظیم Python 3.8 به عنوان پیش‌فرض
    ln -sf /usr/local/bin/python3.8 /usr/bin/python3

else
    echo "Unsupported operating system: $OS"
    exit 1
fi

# بررسی نسخه Python
python3 --version

# نصب pip3 برای Python 3.8 (در صورتی که از قبل نصب نشده باشد)
curl https://bootstrap.pypa.io/get-pip.py -o get-pip.py
python3 get-pip.py

# نصب وابستگی‌های پایتون از فایل requirements.txt
pip3 install -r requirements.txt

# ایجاد سرویس systemd برای اجرای ربات به عنوان سرویس
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

# بارگذاری مجدد systemd برای سرویس جدید و فعال کردن آن
systemctl daemon-reload
systemctl enable telegram-backup-bot.service
systemctl start telegram-backup-bot.service

# بررسی وضعیت سرویس
systemctl status telegram-backup-bot.service
