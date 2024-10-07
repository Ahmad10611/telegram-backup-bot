#!/bin/bash

# شناسایی سیستم عامل
OS=$(grep -w ID /etc/os-release | cut -d '=' -f 2 | tr -d '"')

# بررسی سیستم عامل پشتیبانی شده
if [[ "$OS" != "ubuntu" && "$OS" != "debian" && "$OS" != "centos" && "$OS" != "rhel" ]]; then
    echo "Unsupported operating system: $OS"
    exit 1
fi

# مسیر اصلی برای ربات
BOT_DIR="/root/telegram-backup-bot"

# اگر دایرکتوری وجود نداشت، آن را ایجاد کن
if [[ ! -d "$BOT_DIR" ]]; then
    echo "Directory $BOT_DIR does not exist. Creating it..."
    mkdir -p "$BOT_DIR"
else
    echo "Directory $BOT_DIR already exists. Updating files..."
fi

# دریافت اطلاعات لازم از کاربر
read -p "Please enter your Telegram bot token: " BOT_TOKEN
read -p "Please enter your authorized user ID (your Telegram numeric ID): " AUTHORIZED_USER_ID
read -p "Please enter your MySQL username: " MYSQL_USER
read -p "Please enter your MySQL password: " MYSQL_PASSWORD
read -p "Please enter your MySQL database name: " MYSQL_DB
read -p "Please enter your MySQL database host (e.g., localhost): " MYSQL_HOST

# تنظیم پیکربندی‌ها در فایل config.cfg (در صورت وجود، فایل قبلی را بازنویسی می‌کند)
CONFIG_PATH="$BOT_DIR/config.cfg"
cat <<EOL >"$CONFIG_PATH"
[DEFAULT]
BOT_TOKEN=$BOT_TOKEN
AUTHORIZED_USER_ID=$AUTHORIZED_USER_ID
DB_USER=$MYSQL_USER
DB_PASSWORD=$MYSQL_PASSWORD
DB_NAME=$MYSQL_DB
DB_HOST=$MYSQL_HOST
EOL
echo "Configuration file updated: $CONFIG_PATH"

# نصب پیش‌نیازها با توجه به سیستم عامل
echo "Installing dependencies for $OS..."
if [[ "$OS" == "ubuntu" || "$OS" == "debian" ]]; then
    apt update -y && apt install -y curl python3-pip mariadb-client libmariadb-dev --no-install-recommends
    if [[ $? -ne 0 ]]; then
        echo "Failed to install dependencies on $OS."
        exit 1
    fi
elif [[ "$OS" == "centos" || "$OS" == "rhel" ]]; then
    yum update -y && yum install -y curl python3-pip mariadb mariadb-devel
    if [[ $? -ne 0 ]]; then
        echo "Failed to install dependencies on $OS."
        exit 1
    fi
fi

# به‌روزرسانی فایل requirements.txt در صورت وجود
REQUIREMENTS_PATH="$BOT_DIR/requirements.txt"
if [[ -f "$REQUIREMENTS_PATH" ]]; then
    echo "Updating requirements.txt..."
    cat <<EOL >"$REQUIREMENTS_PATH"
mysql-connector-python==8.0.33
apscheduler==3.10.4
python-telegram-bot==20.3
jdatetime==3.7.0
configparser
EOL
    echo "requirements.txt updated."
else
    echo "requirements.txt not found. Creating a new one."
    cat <<EOL >"$REQUIREMENTS_PATH"
mysql-connector-python==8.0.33
apscheduler==3.10.4
python-telegram-bot==20.3
jdatetime==3.7.0
configparser
EOL
    echo "New requirements.txt created."
fi

# نصب کتابخانه‌های پایتون
pip3 install -r "$REQUIREMENTS_PATH"
if [[ $? -ne 0 ]]; then
    echo "Failed to install Python libraries."
    exit 1
fi

# به‌روزرسانی یا ایجاد سرویس systemd
SERVICE_PATH="/etc/systemd/system/telegram-backup-bot.service"
if [[ -f "$SERVICE_PATH" ]]; then
    echo "Service already exists. Updating service configuration..."
else
    echo "Creating a new systemd service for Telegram Backup Bot..."
fi

cat <<EOL >"$SERVICE_PATH"
[Unit]
Description=Telegram Backup Bot
After=network.target

[Service]
ExecStart=/usr/bin/python3 $BOT_DIR/telegram_bot.py
WorkingDirectory=$BOT_DIR
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
systemctl restart telegram-backup-bot.service

# بررسی وضعیت سرویس
systemctl is-active --quiet telegram-backup-bot.service
if [[ $? -eq 0 ]]; then
    echo "Telegram Backup Bot service started successfully."
else
    echo "Failed to start Telegram Backup Bot service."
    exit 1
fi

# نمایش لاگ‌های سرویس برای بررسی بیشتر
journalctl -u telegram-backup-bot.service --no-pager -n 20
