#!/bin/bash

# استعلام اطلاعات از کاربر
echo "Please enter your Telegram bot token:"
read telegram_token

echo "Please enter the authorized user ID (your Telegram numeric ID):"
read authorized_user_id

echo "Please enter your MySQL username:"
read db_user

echo "Please enter your MySQL password:"
read -s db_password

echo "Please enter your MySQL database name:"
read db_name

echo "Please enter your MySQL database host (e.g., localhost):"
read db_host

# ذخیره اطلاعات در فایل کانفیگ
cat <<EOT > config.cfg
[DEFAULT]
TELEGRAM_TOKEN=${telegram_token}
AUTHORIZED_USER_ID=${authorized_user_id}
DB_USER=${db_user}
DB_PASSWORD=${db_password}
DB_NAME=${db_name}
DB_HOST=${db_host}
EOT

# بررسی سیستم‌عامل و نصب وابستگی‌ها
echo "Checking operating system and installing dependencies..."
if [ -x "$(command -v apt)" ]; then
    echo "Ubuntu detected. Installing dependencies..."

    # حذف کتابخانه‌های قدیمی و نسخه‌های قدیمی Node.js
    echo "Removing any previous Node.js and npm installations..."
    apt-get remove --purge -y nodejs npm libnode72 || true
    apt-get autoremove -y

    # به‌روزرسانی مخازن و نصب پیش‌نیازها
    echo "Updating repositories and installing prerequisites..."
    apt update
    apt install -y python3 python3-pip mariadb-client libmariadb-dev curl ca-certificates gnupg apt-transport-https software-properties-common

    # اضافه کردن مخزن Node.js و نصب نسخه 18
    echo "Installing Node.js version 18..."
    curl -fsSL https://deb.nodesource.com/setup_18.x | bash -
    apt install -y nodejs || { echo "Error installing Node.js."; exit 1; }

    # بررسی نصب npm
    if ! [ -x "$(command -v npm)" ]; then
        echo "npm not found, installing..."
        apt install -y npm || { echo "Error installing npm."; exit 1; }
    fi

    # نصب PM2
    echo "Installing PM2..."
    npm install pm2@latest -g || { echo "Error installing PM2."; exit 1; }

elif [ -x "$(command -v yum)" ]; then
    echo "RHEL/CentOS detected. Installing dependencies..."
    yum install -y python3 python3-pip mariadb curl

    # نصب Node.js نسخه 18
    curl -sL https://rpm.nodesource.com/setup_18.x | bash -
    yum install -y nodejs || { echo "Error installing Node.js."; exit 1; }
else
    echo "Unsupported OS. Please install dependencies manually."
    exit 1
fi

# به‌روز رسانی pip و نصب کتابخانه‌های پایتون
pip3 install --upgrade pip
echo "Installing Python libraries..."
pip3 install -r requirements.txt || { echo "Error installing Python libraries."; exit 1; }

# اجرای ربات با PM2
echo "Running the bot with PM2..."
pm2 start telegram_bot.py --interpreter python3 --name telegram-backup-bot || { echo "Error starting the bot with PM2."; exit 1; }

# ذخیره فرآیند PM2 برای اجرا در زمان بوت
pm2 save
pm2 startup || { echo "Error setting up PM2 to run on startup."; exit 1; }

echo "The bot has been successfully started and added to PM2."
echo "Use 'pm2 logs telegram-backup-bot' to see the bot logs."
echo "To stop the bot, use: pm2 stop telegram-backup-bot"
