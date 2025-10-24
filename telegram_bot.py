# main.py
#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import logging
import subprocess
import os
import sys
from datetime import datetime
import zipfile
import configparser
from pathlib import Path

# بررسی ورژن Python
if sys.version_info < (3, 7):
    print("❌ Python 3.7 یا بالاتر مورد نیاز است")
    print(f"ورژن فعلی شما: {sys.version}")
    sys.exit(1)

try:
    from telegram import Update, InlineKeyboardButton, InlineKeyboardMarkup
    from telegram.ext import Application, CommandHandler, CallbackQueryHandler, MessageHandler, filters, ContextTypes
    from apscheduler.schedulers.asyncio import AsyncIOScheduler
    from apscheduler.triggers.interval import IntervalTrigger
except ImportError as e:
    print(f"❌ خطا در import کتابخانه‌ها: {e}")
    print("لطفاً ابتدا dependencies را نصب کنید:")
    print("pip install -r requirements.txt")
    sys.exit(1)

# خواندن تنظیمات
CONFIG_FILE = 'config.cfg'
if not os.path.exists(CONFIG_FILE):
    print(f"❌ فایل {CONFIG_FILE} یافت نشد!")
    print("لطفاً ابتدا setup.sh را اجرا کنید")
    sys.exit(1)

config = configparser.ConfigParser()
config.read(CONFIG_FILE, encoding='utf-8')

try:
    TELEGRAM_TOKEN = config['DEFAULT']['BOT_TOKEN']
    AUTHORIZED_USER_ID = int(config['DEFAULT']['AUTHORIZED_USER_ID'])
    BACKUP_DIR = config['DEFAULT'].get('BACKUP_DIR', '/root/backups')
    
    db_config = {
        'host': config['DEFAULT']['DB_HOST'],
        'user': config['DEFAULT']['DB_USER'],
        'password': config['DEFAULT']['DB_PASSWORD'],
        'database': config['DEFAULT']['DB_NAME']
    }
except KeyError as e:
    print(f"❌ خطا: کلید {e} در {CONFIG_FILE} یافت نشد")
    sys.exit(1)
except ValueError as e:
    print(f"❌ خطا در خواندن AUTHORIZED_USER_ID: {e}")
    sys.exit(1)

# تنظیمات لاگ
log_dir = Path(BACKUP_DIR) / "logs"
log_dir.mkdir(parents=True, mode=0o700, exist_ok=True)
log_file = log_dir / f"bot_{datetime.now().strftime('%Y%m%d_%H%M%S')}.log"

logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler(log_file, encoding='utf-8'),
        logging.StreamHandler(sys.stdout)
    ]
)

logger = logging.getLogger(__name__)

# شیء زمانبند
scheduler = AsyncIOScheduler()

def is_authorized(update: Update) -> bool:
    """بررسی مجوز کاربر"""
    try:
        if update.message:
            user_id = update.message.chat_id
        elif update.callback_query:
            user_id = update.callback_query.message.chat_id
        else:
            return False
        
        authorized = user_id == AUTHORIZED_USER_ID
        if not authorized:
            logger.warning(f"تلاش دسترسی غیرمجاز از کاربر: {user_id}")
        return authorized
    except Exception as e:
        logger.error(f"خطا در بررسی مجوز: {e}")
        return False

def find_mysqldump():
    """پیدا کردن مسیر mysqldump"""
    paths = [
        'mysqldump',
        '/usr/bin/mysqldump',
        '/usr/local/bin/mysqldump',
        '/usr/local/mysql/bin/mysqldump',
        '/opt/mysql/bin/mysqldump',
        'C:\\Program Files\\MySQL\\MySQL Server 8.0\\bin\\mysqldump.exe',
        'C:\\xampp\\mysql\\bin\\mysqldump.exe'
    ]
    
    for path in paths:
        try:
            result = subprocess.run([path, '--version'], 
                                  capture_output=True, 
                                  text=True, 
                                  timeout=5)
            if result.returncode == 0:
                logger.info(f"mysqldump یافت شد: {path}")
                return path
        except (FileNotFoundError, subprocess.TimeoutExpired):
            continue
    
    return None

def backup_database():
    """تهیه پشتیبان از دیتابیس"""
    try:
        backup_path = Path(BACKUP_DIR)
        backup_path.mkdir(parents=True, mode=0o700, exist_ok=True)
        
        timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
        backup_file = backup_path / f"backup_{timestamp}.sql"
        zip_file = backup_path / f"backup_{timestamp}.zip"
        temp_cnf = backup_path / ".my.cnf.tmp"
        
        # ایجاد فایل موقت تنظیمات MySQL
        with open(temp_cnf, 'w', encoding='utf-8') as f:
            f.write("[client]\n")
            f.write(f"user={db_config['user']}\n")
            f.write(f"password={db_config['password']}\n")
            f.write(f"host={db_config['host']}\n")
        
        os.chmod(temp_cnf, 0o600)
        
        # یافتن mysqldump
        mysqldump_cmd = find_mysqldump()
        if not mysqldump_cmd:
            logger.error("mysqldump یافت نشد!")
            return None
        
        # اجرای mysqldump
        cmd = [
            mysqldump_cmd,
            f"--defaults-extra-file={temp_cnf}",
            "--single-transaction",
            "--quick",
            "--lock-tables=false",
            db_config['database']
        ]
        
        logger.info(f"شروع backup از دیتابیس: {db_config['database']}")
        
        with open(backup_file, 'w', encoding='utf-8') as f:
            result = subprocess.run(cmd, 
                                  stdout=f, 
                                  stderr=subprocess.PIPE, 
                                  text=True,
                                  timeout=300)
        
        if result.returncode != 0:
            logger.error(f"خطای mysqldump: {result.stderr}")
            temp_cnf.unlink(missing_ok=True)
            backup_file.unlink(missing_ok=True)
            return None
        
        # فشرده‌سازی
        logger.info("فشرده‌سازی فایل backup...")
        with zipfile.ZipFile(zip_file, 'w', zipfile.ZIP_DEFLATED) as zf:
            zf.write(backup_file, arcname=backup_file.name)
        
        # پاک‌سازی
        temp_cnf.unlink(missing_ok=True)
        backup_file.unlink(missing_ok=True)
        
        file_size = zip_file.stat().st_size / (1024 * 1024)
        logger.info(f"✅ backup موفق: {zip_file.name} ({file_size:.2f} MB)")
        
        return str(zip_file)
        
    except subprocess.TimeoutExpired:
        logger.error("mysqldump timeout شد!")
        return None
    except Exception as e:
        logger.error(f"خطا در backup: {e}", exc_info=True)
        return None

async def send_backup(context: ContextTypes.DEFAULT_TYPE, chat_id: int = None):
    """ارسال فایل پشتیبان"""
    target_chat_id = chat_id or AUTHORIZED_USER_ID
    
    try:
        backup_file = backup_database()
        
        if backup_file and os.path.exists(backup_file):
            file_size = os.path.getsize(backup_file) / (1024 * 1024)
            
            with open(backup_file, 'rb') as f:
                await context.bot.send_document(
                    chat_id=target_chat_id,
                    document=f,
                    caption=f"📦 پشتیبان دیتابیس\n"
                            f"🗓 {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}\n"
                            f"💾 حجم: {file_size:.2f} MB",
                    filename=os.path.basename(backup_file)
                )
            
            logger.info(f"فایل backup به {target_chat_id} ارسال شد")
        else:
            await context.bot.send_message(
                chat_id=target_chat_id,
                text="❌ خطا در تهیه پشتیبان!\nلطفاً لاگ‌ها را بررسی کنید."
            )
            logger.error("فایل backup ایجاد نشد")
            
    except Exception as e:
        logger.error(f"خطا در ارسال backup: {e}", exc_info=True)
        try:
            await context.bot.send_message(
                chat_id=target_chat_id,
                text=f"❌ خطا در ارسال: {str(e)}"
            )
        except:
            pass

async def start(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """هندلر دستور /start"""
    if not is_authorized(update):
        await update.message.reply_text('⛔️ شما مجاز به استفاده از این ربات نیستید.')
        return
    
    keyboard = [
        [InlineKeyboardButton("📦 پشتیبان فوری", callback_data='backup')],
        [InlineKeyboardButton("⏰ تنظیم زمانبندی", callback_data='schedule')],
        [InlineKeyboardButton("📊 وضعیت", callback_data='status')],
        [InlineKeyboardButton("🗑 حذف زمانبندی", callback_data='clear')]
    ]
    reply_markup = InlineKeyboardMarkup(keyboard)
    
    welcome_text = (
        "👋 خوش آمدید به ربات پشتیبان‌گیری\n\n"
        "🔹 پشتیبان فوری: دریافت آنی backup\n"
        "🔹 زمانبندی: backup خودکار دوره‌ای\n"
        "🔹 وضعیت: مشاهده تنظیمات فعلی\n"
        "🔹 حذف زمانبندی: غیرفعال کردن backup خودکار"
    )
    
    await update.message.reply_text(welcome_text, reply_markup=reply_markup)
    logger.info(f"کاربر {update.message.chat_id} ربات را استارت کرد")

async def button(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """هندلر دکمه‌های inline"""
    query = update.callback_query
    await query.answer()
    
    if not is_authorized(update):
        await query.message.reply_text('⛔️ دسترسی غیرمجاز')
        return
    
    if query.data == 'backup':
        await query.message.reply_text('⏳ در حال تهیه پشتیبان...')
        await send_backup(context, query.message.chat_id)
        
    elif query.data == 'schedule':
        await query.message.reply_text(
            '⏰ تنظیم زمانبندی\n\n'
            'تعداد دقایق بین هر پشتیبان‌گیری را وارد کنید:\n'
            '(مثال: 60 برای هر ساعت، 1440 برای روزانه)'
        )
        context.user_data['waiting_for_schedule'] = True
        
    elif query.data == 'status':
        jobs = scheduler.get_jobs()
        if jobs:
            job = jobs[0]
            interval = job.trigger.interval.total_seconds() / 60
            next_run = job.next_run_time.strftime('%Y-%m-%d %H:%M:%S') if job.next_run_time else 'نامشخص'
            
            status_text = (
                f"📊 وضعیت سیستم\n\n"
                f"✅ زمانبندی: فعال\n"
                f"⏱ هر {interval:.0f} دقیقه\n"
                f"🕐 اجرای بعدی: {next_run}‌\n"
                f"💾 مسیر ذخیره: {BACKUP_DIR}"
            )
        else:
            status_text = (
                "📊 وضعیت سیستم\n\n"
                "❌ زمانبندی: غیرفعال\n"
                f"💾 مسیر ذخیره: {BACKUP_DIR}"
            )
        
        await query.message.reply_text(status_text)
        
    elif query.data == 'clear':
        jobs = scheduler.get_jobs()
        if jobs:
            scheduler.remove_all_jobs()
            await query.message.reply_text('✅ زمانبندی حذف شد')
            logger.info("زمانبندی حذف شد")
        else:
            await query.message.reply_text('ℹ️ هیچ زمانبندی فعالی وجود ندارد')

async def handle_message(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """هندلر پیام‌های متنی"""
    if not is_authorized(update):
        return
    
    if context.user_data.get('waiting_for_schedule'):
        try:
            minutes = int(update.message.text.strip())
            
            if minutes <= 0:
                await update.message.reply_text('❌ لطفاً یک عدد مثبت وارد کنید')
                return
            
            if minutes < 5:
                await update.message.reply_text('⚠️ حداقل فاصله: 5 دقیقه')
                return
            
            # حذف job قبلی
            scheduler.remove_all_jobs()
            
            # اضافه کردن job جدید
            scheduler.add_job(
                send_backup,
                IntervalTrigger(minutes=minutes),
                args=(context,),
                id='backup_job',
                replace_existing=True
            )
            
            next_run = scheduler.get_jobs()[0].next_run_time.strftime('%Y-%m-%d %H:%M:%S')
            
            await update.message.reply_text(
                f"✅ زمانبندی تنظیم شد\n\n"
                f"⏱ هر {minutes} دقیقه\n"
                f"🕐 اجرای بعدی: {next_run}"
            )
            
            logger.info(f"زمانبندی تنظیم شد: هر {minutes} دقیقه")
            context.user_data['waiting_for_schedule'] = False
            
        except ValueError:
            await update.message.reply_text('❌ لطفاً یک عدد معتبر وارد کنید')
    else:
        await update.message.reply_text(
            'ℹ️ از دستور /start برای شروع استفاده کنید'
        )

async def error_handler(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """هندلر خطاها"""
    logger.error(f"خطا در به‌روزرسانی: {context.error}", exc_info=context.error)
    
    if update and update.effective_message:
        try:
            await update.effective_message.reply_text(
                '❌ خطایی رخ داد. لطفاً دوباره تلاش کنید.'
            )
        except:
            pass

def main():
    """تابع اصلی"""
    try:
        logger.info("=" * 50)
        logger.info("شروع ربات پشتیبان‌گیری تلگرام")
        logger.info(f"Python: {sys.version}")
        logger.info(f"مسیر backup: {BACKUP_DIR}")
        logger.info("=" * 50)
        
        # ساخت Application
        application = Application.builder().token(TELEGRAM_TOKEN).build()
        
        # اضافه کردن هندلرها
        application.add_handler(CommandHandler("start", start))
        application.add_handler(CallbackQueryHandler(button))
        application.add_handler(MessageHandler(filters.TEXT & ~filters.COMMAND, handle_message))
        application.add_error_handler(error_handler)
        
        # شروع زمانبند
        scheduler.start()
        logger.info("✅ زمانبند شروع شد")
        
        # شروع ربات
        logger.info("✅ ربات آماده است")
        application.run_polling(
            allowed_updates=Update.ALL_TYPES,
            drop_pending_updates=True
        )
        
    except KeyboardInterrupt:
        logger.info("توقف ربات توسط کاربر")
    except Exception as e:
        logger.error(f"خطای critical: {e}", exc_info=True)
        sys.exit(1)
    finally:
        if scheduler.running:
            scheduler.shutdown()
        logger.info("ربات متوقف شد")

if __name__ == '__main__':
    main()
