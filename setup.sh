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

# تابع بررسی نصب شدن یک دستور
check_command() {
    if ! command -v $1 &> /dev/null
    then
        echo "$1 could not be found, attempting to install..."
        return 1
    else
        return 0
    fi
}

# نصب بسته‌ها و رفع خودکار خطاها
install_dependencies() {
    echo "Checking and installing dependencies..."

    # شناسایی سیستم‌عامل
    if [ -x "$(command -v apt)" ]; then
        echo "Debian/Ubuntu detected."
        apt update

        # نصب بسته‌های مورد نیاز
        apt install -y python3 python3-pip mariadb-client libmariadb-dev curl

        # نصب Node.js 18
        curl -sL https://deb.nodesource.com/setup_18.x | bash -
        apt install -y nodejs

    elif [ -x "$(command -v yum)" ]; then
        echo "RHEL/CentOS detected."
        yum install -y python3 python3-pip mariadb curl

        # نصب Node.js 18
        curl -sL https://rpm.nodesource.com/setup_18.x | bash -
        yum install -y nodejs

        # بررسی Python 3.8 و نصب در صورت نبودن
        check_command python3.8
        if [ $? -ne 0 ]; then
            echo "Python 3.8 not found, installing..."
            yum install -y centos-release-scl
            yum install -y rh-python38
            source /opt/rh/rh-python38/enable
        fi

    else
        echo "Unsupported OS. Please install dependencies manually."
        exit 1
    fi
}

# نصب کتابخانه‌های پایتون و رفع مشکلات احتمالی
install_python_libraries() {
    echo "Installing Python libraries..."
    if ! pip3 install -r requirements.txt; then
        echo "Error installing Python libraries. Attempting to resolve..."
        pip3 install --upgrade pip
        pip3 install -r requirements.txt
    fi
}

# نصب و تنظیم PM2
install_pm2() {
    echo "Installing PM2..."
    if ! npm install pm2@latest -g; then
        echo "PM2 installation failed. Retrying..."
        npm cache clean -f
        npm install -g n
        npm install pm2@latest -g
    fi
}

# اجرای ربات با PM2
run_bot_with_pm2() {
    echo "Running the bot with PM2..."
    pm2 start telegram_bot.py --name telegram-backup-bot

    # ذخیره فرآیند PM2 در سیستم‌عامل
    pm2 save
    pm2 startup
}

# اجرای کلیه توابع
install_dependencies
install_python_libraries
install_pm2
run_bot_with_pm2

echo "The bot has been successfully started and added to PM2."
echo "Use 'pm2 logs telegram-backup-bot' to see the bot logs."
echo "To stop the bot, use: pm2 stop telegram-backup-bot"