#!/bin/bash

# استعلام اطلاعات از کاربر
echo "لطفاً توکن ربات تلگرام خود را وارد کنید:"
read telegram_token

echo "لطفاً آیدی عددی کاربر مجاز را وارد کنید:"
read authorized_user_id

echo "لطفاً نام کاربری MySQL را وارد کنید:"
read db_user

echo "لطفاً رمز عبور MySQL را وارد کنید:"
read -s db_password

echo "لطفاً نام دیتابیس MySQL را وارد کنید:"
read db_name

echo "لطفاً هاست دیتابیس MySQL (مثلاً localhost) را وارد کنید:"
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
echo "در حال نصب وابستگی‌ها..."
pip3 install -r requirements.txt

# اجرای ربات
echo "ربات در حال اجرا است..."
python3 telegram_bot.py
