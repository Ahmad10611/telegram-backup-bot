# -*- coding: utf-8 -*-

import logging
import mysql.connector
import subprocess
import telegram
from telegram import Update, InlineKeyboardButton, InlineKeyboardMarkup
from telegram.ext import Application, CommandHandler, CallbackQueryHandler, MessageHandler, filters
import os
from datetime import datetime
import zipfile
from apscheduler.schedulers.asyncio import AsyncIOScheduler
from apscheduler.triggers.interval import IntervalTrigger
import jdatetime
import configparser

# خواندن فایل کانفیگ
config = configparser.ConfigParser()
config.read('config.cfg')

# گرفتن مقادیر از فایل config.cfg
TELEGRAM_TOKEN = config['DEFAULT']['TELEGRAM_TOKEN']
AUTHORIZED_USER_ID = int(config['DEFAULT']['AUTHORIZED_USER_ID'])  # باید به عدد تبدیل شود
db_config = {
    'host': config['DEFAULT']['DB_HOST'],
    'user': config['DEFAULT']['DB_USER'],
    'password': config['DEFAULT']['DB_PASSWORD'],
    'database': config['DEFAULT']['DB_NAME']
}

# تنظیمات لاگر
log_dir = "/root/backups/logs"
if not os.path.exists(log_dir):
    os.makedirs(log_dir, mode=0o700)

log_file = "{}/backup_log_{}.log".format(log_dir, datetime.now().strftime('%Y%m%d_%H%M%S'))

logging.basicConfig(
    filename=log_file,
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s',
    datefmt='%Y-%m-%d %H:%M:%S'
)

# ایجاد شیء Scheduler
scheduler = AsyncIOScheduler()

# تابع بررسی کاربر مجاز
def is_authorized(update: Update):
    user_id = update.message.chat_id
    authorized = user_id == AUTHORIZED_USER_ID
    if authorized:
        logging.info(f"کاربر مجاز: {user_id} در حال استفاده از ربات است.")
    else:
        logging.warning(f"دسترسی غیرمجاز از طرف کاربر: {user_id}.")
    return authorized

# تهیه و فشرده‌سازی فایل پشتیبان از دیتابیس
def backup_database():
    try:
        backup_dir = "/root/backups"
        if not os.path.exists(backup_dir):
            os.makedirs(backup_dir, mode=0o700)

        backup_file = f"{backup_dir}/backup.sql"
        command = f"mysqldump -h {db_config['host']} -u {db_config['user']} -p{db_config['password']} {db_config['database']} > {backup_file}"
        subprocess.run(command, shell=True, check=True)

        # فشرده‌سازی فایل پشتیبان
        zip_file = f"{backup_dir}/backup.zip"
        with zipfile.ZipFile(zip_file, 'w', zipfile.ZIP_DEFLATED) as zf:
            zf.write(backup_file, os.path.basename(backup_file))

        logging.info("پشتیبان‌گیری از دیتابیس و فشرده‌سازی با موفقیت انجام شد.")
        return zip_file
    except Exception as e:
        logging.error(f"خطا در پشتیبان‌گیری از دیتابیس: {e}")
        return None

# تابع ارسال پشتیبان دیتابیس
async def send_backup(context):
    chat_id = AUTHORIZED_USER_ID
    backup_file = backup_database()
    if backup_file:
        await context.bot.send_document(chat_id=chat_id, document=open(backup_file, 'rb'))
        logging.info(f"فایل پشتیبان به کاربر {chat_id} ارسال شد.")

# ایجاد دکمه برای ارسال پشتیبان و زمان‌بندی
async def start(update: Update, context):
    if is_authorized(update):
        keyboard = [
            [InlineKeyboardButton("پشتیبانی از دیتابیس", callback_data='backup')],
            [InlineKeyboardButton("زمان‌بندی خودکار", callback_data='schedule')]
        ]
        reply_markup = InlineKeyboardMarkup(keyboard)
        await update.message.reply_text('لطفاً یکی از دکمه‌ها را انتخاب کنید:', reply_markup=reply_markup)
        logging.info(f"دکمه‌ها برای کاربر {update.message.chat_id} نمایش داده شد.")
    else:
        await update.message.reply_text('شما اجازه دسترسی ندارید.')

async def button(update: Update, context):
    query = update.callback_query
    if query.data == 'backup':
        await send_backup(context)
        logging.info(f"کاربر {query.message.chat_id} دکمه پشتیبانی از دیتابیس را فشار داد.")
    elif query.data == 'schedule':
        await query.message.reply_text('لطفاً تعداد دقایقی که می‌خواهید بین پشتیبان‌گیری‌ها باشد را وارد کنید:')
        logging.info(f"کاربر {query.message.chat_id} دکمه زمان‌بندی خودکار را فشار داد.")

# تابع دریافت زمان‌بندی از کاربر
async def handle_message(update: Update, context):
    if is_authorized(update):
        try:
            interval_minutes = int(update.message.text)
            if interval_minutes > 0:
                scheduler.remove_all_jobs()  # حذف تمامی زمان‌بندی‌های قبلی
                scheduler.add_job(send_backup, trigger=IntervalTrigger(minutes=interval_minutes), args=(context,), id='send_backup')
                await update.message.reply_text(f"پشتیبان‌گیری خودکار هر {interval_minutes} دقیقه تنظیم شد.")
                logging.info(f"پشتیبان‌گیری خودکار هر {interval_minutes} دقیقه تنظیم شد.")
            else:
                await update.message.reply_text('لطفاً یک عدد معتبر وارد کنید.')
        except ValueError:
            await update.message.reply_text('لطفاً یک عدد معتبر وارد کنید.')
            logging.error("ورودی نامعتبر برای زمان‌بندی.")

def main():
    logging.info("ربات تلگرامی شروع به کار کرد.")
    
    application = Application.builder().token(TELEGRAM_TOKEN).build()
    
    application.add_handler(CommandHandler("start", start))
    application.add_handler(CallbackQueryHandler(button))
    application.add_handler(MessageHandler(filters.TEXT & ~filters.COMMAND, handle_message))

    # شروع زمان‌بندی
    scheduler.start()

    # اجرای ربات
    application.run_polling()

if __name__ == '__main__':
    main()