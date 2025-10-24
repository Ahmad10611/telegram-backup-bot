# main.py
import logging
import subprocess
import os
from datetime import datetime
import zipfile
import configparser
import sys

# بررسی ورژن Python
if sys.version_info < (3, 7):
    print("Python 3.7+ مورد نیاز است")
    sys.exit(1)

try:
    from telegram import Update, InlineKeyboardButton, InlineKeyboardMarkup
    from telegram.ext import Application, CommandHandler, CallbackQueryHandler, MessageHandler, filters, ContextTypes
    from apscheduler.schedulers.asyncio import AsyncIOScheduler
    from apscheduler.triggers.interval import IntervalTrigger
except ImportError:
    print("نصب dependencies با: pip install -r requirements.txt")
    sys.exit(1)

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
    print(f"خطا: کلید {e} در config.cfg یافت نشد")
    sys.exit(1)

log_dir = "/root/backups/logs"
os.makedirs(log_dir, mode=0o700, exist_ok=True)
log_file = f"{log_dir}/backup_{datetime.now().strftime('%Y%m%d_%H%M%S')}.log"

logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler(log_file, encoding='utf-8'),
        logging.StreamHandler()
    ]
)

scheduler = AsyncIOScheduler()

def is_authorized(update: Update) -> bool:
    user_id = update.message.chat_id if update.message else update.callback_query.message.chat_id
    return user_id == AUTHORIZED_USER_ID

def backup_database():
    try:
        backup_dir = "/root/backups"
        os.makedirs(backup_dir, mode=0o700, exist_ok=True)
        
        timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
        backup_file = f"{backup_dir}/backup_{timestamp}.sql"
        zip_file = f"{backup_dir}/backup_{timestamp}.zip"
        temp_cnf = f"{backup_dir}/.my.cnf"

        with open(temp_cnf, 'w') as f:
            f.write(f"[client]\nuser={db_config['user']}\npassword={db_config['password']}\nhost={db_config['host']}\n")
        os.chmod(temp_cnf, 0o600)

        cmd = f"mysqldump --defaults-extra-file={temp_cnf} {db_config['database']} > {backup_file}"
        result = subprocess.run(cmd, shell=True, capture_output=True, text=True)
        
        if result.returncode != 0:
            logging.error(f"خطای mysqldump: {result.stderr}")
            os.remove(temp_cnf)
            return None

        with zipfile.ZipFile(zip_file, 'w', zipfile.ZIP_DEFLATED) as zf:
            zf.write(backup_file, arcname=os.path.basename(backup_file))

        os.remove(temp_cnf)
        os.remove(backup_file)
        logging.info(f"پشتیبان: {zip_file}")
        return zip_file

    except Exception as e:
        logging.error(f"خطا: {e}")
        return None

async def send_backup(context: ContextTypes.DEFAULT_TYPE):
    backup_file = backup_database()
    if backup_file:
        with open(backup_file, 'rb') as f:
            await context.bot.send_document(chat_id=AUTHORIZED_USER_ID, document=f)
        logging.info("فایل ارسال شد")
    else:
        await context.bot.send_message(chat_id=AUTHORIZED_USER_ID, text="❌ خطا در پشتیبان")

async def start(update: Update, context: ContextTypes.DEFAULT_TYPE):
    if not is_authorized(update):
        await update.message.reply_text('دسترسی غیرمجاز')
        return
    
    keyboard = [
        [InlineKeyboardButton("پشتیبان فوری", callback_data='backup')],
        [InlineKeyboardButton("زمانبندی", callback_data='schedule')],
        [InlineKeyboardButton("وضعیت", callback_data='status')]
    ]
    await update.message.reply_text('گزینه:', reply_markup=InlineKeyboardMarkup(keyboard))

async def button(update: Update, context: ContextTypes.DEFAULT_TYPE):
    query = update.callback_query
    await query.answer()
    
    if not is_authorized(update):
        await query.message.reply_text('دسترسی غیرمجاز')
        return
    
    if query.data == 'backup':
        await query.message.reply_text('در حال پشتیبان...')
        await send_backup(context)
    elif query.data == 'schedule':
        await query.message.reply_text('تعداد دقایق:')
    elif query.data == 'status':
        jobs = scheduler.get_jobs()
        if jobs:
            await query.message.reply_text(f'زمانبندی فعال: هر {jobs[0].trigger.interval.total_seconds()/60:.0f} دقیقه')
        else:
            await query.message.reply_text('زمانبندی غیرفعال')

async def handle_message(update: Update, context: ContextTypes.DEFAULT_TYPE):
    if not is_authorized(update):
        return
    
    try:
        minutes = int(update.message.text)
        if minutes > 0:
            scheduler.remove_all_jobs()
            scheduler.add_job(send_backup, IntervalTrigger(minutes=minutes), args=(context,), id='backup_job')
            await update.message.reply_text(f"✅ زمانبندی: هر {minutes} دقیقه")
        else:
            await update.message.reply_text("عدد مثبت وارد کنید")
    except ValueError:
        await update.message.reply_text("عدد وارد کنید")

def main():
    application = Application.builder().token(TELEGRAM_TOKEN).build()
    
    application.add_handler(CommandHandler("start", start))
    application.add_handler(CallbackQueryHandler(button))
    application.add_handler(MessageHandler(filters.TEXT & ~filters.COMMAND, handle_message))
    
    scheduler.start()
    logging.info("ربات شروع شد")
    application.run_polling(allowed_updates=Update.ALL_TYPES)

if __name__ == '__main__':
    main()
