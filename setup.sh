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

# نصب وابستگی‌ها بر اساس سیستم عامل
echo "Installing dependencies..."
if [ -x "$(command -v apt)" ]; then
    echo "Debian/Ubuntu detected. Installing dependencies..."
    apt update
    apt install -y python3 python3-pip mariadb-client libmariadb-dev curl

    # نصب Node.js نسخه 16 یا بالاتر
    curl -sL https://deb.nodesource.com/setup_16.x | bash -
    apt install -y nodejs
elif [ -x "$(command -v yum)" ]; then
    echo "RHEL/CentOS detected. Installing dependencies..."
    yum install -y python3 python3-pip mariadb curl

    # نصب Node.js نسخه 16 یا بالاتر
    curl -sL https://rpm.nodesource.com/setup_16.x | bash -
    yum install -y nodejs
else
    echo "Unsupported OS. Please install dependencies manually."
    exit 1
fi

# بررسی نصب پایتون 3.8
if ! command -v python3.8 &> /dev/null
then
    echo "Python 3.8 not found, installing..."
    if [ -x "$(command -v apt)" ]; then
        apt install -y python3.8
    elif [ -x "$(command -v yum)" ]; then
        yum install -y python38
    fi
fi

# نصب کتابخانه‌های پایتون
echo "Installing Python libraries..."
pip3 install mysql-connector-python==8.0.33
pip3 install apscheduler==3.10.4 python-telegram-bot==21.6 pytz==2024.2 jdatetime==3.7.0 tzlocal==5.2

# نصب و تنظیم PM2
echo "Installing PM2..."
npm install pm2@latest -g

# اجرای ربات با PM2 با مسیر صحیح پایتون 3.8
echo "Running the bot with PM2..."
pm2 start telegram_bot.py --interpreter $(which python3.8) --name telegram-backup-bot

# ذخیره فرآیند PM2 در سیستم‌عامل
pm2 save
pm2 startup

echo "The bot has been successfully started and added to PM2."
echo "Use 'pm2 logs telegram-backup-bot' to see the bot logs."

# دستور غیرفعال کردن ربات
echo "To stop the bot, use: pm2 stop telegram-backup-bot"