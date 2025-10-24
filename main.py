#!/usr/bin/env python3
# -*- coding: utf-8 -*-

"""
Telegram Backup Bot
Automatic MySQL/MariaDB backup with Telegram notification
Compatible with Python 3.6+
"""

import logging
import subprocess
import os
import sys
from datetime import datetime
import zipfile
import configparser
from pathlib import Path

# Check Python version
if sys.version_info < (3, 6):
    print("❌ Python 3.6 or higher is required")
    print(f"Current version: {sys.version}")
    sys.exit(1)

# Import telegram libraries with version detection
try:
    import telegram
    PTB_VERSION = int(telegram.__version__.split('.')[0])
    
    if PTB_VERSION >= 20:
        # python-telegram-bot 20.x (Python 3.8+)
        from telegram import Update, InlineKeyboardButton, InlineKeyboardMarkup
        from telegram.ext import Application, CommandHandler, CallbackQueryHandler, MessageHandler, filters, ContextTypes
        PTB_LEGACY = False
    else:
        # python-telegram-bot 13.x (Python 3.6+)
        from telegram import Update, InlineKeyboardButton, InlineKeyboardMarkup
        from telegram.ext import Updater, CommandHandler, CallbackQueryHandler, MessageHandler, Filters, CallbackContext
        PTB_LEGACY = True
        
except ImportError as e:
    print(f"❌ Import error: {e}")
    print("Please install dependencies: pip install -r requirements.txt")
    sys.exit(1)

try:
    from apscheduler.schedulers.asyncio import AsyncIOScheduler
    from apscheduler.schedulers.background import BackgroundScheduler
    from apscheduler.triggers.interval import IntervalTrigger
except ImportError as e:
    print(f"❌ APScheduler not found: {e}")
    sys.exit(1)

# Read configuration
CONFIG_FILE = 'config.cfg'
if not os.path.exists(CONFIG_FILE):
    print(f"❌ Configuration file '{CONFIG_FILE}' not found!")
    print("Please run setup.sh first or copy config.cfg.example to config.cfg")
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
    print(f"❌ Configuration error: Missing key {e}")
    print("Please check your config.cfg file")
    sys.exit(1)
except ValueError as e:
    print(f"❌ Configuration error: Invalid AUTHORIZED_USER_ID")
    sys.exit(1)

# Setup logging
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

# Initialize scheduler based on PTB version
if PTB_LEGACY:
    scheduler = BackgroundScheduler()
else:
    scheduler = AsyncIOScheduler()


def is_authorized(update: Update) -> bool:
    """Check if user is authorized"""
    try:
        if update.message:
            user_id = update.message.chat_id
        elif update.callback_query:
            user_id = update.callback_query.message.chat_id
        else:
            return False
        
        authorized = user_id == AUTHORIZED_USER_ID
        if not authorized:
            logger.warning(f"Unauthorized access attempt from user: {user_id}")
        return authorized
    except Exception as e:
        logger.error(f"Authorization check error: {e}")
        return False


def find_mysqldump():
    """Find mysqldump executable in common paths"""
    paths = [
        'mysqldump',
        '/usr/bin/mysqldump',
        '/usr/local/bin/mysqldump',
        '/usr/local/mysql/bin/mysqldump',
        '/opt/mysql/bin/mysqldump',
        '/www/server/mysql/bin/mysqldump',  # BaoTa Panel
        '/opt/lampp/bin/mysqldump',  # XAMPP
        'C:\\Program Files\\MySQL\\MySQL Server 8.0\\bin\\mysqldump.exe',
        'C:\\xampp\\mysql\\bin\\mysqldump.exe'
    ]
    
    for path in paths:
        try:
            result = subprocess.run(
                [path, '--version'],
                capture_output=True,
                text=True,
                timeout=5
            )
            if result.returncode == 0:
                logger.info(f"Found mysqldump: {path}")
                return path
        except (FileNotFoundError, subprocess.TimeoutExpired, OSError):
            continue
    
    logger.error("mysqldump not found in system")
    return None


def backup_database():
    """Create database backup"""
    try:
        backup_path = Path(BACKUP_DIR)
        backup_path.mkdir(parents=True, mode=0o700, exist_ok=True)
        
        timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
        backup_file = backup_path / f"backup_{timestamp}.sql"
        zip_file = backup_path / f"backup_{timestamp}.zip"
        temp_cnf = backup_path / ".my.cnf.tmp"
        
        # Create temporary MySQL config file
        with open(temp_cnf, 'w', encoding='utf-8') as f:
            f.write("[client]\n")
            f.write(f"user={db_config['user']}\n")
            f.write(f"password={db_config['password']}\n")
            f.write(f"host={db_config['host']}\n")
        
        os.chmod(temp_cnf, 0o600)
        
        # Find mysqldump
        mysqldump_cmd = find_mysqldump()
        if not mysqldump_cmd:
            logger.error("mysqldump not found")
            temp_cnf.unlink(missing_ok=True)
            return None
        
        # Execute mysqldump
        cmd = [
            mysqldump_cmd,
            f"--defaults-extra-file={temp_cnf}",
            "--single-transaction",
            "--quick",
            "--lock-tables=false",
            db_config['database']
        ]
        
        logger.info(f"Creating backup of database: {db_config['database']}")
        
        with open(backup_file, 'w', encoding='utf-8') as f:
            result = subprocess.run(
                cmd,
                stdout=f,
                stderr=subprocess.PIPE,
                text=True,
                timeout=600  # 10 minutes timeout
            )
        
        if result.returncode != 0:
            logger.error(f"mysqldump error: {result.stderr}")
            temp_cnf.unlink(missing_ok=True)
            backup_file.unlink(missing_ok=True)
            return None
        
        # Compress backup
        logger.info("Compressing backup file...")
        with zipfile.ZipFile(zip_file, 'w', zipfile.ZIP_DEFLATED) as zf:
            zf.write(backup_file, arcname=backup_file.name)
        
        # Cleanup
        temp_cnf.unlink(missing_ok=True)
        backup_file.unlink(missing_ok=True)
        
        file_size = zip_file.stat().st_size / (1024 * 1024)
        logger.info(f"✅ Backup successful: {zip_file.name} ({file_size:.2f} MB)")
        
        return str(zip_file)
        
    except subprocess.TimeoutExpired:
        logger.error("mysqldump timeout (>10 minutes)")
        return None
    except Exception as e:
        logger.error(f"Backup error: {e}", exc_info=True)
        return None


# Different implementations for legacy and modern PTB
if PTB_LEGACY:
    # Python 3.6+ with python-telegram-bot 13.x
    
    def send_backup(context: CallbackContext, chat_id: int = None):
        """Send backup file (Legacy version)"""
        target_chat_id = chat_id or AUTHORIZED_USER_ID
        
        try:
            backup_file = backup_database()
            
            if backup_file and os.path.exists(backup_file):
                file_size = os.path.getsize(backup_file) / (1024 * 1024)
                
                with open(backup_file, 'rb') as f:
                    context.bot.send_document(
                        chat_id=target_chat_id,
                        document=f,
                        caption=f"📦 Database Backup\n"
                                f"🗓 {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}\n"
                                f"💾 Size: {file_size:.2f} MB",
                        filename=os.path.basename(backup_file)
                    )
                
                logger.info(f"Backup sent to {target_chat_id}")
            else:
                context.bot.send_message(
                    chat_id=target_chat_id,
                    text="❌ Backup failed! Please check the logs."
                )
                logger.error("Backup file was not created")
                
        except Exception as e:
            logger.error(f"Error sending backup: {e}", exc_info=True)
            try:
                context.bot.send_message(
                    chat_id=target_chat_id,
                    text=f"❌ Error: {str(e)}"
                )
            except:
                pass
    
    def start(update: Update, context: CallbackContext):
        """Start command handler (Legacy)"""
        if not is_authorized(update):
            update.message.reply_text('⛔️ You are not authorized to use this bot.')
            return
        
        keyboard = [
            [InlineKeyboardButton("📦 Backup Now", callback_data='backup')],
            [InlineKeyboardButton("⏰ Schedule", callback_data='schedule')],
            [InlineKeyboardButton("📊 Status", callback_data='status')],
            [InlineKeyboardButton("🗑 Clear Schedule", callback_data='clear')]
        ]
        reply_markup = InlineKeyboardMarkup(keyboard)
        
        welcome_text = (
            "👋 Welcome to Telegram Backup Bot\n\n"
            "🔹 Backup Now: Get instant backup\n"
            "🔹 Schedule: Set automatic periodic backups\n"
            "🔹 Status: View current settings\n"
            "🔹 Clear Schedule: Disable automatic backups"
        )
        
        update.message.reply_text(welcome_text, reply_markup=reply_markup)
        logger.info(f"User {update.message.chat_id} started the bot")
    
    def button(update: Update, context: CallbackContext):
        """Button handler (Legacy)"""
        query = update.callback_query
        query.answer()
        
        if not is_authorized(update):
            query.message.reply_text('⛔️ Unauthorized access')
            return
        
        if query.data == 'backup':
            query.message.reply_text('⏳ Creating backup...')
            send_backup(context, query.message.chat_id)
            
        elif query.data == 'schedule':
            query.message.reply_text(
                '⏰ Schedule Setup\n\n'
                'Enter the number of minutes between each backup:\n'
                '(Example: 60 for hourly, 1440 for daily)'
            )
            context.user_data['waiting_for_schedule'] = True
            
        elif query.data == 'status':
            jobs = scheduler.get_jobs()
            if jobs:
                job = jobs[0]
                interval = job.trigger.interval.total_seconds() / 60
                next_run = job.next_run_time.strftime('%Y-%m-%d %H:%M:%S') if job.next_run_time else 'Unknown'
                
                status_text = (
                    f"📊 System Status\n\n"
                    f"✅ Schedule: Active\n"
                    f"⏱ Interval: Every {interval:.0f} minutes\n"
                    f"🕐 Next run: {next_run}\n"
                    f"💾 Backup path: {BACKUP_DIR}"
                )
            else:
                status_text = (
                    "📊 System Status\n\n"
                    "❌ Schedule: Inactive\n"
                    f"💾 Backup path: {BACKUP_DIR}"
                )
            
            query.message.reply_text(status_text)
            
        elif query.data == 'clear':
            jobs = scheduler.get_jobs()
            if jobs:
                scheduler.remove_all_jobs()
                query.message.reply_text('✅ Schedule cleared')
                logger.info("Schedule cleared")
            else:
                query.message.reply_text('ℹ️ No active schedule')
    
    def handle_message(update: Update, context: CallbackContext):
        """Message handler (Legacy)"""
        if not is_authorized(update):
            return
        
        if context.user_data.get('waiting_for_schedule'):
            try:
                minutes = int(update.message.text.strip())
                
                if minutes <= 0:
                    update.message.reply_text('❌ Please enter a positive number')
                    return
                
                if minutes < 5:
                    update.message.reply_text('⚠️ Minimum interval: 5 minutes')
                    return
                
                scheduler.remove_all_jobs()
                
                scheduler.add_job(
                    send_backup,
                    IntervalTrigger(minutes=minutes),
                    args=(context,),
                    id='backup_job',
                    replace_existing=True
                )
                
                next_run = scheduler.get_jobs()[0].next_run_time.strftime('%Y-%m-%d %H:%M:%S')
                
                update.message.reply_text(
                    f"✅ Schedule set successfully\n\n"
                    f"⏱ Interval: Every {minutes} minutes\n"
                    f"🕐 Next run: {next_run}"
                )
                
                logger.info(f"Schedule set: every {minutes} minutes")
                context.user_data['waiting_for_schedule'] = False
                
            except ValueError:
                update.message.reply_text('❌ Please enter a valid number')
        else:
            update.message.reply_text(
                'ℹ️ Use /start to begin'
            )

else:
    # Python 3.8+ with python-telegram-bot 20.x
    
    async def send_backup(context: ContextTypes.DEFAULT_TYPE, chat_id: int = None):
        """Send backup file (Modern version)"""
        target_chat_id = chat_id or AUTHORIZED_USER_ID
        
        try:
            backup_file = backup_database()
            
            if backup_file and os.path.exists(backup_file):
                file_size = os.path.getsize(backup_file) / (1024 * 1024)
                
                with open(backup_file, 'rb') as f:
                    await context.bot.send_document(
                        chat_id=target_chat_id,
                        document=f,
                        caption=f"📦 Database Backup\n"
                                f"🗓 {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}\n"
                                f"💾 Size: {file_size:.2f} MB",
                        filename=os.path.basename(backup_file)
                    )
                
                logger.info(f"Backup sent to {target_chat_id}")
            else:
                await context.bot.send_message(
                    chat_id=target_chat_id,
                    text="❌ Backup failed! Please check the logs."
                )
                logger.error("Backup file was not created")
                
        except Exception as e:
            logger.error(f"Error sending backup: {e}", exc_info=True)
            try:
                await context.bot.send_message(
                    chat_id=target_chat_id,
                    text=f"❌ Error: {str(e)}"
                )
            except:
                pass
    
    async def start(update: Update, context: ContextTypes.DEFAULT_TYPE):
        """Start command handler (Modern)"""
        if not is_authorized(update):
            await update.message.reply_text('⛔️ You are not authorized to use this bot.')
            return
        
        keyboard = [
            [InlineKeyboardButton("📦 Backup Now", callback_data='backup')],
            [InlineKeyboardButton("⏰ Schedule", callback_data='schedule')],
            [InlineKeyboardButton("📊 Status", callback_data='status')],
            [InlineKeyboardButton("🗑 Clear Schedule", callback_data='clear')]
        ]
        reply_markup = InlineKeyboardMarkup(keyboard)
        
        welcome_text = (
            "👋 Welcome to Telegram Backup Bot\n\n"
            "🔹 Backup Now: Get instant backup\n"
            "🔹 Schedule: Set automatic periodic backups\n"
            "🔹 Status: View current settings\n"
            "🔹 Clear Schedule: Disable automatic backups"
        )
        
        await update.message.reply_text(welcome_text, reply_markup=reply_markup)
        logger.info(f"User {update.message.chat_id} started the bot")
    
    async def button(update: Update, context: ContextTypes.DEFAULT_TYPE):
        """Button handler (Modern)"""
        query = update.callback_query
        await query.answer()
        
        if not is_authorized(update):
            await query.message.reply_text('⛔️ Unauthorized access')
            return
        
        if query.data == 'backup':
            await query.message.reply_text('⏳ Creating backup...')
            await send_backup(context, query.message.chat_id)
            
        elif query.data == 'schedule':
            await query.message.reply_text(
                '⏰ Schedule Setup\n\n'
                'Enter the number of minutes between each backup:\n'
                '(Example: 60 for hourly, 1440 for daily)'
            )
            context.user_data['waiting_for_schedule'] = True
            
        elif query.data == 'status':
            jobs = scheduler.get_jobs()
            if jobs:
                job = jobs[0]
                interval = job.trigger.interval.total_seconds() / 60
                next_run = job.next_run_time.strftime('%Y-%m-%d %H:%M:%S') if job.next_run_time else 'Unknown'
                
                status_text = (
                    f"📊 System Status\n\n"
                    f"✅ Schedule: Active\n"
                    f"⏱ Interval: Every {interval:.0f} minutes\n"
                    f"🕐 Next run: {next_run}\n"
                    f"💾 Backup path: {BACKUP_DIR}"
                )
            else:
                status_text = (
                    "📊 System Status\n\n"
                    "❌ Schedule: Inactive\n"
                    f"💾 Backup path: {BACKUP_DIR}"
                )
            
            await query.message.reply_text(status_text)
            
        elif query.data == 'clear':
            jobs = scheduler.get_jobs()
            if jobs:
                scheduler.remove_all_jobs()
                await query.message.reply_text('✅ Schedule cleared')
                logger.info("Schedule cleared")
            else:
                await query.message.reply_text('ℹ️ No active schedule')
    
    async def handle_message(update: Update, context: ContextTypes.DEFAULT_TYPE):
        """Message handler (Modern)"""
        if not is_authorized(update):
            return
        
        if context.user_data.get('waiting_for_schedule'):
            try:
                minutes = int(update.message.text.strip())
                
                if minutes <= 0:
                    await update.message.reply_text('❌ Please enter a positive number')
                    return
                
                if minutes < 5:
                    await update.message.reply_text('⚠️ Minimum interval: 5 minutes')
                    return
                
                scheduler.remove_all_jobs()
                
                scheduler.add_job(
                    send_backup,
                    IntervalTrigger(minutes=minutes),
                    args=(context,),
                    id='backup_job',
                    replace_existing=True
                )
                
                next_run = scheduler.get_jobs()[0].next_run_time.strftime('%Y-%m-%d %H:%M:%S')
                
                await update.message.reply_text(
                    f"✅ Schedule set successfully\n\n"
                    f"⏱ Interval: Every {minutes} minutes\n"
                    f"🕐 Next run: {next_run}"
                )
                
                logger.info(f"Schedule set: every {minutes} minutes")
                context.user_data['waiting_for_schedule'] = False
                
            except ValueError:
                await update.message.reply_text('❌ Please enter a valid number')
        else:
            await update.message.reply_text(
                'ℹ️ Use /start to begin'
            )


def main():
    """Main function"""
    try:
        logger.info("=" * 60)
        logger.info("Starting Telegram Backup Bot")
        logger.info(f"Python version: {sys.version}")
        logger.info(f"PTB version: {telegram.__version__} ({'Legacy' if PTB_LEGACY else 'Modern'})")
        logger.info(f"Backup directory: {BACKUP_DIR}")
        logger.info("=" * 60)
        
        if PTB_LEGACY:
            # Legacy PTB (13.x)
            updater = Updater(token=TELEGRAM_TOKEN, use_context=True)
            dispatcher = updater.dispatcher
            
            dispatcher.add_handler(CommandHandler("start", start))
            dispatcher.add_handler(CallbackQueryHandler(button))
            dispatcher.add_handler(MessageHandler(Filters.text & ~Filters.command, handle_message))
            
            scheduler.start()
            logger.info("✅ Scheduler started")
            
            logger.info("✅ Bot is ready (Legacy mode)")
            updater.start_polling()
            updater.idle()
            
        else:
            # Modern PTB (20.x)
            application = Application.builder().token(TELEGRAM_TOKEN).build()
            
            application.add_handler(CommandHandler("start", start))
            application.add_handler(CallbackQueryHandler(button))
            application.add_handler(MessageHandler(filters.TEXT & ~filters.COMMAND, handle_message))
            
            scheduler.start()
            logger.info("✅ Scheduler started")
            
            logger.info("✅ Bot is ready (Modern mode)")
            application.run_polling(
                allowed_updates=Update.ALL_TYPES,
                drop_pending_updates=True
            )
        
    except KeyboardInterrupt:
        logger.info("Bot stopped by user")
    except Exception as e:
        logger.error(f"Critical error: {e}", exc_info=True)
        sys.exit(1)
    finally:
        if scheduler.running:
            scheduler.shutdown()
        logger.info("Bot shutdown complete")


if __name__ == '__main__':
    main()
