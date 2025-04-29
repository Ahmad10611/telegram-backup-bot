# -*- coding: utf-8 -*-

import logging
import mysql.connector
import subprocess
import telegram
from telegram import Update, InlineKeyboardButton, InlineKeyboardMarkup
from telegram.ext import Application, CommandHandler, CallbackQueryHandler, MessageHandler, filters, ContextTypes
import os
from datetime import datetime
import zipfile
from apscheduler.schedulers.asyncio import AsyncIOScheduler
from apscheduler.triggers.interval import IntervalTrigger
import jdatetime
import configparser

# خواندن فایل پیکربندی
config = configparser.ConfigParser()
config.read('config.cfg')

try:
    TELEGRAM_TOKEN = config['DEFAULT']['BOT_TOKEN']
    AUTHORIZED_USER_ID = int(config['DEFAULT']['AUTHORIZED_USER_ID'])
    db_config = {
        'host': config['DEFAULT']['DB_HOST'],
        'user': config['DEFAULT']['DB_USER'],
        'password': config['DEFAULT']['DB_PASSWORD'],
        'database': config['DEFAULT']['DB_NAME']
    }
except KeyError as e:
    print(f"Error: Key {e} not found in config.cfg")
    exit(1)

# تنظیمات لاگ
log_dir = "/root/backups/logs"
os.makedirs(log_dir, mode=0o700, exist_ok=True)
log_file = f"{log_dir}/backup_log_{datetime.now().strftime('%Y%m%d_%H%M%S')}.log"

logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler(log_file),
        logging.StreamHandler()
    ]
)

# شیء زمانبند
scheduler = AsyncIOScheduler()

# بررسی کاربر مجاز
def is_authorized(update: Update) -> bool:
    user_id = update.message.chat_id
    if user_id == AUTHORIZED_USER_ID:
        logging.info(f"کاربر مجاز: {user_id}")
        return True
    else:
        logging.warning(f"دسترسی غیرمجاز از طرف کاربر: {user_id}")
        return False

# تهیه پشتیبان دیتابیس
def backup_database():
    try:
        backup_dir = "/root/backups"
        os.makedirs(backup_dir, mode=0o700, exist_ok=True)

        backup_file = f"{backup_dir}/backup.sql"
        zip_file = f"{backup_dir}/backup.zip"
        temp_cnf = f"{backup_dir}/my.cnf"

        with open(temp_cnf, 'w') as f:
            f.write(f"[client]\nuser={db_config['user']}\npassword={db_config['password']}\nhost={db_config['host']}\n")
        os.chmod(temp_cnf, 0o600)

        command = f"mysqldump --defaults-extra-file={temp_cnf} {db_config['database']} > {backup_file}"
        subprocess.run(command, shell=True, check=True)

        with zipfile.ZipFile(zip_file, 'w', zipfile.ZIP_DEFLATED) as zf:
            zf.write(backup_file, arcname=os.path.basename(backup_file))

        os.remove(temp_cnf)
        logging.info("پشتیبان‌گیری با موفقیت انجام شد.")
        return zip_file

    except Exception as e:
        logging.error(f"خطا در پشتیبان‌گیری: {e}")
        return None

# ارسال فایل پشتیبان
async def send_backup(context: ContextTypes.DEFAULT_TYPE):
    chat_id = AUTHORIZED_USER_ID
    backup_file = backup_database()
    if backup_file:
        await context.bot.send_document(chat_id=chat_id, document=open(backup_file, 'rb'))
        logging.info(f"فایل پشتیبان به کاربر {chat_id} ارسال شد.")
    else:
        await context.bot.send_message(chat_id=chat_id, text="❌ خطا در تهیه پشتیبان!")

# هندلر استارت
async def start(update: Update, context: ContextTypes.DEFAULT_TYPE):
    if is_authorized(update):
        keyboard = [
            [InlineKeyboardButton("پشتیبان گیری فوری", callback_data='backup')],
            [InlineKeyboardButton("تنظیم زمانبندی", callback_data='schedule')]
        ]
        reply_markup = InlineKeyboardMarkup(keyboard)
        await update.message.reply_text('لطفا یک گزینه انتخاب کنید:', reply_markup=reply_markup)
    else:
        await update.message.reply_text('شما مجاز به استفاده از این ربات نیستید.')

# هندلر دکمه‌ها
async def button(update: Update, context: ContextTypes.DEFAULT_TYPE):
    query = update.callback_query
    await query.answer()
    if query.data == 'backup':
        await send_backup(context)
    elif query.data == 'schedule':
        await query.message.reply_text('تعداد دقایق بین هر پشتیبان‌گیری را وارد کنید:')

# هندلر پیام برای تعیین زمانبندی
async def handle_message(update: Update, context: ContextTypes.DEFAULT_TYPE):
    if is_authorized(update):
        try:
            minutes = int(update.message.text)
            if minutes > 0:
                scheduler.remove_all_jobs()
                scheduler.add_job(send_backup, IntervalTrigger(minutes=minutes), args=(context,), id='send_backup')
                await update.message.reply_text(f"پشتیبان‌گیری هر {minutes} دقیقه تنظیم شد.")
            else:
                await update.message.reply_text("لطفاً یک عدد معتبر وارد کنید.")
        except ValueError:
            await update.message.reply_text("ورودی نامعتبر است. لطفاً یک عدد وارد کنید.")

# تابع اصلی
def main():
    application = Application.builder().token(TELEGRAM_TOKEN).build()

    application.add_handler(CommandHandler("start", start))
    application.add_handler(CallbackQueryHandler(button))
    application.add_handler(MessageHandler(filters.TEXT & ~filters.COMMAND, handle_message))

    scheduler.start()

    logging.info("ربات آماده اجراست.")
    application.run_polling()

if __name__ == '__main__':
    main()
