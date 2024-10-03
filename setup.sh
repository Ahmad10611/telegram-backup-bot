#!/bin/bash

# تابع نصب بسته‌های مورد نیاز برای توزیع‌های مختلف
install_dependencies() {
    if [ -f /etc/debian_version ]; then
        echo "Debian/Ubuntu detected. Installing dependencies..."
        sudo apt update
        sudo apt install -y python3 python3-pip mysql-client libmysqlclient-dev
    elif [ -f /etc/redhat-release ]; then
        echo "CentOS/RHEL detected. Installing dependencies..."
        sudo yum install -y python3 python3-pip mariadb mariadb-devel
    elif [ -f /etc/arch-release ]; then
        echo "Arch Linux detected. Installing dependencies..."
        sudo pacman -Syu --noconfirm python3 python-pip mariadb
    else
        echo "Unsupported Linux distribution. Please install dependencies manually."
        exit 1
    fi
}

# استعلام اطلاعات از کاربر
echo "Please enter your Telegram bot token:"
read telegram_token

echo "Please enter the authorized user ID:"
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
TELEGRAM_TOKEN=${telegram_token}
AUTHORIZED_USER_ID=${authorized_user_id}
DB_USER=${db_user}
DB_PASSWORD=${db_password}
DB_NAME=${db_name}
DB_HOST=${db_host}
EOT

# نصب وابستگی‌ها
echo "Installing dependencies..."
install_dependencies

# نصب کتابخانه‌های Python از فایل requirements.txt
echo "Installing Python libraries..."
pip3 install -r requirements.txt

# اجرای ربات
echo "Running the bot..."
python3 telegram_bot.py
